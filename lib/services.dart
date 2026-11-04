import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
export 'package:flutter_v2ray_client/flutter_v2ray.dart' show V2ray, V2RayURL, V2RayStatus;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auto_switch.dart';
import 'data.dart';
import 'haptics.dart';
import 'widget_bridge.dart';

const kSubUa = 'v2rayNG/1.8.23';

/* ------------------------- IP Service ------------------------- */

class IpService {
  static String currentIp = '...';
  static bool fetching = false;

  static const _endpoints = [
    'https://api.ipify.org',
    'https://ifconfig.me/ip',
    'https://api4.my-ip.io/ip',
    'https://icanhazip.com',
  ];

  static Future<String> refresh() async {
    if (fetching) return currentIp;
    fetching = true;
    try {
      for (final ep in _endpoints) {
        try {
          final res = await http.get(Uri.parse(ep)).timeout(const Duration(seconds: 3));
          if (res.statusCode == 200) {
            final body = res.body.trim();
            if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(body)) {
              currentIp = body;
              return currentIp;
            }
          }
        } catch (_) {}
      }
    } finally {
      fetching = false;
    }
    return currentIp;
  }
}

/* ------------------------- subscriptions store ------------------------- */

class Store {
  static late SharedPreferences _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  static List<Subscription> loadSubs() {
    final raw = _p.getStringList('subs') ?? [];
    return raw
        .map((e) => Subscription.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .where((s) => s.id != 'quattro' && s.id != 'gemini') // strip demo subs
        .toList();
  }

  static Future<void> clearAll() async {
    await _p.remove('subs');
    await _p.remove('servers');
    await _p.remove('selected');
    await _p.remove('last_v2ray_config');
    await _p.remove('last_v2ray_remark');
    await _p.remove('vpn_active');
  }

  static void saveSubs(List<Subscription> subs) {
    _p.setStringList('subs', subs.map((s) => jsonEncode(s.toJson())).toList());
  }

  static List<ServerData> loadServers() {
    final raw = _p.getStringList('servers') ?? [];
    final list = raw
        .map((e) => ServerData.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .where((s) => s.vlessUrl != null && s.vlessUrl!.isNotEmpty) // only real servers
        .toList();

    var changed = false;
    for (final s in list) {
      if (s.vlessUrl != null) {
        final healed = sanitizeVlessUrl(s.vlessUrl!);
        if (healed != s.vlessUrl) {
          s.vlessUrl = healed;
          changed = true;
        }
      }
      // Re-evaluate flags & stripped names
      if (isTechnicalOrAuto(s.name) || isTechnicalOrAuto(s.rawName)) {
        if (s.flag != null) {
          s.flag = null;
          changed = true;
        }
      } else {
        final f = detectCountryFlag(s.name);
        if (f != null && f != s.flag) {
          s.flag = f;
          changed = true;
        }
      }
      final cleanList = stripFlagEmojis(s.name);
      if (cleanList != s.name) {
        s.name = cleanList;
        changed = true;
      }
      final cleanPlate = stripAllEmojis(s.plateName);
      if (cleanPlate != s.plateName) {
        s.plateName = cleanPlate;
        changed = true;
      }
    }
    if (changed) saveServers(list);
    return list;
  }

  static void saveServers(List<ServerData> servers) {
    _p.setStringList('servers', servers.map((s) => jsonEncode(s.toJson())).toList());
  }

  static String? get pendingLink => _p.getString('pendingLink');
  static void clearPendingLink() => _p.remove('pendingLink');
}

/* ------------------------- vless url sanitization ------------------------- */

String sanitizeVlessUrl(String rawUrl) {
  var url = rawUrl.trim();
  // Normalize unknown uTLS fingerprints that crash older Go runtimes
  if (url.contains('fp=qq')) {
    url = url.replaceAll('fp=qq', 'fp=chrome');
  }
  // If URL has public key (pbk) it MUST have security=reality
  if (url.contains('pbk=') && !url.contains('security=reality')) {
    if (url.contains('security=')) {
      url = url.replaceAll(RegExp(r'security=[^&]*'), 'security=reality');
    } else {
      url = url.contains('?') ? '$url&security=reality' : '$url?security=reality';
    }
  }
  // Reality requires uTLS fingerprint. Insert into the query, never after the #fragment.
  if (url.contains('security=reality') && !url.contains('fp=')) {
    final hashIdx = url.indexOf('#');
    if (hashIdx == -1) {
      url = '$url&fp=chrome';
    } else {
      url = '${url.substring(0, hashIdx)}&fp=chrome${url.substring(hashIdx)}';
    }
  }
  return url;
}

/// Extracts query parameters from a vless:// URL without relying on Uri.parse
/// (fragments may contain raw unicode/emoji).
Map<String, String> vlessQueryParams(String url) {
  final noFrag = url.split('#').first;
  final qIdx = noFrag.indexOf('?');
  if (qIdx == -1) return const {};
  final out = <String, String>{};
  for (final part in noFrag.substring(qIdx + 1).split('&')) {
    final i = part.indexOf('=');
    if (i <= 0) continue;
    try {
      out[part.substring(0, i)] = Uri.decodeComponent(part.substring(i + 1).replaceAll('+', '%20'));
    } catch (_) {
      out[part.substring(0, i)] = part.substring(i + 1);
    }
  }
  return out;
}

/// Applies certificate pinning from the `pcs` / `vcn` share-link parameters.
///
/// Modern Xray cores (25.1.30+) removed `allowInsecure` entirely — setting it is
/// a hard config error, so trust must come from pinning instead. Both field
/// generations are set for core compatibility:
///  - `pinnedPeerCertSha256` (string, hex) — new cores (25.1.30+ / 26.x)
///  - `pinnedPeerCertificateChainSha256` (array, base64) — older cores
void _applyCertPinning(Map<String, dynamic> tls, String? pcs, String? vcn) {
  if (pcs != null && pcs.trim().isNotEmpty) {
    final hexList = <String>[];
    for (final e in pcs.split(',')) {
      final entry = e.trim();
      if (entry.isEmpty) continue;
      final hexOnly = entry.replaceAll(':', '').replaceAll(' ', '');
      final isHex = hexOnly.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(hexOnly);
      if (isHex) {
        hexList.add(hexOnly.toUpperCase());
      } else {
        try {
          final bytes = base64Decode(entry);
          hexList.add(bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join());
        } catch (_) {
          hexList.add(entry);
        }
      }
    }
    if (hexList.isNotEmpty) {
      tls['pinnedPeerCertSha256'] = hexList.join(',');
    }
  }
  if (vcn != null && vcn.trim().isNotEmpty) {
    tls['verifyPeerCertByName'] = vcn.trim();
  }
}

/* ------------------------- subscription fetching ------------------------- */

Future<(Subscription, List<ServerData>)> fetchSubscription(String rawLink, {required String subId}) async {
  var link = rawLink.trim();
  if (link.startsWith('happ://add/')) link = link.substring('happ://add/'.length);
  if (link.startsWith('develvpn://add/')) link = link.substring('develvpn://add/'.length);
  if (!link.startsWith('http')) link = 'https://$link';

  final res = await http.get(Uri.parse(link), headers: {'User-Agent': kSubUa}).timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw Exception('HTTP ${res.statusCode}');
  }
  final body = res.body.trim();

  // 1) plain vless:// lines
  List<String> urls = _vlessLines(body);

  // 2) base64-encoded list
  if (urls.isEmpty) {
    try {
      final decoded = utf8.decode(base64.decode(base64.normalize(body.replaceAll('\n', '').replaceAll('\r', ''))));
      urls = _vlessLines(decoded);
    } catch (_) {}
  }

  // 3) sing-box / xray JSON (array or object with outbounds)
  if (urls.isEmpty && (body.startsWith('[') || body.startsWith('{'))) {
    try {
      final j = jsonDecode(body);
      final outbounds = j is List ? j : (j['outbounds'] as List? ?? []);
      for (final o in outbounds) {
        if (o is! Map || (o['type'] != 'vless' && o['protocol'] != 'vless')) continue;
        final server = (o['server'] ?? '').toString();
        final port = (o['server_port'] ?? 443).toString();
        final uuid = (o['uuid'] ?? '').toString();
        if (server.isEmpty || uuid.isEmpty) continue;

        final tls = (o['tls'] ?? {}) as Map;
        final reality = (tls['reality'] ?? {}) as Map;
        final isReality = reality['enabled'] == true || reality.isNotEmpty;
        final isTls = (tls['enabled'] == true) || isReality;
        final security = isReality
            ? 'reality'
            : (isTls ? 'tls' : (tls['streamSecurity'] ?? '').toString());

        final sni = (tls['server_name'] ?? tls['sni'] ?? '').toString();
        final fp = (tls['fingerprint'] ?? reality['fingerprint'] ?? (isReality ? 'chrome' : '')).toString();
        final pbk = (reality['public_key'] ?? '').toString();
        final sid = (reality['short_id'] ?? '').toString();
        final spx = (reality['spider_x'] ?? '').toString();

        final transport = (o['transport'] ?? {}) as Map;
        final netType = (o['network'] ?? transport['type'] ?? 'tcp').toString();
        final path = (transport['path'] ?? '').toString();
        final host = (transport['headers']?['Host'] ?? '').toString();

        final q = <String, String>{
          'encryption': 'none',
          if (o['flow'] != null && o['flow'] != '') 'flow': o['flow'].toString(),
          if (security.isNotEmpty) 'security': security,
          if (sni.isNotEmpty) 'sni': sni,
          if (fp.isNotEmpty) 'fp': fp,
          if (pbk.isNotEmpty) 'pbk': pbk,
          if (sid.isNotEmpty) 'sid': sid,
          if (spx.isNotEmpty) 'spx': spx,
          'type': netType,
          if (path.isNotEmpty) 'path': path,
          if (host.isNotEmpty) 'host': host,
          'headerType': 'none',
        };
        final query = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
        final tag = (o['tag'] ?? 'Server').toString();
        urls.add('vless://$uuid@$server:$port?$query#${Uri.encodeComponent(tag)}');
      }
    } catch (_) {}
  }

  if (urls.isEmpty) throw Exception('No servers found in subscription (format not recognized)');

  // Parse real user traffic information from subscription header if provided
  int up = 0, down = 0, total = 0;
  final userInfoHeader = res.headers['subscription-userinfo'];
  if (userInfoHeader != null) {
    for (final part in userInfoHeader.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length == 2) {
        final k = kv[0].trim().toLowerCase();
        final v = int.tryParse(kv[1].trim()) ?? 0;
        if (k == 'upload') up = v;
        if (k == 'download') down = v;
        if (k == 'total') total = v;
      }
    }
  }

