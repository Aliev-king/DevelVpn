import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'services.dart';
import 'screens/account_screen.dart';
import 'screens/home_screen.dart';
import 'screens/servers_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';

const _linksChannel = MethodChannel('devel_vpn/links');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  runApp(const DevelVpnApp());
}

class DevelVpnApp extends StatelessWidget {
  const DevelVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevelVpn',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  final AppState app = AppState();
  String? _pendingLink;
  late final PageController _pageController = PageController(initialPage: app.tab);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    app.addListener(_onAppStateChanged);
    _bootstrap();
    _linksChannel.setMethodCallHandler((call) async {
      if (call.method == 'takePendingLink') return _pendingLink;
      return null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pollTileAndDeepLink();
    }
  }

  Future<void> _bootstrap() async {
    await app.load();
    await app.vpn.init();
    await _pollTileAndDeepLink();

    // Auto-Connect setting: connect to the last server on app launch.
    if (app.autoConnect && app.vpn.phase == VpnPhase.idle && app.selected != null) {
      await app.vpn.connect(app.selected!);
    }
    _maybeAutostart();
  }

  Future<void> _pollTileAndDeepLink() async {
    await _pollDeepLink();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('tile_toggle') == true) {
        await prefs.remove('tile_toggle');
        final shouldConnect = prefs.getBool('autostart') ?? false;
        if (mounted) {
          if (shouldConnect && app.vpn.phase == VpnPhase.idle && app.selected != null) {
            await app.vpn.connect(app.selected!);
          } else if (!shouldConnect && app.vpn.phase == VpnPhase.connected) {
            await app.vpn.disconnect();
          } else {
            await app.vpn.tap(app.selected);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _pollDeepLink() async {
    try {
      final link = await _linksChannel.invokeMethod<String>('takePendingLink');
      if (link != null && link.isNotEmpty && mounted) {
        await app.addSubscription(link);
        if (mounted) {
          _onTabSelected(1);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(behavior: SnackBarBehavior.floating, content: Text('${app.strings.subAdded}: ${app.subs.last.name}')),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _maybeAutostart() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('autostart') == true) {
      await prefs.remove('autostart');
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) await app.vpn.tap(app.selected);
    }
  }

  void _onTabSelected(int index) {
    if (app.tab == index) return;
    app.setTab(index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _onAppStateChanged() {
    if (_pageController.hasClients && (_pageController.page?.round() ?? 0) != app.tab) {
      if (!_pageController.position.isScrollingNotifier.value) {
        _pageController.animateToPage(
          app.tab,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    app.removeListener(_onAppStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Theme colors/system-bar style are resolved by MaterialApp.builder
    // (DevelVpnApp) — this build only repaints with the current palette.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: AppColors.isLight ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: AppColors.isLight ? Brightness.dark : Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final w = MediaQuery.sizeOf(context).width;
        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              /* background gradient (adapts to theme) */
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, .42, .72, 1],
                    colors: AppColors.bgGradient,
                  ),
                ),
              ),
              /* watermark (rendered on all tabs, elevated behind the gem button) */
              Positioned(
                top: 135,
                left: (w - w * 1.26) / 2,
                width: w * 1.26,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: AppColors.isLight ? .34 : .14,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        AppColors.isLight ? const Color(0xFFD4D4DE) : Colors.white,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset('assets/logo-white.png', fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              /* bottom fade (dark theme: fades to near-black; light theme: none —
                 the card is already separated by its own shadow) */
              if (!AppColors.isLight)
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, .40, .78, 1],
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Color(0x5F040406),
                          Color(0xB8040406),
                        ],
                      ),
                    ),
                  ),
                ),
              /* 12px blur + subtle darkening on non-home tabs */
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: app.tab == 0,
                  child: AnimatedOpacity(
                    opacity: app.tab != 0 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(color: const Color(0x59000000)),
                      ),
                    ),
                  ),
                ),
              ),
              /* animated swipeable content */
              Positioned.fill(
                bottom: 94,
                child: SafeArea(
                  bottom: false,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) {
                      if (app.tab != page) {
                        app.setTab(page);
                      }
                    },
                    physics: const BouncingScrollPhysics(),
                    children: [
                      HomeScreen(app: app),
                      ServersScreen(app: app),
                      SettingsScreen(app: app),
                      AccountScreen(app: app),
                    ],
                  ),
                ),
              ),
              /* bottom nav */
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: TabBarPanel(index: app.tab, onTap: _onTabSelected, lang: app.language),
              ),
            ],
          ),
        );
      },
    );
  }
}
