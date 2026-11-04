import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auto_switch.dart';
import 'data.dart';
import 'haptics.dart';
import 'l10n.dart';
import 'ping_manager.dart';
import 'services.dart';
import 'theme.dart';

/// Global app state: subscriptions, servers, selection, tabs, ui flags.
class AppState extends ChangeNotifier {
  final VpnController vpn = VpnController();

  AppState() {
    vpn.onPingResult = (ping) {
      checkAndAutoSwitch(ping);
    };
  }

  int tab = 0;
  List<Subscription> subs = [];
  List<ServerData> servers = [];
  String selectedId = '';

  /* localization */
  String language = 'en';
  AppStrings get strings => AppStrings(language);

  /* settings */
  bool autoConnect = false;
  bool autoSwitch = true;
  int autoSwitchThreshold = 650;
  ScanScope autoSwitchScope = ScanScope.all;
  String autoSwitchSubId = 'all'; // 'all' or a specific subscription id
  bool killSwitch = false;
  bool bypassLan = false;
  String customDns = '1.1.1.1';
  int pingThreads = 15;
  bool pingCoreMethod = false; // false = light TCP scan, true = core delay
  bool backgroundPing = true; // keep pings fresh in the background
  int pingCacheMinutes = 5; // background refresh interval
  EmojiFilterMode inAppEmojiMode = EmojiFilterMode.hideFlags;
  EmojiFilterMode notificationEmojiMode = EmojiFilterMode.hideAll;

  /* tunnel settings (Happ-style) */
  bool showPingInNotification = true;
  bool tunnelFragment = false;
  bool tunnelMux = false;
  String ipStrategy = 'auto'; // auto | ipv4 | ipv6
  bool blockAds = false;
  bool appProxyEnabled = false;
  String appProxyMode = 'exclude'; // exclude | include
  List<String> appProxyList = [];
  bool groupByCountry = false;
  List<String> pinnedCountries = [];
  bool lightTheme = false;
  String themeMode = 'dark'; // system | dark | light
  int autoRefreshHours = 0; // 0 = off
  List<String> autoswitchExemptApps = [];

  /* servers tab ui state */
  bool merged = false;
  bool showFavoritesOnly = false;
  String sortBy = 'default';
  String searchQ = '';

  int rippleSeed = 0;

  String? get pendingLink => Store.pendingLink;

  ServerData? get selected {
    for (final s in servers) {
      if (s.id == selectedId) return s;
    }
    return servers.isEmpty ? null : servers.first;
  }

  Subscription? get selectedSub {
    final sel = selected;
    if (sel == null) return subs.isEmpty ? null : subs.first;
    for (final s in subs) {
      if (s.id == sel.subId) return s;
    }
    return subs.isEmpty ? null : subs.first;
  }

  Future<void> load() async {
    await Store.init();
    subs = Store.loadSubs();
    servers = Store.loadServers();

    final prefs = await SharedPreferences.getInstance();
    language = prefs.getString('app_lang') ?? 'en';
    autoConnect = prefs.getBool('auto_connect') ?? false;
    autoSwitch = prefs.getBool('auto_switch') ?? true;
    autoSwitchThreshold = prefs.getInt('auto_switch_threshold') ?? 650;
    autoSwitchScope = ScanScope.values.firstWhere(
      (e) => e.name == (prefs.getString('auto_switch_scope') ?? 'all'),
      orElse: () => ScanScope.all,
    );
    autoSwitchSubId = prefs.getString('auto_switch_sub') ?? 'all';
    killSwitch = prefs.getBool('kill_switch') ?? false;
    bypassLan = prefs.getBool('bypass_lan') ?? false;
    customDns = prefs.getString('custom_dns') ?? '1.1.1.1';
    pingThreads = prefs.getInt('ping_threads') ?? 15;
    pingCoreMethod = prefs.getBool('ping_core_method') ?? false;
    showPingInNotification = prefs.getBool('show_ping_in_notification') ?? true;
    tunnelFragment = prefs.getBool('tunnel_fragment') ?? false;
    tunnelMux = prefs.getBool('tunnel_mux') ?? false;
    ipStrategy = prefs.getString('tunnel_ip_strategy') ?? 'auto';
    blockAds = prefs.getBool('tunnel_block_ads') ?? false;
    appProxyEnabled = prefs.getBool('app_proxy_enabled') ?? false;
    appProxyMode = prefs.getString('app_proxy_mode') ?? 'exclude';
    appProxyList = prefs.getStringList('app_proxy_list') ?? [];
    groupByCountry = prefs.getBool('group_by_country') ?? false;
    pinnedCountries = prefs.getStringList('pinned_countries') ?? [];
    themeMode = prefs.getString('theme_mode') ?? 'dark';
    _applyThemeMode(prefs.getString('theme_mode') ?? 'dark');
    autoRefreshHours = prefs.getInt('auto_refresh_hours') ?? 0;
    autoswitchExemptApps = prefs.getStringList('autoswitch_exempt_apps') ?? [];
    backgroundPing = prefs.getBool('background_ping') ?? true;
    pingCacheMinutes = prefs.getInt('ping_cache_minutes') ?? 5;
    inAppEmojiMode = EmojiFilterMode.fromString(
      prefs.getString('in_app_emoji_mode'),
      EmojiFilterMode.hideFlags,
    );
    notificationEmojiMode = EmojiFilterMode.fromString(
      prefs.getString('notification_emoji_mode'),
      EmojiFilterMode.hideAll,
    );
    await PingManager.restoreCache(servers);
    _restoreUsage(prefs);

    final sel = prefs.getString('selected');
    if (sel != null && servers.any((s) => s.id == sel)) {
      selectedId = sel;
    } else if (servers.isNotEmpty) {
      selectedId = servers.first.id;
    }

    // Mirror settings into the global tunnel config + controller flags.
    TunnelSettings.pingUrl = prefs.getString('tunnel_ping_url') ?? TunnelSettings.pingUrl;
    _pushTunnelSettings();
    vpn.autoRestore = killSwitch;
    _syncTileConfig();
    notifyListeners();
  }

