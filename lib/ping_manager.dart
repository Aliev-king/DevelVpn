import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';

class PingManager {
  static bool _cancelled = false;
  static bool _isRunning = false;

  /// How long a measured ping is trusted before it is considered stale.
  static const Duration cacheDuration = Duration(minutes: 5);

  static bool get isRunning => _isRunning;

  static void cancel() {
    _cancelled = true;
  }

  /// Health history: last N measurements per server (epoch ms, ping).
  /// Powers the sparkline in the server info sheet.
  static final Map<String, List<List<int>>> history = {};
  static const int historyLimit = 24;

  static void record(ServerData s, int ping) {
    final list = history.putIfAbsent(s.id, () => []);
    list.add([DateTime.now().millisecondsSinceEpoch, ping]);
    if (list.length > historyLimit) list.removeRange(0, list.length - historyLimit);
  }

  static List<List<int>> historyFor(String serverId) =>
      List<List<int>>.from(history[serverId] ?? const []);

  static bool isFresh(ServerData s) {
    final t = s.pingAt;
    if (t == null) return false;
    return DateTime.now().millisecondsSinceEpoch - t < cacheDuration.inMilliseconds;
  }

  /// Restores cached ping values from storage (kept across restarts).
  static Future<void> restoreCache(List<ServerData> servers) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('ping_cache');
      if (raw == null) return;
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final s in servers) {
        final e = map[s.id];
        if (e is Map) {
          final ms = (e['ms'] as num?)?.toInt() ?? -1;
          final t = (e['t'] as num?)?.toInt() ?? 0;
          if (now - t < cacheDuration.inMilliseconds) {
            s.pingMs = ms;
            s.pingAt = t;
          }
        }
      }
    } catch (_) {}
  }

  static Future<void> persistCache(List<ServerData> servers) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final map = <String, dynamic>{};
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final s in servers) {
        if (s.pingAt != null && now - s.pingAt! < cacheDuration.inMilliseconds) {
          map[s.id] = {'ms': s.pingMs, 't': s.pingAt};
        }
      }
      await sp.setString('ping_cache', jsonEncode(map));
    } catch (_) {}
  }

  /// Lightweight TCP ping measuring 3-way handshake latency (SYN -> SYN/ACK -> ACK).
  /// Does 2 attempts and returns the faster one: the first SYN on many networks
  /// includes ARP/radio wake-up and overestimates the real RTT.
  static Future<int> tcpPing(String host, int port, {Duration timeout = const Duration(milliseconds: 2200)}) async {
    final a = await _rawTcpPing(host, port, timeout);
    // Only refine when the first attempt looks plausible; dead hosts stay dead.
    if (a <= 0) return a;
    final b = await _rawTcpPing(host, port, timeout);
    return (b > 0 && b < a) ? b : a;
  }

  static Future<int> _rawTcpPing(String host, int port, Duration timeout) async {
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      sw.stop();
      socket.destroy();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }

  /// Extracts the destination host and port from a server (either vless URL or city/address)
  static (String, int) resolveServerEndpoint(ServerData s) {
    if (s.vlessUrl != null && s.vlessUrl!.isNotEmpty) {
      try {
        final uri = Uri.parse(s.vlessUrl!);
        final host = uri.host.isNotEmpty ? uri.host : s.city;
        final port = uri.hasPort ? uri.port : 443;
        return (host, port);
      } catch (_) {}
    }
    return (s.city, 443);
  }

  /// Runs ping across target servers with a gentle worker pool (6-8 threads) to protect CPU and battery
  static Future<void> pingAll({
    required List<ServerData> servers,
    required void Function(ServerData s, int ping) onResult,
    required void Function() onDone,
    int concurrency = 6,
    bool skipFresh = false,
  }) async {
    _cancelled = false;
    _isRunning = true;

    final pool = servers.where((s) => s.city.isNotEmpty || (s.vlessUrl != null && s.vlessUrl!.isNotEmpty)).toList();
    final target = skipFresh ? pool.where((s) => !isFresh(s)).toList() : pool;
    if (target.isEmpty) {
      _isRunning = false;
      onDone();
      return;
    }

    var cursor = 0;
    var lastUpdate = DateTime.now();

    Future<void> worker() async {
      while (!_cancelled) {
        int idx;
        if (cursor >= target.length) break;
        idx = cursor++;
        if (idx >= target.length || _cancelled) break;

        final server = target[idx];
        final (host, port) = resolveServerEndpoint(server);
        final ping = await tcpPing(host, port, timeout: const Duration(milliseconds: 1800));

        if (!_cancelled) {
          server.pingMs = ping;
          server.pingAt = DateTime.now().millisecondsSinceEpoch;
          record(server, ping);
          final now = DateTime.now();
          if (now.difference(lastUpdate).inMilliseconds >= 120 || idx == target.length - 1) {
            lastUpdate = now;
            onResult(server, ping);
          }
        }
      }
    }

    final workerCount = concurrency.clamp(4, 32);
    final workers = List.generate(workerCount, (_) => worker());

    await Future.wait(workers);
    _isRunning = false;
    onDone();
  }

  /// Pings a batch of servers with a wide worker pool (used by the auto-switch
  /// scanner: up to 20 servers measured simultaneously). Servers with a fresh
  /// cached ping are skipped so the scanner never re-measures what it already
  /// knows — it decides from the cache instead of guessing.
  static Future<void> pingList(
    List<ServerData> servers, {
    int concurrency = 20,
    Duration timeout = const Duration(milliseconds: 1800),
    bool skipFresh = true,
  }) async {
    final pool = servers.where((s) => s.city.isNotEmpty || (s.vlessUrl != null && s.vlessUrl!.isNotEmpty)).toList();
    final target = skipFresh ? pool.where((s) => !isFresh(s)).toList() : pool;
    if (target.isEmpty) return;

    var cursor = 0;
    Future<void> worker() async {
      while (cursor < target.length) {
        final idx = cursor++;
        if (idx >= target.length) break;
        final server = target[idx];
        final (host, port) = resolveServerEndpoint(server);
        server.pingMs = await tcpPing(host, port, timeout: timeout);
        server.pingAt = DateTime.now().millisecondsSinceEpoch;
        record(server, server.pingMs);
      }
    }

    final workerCount = concurrency.clamp(1, 20);
    await Future.wait(List.generate(workerCount, (_) => worker()));
  }
}
