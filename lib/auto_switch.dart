import 'dart:async';

import 'data.dart';
import 'haptics.dart';
import 'ping_manager.dart';

/// Pool of candidates for auto-switch: region scope + subscription scope.
enum ScanScope { all, noRu, favorites }

/// Auto-failover engine.
///
/// When the connected server's ping exceeds the threshold twice in a row
/// (checked by the app state), the engine scans candidate servers in batches
/// of 20 with a light TCP ping. TCP pings of OTHER servers made while a VPN
/// is active travel through the tunnel, so the current server's RTT (measured
/// directly by the core) is subtracted from every result. The best candidate
/// is then switched to and verified with a real core delay check (protected
/// sockets — bypasses the tunnel, uses the user-selected ping service URL).
/// Verification takes up to 3 samples because a freshly switched tunnel needs
/// a moment before delay checks succeed. If the verification fails, the next
/// candidates of the batch are tried; if the whole batch is slow, the next
/// batch is appended.
///
/// Note: the TCP *scan* is protocol-independent (a SYN to the server), the
/// ping *service* choice applies to the final verification and display.
class AutoSwitchEngine {
  static bool _running = false;
  static int _generation = 0;
  static DateTime? _lastManualAction;
  static String? scanningNote;
  static final Set<String> _failedIds = {};

  static Set<String> get failedIds => _failedIds;
  static void resetFailures() => _failedIds.clear();

  static bool get isRunning => _running;

  /// Called on every manual user action (server pick, connect, disconnect):
  /// instantly cancels any scan and starts the manual-choice grace period.
  static void markManual() {
    _generation++;
    _lastManualAction = DateTime.now();
    _failedIds.clear();
  }

  static Duration sinceManualAction() {
    final t = _lastManualAction;
    return t == null ? const Duration(days: 1) : DateTime.now().difference(t);
  }

  /// Cancels any scan in progress (e.g. user disconnected or changed server).
  static void invalidate() => _generation++;

  /// Returns the id of the server it switched to, or null.
  static Future<String?> scanAndSwitch({
    required List<ServerData> pool,
    required Future<void> Function(ServerData candidate) onPickCandidate,
    required Future<int> Function() verifyRealPing,
    required int threshold,
    required int connectedOverheadMs,
    required Set<String> excludedIds,
    required bool Function() stillWanted,
  }) async {
    if (_running) return null;
    _running = true;
    final gen = ++_generation;
    try {
      const batchSize = 20;
      for (var i = 0; i < pool.length; i += batchSize) {
        if (gen != _generation || !stillWanted()) return null;
        final batch = pool.skip(i).take(batchSize).toList();
        scanningNote = '${i + 1}–${i + batch.length} / ${pool.length}';
        await PingManager.pingList(batch, concurrency: 20);
        if (gen != _generation || !stillWanted()) return null;

        // Adjust tunnel overhead: TCP ping through the active VPN includes
        // the current server's RTT — subtract it for a fair comparison.
        int adj(ServerData s) => s.pingMs - (connectedOverheadMs > 0 ? connectedOverheadMs : 0);
        final ok = batch
            .where((s) =>
                s.pingMs > 0 &&
                adj(s) <= threshold &&
                !excludedIds.contains(s.id))
            .toList()
          ..sort((a, b) => a.pingMs.compareTo(b.pingMs));

        // Try up to 3 best candidates of the batch with a real delay check.
        for (final candidate in ok.take(3)) {
          if (gen != _generation || !stillWanted()) return null;
          Haptics.serverSwitch();
          await onPickCandidate(candidate);
          final realPing = await verifyRealPing();
          if (gen != _generation || !stillWanted()) return null;
          if (realPing > 0 && realPing <= threshold) {
            scanningNote = null;
            return candidate.id;
          }
          // Candidate didn't survive verification — blacklist it for this
          // session so the scanner stops revisiting dead ends.
          _failedIds.add(candidate.id);
        }
      }
      scanningNote = null;
      return null;
    } finally {
      if (gen == _generation) scanningNote = null;
      _running = false;
    }
  }
}