  void setLanguage(String lang) {
    if (language == lang) return;
    language = lang;
    SharedPreferences.getInstance().then((p) => p.setString('app_lang', lang));
    notifyListeners();
  }

  void setAutoConnect(bool v) {
    autoConnect = v;
    SharedPreferences.getInstance().then((p) => p.setBool('auto_connect', v));
    notifyListeners();
  }

  void setAutoSwitch(bool v) {
    autoSwitch = v;
    SharedPreferences.getInstance().then((p) => p.setBool('auto_switch', v));
    notifyListeners();
  }

  void setAutoSwitchThreshold(int ms) {
    autoSwitchThreshold = ms;
    SharedPreferences.getInstance().then((p) => p.setInt('auto_switch_threshold', ms));
    notifyListeners();
  }

  void setAutoSwitchScope(ScanScope scope) {
    if (autoSwitchScope == scope) return;
    autoSwitchScope = scope;
    SharedPreferences.getInstance().then((p) => p.setString('auto_switch_scope', scope.name));
    notifyListeners();
  }

  void setAutoSwitchSubId(String subId) {
    if (autoSwitchSubId == subId) return;
    autoSwitchSubId = subId;
    SharedPreferences.getInstance().then((p) => p.setString('auto_switch_sub', subId));
    notifyListeners();
  }

  /* tunnel settings setters — update TunnelSettings immediately so the very
     next generated config uses the new values */
  void _pushTunnelSettings() {
    TunnelSettings.fragment = tunnelFragment;
    TunnelSettings.mux = tunnelMux;
    TunnelSettings.ipStrategy = ipStrategy;
    TunnelSettings.blockAds = blockAds;
    TunnelSettings.customDns = customDns;
    TunnelSettings.bypassLan = bypassLan;
    TunnelSettings.showPingInNotification = showPingInNotification;
    _syncTileConfig();
  }

  void setShowPingInNotification(bool v) {
    showPingInNotification = v;
    SharedPreferences.getInstance().then((p) => p.setBool('show_ping_in_notification', v));
    _pushTunnelSettings();
    vpn.updateNotificationPing();
    notifyListeners();
  }

  void setTunnelFragment(bool v) {
    tunnelFragment = v;
    SharedPreferences.getInstance().then((p) => p.setBool('tunnel_fragment', v));
    _pushTunnelSettings();
    notifyListeners();
  }

  void setTunnelMux(bool v) {
    tunnelMux = v;
    SharedPreferences.getInstance().then((p) => p.setBool('tunnel_mux', v));
    _pushTunnelSettings();
    notifyListeners();
  }

  void setIpStrategy(String v) {
    ipStrategy = v;
    SharedPreferences.getInstance().then((p) => p.setString('tunnel_ip_strategy', v));
    _pushTunnelSettings();
    notifyListeners();
  }

  void setBlockAds(bool v) {
    blockAds = v;
    SharedPreferences.getInstance().then((p) => p.setBool('tunnel_block_ads', v));
    _pushTunnelSettings();
    notifyListeners();
  }

  void setAppProxyEnabled(bool v) {
    appProxyEnabled = v;
    SharedPreferences.getInstance().then((p) => p.setBool('app_proxy_enabled', v));
    notifyListeners();
  }

  void setAppProxyMode(String mode) {
    appProxyMode = mode;
    SharedPreferences.getInstance().then((p) => p.setString('app_proxy_mode', mode));
    notifyListeners();
  }

  void setAppProxyList(List<String> list) {
    appProxyList = list;
    SharedPreferences.getInstance().then((p) => p.setStringList('app_proxy_list', list));
    notifyListeners();
  }