  final host = Uri.parse(link).host;
  final parts = host.split('.');
  final subName = parts.length >= 2 ? parts[parts.length - 2] : host;
  // Some providers ship a long human-readable description in the Announce
  // header (base64 utf-8) — keep it for the subscription info sheet.
  String? description;
  try {
    String? announce;
    for (final e in res.headers.entries) {
      if (e.key.toLowerCase() == 'announce') {
        announce = e.value;
        break;
      }
    }
    if (announce != null && announce.trim().isNotEmpty) {
      var b = announce.trim();
      if (b.startsWith('base64:')) b = b.substring(7).trim();
      final decoded = utf8.decode(
        base64.decode(base64.normalize(b.replaceAll('\n', '').replaceAll('\r', ''))),
        allowMalformed: true,
      );
      if (decoded.trim().isNotEmpty) description = decoded.trim();
    }
  } catch (_) {}

  final sub = Subscription(
    id: subId,
    name: subName,
    desc: '${urls.length} servers · auto-update',
    description: description,
    link: link,
    uploadBytes: up,
    downloadBytes: down,
    totalBytes: total,
  );

  final servers = <ServerData>[];
  var i = 0;
  for (final u in urls) {
    try {
      final sanitized = sanitizeVlessUrl(u);
      final parsed = V2ray.parseFromURL(sanitized);
      final rawName = parsed.remark.isEmpty ? 'Server ${i + 1}' : parsed.remark;
      final flag = detectCountryFlag(rawName);
      final listName = stripFlagEmojis(rawName);
      final plateName = stripAllEmojis(rawName);

      servers.add(ServerData(
        id: '${subId}_s$i',
        subId: subId,
        name: listName,
        plateName: plateName,
        rawName: rawName,
        city: parsed.address,
        flag: flag,
        pingMs: -1, // NO MOCK PING! Real measurement only
        load: 18,
        vlessUrl: sanitized,
      ));
      i++;
    } catch (_) {/* skip broken line */}
  }
  if (servers.isEmpty) throw Exception('No servers parsed from subscription');
  return (sub, servers);
}

