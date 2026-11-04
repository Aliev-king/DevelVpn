import 'dart:io';

import 'package:flutter/services.dart';

import 'services.dart';

/// Keeps the home-screen widget in sync with the VPN state.
/// The native widget reads its state from SharedPreferences and is refreshed
/// through the AppWidgetManager; the toggle runs fully natively.
class WidgetBridge {
  static const _channel = MethodChannel('devel_vpn/widget');
  static bool _supported = true;

  static Future<void> push({required bool connected}) async {
    if (!_supported || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('update', {
        'connected': connected,
        'ping': TunnelSettings.showPingInNotification ? '' : '',
      });
    } on PlatformException {
      _supported = false;
    } catch (_) {
      _supported = false;
    }
  }
}