  void setGroupByCountry(bool v) {
    groupByCountry = v;
    SharedPreferences.getInstance().then((p) => p.setBool('group_by_country', v));
    notifyListeners();
  }

  void _applyThemeMode(String mode) {
    if (mode == 'system') {
      // platform brightness is resolved at build time via AppColors.isLightSync
      // (set in main.dart on ui change); keep stored value for the row label.
      return;
    }
    lightTheme = mode == 'light';
    AppColors.isLight = lightTheme;
  }

  void setThemeMode(String mode) {
    themeMode = mode;
    SharedPreferences.getInstance().then((p) async {
      await p.setString('theme_mode', mode);
      await p.setBool('light_theme', mode == 'light');
    });
    _applyThemeMode(mode);
    notifyListeners();
  }

  void setAutoRefreshHours(int h) {
    autoRefreshHours = h;
    SharedPreferences.getInstance().then((p) => p.setInt('auto_refresh_hours', h));
    _ensureSubRefreshTimer();
    notifyListeners();
  }

  void setAutoswitchExemptApps(List<String> list) {
    autoswitchExemptApps = list;
    SharedPreferences.getInstance().then((p) => p.setStringList('autoswitch_exempt_apps', list));
    notifyListeners();
  }

  void togglePinnedCountry(String code) {
    if (pinnedCountries.contains(code)) {
      pinnedCountries.remove(code);
    } else {
      pinnedCountries.add(code);
    }
    SharedPreferences.getInstance().then((p) => p.setStringList('pinned_countries', pinnedCountries));
    notifyListeners();
  }

  void setInAppEmojiMode(EmojiFilterMode mode) {
    if (inAppEmojiMode == mode) return;
    inAppEmojiMode = mode;
    SharedPreferences.getInstance().then((p) => p.setString('in_app_emoji_mode', mode.name));
    notifyListeners();
  }

  void setNotificationEmojiMode(EmojiFilterMode mode) {
    if (notificationEmojiMode == mode) return;
    notificationEmojiMode = mode;
    SharedPreferences.getInstance().then((p) => p.setString('notification_emoji_mode', mode.name));
    notifyListeners();
  }

  void setPingMethod(bool core) {
    pingCoreMethod = core;
    SharedPreferences.getInstance().then((p) => p.setBool('ping_core_method', core));
    notifyListeners();
  }

  void setPingThreads(int n) {
    pingThreads = n;
    SharedPreferences.getInstance().then((p) => p.setInt('ping_threads', n));
    notifyListeners();
  }

  void setPingUrl(String url) {
    TunnelSettings.pingUrl = url;
    SharedPreferences.getInstance().then((p) => p.setString('tunnel_ping_url', url));
    notifyListeners();
  }

  void setKillSwitch(bool v) {
    killSwitch = v;
    vpn.autoRestore = v; // restore the tunnel right after an unexpected drop
    SharedPreferences.getInstance().then((p) => p.setBool('kill_switch', v));
    notifyListeners();
  }

  void setBypassLan(bool v) {
    bypassLan = v;
    SharedPreferences.getInstance().then((p) => p.setBool('bypass_lan', v));
    _pushTunnelSettings();
    notifyListeners();
  }

  void setCustomDns(String dns) {
    customDns = dns;
    SharedPreferences.getInstance().then((p) => p.setString('custom_dns', dns));
    _pushTunnelSettings();
    notifyListeners();
  }

  DateTime? _lastAutoSwitchAt;
  int _badPingStreak = 0;