List<String> _vlessLines(String text) {
  // NOTE: no hysteria2/hy2 — the bundled Xray core has no hysteria protocol,
  // so those links would show up as dead servers that auto-switch might pick.
  const validPrefixes = [
    'vless://',
    'vmess://',
    'trojan://',
    'ss://',
    'socks://',
  ];
  return text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => validPrefixes.any((p) => l.toLowerCase().startsWith(p)))
      .toList();
}

/* ------------------------- tunnel settings (applied to every generated config) ------------------------- */

/// Global tunnel-level settings (Happ-style). Kept in memory and mirrored to
/// SharedPreferences by [AppState]; applied by [buildOptimizedConfig] and
/// [VpnController.connect] on every (re)connect.
class TunnelSettings {
  static bool fragment = false; // TLS fragmentation to fight DPI
  static bool mux = false; // multiplex connections (ignored for vision flow)
  static String ipStrategy = 'auto'; // auto | ipv4 | ipv6
  static bool blockAds = false; // geosite:category-ads-all -> blackhole
  static String customDns = '1.1.1.1';
  static bool bypassLan = false;
  static String pingUrl = 'https://cp.cloudflare.com/generate_204';
  static bool showPingInNotification = true;

  static void loadFromMap(Map<String, Object?> p) {
    showPingInNotification = p['show_ping_in_notification'] as bool? ?? true;
    fragment = p['tunnel_fragment'] as bool? ?? false;
    mux = p['tunnel_mux'] as bool? ?? false;
    ipStrategy = p['tunnel_ip_strategy'] as String? ?? 'auto';
    blockAds = p['tunnel_block_ads'] as bool? ?? false;
    customDns = p['custom_dns'] as String? ?? '1.1.1.1';
    bypassLan = p['bypass_lan'] as bool? ?? false;
    pingUrl = p['tunnel_ping_url'] as String? ?? 'https://cp.cloudflare.com/generate_204';
  }
}

