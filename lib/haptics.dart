import 'package:flutter/services.dart';

/// Centralized haptic feedback for user actions.
class Haptics {
  static bool enabled = true;

  /// Single-pulse feedback when starting a VPN connection (во время подключения).
  static Future<void> connecting() async {
    if (!enabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Double-pulse feedback after VPN connection is successfully established (после подключения).
  static Future<void> connected() async {
    if (!enabled) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Legacy alias.
  static Future<void> connect() => connecting();

  /// Server change (manual selection or auto-failover).
  static void serverSwitch() {
    if (!enabled) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Ping measurement completed / refresh triggered.
  static void ping() {
    if (!enabled) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Subtle click for cancel / disconnect.
  static void light() {
    if (!enabled) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