  /// Triggers auto failover when the connected server's ping exceeds the
  /// threshold (or the check fails). Delegates to [AutoSwitchEngine]:
  /// scans candidate servers in batches of 20 with a light TCP ping, picks
  /// the fastest, switches and verifies it with a real core delay check.
  Future<void> checkAndAutoSwitch(int currentPing) async {
    if (!autoSwitch || vpn.phase != VpnPhase.connected) return;
    if (AutoSwitchEngine.isRunning) return; // engine manages its own flow
    if (await autoswitchPausedByApp()) return; // exempt foreground app: keep connection stable

    // A fresh tunnel needs time to warm up: the first delay checks right
    // after connecting are often slow or fail outright. Never judge a server
    // during warm-up and never act on a single bad sample.
    final connectedFor = vpn.connectedFor;
    if (connectedFor == null || connectedFor < const Duration(seconds: 20)) {
      _badPingStreak = 0;
      return;
    }
    if (currentPing > 0 && currentPing <= autoSwitchThreshold) {
      _badPingStreak = 0;
      return;
    }

    // Require two consecutive bad samples before even thinking about moving.
    _badPingStreak++;
    if (_badPingStreak < 2) return;

    // Respect a manual choice: no auto-switching for 90s after the user
    // picked or connected themselves.
    if (AutoSwitchEngine.sinceManualAction() < const Duration(seconds: 90)) return;

    // Cooldown between full scan sessions — but when the tunnel has been
    // dead for 3+ samples in a row, force a scan right away (no cooldown):
    // the user is effectively offline and waiting makes it worse.
    final now = DateTime.now();
    final force = _badPingStreak >= 3;
    if (!force && _lastAutoSwitchAt != null && now.difference(_lastAutoSwitchAt!).inSeconds < 60) return;
    _lastAutoSwitchAt = now;

    final pool = _autoSwitchPool();
    if (pool.isEmpty) return;

    final currentId = selectedId;
    _badPingStreak = 0;
    final switchedTo = await AutoSwitchEngine.scanAndSwitch(
      pool: pool,
      excludedIds: AutoSwitchEngine.failedIds,
      threshold: autoSwitchThreshold,
      // TCP pings of other servers made while connected go through the tunnel:
      // subtract the current server's direct RTT measured by the core.
      connectedOverheadMs: (vpn.realPing != null && vpn.realPing! > 0) ? vpn.realPing! : 0,
      stillWanted: () => vpn.phase == VpnPhase.connected && selectedId == currentId,
      onPickCandidate: (candidate) async {
        select(candidate.id, manual: false);
        // Wait for the switch to complete (connect → CONNECTED).
        final deadline = DateTime.now().add(const Duration(seconds: 25));
        while (DateTime.now().isBefore(deadline)) {
          if (vpn.phase == VpnPhase.connected && vpn.active?.id == candidate.id) break;
          if (vpn.phase == VpnPhase.idle) return; // user aborted / failed
          await Future.delayed(const Duration(milliseconds: 200));
        }
      },
      verifyRealPing: () async {
        // Deep check: up to 3 samples — a freshly switched tunnel often needs
        // a couple of seconds before delay checks succeed.
        int best = -1;
        for (var attempt = 0; attempt < 3; attempt++) {
          await vpn.checkConnectedPing();
          final p = vpn.realPing ?? -1;
          if (p > 0 && (best == -1 || p < best)) best = p;
          if (best > 0 && best <= autoSwitchThreshold) break;
          await Future.delayed(const Duration(milliseconds: 1500));
          if (!(vpn.phase == VpnPhase.connected && selectedId == currentId)) break;
        }
        return best;
      },
    );
    if (switchedTo != null) {
      AutoSwitchEngine.resetFailures();
      // Deep ping on the freshly chosen server: 3 measurements, keep the best
      // one so the UI shows a stable, honest number.
      for (var i = 0; i < 3; i++) {
        if (vpn.phase != VpnPhase.connected) break;
        await vpn.checkConnectedPing();
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    }
  }

  /// Candidate pool for the auto-switch scanner according to user settings:
  /// region scope (all / except Russia / favorites) × subscription scope.
  List<ServerData> _autoSwitchPool() {
    var pool = servers.where((s) => s.vlessUrl != null && s.vlessUrl!.isNotEmpty).toList();
    switch (autoSwitchScope) {
      case ScanScope.all:
        break;
      case ScanScope.noRu:
        pool = pool.where((s) => s.flag != 'ru').toList();
        break;
      case ScanScope.favorites:
        pool = pool.where((s) => s.isFavorite).toList();
        break;
    }
    if (autoSwitchSubId != 'all') {
      pool = pool.where((s) => s.subId == autoSwitchSubId).toList();
    }
    return pool;
  }

  void setBackgroundPing(bool v) {
    backgroundPing = v;
    SharedPreferences.getInstance().then((p) => p.setBool('background_ping', v));
    notifyListeners();
  }

  void setPingCacheMinutes(int m) {
    pingCacheMinutes = m;
    SharedPreferences.getInstance().then((p) => p.setInt('ping_cache_minutes', m));
    notifyListeners();
  }

  /* ---------- ping cache background refresh ---------- */

  Timer? _bgPingTimer;
  DateTime _lastBgScan = DateTime.fromMillisecondsSinceEpoch(0);
  bool _bgScanBusy = false;

  void _ensureBackgroundPingTimer() {
    _bgPingTimer?.cancel();
    _bgPingTimer = Timer.periodic(const Duration(minutes: 1), (_) => _bgPingTick());
  }

  Future<void> _bgPingTick() async {
    if (!backgroundPing || _bgScanBusy) return;
    if (DateTime.now().difference(_lastBgScan).inMinutes < pingCacheMinutes) return;
    if (servers.isEmpty) return;
    _bgScanBusy = true;
    _lastBgScan = DateTime.now();
    try {
      final stale = servers
          .where((s) => !s.mode && s.vlessUrl != null && s.vlessUrl!.isNotEmpty && !PingManager.isFresh(s))
          .toList();
      if (stale.isEmpty) return;
      // Refresh in small silent batches so the UI and battery stay calm.
      const chunk = 40;
      for (var i = 0; i < stale.length; i += chunk) {
        await PingManager.pingList(stale.skip(i).take(chunk).toList(), concurrency: pingThreads.clamp(4, 20));
        if (pingCacheMinutes <= 0) break;
        notifyListeners();
      }
      await PingManager.persistCache(servers);
    } finally {
      _bgScanBusy = false;
    }
  }

  /* ---------- auto-refresh subscriptions ---------- */

  Timer? _subRefreshTimer;
  DateTime _lastSubRefresh = DateTime.fromMillisecondsSinceEpoch(0);
  bool _subRefreshBusy = false;

  void _ensureSubRefreshTimer() {
    _subRefreshTimer?.cancel();
    if (autoRefreshHours <= 0) return;
    _subRefreshTimer = Timer.periodic(const Duration(minutes: 10), (_) => _subRefreshTick());
  }

  Future<void> _subRefreshTick() async {
    if (autoRefreshHours <= 0 || _subRefreshBusy || subs.isEmpty) return;
    if (DateTime.now().difference(_lastSubRefresh).inHours < autoRefreshHours) return;
    _subRefreshBusy = true;
    _lastSubRefresh = DateTime.now();
    try {
      for (final sub in List<Subscription>.from(subs)) {
        if (sub.link == null || sub.link!.isEmpty) continue;
        try {
          await refreshSubscription(sub.id);
        } catch (_) {}
      }
      notifyListeners();
    } finally {
      _subRefreshBusy = false;
    }
  }

  /// True if auto-switching is paused because the foreground app is in the
  /// user's exempt list (e.g. a game that must not reconnect mid-match).
  Future<bool> autoswitchPausedByApp() async {
    if (autoswitchExemptApps.isEmpty) return false;
    String? fg;
    try {
      fg = await getForegroundAppBundleId();
    } catch (_) {}
    return fg != null && autoswitchExemptApps.contains(fg);
  }

  /* ---------- usage statistics (time with VPN per server/subscription) ---------- */

  Map<String, int> srvSeconds = {};
  Map<String, int> subSeconds = {};
  Map<String, String> srvNames = {};
  Map<String, String> srvSubIds = {};
  int totalSeconds = 0;
  Timer? _usageTicker;
  int _ticksSinceSave = 0;

  void _restoreUsage(SharedPreferences prefs) {
    try {
      final raw = prefs.getString('usage_stats');
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        srvSeconds.clear();
        final srvMap = j['srv'];
        if (srvMap is Map) {
          srvMap.forEach((k, v) {
            if (v is num) srvSeconds[k.toString()] = v.toInt();
          });
        }
        subSeconds.clear();
        final subMap = j['sub'];
        if (subMap is Map) {
          subMap.forEach((k, v) {
            if (v is num) subSeconds[k.toString()] = v.toInt();
          });
        }
        srvNames.clear();
        final namesMap = j['names'];
        if (namesMap is Map) {
          namesMap.forEach((k, v) => srvNames[k.toString()] = v.toString());
        }
        srvSubIds.clear();
        final subIdsMap = j['subIds'];
        if (subIdsMap is Map) {
          subIdsMap.forEach((k, v) => srvSubIds[k.toString()] = v.toString());
        }
        totalSeconds = (j['total'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    _ensureUsageTracking();
    _ensureBackgroundPingTimer();
  }

  void _ensureUsageTracking() {
    vpn.removeListener(_usageVpnListener);
    vpn.addListener(_usageVpnListener);
    _usageVpnListener();
  }

  void _usageVpnListener() {
    if (vpn.phase == VpnPhase.connected) {
      if (_usageTicker == null || !_usageTicker!.isActive) {
        _usageTicker = Timer.periodic(const Duration(seconds: 1), (_) {
          final s = vpn.active ?? vpn.lastActive ?? selected;
          if (s != null) {
            srvSeconds[s.id] = (srvSeconds[s.id] ?? 0) + 1;
            subSeconds[s.subId] = (subSeconds[s.subId] ?? 0) + 1;
            srvNames[s.id] = s.name;
            srvSubIds[s.id] = s.subId;
          }
          totalSeconds += 1;
          _ticksSinceSave++;
          if (_ticksSinceSave >= 5) {
            _ticksSinceSave = 0;
            _saveUsage();
          }
          notifyListeners();
        });
      }
    } else {
      _usageTicker?.cancel();
      _usageTicker = null;
      _saveUsage();
      notifyListeners();
    }
  }

  void _saveUsage() {
    SharedPreferences.getInstance().then((p) => p.setString(
          'usage_stats',
          jsonEncode({
            'srv': srvSeconds,
            'sub': subSeconds,
            'names': srvNames,
            'subIds': srvSubIds,
            'total': totalSeconds,
          }),
        ));
  }

  String? get favoriteServerName {
    for (final s in servers) {
      if (s.isFavorite) return s.name;
    }
    return mostUsedServerName;
  }

  bool _speedTesting = false;
  double? lastSpeedMbps;

  bool get speedTesting => _speedTesting;

  /// General connection speed test: downloads a payload through the active
  /// tunnel (or direct when disconnected). Tries several endpoints so a
  /// blocked/slow one never kills the test.
  Future<double> runSpeedTest([ServerData? server]) async {
    if (_speedTesting) return lastSpeedMbps ?? 0;
    _speedTesting = true;
    notifyListeners();
    final endpoints = [
      'https://speed.cloudflare.com/__down?bytes=25000000',
      'https://proof.ovh.net/files/10Mb.dat',
      'https://nbg1-speed.hetzner.com/10MB.bin',
    ];
    double best = 0;
    try {
      for (final url in endpoints) {
        try {
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 8);
          final sw = Stopwatch()..start();
          var bytes = 0;
          final request = await client.getUrl(Uri.parse(url));
          final response = await request.close().timeout(const Duration(seconds: 20));
          await for (final chunk in response) {
            bytes += chunk.length;
            if (sw.elapsedMilliseconds > 8000) break;
          }
          client.close();
          sw.stop();
          if (sw.elapsedMilliseconds >= 500 && bytes > 50000) {
            final mbps = bytes * 8 / 1000 / 1000 / (sw.elapsedMilliseconds / 1000);
            if (mbps > best) best = mbps;
            if (best > 1) break; // good enough, stop trying
          }
        } catch (_) {
          continue;
        }
      }
    } finally {
      _speedTesting = false;
      if (best > 0) lastSpeedMbps = best;
      notifyListeners();
    }
    return best;
  }

  String? get mostUsedServerName {
    String? bestId;
    var best = 0;
    srvSeconds.forEach((id, secs) {
      if (secs > best) {
        best = secs;
        bestId = id;
      }
    });
    if (bestId != null) {
      if (srvNames.containsKey(bestId)) return srvNames[bestId];
      for (final s in servers) {
        if (s.id == bestId) return s.name;
      }
    }
    if (vpn.active != null) return vpn.active!.name;
    for (final s in servers) {
      if (s.isFavorite) return s.name;
    }
    if (selected != null) return selected!.name;
    return servers.isNotEmpty ? servers.first.name : null;
  }

  int subUsageSeconds(String subId) {
    var secs = subSeconds[subId] ?? 0;
    if (secs == 0) {
      srvSeconds.forEach((id, sSecs) {
        final sSub = srvSubIds[id] ?? '';
        if (sSub == subId || id.startsWith(subId) || id.startsWith('${subId}_')) {
          secs += sSecs;
        }
      });
    }
    return secs;
  }

  String? mostUsedServerNameFor(String subId) {
    String? bestId;
    var best = 0;
    srvSeconds.forEach((id, secs) {
      final sSub = srvSubIds[id] ?? '';
      final matches = sSub == subId || id.startsWith(subId) || id.startsWith('${subId}_');
      if (matches && secs > best) {
        best = secs;
        bestId = id;
      }
    });
    if (bestId != null) {
      if (srvNames.containsKey(bestId)) return srvNames[bestId];
      for (final s in servers) {
        if (s.id == bestId) return s.name;
      }
    }
    for (final s in servers) {
      if (s.subId == subId && s.isFavorite) return s.name;
    }
    if (vpn.active != null && (vpn.active!.subId == subId || vpn.active!.id.startsWith(subId))) {
      return vpn.active!.name;
    }
    if (selected != null && (selected!.subId == subId || selected!.id.startsWith(subId))) {
      return selected!.name;
    }
    for (final s in servers) {
      if (s.subId == subId) return s.name;
    }
    return null;
  }

  String? subDescription(String subId) {
    for (final s in subs) {
      if (s.id == subId) return s.description;
    }
    return null;
  }

  /// Manual subscription: user-provided name + pasted vless:// links.
  Future<void> addManualSubscription(String name, List<String> links) async {
    final subId = 'sub${DateTime.now().millisecondsSinceEpoch}';
    final servers0 = <ServerData>[];
    var i = 0;
    for (final raw in links) {
      final link = raw.trim();
      if (link.isEmpty) continue;
      try {
        final sanitized = sanitizeVlessUrl(link);
        final parsed = V2ray.parseFromURL(sanitized);
        final rawName = parsed.remark.isEmpty ? 'Server ${i + 1}' : parsed.remark;
        servers0.add(ServerData(
          id: '${subId}_s$i',
          subId: subId,
          name: stripFlagEmojis(rawName),
          plateName: stripAllEmojis(rawName),
          city: parsed.address,
          flag: detectCountryFlag(rawName),
          pingMs: -1,
          load: 18,
          vlessUrl: sanitized,
        ));
        i++;
      } catch (_) {/* skip broken line */}
    }
    if (servers0.isEmpty) throw Exception('No valid vless links');
    final sub = Subscription(
      id: subId,
      name: name.trim().isEmpty ? (isRuLang ? 'Ручная подписка' : 'Manual subscription') : name.trim(),
      desc: '${servers0.length} servers · manual',
      link: null,
    );
    subs.add(sub);
    servers.addAll(servers0);
    selectedId = servers0.first.id;
    Store.saveSubs(subs);
    Store.saveServers(servers);
    notifyListeners();
  }

  bool get isRuLang => language == 'ru';

  /* ---------- config export / import ---------- */

  /// Preference keys that belong to the user's setup and should travel with
  /// the export (everything else is runtime/ephemeral).
  static const _exportedPrefKeys = [
    'app_lang', 'auto_connect', 'auto_switch', 'auto_switch_threshold',
    'auto_switch_scope', 'auto_switch_sub', 'kill_switch', 'bypass_lan',
    'custom_dns', 'ping_threads', 'ping_core_method', 'background_ping',
    'ping_cache_minutes', 'tunnel_fragment', 'tunnel_mux',
    'tunnel_ip_strategy', 'tunnel_block_ads', 'tunnel_ping_url',
    'app_proxy_enabled', 'app_proxy_mode', 'app_proxy_list',
    'group_by_country', 'pinned_countries', 'light_theme',
    'show_ping_in_notification', 'in_app_emoji_mode', 'notification_emoji_mode',
    'autoswitch_exempt_apps',
  ];

  Future<Map<String, dynamic>> exportConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final exportedPrefs = <String, dynamic>{};
    for (final key in _exportedPrefKeys) {
      final v = prefs.get(key);
      if (v != null) exportedPrefs[key] = v;
    }
    final rawPingCache = prefs.getString('ping_cache');
    return {
      'type': 'develvpn_config',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'prefs': exportedPrefs,
      'ping_cache': rawPingCache != null ? jsonDecode(rawPingCache) : null,
      'subs': subs.map((s) => s.toJson()).toList(),
      'servers': servers.map((s) => s.toJson()).toList(),
      'selected': selectedId,
      'usage': {'srv': srvSeconds, 'sub': subSeconds, 'total': totalSeconds},
    };
  }

  Future<void> applyExportedConfig(Map<String, dynamic> data) async {
    if (data['type'] != 'develvpn_config') throw Exception('Not a DevelVpn config file');
    final prefs = await SharedPreferences.getInstance();
    final exported = (data['prefs'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final key in _exportedPrefKeys) {
      final v = exported[key];
      if (v == null) continue;
      if (v is bool) await prefs.setBool(key, v);
      else if (v is int) await prefs.setInt(key, v);
      else if (v is String) await prefs.setString(key, v);
      else if (v is List) await prefs.setStringList(key, v.cast<String>());
    }

    subs.clear();
    servers.clear();
    for (final sj in (data['subs'] as List? ?? [])) {
      subs.add(Subscription.fromJson((sj as Map).cast<String, dynamic>()));
    }
    for (final sj in (data['servers'] as List? ?? [])) {
      servers.add(ServerData.fromJson((sj as Map).cast<String, dynamic>()));
    }
    Store.saveSubs(subs);
    Store.saveServers(servers);

    final sel = data['selected'];
    if (sel is String && servers.any((s) => s.id == sel)) {
      selectedId = sel;
      await prefs.setString('selected', sel);
    }

    final pc = data['ping_cache'];
    if (pc is Map) {
      await prefs.setString('ping_cache', jsonEncode(pc));
    }

    final usage = data['usage'];
    if (usage is Map) {
      srvSeconds.clear();
      ((usage['srv'] ?? {}) as Map).forEach((k, v) { if (v is num) srvSeconds[k.toString()] = v.toInt(); });
      subSeconds.clear();
      ((usage['sub'] ?? {}) as Map).forEach((k, v) { if (v is num) subSeconds[k.toString()] = v.toInt(); });
      totalSeconds = (usage['total'] as num?)?.toInt() ?? 0;
      await prefs.setString('usage_stats', jsonEncode({'srv': srvSeconds, 'sub': subSeconds, 'total': totalSeconds}));
    }

    await load();
  }

  Future<void> clearAllData() async {
    await Store.clearAll();
    subs.clear();
    servers.clear();
    selectedId = '';
    notifyListeners();
  }

  /// Real delay of any server measured by the core (protected sockets —
  /// bypasses the active tunnel). Works both connected and disconnected.
  Future<int> pingServer(ServerData s) async {
    if (!vpn.coreReady) {
      final (host, port) = PingManager.resolveServerEndpoint(s);
      final d = await PingManager.tcpPing(host, port);
      s.pingMs = d;
      s.pingAt = DateTime.now().millisecondsSinceEpoch;
      PingManager.record(s, d);
      notifyListeners();
      return d;
    }
    final d = await vpn.testServerDelay(s);
    s.pingMs = d;
    s.pingAt = DateTime.now().millisecondsSinceEpoch;
    PingManager.record(s, d);
    if (vpn.active?.id == s.id) vpn.realPing = d > 0 ? d : null;
    notifyListeners();
    return d;
  }

  /// Ping of the currently selected server (home screen plate refresh).
  Future<void> pingSelectedServer() async {
    final s = selected;
    if (s == null) return;
    if (vpn.phase == VpnPhase.connected) {
      await vpn.checkConnectedPing();
      return;
    }
    await pingServer(s);
  }

  void _syncTileConfig() {
    final selServer = selected;
    if (selServer != null && selServer.vlessUrl != null) {
      try {
        final config = buildOptimizedConfig(selServer.vlessUrl!);
        final remark = stripAllEmojis(selServer.plateName);
        SharedPreferences.getInstance().then((p) {
          p.setString('last_v2ray_config', config);
          p.setString('last_v2ray_remark', remark);
        });
      } catch (_) {}
    }
  }

  void select(String id, {bool manual = true}) {
    if (selectedId == id) return;
    selectedId = id;
    if (manual) {
      // A manual pick always wins: stop any running auto-scan and give the
      // user's choice a grace period before auto-switching may return.
      AutoSwitchEngine.markManual();
      _badPingStreak = 0;
    }
    Haptics.serverSwitch();
    SharedPreferences.getInstance().then((p) => p.setString('selected', id));
    _syncTileConfig();
    notifyListeners();

    // Auto-reconnect if connected or connecting
    if (vpn.phase == VpnPhase.connected || vpn.phase == VpnPhase.connecting) {
      vpn.switchServer(selected);
    }
  }

  void setTab(int t) {
    tab = t;
    notifyListeners();
  }

  void setMerged(bool v) {
    merged = v;
    notifyListeners();
  }

  void setSort(String v) {
    sortBy = v;
    notifyListeners();
  }

  void setSearch(String q) {
    searchQ = q;
    notifyListeners();
  }

  void toggleFavorite(String serverId) {
    for (final s in servers) {
      if (s.id == serverId) {
        s.isFavorite = !s.isFavorite;
        break;
      }
    }
    Store.saveServers(servers);
    notifyListeners();
  }

  /// Manual server edit (long-press on a server card): rename, change the
  /// display address and the country flag code.
  void editServer(String serverId, {required String name, required String city, String? flag}) {
    for (final s in servers) {
      if (s.id == serverId) {
        s.name = name;
        s.plateName = name;
        s.city = city;
        s.flag = (flag == null || flag.isEmpty) ? null : flag;
        s.refreshSearchKey();
        break;
      }
    }
    Store.saveServers(servers);
    _syncTileConfig();
    notifyListeners();
  }

  void setShowFavoritesOnly(bool v) {
    showFavoritesOnly = v;
    notifyListeners();
  }

  Future<void> addSubscription(String rawLink) async {
    // Normalize the link and re-fetch instead of duplicating an existing sub
    var link = rawLink.trim();
    if (link.startsWith('happ://add/')) link = link.substring('happ://add/'.length);
    if (link.startsWith('develvpn://add/')) link = link.substring('develvpn://add/'.length);
    if (!link.startsWith('http')) link = 'https://$link';
    final existing = subs.where((s) => s.link != null && s.link!.trim() == link).toList();
    if (existing.isNotEmpty) {
      await refreshSubscription(existing.first.id);
      return;
    }

    final subId = 'sub${DateTime.now().millisecondsSinceEpoch}';
    final (sub, newServers) = await fetchSubscription(link, subId: subId);
    subs.add(sub);
    servers.addAll(newServers);
    selectedId = newServers.first.id;
    Store.saveSubs(subs);
    Store.saveServers(servers);
    notifyListeners();
  }

  void deleteSubscription(String subId) {
    subs.removeWhere((s) => s.id == subId);
    servers.removeWhere((s) => s.subId == subId);
    if (autoSwitchSubId == subId) setAutoSwitchSubId('all');
    if (!servers.any((s) => s.id == selectedId)) {
      selectedId = servers.isEmpty ? '' : servers.first.id;
    }
    Store.saveSubs(subs);
    Store.saveServers(servers);
    notifyListeners();
  }

  void renameSubscription(String subId, String newName) {
    final idx = subs.indexWhere((s) => s.id == subId);
    if (idx != -1) {
      subs[idx].name = newName;
      Store.saveSubs(subs);
      notifyListeners();
    }
  }

  Future<void> refreshSubscription(String subId) async {
    final idx = subs.indexWhere((s) => s.id == subId);
    if (idx == -1) return;
    final sub = subs[idx];
    if (sub.link == null || sub.link!.isEmpty) return;
    final (newSub, newServers) = await fetchSubscription(sub.link!, subId: subId);
    subs[idx] = newSub;
    servers.removeWhere((s) => s.subId == subId);
    servers.addAll(newServers);
    Store.saveSubs(subs);
    Store.saveServers(servers);
    notifyListeners();
  }

  void refresh() => notifyListeners();
}