/// Well-known delay-test endpoints (Happ-style ping service presets).
const kPingServicePresets = <(String, String, String)>[
  ('cloudflare', 'Cloudflare', 'https://cp.cloudflare.com/generate_204'),
  ('google', 'Google', 'https://www.gstatic.com/generate_204'),
  ('telegram', 'Telegram', 'https://web.telegram.org/a/'),
  ('instagram', 'Instagram', 'https://www.instagram.com'),
  ('youtube', 'YouTube', 'https://www.youtube.com/generate_204'),
  ('apple', 'Apple', 'https://captive.apple.com/hotspot-detect.html'),
];

/// Subnets excluded from the VPN tunnel when "Bypass LAN" is on.
const kLanBypassSubnets = [
  '192.168.0.0/16',
  '10.0.0.0/8',
  '172.16.0.0/12',
  '169.254.0.0/16',
  '224.0.0.0/3',
  'fe80::/10',
];

String buildOptimizedConfig(String rawVlessUrl) {
  final vlessUrl = sanitizeVlessUrl(rawVlessUrl);
  final rawConfig = V2ray.parseFromURL(vlessUrl).getFullConfiguration();
  final configMap = jsonDecode(rawConfig) as Map<String, dynamic>;

  // Enable sniffing so Android DNS queries and domain requests are resolved properly
  if (configMap['inbounds'] is List && (configMap['inbounds'] as List).isNotEmpty) {
    final in0 = (configMap['inbounds'] as List)[0];
    if (in0 is Map) {
      in0['sniffing'] = {
        'enabled': true,
        'destOverride': ['http', 'tls', 'quic'],
      };
    }
  }

  // Sanitize outbounds to prevent Xray/V2Ray config validation errors.
  // NOTE: never write `allowInsecure` — Xray 25.1.30+ rejects the whole config
  // because of it (this silently killed every tls/grpc server). Trust comes
  // from certificate pinning (`pcs`/`vcn` share-link params) instead.
  final qParams = vlessQueryParams(vlessUrl);
  final pcs = qParams['pcs'];
  final vcn = qParams['vcn'];
  if (configMap['outbounds'] is List) {
    for (final out in configMap['outbounds']) {
      if (out is Map && out['streamSettings'] is Map) {
        final stream = out['streamSettings'] as Map<String, dynamic>;
        final sec = (stream['security'] as String?)?.toLowerCase() ?? '';

        if (sec == 'tls') {
          stream.remove('realitySettings');
          if (stream['tlsSettings'] is Map) {
            final tls = stream['tlsSettings'] as Map<String, dynamic>;
            tls.remove('publicKey');
            tls.remove('shortId');
            tls.remove('spiderX');
            tls.remove('allowInsecure');
            if (tls['fingerprint'] == 'qq' || tls['fingerprint'] == null) {
              tls['fingerprint'] = 'chrome';
            }
            _applyCertPinning(tls, pcs, vcn);
          }
        } else if (sec == 'reality') {
          stream.remove('tlsSettings');
          if (stream['realitySettings'] is Map) {
            final real = stream['realitySettings'] as Map<String, dynamic>;
            real.remove('allowInsecure');
            if (real['spiderX'] == null || real['spiderX'] == '') {
              real.remove('spiderX');
            }
            if (real['fingerprint'] == 'qq' || real['fingerprint'] == null) {
              real['fingerprint'] = 'chrome';
            }
          }
        }
      }
    }
  }

  // DNS: user-selected server first, then robust fallbacks so resolution
  // never hangs in Russian/filtered networks.
  final dnsServers = <String>[
    TunnelSettings.customDns,
    '1.1.1.1',
    '8.8.8.8',
    '77.88.8.8',
  ];
  configMap['dns'] = {
    'servers': dnsServers,
    if (TunnelSettings.ipStrategy == 'ipv4') 'queryStrategy': 'UseIPv4',
    if (TunnelSettings.ipStrategy == 'ipv6') 'queryStrategy': 'UseIPv6',
  };

  // Routing: preferred IP family + DNS proxy rules + optional ad blocking.
  final routing = (configMap['routing'] as Map<String, dynamic>? ?? <String, dynamic>{});
  routing['domainStrategy'] = switch (TunnelSettings.ipStrategy) {
    'ipv4' => 'UseIPv4',
    'ipv6' => 'UseIPv6',
    _ => 'UseIp',
  };
  final rules = (routing['rules'] as List? ?? []).toList();

  // Route all DNS queries through proxy outbound so LTE mobile networks (MTS/Megafon/Beeline/Tele2)
  // DPI cannot intercept or drop port 53 traffic.
  rules.add({
    'type': 'field',
    'port': '53,853',
    'outboundTag': 'proxy',
  });
  rules.add({
    'type': 'field',
    'ip': ['1.1.1.1', '8.8.8.8', '77.88.8.8', '1.0.0.1'],
    'outboundTag': 'proxy',
  });
  // Bypass flutter_v2ray_client's Utilities.java DNS leak:
  // Utilities.java automatically injects direct DNS on port 53/853 at index 0 UNLESS a direct rule on port 853 already exists.
  // We place a dummy rule matching an invalid domain so Utilities.java skips injecting direct DNS.
  rules.add({
    'type': 'field',
    'port': '853',
    'outboundTag': 'direct',
    'domain': ['domain:devel-vpn-bypass-leak.invalid'],
  });

  if (TunnelSettings.blockAds) {
    rules.add({
      'type': 'field',
      'domain': ['geosite:category-ads-all'],
      'outboundTag': 'blackhole',
    });
  }
  routing['rules'] = rules;
  configMap['routing'] = routing;

  // Mux: multiplexes connections over one stream — completely incompatible with
  // xtls-rprx-vision flow (Xray core rejects configs with mux on vision flow).
  // Cleanly remove mux if flow is present or if mux is disabled.
  if (configMap['outbounds'] is List) {
    final hasFlow = (vlessQueryParams(vlessUrl)['flow']?.isNotEmpty ?? false);
    for (final out in configMap['outbounds']) {
      if (out is Map && out['tag'] == 'proxy') {
        final outUsersFlow = (out['settings']?['vnext']?[0]?['users']?[0]?['flow'] as String?)?.isNotEmpty ?? false;
        if (hasFlow || outUsersFlow || !TunnelSettings.mux) {
          out.remove('mux');
        } else {
          out['mux'] = {'enabled': true, 'concurrency': 8};
        }
      }
    }
  }

  // Fragment: split the TLS ClientHello into small pieces to defeat DPI.
  // Implemented as a chained freedom outbound ("dialerProxy") — the official
  // Xray way. Works with reality/tls/grpc alike.
  if (TunnelSettings.fragment && configMap['outbounds'] is List) {
    final outs = configMap['outbounds'] as List;
    outs.add({
      'tag': 'fragment-out',
      'protocol': 'freedom',
      'settings': {
        'domainStrategy': 'AsIs',
        'fragment': {
          'packets': 'tlshello',
          'length': '100-200',
          'interval': '10-20',
        },
      },
    });
    for (final out in outs) {
      if (out is Map && out['tag'] == 'proxy') {
        final stream = (out['streamSettings'] as Map<String, dynamic>? ?? <String, dynamic>{});
        final sockopt = (stream['sockopt'] as Map<String, dynamic>? ?? <String, dynamic>{});
        sockopt['dialerProxy'] = 'fragment-out';
        stream['sockopt'] = sockopt;
        out['streamSettings'] = stream;
      }
    }
  }

  // Ensure system stats & policy are enabled for real-time speed tracking
  configMap['stats'] = {};
  configMap['policy'] = {
    'system': {
      'statsInboundUplink': true,
      'statsInboundDownlink': true,
      'statsOutboundUplink': true,
      'statsOutboundDownlink': true,
    },
  };

  // Keep some core logging so the Logs screen shows connection errors.
  final log = (configMap['log'] as Map<String, dynamic>? ?? <String, dynamic>{});
  log['loglevel'] = 'warning';
  configMap['log'] = log;

  return jsonEncode(configMap);
}

