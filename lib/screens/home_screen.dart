import 'dart:ui';

import 'package:flutter/material.dart';

import '../add_sheet.dart';
import '../app_state.dart';
import '../haptics.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  final AppState app;
  HomeScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([app, app.vpn]),
      builder: (context, _) {
        final connected = app.vpn.phase == VpnPhase.connected;
        return Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  clipBehavior: Clip.none,
                  physics: ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          SizedBox(height: 32),
                          Center(
                            child: Text(
                              'DevelVpn',
                              style: AppText.brand,
                            ),
                          ),
                          SizedBox(height: 2),
                          Center(
                            child: _IpHeader(
                              vpn: app.vpn,
                              ipPrefix: app.strings.yourIp,
                            ),
                          ),
                          SizedBox(height: 20),
                          Center(
                            child: GemButton(
                              vpn: app.vpn,
                              onTap: () => app.vpn.tap(app.selected),
                            ),
                          ),
                          SizedBox(height: 14),
                          Center(child: Shield(connected: connected)),
                          SizedBox(height: 10),
                          Center(
                            child: Text(
                              switch (app.vpn.phase) {
                                VpnPhase.connected => 'CONNECTED',
                                VpnPhase.connecting => 'CONNECTING',
                                _ => 'DISCONNECTED',
                              },
                              style: AppText.state,
                            ),
                          ),
                          SizedBox(height: 4),
                          Center(
                            child: Text(
                              switch (app.vpn.phase) {
                                VpnPhase.connected => (app.vpn.lastError != null
                                    ? app.vpn.lastError!
                                    : app.strings.secureConnection),
                                VpnPhase.connecting => app.strings.establishingTunnel,
                                _ => app.strings.tapToSecure,
                              },
                              style: (app.vpn.phase == VpnPhase.connected && app.vpn.lastError != null)
                                  ? AppText.hint.copyWith(color: Color(0xFFFF5252))
                                  : AppText.hint,
                            ),
                          ),
                          Spacer(),
                          Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: ServerPlate(
                              server: app.selected,
                              subscription: app.selectedSub,
                              vpn: app.vpn,
                              isRu: app.strings.isRu,
                              onOpen: () => app.setTab(1),
                              onPingRefresh: () {
                                Haptics.ping();
                                app.pingSelectedServer();
                              },
                              onSpeedTest: () async {
                                Haptics.ping();
                                await app.runSpeedTest(app.selected);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 18,
              right: 18,
              child: PlusButton(app: app),
            ),
          ],
        );
      },
    );
  }
}

/* ---------------- IP header with soft privacy blur ---------------- */

/// Shows the public IP. While the tunnel is being established (and until the
/// IP actually changes to the server's), the value is softly blurred — like
/// on iOS — and un-blurs with a smooth animation once the new IP arrives.
class _IpHeader extends StatefulWidget {
  final VpnController vpn;
  final String ipPrefix;

  _IpHeader({required this.vpn, required this.ipPrefix});

  @override
  State<_IpHeader> createState() => _IpHeaderState();
}

class _IpHeaderState extends State<_IpHeader> {
  String? _ipAtConnect;
  VpnPhase _prevPhase = VpnPhase.idle;

  bool get _blurred {
    final phase = widget.vpn.phase;
    final ip = widget.vpn.currentPublicIp;
    if (phase == VpnPhase.connecting) return true;
    if (phase == VpnPhase.connected) {
      if (_prevPhase == VpnPhase.connecting && _ipAtConnect == null) {
        _ipAtConnect = ip;
      }
      // Keep hiding the real address until the tunnel reports its own IP.
      return ip == '...' || ip == _ipAtConnect;
    }
    _ipAtConnect = null;
    return false;
  }

  @override
  void didUpdateWidget(covariant _IpHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vpn.phase == VpnPhase.idle && _prevPhase != VpnPhase.idle) {
      _ipAtConnect = null;
    }
    _prevPhase = widget.vpn.phase;
  }

  @override
  Widget build(BuildContext context) {
    final blurred = _blurred;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: blurred ? 7.0 : 0.0),
      duration: Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, sigma, child) => ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
      child: Text(
        '${widget.ipPrefix}${widget.vpn.currentPublicIp}',
        style: AppText.ip,
      ),
    );
  }
}

/* ---------------- plus button + bottom sheet modal (matching sort panel) ---------------- */

class PlusButton extends StatefulWidget {
  final AppState app;
  PlusButton({super.key, required this.app});

  @override
  State<PlusButton> createState() => _PlusButtonState();
}

class _PlusButtonState extends State<PlusButton> {
  bool busy = false;

  void _showAddSheet(BuildContext context) {
    PlusButtonHelper.showAddSheet(context, widget.app);
  }


  @override
  Widget build(BuildContext context) {
    if (busy) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: AppColors.iconRoundBg, shape: BoxShape.circle),
        padding: EdgeInsets.all(8),
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: () => _showAddSheet(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: AppColors.iconRoundBg, shape: BoxShape.circle),
        child: Icon(Icons.add, size: 20, color: AppColors.textHi),
      ),
    );
  }
}
