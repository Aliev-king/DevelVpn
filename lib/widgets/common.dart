import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data.dart';
import '../services.dart';
import '../theme.dart';

/* ---------------- check mark (white circle) ---------------- */

class WhiteCheck extends StatelessWidget {
  final double size;
  WhiteCheck({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.isLight ? const Color(0xFF1C1C1E) : const Color(0xFFF4F4F6),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check,
        size: size * 0.62,
        color: AppColors.isLight ? Colors.white : const Color(0xFF1B1B1E),
      ),
    );
  }
}

/* ---------------- shield (crossfade stack) ---------------- */

class Shield extends StatelessWidget {
  final bool connected;
  Shield({super.key, required this.connected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 45,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: connected
            ? SvgPicture.asset(
                'assets/svg/shield-ok.svg',
                key: ValueKey('shield_connected'),
                height: 45,
                fit: BoxFit.contain,
              )
            : SvgPicture.asset(
                'assets/svg/shield.svg',
                key: ValueKey('shield_disconnected'),
                height: 45,
                fit: BoxFit.contain,
              ),
      ),
    );
  }
}

/* ---------------- gem power button ---------------- */

class GemButton extends StatelessWidget {
  final VpnController vpn;
  final VoidCallback onTap;

  GemButton({super.key, required this.vpn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: vpn,
      builder: (context, _) {
        final connecting = vpn.phase == VpnPhase.connecting;
        return GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 256,
            height: 256,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 1) The circular disc BEHIND the gem frame (dark theme: dark
                //    radial gradient; light theme: clean white disc, as in the mock)
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.isLight ? Colors.white : null,
                    gradient: AppColors.isLight
                        ? null
                        : const RadialGradient(
                            center: Alignment(0, -0.44),
                            radius: 0.85,
                            colors: [Color(0xFF26262A), Color(0xFF202024), Color(0xFF1D1D21)],
                            stops: [0.0, 0.62, 1.0],
                          ),
                  ),
                ),
                // 2) The faceted polyhedron gem frame ON TOP so its geometric facets cross over the disc!
                //    (light theme: tint silver-gray so it stays visible on white)
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    AppColors.isLight ? const Color(0xFFB4B4C0) : Colors.white,
                    BlendMode.srcIn,
                  ),
                  child: SvgPicture.asset('assets/svg/gem-frame.svg', width: 256, height: 256, fit: BoxFit.contain),
                ),
                // 3) Origami flower logo in the center (dark on light theme)
                Transform.translate(
                  offset: Offset(0, -2),
                  child: AnimatedOpacity(
                    opacity: connecting ? 0.5 : 1,
                    duration: Duration(milliseconds: 300),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        AppColors.isLight ? const Color(0xFF1C1C1E) : Colors.white,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset('assets/logo-white.png', width: 78, fit: BoxFit.contain),
                    ),
                  ),
                ),
                if (connecting)
                  Positioned(
                    bottom: 38,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: AppColors.isLight ? const Color(0xFF1C1C1E) : Colors.white,
                        strokeWidth: 2.5,
                        backgroundColor: AppColors.isLight ? const Color(0x241C1C1E) : const Color(0x24FFFFFF),
                      ),
                    ),
                  ),
                if (vpn.phase == VpnPhase.connected) _Ripple(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Ripple extends StatefulWidget {
  _Ripple();

  @override
  State<_Ripple> createState() => _RippleState();
}

class _RippleState extends State<_Ripple> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(milliseconds: 1400))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t1 = Curves.easeOutCubic.transform(_c.value);
        final t2 = Curves.easeOutQuad.transform(((_c.value - 0.1) * 1.11).clamp(0.0, 1.0));
        return IgnorePointer(
          child: OverflowBox(
            maxWidth: 1000,
            maxHeight: 1000,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Primary full-screen shockwave
                Container(
                  width: 200 + 580 * t1,
                  height: 200 + 580 * t1,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Color.fromRGBO(255, 255, 255, 0.75 * (1 - t1)),
                      width: 2.2,
                    ),
                  ),
                ),
                // Secondary delayed wave
                if (_c.value > 0.1)
                  Container(
                    width: 190 + 510 * t2,
                    height: 190 + 510 * t2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.isLight
                            ? Color.fromRGBO(28, 28, 30, 0.35 * (1 - t2))
                            : Color.fromRGBO(255, 255, 255, 0.45 * (1 - t2)),
                        width: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* ---------------- server plate (home) ---------------- */

class ServerPlate extends StatelessWidget {
  final ServerData? server;
  final Subscription? subscription;
  final VpnController? vpn;
  final VoidCallback onOpen;
  final VoidCallback? onPingRefresh;
  final VoidCallback? onSpeedTest;
  final bool isRu;

  ServerPlate({
    super.key,
    required this.server,
    this.subscription,
    this.vpn,
    required this.onOpen,
    this.onPingRefresh,
    this.onSpeedTest,
    this.isRu = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = server;
    final sub = subscription;
    final isTesting = vpn?.testingPing == true;
    final int? realP = vpn?.realPing;

    String pingDisplay;
    if (isTesting) {
      pingDisplay = '...';
    } else if (vpn?.phase == VpnPhase.connected && realP != null && realP > 0) {
      pingDisplay = '$realP ms';
    } else if (s != null && s.pingMs > 0) {
      pingDisplay = '${s.pingMs} ms';
    } else {
      pingDisplay = '-- ms';
    }

    // Real traffic from subscription
    final trafficStr = sub != null ? '${sub.trafficUsedStr} / ${sub.trafficTotalStr}' : '0 GB / ∞';
    final fillVal = sub?.trafficFill ?? 0.0;
    final speedDisplay = vpn?.speedDisplay ?? '0 KB/s';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 14),
      padding: EdgeInsets.fromLTRB(14, 10, 14, 11),
      decoration: BoxDecoration(color: AppColors.nav, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Row(
            children: [
              CircleFlag(s?.flag, serverName: s?.name, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  s?.plateName ?? 'No server - tap + to add',
                  style: AppText.plateName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Only tapping >> navigates to the servers page!
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpen,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: _DoubleChevron(),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: fillVal,
                    minHeight: 3.5,
                    backgroundColor: AppColors.trafficTrack,
                    color: AppColors.textHi,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(trafficStr, style: AppText.traffic),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              // Tapping Ping row ONLY refreshes ping!
              _Stat(
                label: isRu ? 'Пинг:' : 'Ping:',
                value: pingDisplay,
                onTap: onPingRefresh,
                trailing: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPingRefresh,
                  child: Padding(
                    padding: EdgeInsets.only(left: 3),
                    child: isTesting
                        ? SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textMid),
                          )
                        : Icon(Icons.refresh_rounded, size: 14, color: AppColors.textMid),
                  ),
                ),
              ),
              SizedBox(width: 10),
              _Stat(label: isRu ? 'Скорость:' : 'Speed:', value: speedDisplay, onTap: onSpeedTest),
              SizedBox(width: 10),
              _Stat(label: isRu ? 'Протокол:' : 'Protocol:', value: s?.protocolDisplay ?? 'VLESS'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Widget? trailing;
  final VoidCallback? onTap;

  _Stat({required this.label, required this.value, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: Color(0xFF3C3C42), width: 2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.statLabel),
              SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(value, style: AppText.statValue, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoubleChevron extends StatelessWidget {
  _DoubleChevron();

  @override
  Widget build(BuildContext context) {
    Widget chevron() => Icon(Icons.chevron_right, size: 16, color: Color(0xFF7B7B80));
    return SizedBox(
      width: 15,
      height: 15,
      child: Stack(
        alignment: Alignment.center,
        children: [chevron(), Padding(padding: EdgeInsets.only(left: 6), child: chevron())],
      ),
    );
  }
}

/* ---------------- bottom tab bar ---------------- */

class TabBarPanel extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final String? lang;

  TabBarPanel({super.key, required this.index, required this.onTap, this.lang});

  List<(String, IconData)> _items() {
    final isRu = lang == 'ru';
    return [
      (isRu ? 'Главная' : 'Home', Icons.home_rounded),
      (isRu ? 'Серверы' : 'Servers', Icons.storage_rounded),
      (isRu ? 'Настройки' : 'Settings', Icons.settings_outlined),
      (isRu ? 'Аккаунт' : 'Account', Icons.person_outline_rounded),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    return Container(
      height: 94,
      decoration: BoxDecoration(
        color: AppColors.nav,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(top: 10, bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < items.length; i++)
                _Tab(item: items[i], active: i == index, onTap: () => onTap(i)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final (String, IconData) item;
  final bool active;
  final VoidCallback onTap;

  _Tab({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active
      ? (AppColors.isLight ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7))
      : (AppColors.isLight ? const Color(0xFF8A8A90) : const Color(0xFF86868B));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.$2, size: 24, color: color),
          SizedBox(height: 5),
          Text(
            item.$1,
            style: TextStyle(
              fontFamily: 'Inter',
              fontFamilyFallback: ['InterDisplay'],
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              fontSize: 11,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- section title (settings) ---------------- */

class SecTitle extends StatelessWidget {
  final String text;
  SecTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(26, 26, 26, 8),
      child: Align(alignment: Alignment.centerLeft, child: Text(text.toUpperCase(), style: AppText.secTitle)),
    );
  }
}

/* ---------------- settings row ---------------- */

class SettingsRow extends StatelessWidget {
  final String name, sub;
  final bool? switchValue;
  final String? value;
  final ValueChanged<bool>? onSwitch;
  final VoidCallback? onTap;
  final bool showDivider;

  SettingsRow({
    super.key,
    required this.name,
    required this.sub,
    this.switchValue,
    this.value,
    this.onSwitch,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? (switchValue == null ? null : () => onSwitch?.call(!switchValue!)),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            border: showDivider ? Border(top: BorderSide(color: AppColors.divider, width: 0.8)) : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppText.rowName),
                    SizedBox(height: 1),
                    Text(sub, style: AppText.rowSub),
                  ],
                ),
              ),
              if (value != null) ...[
                SizedBox(width: 10),
                Text(value!, style: AppText.rowValue),
              ],
              if (switchValue != null) ...[
                SizedBox(width: 10),
                _Switch(value: switchValue!, onChanged: onSwitch ?? (_) {}),
              ] else
                Icon(Icons.chevron_right, size: 22, color: AppColors.textLow),
            ],
          ),
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  _Switch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 46,
        height: 28,
        padding: EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? AppColors.whiteOrBlack : AppColors.graySwitch,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: value
                ? (AppColors.isLight ? Colors.white : const Color(0xFF141416))
                : Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