/* --------------- foreground app detection (autoswitch exemptions) --------------- */

/// Returns the package id of the current foreground app, or null when
/// unavailable (no UsageStats permission / platform limitation).
Future<String?> getForegroundAppBundleId() async {
  try {
    return await MethodChannel('devel_vpn/apps').invokeMethod<String>('getForegroundApp');
  } catch (_) {
    return null;
  }
}

/// Opens the system screen where the user grants Usage Stats access.
Future<void> openUsageStatsSettings() async {
  try {
    await MethodChannel('devel_vpn/apps').invokeMethod('openUsageAccessSettings');
  } catch (_) {}
}

Future<bool> hasUsageStatsPermission() async {
  try {
    return await MethodChannel('devel_vpn/apps').invokeMethod<bool>('hasUsageAccess') ?? false;
  } catch (_) {
    return false;
  }
}

/* ------------------------- per-app proxy ------------------------- */

const _appsChannel = MethodChannel('devel_vpn/apps');

/// Apps installed on the device: {'apps': [{'package','label'}], 'self': pkg}.
Future<(List<(String, String)>, String)> getInstalledApps() async {
  try {
    final res = await _appsChannel.invokeMethod<Map>('getInstalledApps');
    if (res != null) {
      final self = (res['self'] as String?) ?? '';
      final apps = (res['apps'] as List? ?? [])
          .whereType<Map>()
          .map((m) => ((m['package'] ?? '') as String, (m['label'] ?? '') as String))
          .where((a) => a.$1.isNotEmpty)
          .toList();
      return (apps, self);
    }
  } catch (_) {}
  return (<(String, String)>[], '');
}

/// Computes the `blockedApps` list for startV2Ray according to the per-app
/// proxy mode:
///  - disabled        → null (everything goes through the tunnel)
///  - exclude (list)  → the listed apps bypass the VPN
///  - include (list)  → everything EXCEPT the listed apps bypasses the VPN
Future<List<String>?> computeBlockedApps(SharedPreferences sp) async {
  final enabled = sp.getBool('app_proxy_enabled') ?? false;
  if (!enabled) return null;
  final selected = sp.getStringList('app_proxy_list') ?? [];
  if (selected.isEmpty) return null;
  final mode = sp.getString('app_proxy_mode') ?? 'exclude';

  if (mode == 'exclude') {
    return selected;
  }

  // include: block everything except the selection (minus our own app so the
  // controller keeps working).
  final (apps, self) = await getInstalledApps();
  final blocked = apps.map((a) => a.$1).toSet()
    ..removeAll(selected)
    ..remove(self);
  return blocked.toList();
}

/* ------------------------- VPN Controller ------------------------- */

enum VpnPhase { idle, connecting, connected }

class VpnController extends ChangeNotifier {
  V2ray? _v2ray;
  VpnPhase phase = VpnPhase.idle;
  ServerData? active;
  ServerData? _lastActive;
  ServerData? get lastActive => _lastActive;
  static const _notifChannel = MethodChannel('devel_vpn/notification');

  Future<void> updateNotificationPing({int? ping}) async {
    try {
      final s = active ?? _lastActive;
      if (s == null) return;
      final sp = await SharedPreferences.getInstance();
      final notifEmojiMode = EmojiFilterMode.fromString(
        sp.getString('notification_emoji_mode'),
        EmojiFilterMode.hideAll,
      );
      final cleanBase = s.notificationName(notifEmojiMode).replaceAll('(', ' · ').replaceAll(')', '').trim();
      final effectivePing = (TunnelSettings.showPingInNotification) ? (ping ?? realPing ?? (s.pingMs > 0 ? s.pingMs : null)) : null;
      await _notifChannel.invokeMethod('updateNotification', {
        'title': cleanBase,
        'content': phase == VpnPhase.connected ? 'Connected' : 'Connecting...',
        'ping': (effectivePing != null && effectivePing > 0) ? effectivePing : null,
      });
    } catch (_) {}
  }
  String? lastError;
  int? realPing;
  bool testingPing = false;
  int uploadSpeed = 0;
  int downloadSpeed = 0;
  int _gen = 0;
  DateTime? _lastPingCheck;
  DateTime? _lastSpeedCalcTime;
  String _cachedSpeedDisplay = '0 KB/s';
  bool _isSwitching = false;
  DateTime? _ignoreDisconnectsUntil;
  DateTime? _ignoreConnectsUntil;
  DateTime? _connectedAt;
  void Function(int ping)? onPingResult;
  bool autoRestore = false; // kill switch: re-establish tunnel on unexpected drops

  String get speedDisplay {
    if (phase != VpnPhase.connected) return '0 KB/s';
    final now = DateTime.now();
    if (_lastSpeedCalcTime == null || now.difference(_lastSpeedCalcTime!).inSeconds >= 3) {
      _lastSpeedCalcTime = now;
      final total = downloadSpeed + uploadSpeed;
      if (total <= 0) {
        _cachedSpeedDisplay = '0.0 KB/s';
      } else if (total < 1024 * 1024) {
        _cachedSpeedDisplay = '${(total / 1024).toStringAsFixed(1)} KB/s';
      } else {
        _cachedSpeedDisplay = '${(total / (1024 * 1024)).toStringAsFixed(1)} MB/s';
      }
    }
    return _cachedSpeedDisplay;
  }

  void onStatusChanged(V2RayStatus s) {
    debugPrint('V2Ray status: state=${s.state} duration=${s.duration} up=${s.uploadSpeed} down=${s.downloadSpeed}');
    uploadSpeed = s.uploadSpeed;
    downloadSpeed = s.downloadSpeed;
    if (s.state == 'CONNECTED') {
      // The core sometimes replays a stale CONNECTED event right after we
      // told it to stop — never let it flip the UI back on.
      final nowConn = DateTime.now();
      if (_ignoreConnectsUntil != null && nowConn.isBefore(_ignoreConnectsUntil!)) return;
      _isSwitching = false;
      _connectedAt = DateTime.now();
      final wasNotConnected = phase != VpnPhase.connected;
      phase = VpnPhase.connected;
      lastError = null;
      _syncTileActive(true);
      WidgetBridge.push(connected: true);
      if (wasNotConnected) {
        Haptics.connected();
        IpService.refresh().then((_) => notifyListeners());
        _lastPingCheck = DateTime.now();
        updateNotificationPing();
        checkConnectedPing();
      } else {
        // Only refresh ping every 10 seconds, not on every 1-second status tick
        final now = DateTime.now();
        if (_lastPingCheck == null || now.difference(_lastPingCheck!).inSeconds >= 10) {
          _lastPingCheck = now;
          checkConnectedPing();
        }
      }
      notifyListeners();
    } else if (s.state == 'DISCONNECTED') {
      final now = DateTime.now();
      // Ignore disconnect events during switching, connecting, or if an old service is tearing down
      if (phase == VpnPhase.connecting || _isSwitching) return;
      if (_ignoreDisconnectsUntil != null && now.isBefore(_ignoreDisconnectsUntil!)) return;
      if (_connectedAt != null && now.difference(_connectedAt!).inMilliseconds < 1500) return;

      _lastActive = active;
      phase = VpnPhase.idle;
      realPing = null;
      uploadSpeed = 0;
      downloadSpeed = 0;
      _cachedSpeedDisplay = '0 KB/s';
      _syncTileActive(false);
      WidgetBridge.push(connected: false);
      IpService.refresh().then((_) => notifyListeners());
      notifyListeners();

      // Kill switch mode: the tunnel dropped on its own — restore it.
      if (autoRestore && active?.vlessUrl != null) {
        final target = active;
        Timer(const Duration(milliseconds: 1200), () {
          if (phase == VpnPhase.idle && target != null && active?.id == target.id) {
            connect(target);
          }
        });
      }
    }
  }

  void _syncTileActive(bool active) {
    SharedPreferences.getInstance().then((p) => p.setBool('vpn_active', active));
  }

  Future<void> init() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final v = V2ray(onStatusChanged: onStatusChanged);
      _v2ray = v;
      await v.initialize(
        notificationIconResourceType: 'drawable',
        notificationIconResourceName: 'ic_notification',
      );
      IpService.refresh().then((_) => notifyListeners());
    } catch (e) {
      lastError = 'v2ray init: $e';
      debugPrint(lastError);
    }
  }

  bool get coreReady => _v2ray != null;
  V2ray? get core => _v2ray;

  /// How long the current tunnel has been up (null when not connected).
  Duration? get connectedFor =>
      phase == VpnPhase.connected && _connectedAt != null ? DateTime.now().difference(_connectedAt!) : null;

  Future<void> checkConnectedPing() async {
    final v2 = _v2ray;
    if (v2 == null) return;
    testingPing = true;
    notifyListeners();
    try {
      int delay = -1;
      if (phase == VpnPhase.connected) {
        // Query running tunnel delay with timeout. Never fake ping through direct Wi-Fi.
        delay = await v2.getConnectedServerDelay(url: TunnelSettings.pingUrl)
            .timeout(const Duration(milliseconds: 4500), onTimeout: () => -1);
      } else if (active?.vlessUrl != null) {
        final cfg = buildOptimizedConfig(active!.vlessUrl!);
        delay = await v2.getServerDelay(config: cfg, url: TunnelSettings.pingUrl)
            .timeout(const Duration(milliseconds: 4500), onTimeout: () => -1);
      }

      if (delay > 0) {
        realPing = delay;
        if (active != null) active!.pingMs = delay;
        lastError = null;
        updateNotificationPing(ping: delay);
      } else {
        realPing = -1;
        if (active != null) active!.pingMs = -1;
      }
    } catch (e) {
      debugPrint('Ping error: $e');
      realPing = -1;
    } finally {
      testingPing = false;
      notifyListeners();
      onPingResult?.call(realPing ?? -1);
    }
  }

  Future<int> testServerDelay(ServerData s) async {
    final v2 = _v2ray;
    if (v2 == null || s.vlessUrl == null || s.vlessUrl!.isEmpty) return -1;
    try {
      final cfg = buildOptimizedConfig(s.vlessUrl!);
      final d = await v2
          .getServerDelay(config: cfg, url: TunnelSettings.pingUrl)
          .timeout(const Duration(seconds: 5), onTimeout: () => -1);
      return d;
    } catch (_) {
      return -1;
    }
  }

  Future<bool> connect(ServerData s) async {
    if (phase == VpnPhase.connecting && !_isSwitching) return false;
    if (phase == VpnPhase.connected && !_isSwitching) {
      _isSwitching = true;
      await disconnect();
      await Future.delayed(const Duration(milliseconds: 600));
      _isSwitching = false;
    }
    final gen = ++_gen;
    active = s;
    phase = VpnPhase.connecting;
    lastError = null;
    realPing = null;
    notifyListeners();
    bool cancelled() => gen != _gen;

    final v2 = _v2ray;
    if (s.vlessUrl == null || v2 == null) {
      phase = VpnPhase.idle;
      lastError = 'No configuration for server';
      notifyListeners();
      return false;
    }

    try {
      final granted = await v2.requestPermission();
      if (!granted) {
        phase = VpnPhase.idle;
        lastError = 'VPN permission denied';
        notifyListeners();
        return false;
      }
      // Refresh tunnel settings from storage (tile/other entry points may
      // have changed them while the app process was away).
      final sp = await SharedPreferences.getInstance();
      TunnelSettings.loadFromMap({
        'tunnel_fragment': sp.getBool('tunnel_fragment'),
        'tunnel_mux': sp.getBool('tunnel_mux'),
        'tunnel_ip_strategy': sp.getString('tunnel_ip_strategy'),
        'tunnel_block_ads': sp.getBool('tunnel_block_ads'),
        'custom_dns': sp.getString('custom_dns'),
        'bypass_lan': sp.getBool('bypass_lan'),
        'tunnel_ping_url': sp.getString('tunnel_ping_url'),
        'show_ping_in_notification': sp.getBool('show_ping_in_notification'),
      });

      final config = buildOptimizedConfig(s.vlessUrl!);
      // Round brackets get cut mid-way by the Android notification title —
      // replace them with a separator dot so names like "Италия (Мост)" stay whole.
      final notifEmojiMode = EmojiFilterMode.fromString(sp.getString('notification_emoji_mode'), EmojiFilterMode.hideAll);
      final cleanBase = s.notificationName(notifEmojiMode).replaceAll('(', ' · ').replaceAll(')', '').trim();
      final hasInitPing = TunnelSettings.showPingInNotification && s.pingMs > 0;
      final cleanRemark = hasInitPing ? '$cleanBase · ${s.pingMs} ms' : cleanBase;
      await sp.setString('last_v2ray_config', config);
      await sp.setString('last_v2ray_remark', cleanRemark);

      // Per-app proxy + LAN bypass are applied at the VpnService level.
      final blockedApps = await computeBlockedApps(sp);
      await v2.startV2Ray(
        remark: cleanRemark,
        config: config,
        blockedApps: blockedApps,
        bypassSubnets: TunnelSettings.bypassLan ? kLanBypassSubnets : null,
        notificationDisconnectButtonName: 'DISCONNECT',
      );

      // Wait up to 6s for CONNECTED status event
      var waited = 0;
      while (waited < 6000 && phase == VpnPhase.connecting && !cancelled()) {
        await Future.delayed(const Duration(milliseconds: 250));
        waited += 250;
      }

      if (cancelled()) return false;
      if (phase != VpnPhase.connected) {
        // Fallback check
        final delay = await v2.getConnectedServerDelay(url: TunnelSettings.pingUrl)
            .timeout(const Duration(seconds: 3), onTimeout: () => -1);
        if (delay > 0) {
          phase = VpnPhase.connected;
          _isSwitching = false;
          Haptics.connected();
          IpService.refresh().then((_) => notifyListeners());
          checkConnectedPing();
          notifyListeners();
          return true;
        } else {
          phase = VpnPhase.idle;
          lastError = 'Connection failed';
          notifyListeners();
          return false;
        }
      }
      return true;
    } catch (e) {
      if (cancelled()) return false;
      phase = VpnPhase.idle;
      lastError = 'connect: $e';
      debugPrint(lastError);
      notifyListeners();
      return false;
    }
  }

  /// Seamless server switch: cleanly stops previous service, waits for complete unbind, and connects to new
  Future<void> switchServer(ServerData? newServer) async {
    if (newServer == null) return;
    active = newServer;
    notifyListeners();
    if (phase == VpnPhase.connected || phase == VpnPhase.connecting) {
      _isSwitching = true;
      _ignoreDisconnectsUntil = DateTime.now().add(const Duration(milliseconds: 2500));
      final v2 = _v2ray;
      if (v2 != null) {
        try {
          await v2.stopV2Ray();
        } catch (_) {}
      }
      phase = VpnPhase.connecting;
      notifyListeners();
      // Wait for Android VpnService to fully unbind and release tun fd
      await Future.delayed(const Duration(milliseconds: 500));
      await connect(newServer);
      _isSwitching = false;
    }
  }

  Future<void> tap(ServerData? s) async {
    if (phase == VpnPhase.connecting) {
      _gen++;
      phase = VpnPhase.idle;
      active = null;
      AutoSwitchEngine.markManual(); // user aborted — stop any auto-scan
      Haptics.light();
      notifyListeners();
      return;
    }
    if (phase == VpnPhase.connected) {
      Haptics.light();
      AutoSwitchEngine.markManual();
      await disconnect();
      return;
    }
    if (s != null) {
      AutoSwitchEngine.markManual();
      await Haptics.connecting(); // single-pulse on connect start
      await connect(s);
    }
  }

  String get currentPublicIp => IpService.currentIp;

  Future<void> disconnect() async {
    _ignoreDisconnectsUntil = null;
    _ignoreConnectsUntil = DateTime.now().add(const Duration(milliseconds: 2500));
    _connectedAt = null;
    phase = VpnPhase.idle;
    _lastActive = active;
    active = null;
    realPing = null;
    uploadSpeed = 0;
    downloadSpeed = 0;
    _cachedSpeedDisplay = '0 KB/s';
    _syncTileActive(false);
    notifyListeners();
    final v2 = _v2ray;
    if (v2 != null) {
      try {
        await v2.stopV2Ray();
      } catch (_) {}
    }
    IpService.refresh().then((_) => notifyListeners());
  }
}
