import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../app_state.dart';
import '../auto_switch.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data.dart';
import '../logs_sheet.dart';
import '../ota_service.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  final AppState app;
  SettingsScreen({super.key, required this.app});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  bool _pendingExemptEditor = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the system Usage Access screen: re-check the permission
    // and open the editor automatically so the flow completes in one pass.
    if (state == AppLifecycleState.resumed && _pendingExemptEditor) {
      _pendingExemptEditor = false;
      hasUsageStatsPermission().then((granted) {
        if (granted && mounted) {
          _openAutoswitchExemptEditor(context);
        }
      });
    }
  }

  AppState get app => widget.app;

  @override
  Widget build(BuildContext context) {
    final s = app.strings;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        return ListView(
          padding: EdgeInsets.only(bottom: 40),
          physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            /* Header aligned with ServersScreen */
            Padding(
              padding: EdgeInsets.fromLTRB(22, 20, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.settings, style: AppText.pageTitle),
                  SizedBox(height: 4),
                  Text(s.appPreferences, style: AppText.pageSub),
                ],
              ),
            ),
            SizedBox(height: 10),

            /* Connection Section */
            SecTitle(s.connectionSection),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  SettingsRow(
                    name: s.autoConnect,
                    sub: s.autoConnectSub,
                    switchValue: app.autoConnect,
                    onSwitch: app.setAutoConnect,
                    showDivider: false,
                  ),
                  SettingsRow(
                    name: s.autoSwitch,
                    sub: s.autoSwitchSub,
                    switchValue: app.autoSwitch,
                    onSwitch: app.setAutoSwitch,
                  ),
                  if (app.autoSwitch) ...[
                    SettingsRow(
                      name: s.maxPingThreshold,
                      sub: '${app.autoSwitchThreshold} ms',
                      value: '${app.autoSwitchThreshold} ms',
                      onTap: () => _showThresholdSheet(context),
                    ),
                    SettingsRow(
                      name: s.scanScope,
                      sub: s.scanScopeSub,
                      value: _scopeLabel(),
                      onTap: () => _showScopeSheet(context),
                    ),
                    SettingsRow(
                      name: s.scanSubSource,
                      sub: s.scanSubSourceSub,
                      value: _subSourceLabel(),
                      onTap: () => _showSubSourceSheet(context),
                    ),
                  ],
                  SettingsRow(
                    name: s.isRu ? 'Приложения без автосмены' : 'No Auto-Switch Apps',
                    sub: s.isRu
                        ? 'В этих приложениях сервер не меняется'
                        : 'Servers never switch while these apps are open',
                    value: app.autoswitchExemptApps.isEmpty
                        ? (s.isRu ? 'Выкл.' : 'Off')
                        : '${app.autoswitchExemptApps.length}',
                    onTap: () => _openAutoswitchExemptEditor(context),
                  ),
                  SettingsRow(
                    name: s.killSwitch,
                    sub: s.killSwitchSub,
                    switchValue: app.killSwitch,
                    onSwitch: app.setKillSwitch,
                  ),
                  SettingsRow(
                    name: s.groupByCountry,
                    sub: s.groupByCountrySub,
                    switchValue: app.groupByCountry,
                    onSwitch: app.setGroupByCountry,
                  ),
                  _LanguageRow(
                    currentLang: app.language,
                    onTap: () => _showLanguageSheet(context),
                    title: s.language,
                    subtitle: s.languageSub,
                  ),
                  SettingsRow(
                    name: s.themeRow,
                    sub: s.themeRowSub,
                    value: app.themeMode == 'system'
                        ? (s.isRu ? 'Как в системе' : 'System')
                        : (app.lightTheme ? (s.isRu ? 'Светлая' : 'Light') : (s.isRu ? 'Тёмная' : 'Dark')),
                    onTap: () => _showThemeSheet(context),
                    showDivider: false,
                  ),
                ],
              ),
            ),

            /* Emoji Display Section */
            SecTitle(s.emojiDisplay),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  SettingsRow(
                    name: s.emojiInApp,
                    sub: s.emojiInAppSub,
                    value: _emojiLabel(app.inAppEmojiMode),
                    onTap: () => _showEmojiSheet(context, isInApp: true),
                    showDivider: false,
                  ),
                  SettingsRow(
                    name: s.emojiNotification,
                    sub: s.emojiNotificationSub,
                    value: _emojiLabel(app.notificationEmojiMode),
                    onTap: () => _showEmojiSheet(context, isInApp: false),
                  ),
                  SettingsRow(
                    name: s.notifPing,
                    sub: s.notifPingSub,
                    switchValue: app.showPingInNotification,
                    onSwitch: app.setShowPingInNotification,
                  ),
                ],
              ),
            ),

            /* Tunnel Settings (Happ-style, all functional) */
            SecTitle(s.tunnelSection),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  SettingsRow(
                    name: s.routingRules,
                    sub: s.routingRulesSub,
                    value: app.blockAds ? s.routeNoAds : s.routeAll,
                    onTap: () => _showRoutingSheet(context),
                    showDivider: false,
                  ),
                  SettingsRow(
                    name: s.appProxy,
                    sub: s.appProxySub,
                    value: app.appProxyEnabled
                        ? (app.appProxyMode == 'exclude'
                            ? (s.isRu ? 'Все кроме ${app.appProxyList.length}' : 'All except ${app.appProxyList.length}')
                            : (s.isRu ? 'Только ${app.appProxyList.length}' : 'Only ${app.appProxyList.length}'))
                        : (s.isRu ? 'Выкл.' : 'Off'),
                    onTap: () => _openAppProxyEditor(context),
                  ),
                  SettingsRow(
                    name: s.fragmentation,
                    sub: s.fragmentationSub,
                    switchValue: app.tunnelFragment,
                    onSwitch: app.setTunnelFragment,
                  ),
                  SettingsRow(
                    name: s.multiplexor,
                    sub: s.multiplexorSub,
                    switchValue: app.tunnelMux,
                    onSwitch: app.setTunnelMux,
                  ),
                  SettingsRow(
                    name: s.preferredIp,
                    sub: s.ipTypeDesc,
                    value: switch (app.ipStrategy) {
                      'ipv4' => 'IPv4',
                      'ipv6' => 'IPv6',
                      _ => s.isRu ? 'Авто' : 'Auto',
                    },
                    onTap: () => _showIpStrategySheet(context),
                  ),
                  SettingsRow(
                    name: s.allowLan,
                    sub: s.allowLanSub,
                    switchValue: app.bypassLan,
                    onSwitch: app.setBypassLan,
                  ),
                  SettingsRow(
                    name: s.customDns,
                    sub: s.customDnsSub,
                    value: app.customDns,
                    onTap: () => _showDnsSheet(context),
                  ),
                  SettingsRow(
                    name: s.pingService,
                    sub: s.pingServiceSub,
                    value: _pingServiceLabel(),
                    onTap: () => _showPingServiceSheet(context),
                  ),
                ],
              ),
            ),

            /* Tunnel & Network Section */
            SecTitle(s.networkSection),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  SettingsRow(
                    name: s.pingMethod,
                    sub: s.pingMethodSub,
                    value: app.pingCoreMethod ? s.pingCore : s.pingTcp,
                    onTap: () => _showPingMethodSheet(context),
                    showDivider: false,
                  ),
                  SettingsRow(
                    name: s.isRu ? 'Потоков сканирования' : 'Scan Threads',
                    sub: s.isRu ? 'Сколько серверов пинговать разом' : 'How many servers to ping at once',
                    value: '${app.pingThreads}',
                    onTap: () => _showPingThreadsSheet(context),
                  ),
                  SettingsRow(
                    name: s.isRu ? 'Автообновление подписок' : 'Auto-Refresh Subscriptions',
                    sub: s.isRu ? 'Тихо обновлять списки серверов' : 'Silently refresh server lists',
                    value: app.autoRefreshHours == 0
                        ? (s.isRu ? 'Выкл.' : 'Off')
                        : (s.isRu ? 'Каждые ${app.autoRefreshHours} ч' : 'Every ${app.autoRefreshHours} h'),
                    onTap: () => _showAutoRefreshSheet(context),
                  ),
                  SettingsRow(
                    name: s.backgroundPing,
                    sub: s.backgroundPingSub,
                    switchValue: app.backgroundPing,
                    onSwitch: app.setBackgroundPing,
                    showDivider: false,
                  ),
                  if (app.backgroundPing)
                    SettingsRow(
                      name: s.pingCacheInterval,
                      sub: s.backgroundPingSub,
                      value: _pingIntervalLabel(),
                      onTap: () => _showPingIntervalSheet(context),
                    ),
                ],
              ),
            ),

            /* System & Data Section */
            SecTitle(s.systemSection),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  SettingsRow(
                    name: s.channel,
                    sub: s.channelSub,
                    value: 't.me/DevelVpn',
                    onTap: _openChannel,
                    showDivider: false,
                  ),
                  SettingsRow(
                    name: s.logs,
                    sub: s.logsSub,
                    onTap: () => LogsSheet.show(context, isRu: s.isRu),
                  ),
                  SettingsRow(
                    name: s.isRu ? 'Экспорт конфигурации' : 'Export Config',
                    sub: s.isRu ? 'Сохранить подписки и настройки в файл' : 'Save subscriptions and settings to a file',
                    onTap: () => _exportConfig(context),
                  ),
                  SettingsRow(
                    name: s.isRu ? 'Импорт конфигурации' : 'Import Config',
                    sub: s.isRu ? 'Восстановить из файла экспорта' : 'Restore from an export file',
                    onTap: () => _importConfig(context),
                  ),
                  SettingsRow(
                    name: s.resetAllData,
                    sub: s.resetAllDataSub,
                    onTap: () => _showResetDialog(context),
                  ),
                  SettingsRow(
                    name: s.version,
                    sub: s.isRu ? 'Нажмите для проверки обновлений (OTA)' : 'Tap to check for updates (OTA)',
                    value: 'v${OtaService.currentVersion}',
                    onTap: () => OtaSheet.show(context, isRu: s.isRu),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _pingServiceLabel() {
    final url = TunnelSettings.pingUrl;
    for (final preset in kPingServicePresets) {
      if (preset.$3 == url) return preset.$2;
    }
    return app.strings.customUrl;
  }

  Future<void> _openChannel() async {
    try {
      await launcher.launchUrl(
        Uri.parse('https://t.me/DevelVpn'),
        mode: launcher.LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  void _showLanguageSheet(BuildContext context) {
    final s = app.strings;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(s.language, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.textMid),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Divider(color: AppColors.divider),
                ListTile(
                  leading: CircleFlag('us', size: 24),
                  title: Text('English', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                  trailing: app.language == 'en' ? Icon(Icons.check, color: Colors.white) : null,
                  onTap: () {
                    app.setLanguage('en');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: CircleFlag('ru', size: 24),
                  title: Text('Русский', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                  trailing: app.language == 'ru' ? Icon(Icons.check, color: Colors.white) : null,
                  onTap: () {
                    app.setLanguage('ru');
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _scopeLabel() {
    final s = app.strings;
    return switch (app.autoSwitchScope) {
      ScanScope.noRu => s.scopeNoRu,
      ScanScope.favorites => s.scopeFavorites,
      _ => s.scopeAll,
    };
  }

  String _subSourceLabel() {
    if (app.autoSwitchSubId != 'all') {
      for (final sub in app.subs) {
        if (sub.id == app.autoSwitchSubId) return sub.name;
      }
    }
    return app.strings.subsAll;
  }

  void _showScopeSheet(BuildContext context) {
    final s = app.strings;
    final options = [
      (ScanScope.all, s.scopeAll, s.scopeAllSub, null),
      (ScanScope.noRu, s.scopeNoRu, s.scopeNoRuSub, 'ru'),
      (ScanScope.favorites, s.scopeFavorites, s.scopeFavoritesSub, null),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(s.scanScope, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.textMid),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Divider(color: AppColors.divider),
                for (final opt in options)
                  ListTile(
                    leading: opt.$4 != null ? CircleFlag(opt.$4!, size: 24) : Icon(
                      opt.$1 == ScanScope.favorites ? Icons.star_rounded : Icons.public_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    title: Text(opt.$2, style: TextStyle(color: Colors.white, fontSize: 15)),
                    subtitle: Text(opt.$3, style: TextStyle(color: AppColors.textMid, fontSize: 12)),
                    trailing: app.autoSwitchScope == opt.$1 ? Icon(Icons.check, color: Colors.white) : null,
                    onTap: () {
                      app.setAutoSwitchScope(opt.$1);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSubSourceSheet(BuildContext context) {
    final s = app.strings;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.scanSubSource,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.textMid),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Divider(color: AppColors.divider),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        leading: Icon(Icons.public_rounded, color: Colors.white, size: 24),
                        title: Text(s.subsAll, style: TextStyle(color: Colors.white, fontSize: 15)),
                        trailing: app.autoSwitchSubId == 'all' ? Icon(Icons.check, color: Colors.white) : null,
                        onTap: () {
                          app.setAutoSwitchSubId('all');
                          Navigator.pop(ctx);
                        },
                      ),
                      for (final sub in app.subs)
                        ListTile(
                          leading: Icon(Icons.rss_feed_rounded, color: Colors.white, size: 22),
                          title: Text(
                            sub.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                          trailing: app.autoSwitchSubId == sub.id ? Icon(Icons.check, color: Colors.white) : null,
                          onTap: () {
                            app.setAutoSwitchSubId(sub.id);
                            Navigator.pop(ctx);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRoutingSheet(BuildContext context) {
    final s = app.strings;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(s.routingRules, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                      Spacer(),
                      IconButton(icon: Icon(Icons.close, color: AppColors.textMid), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Divider(color: AppColors.divider),
                ListTile(
                  leading: Icon(Icons.public_rounded, color: Colors.white, size: 24),
                  title: Text(s.routeAll, style: TextStyle(color: Colors.white, fontSize: 15)),
                  subtitle: Text(s.routeAllSub, style: TextStyle(color: AppColors.textMid, fontSize: 12)),
                  trailing: !app.blockAds ? Icon(Icons.check, color: Colors.white) : null,
                  onTap: () {
                    app.setBlockAds(false);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.block_rounded, color: Colors.white, size: 24),
                  title: Text(s.routeNoAds, style: TextStyle(color: Colors.white, fontSize: 15)),
                  subtitle: Text(s.routeNoAdsSub, style: TextStyle(color: AppColors.textMid, fontSize: 12)),
                  trailing: app.blockAds ? Icon(Icons.check, color: Colors.white) : null,
                  onTap: () {
                    app.setBlockAds(true);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showIpStrategySheet(BuildContext context) {
    final s = app.strings;
    final options = <(String, String)>[
      ('auto', s.isRu ? 'Авто' : 'Auto'),
      ('ipv4', 'IPv4'),
      ('ipv6', 'IPv6'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(s.preferredIp, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                      Spacer(),
                      IconButton(icon: Icon(Icons.close, color: AppColors.textMid), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Divider(color: AppColors.divider),
                for (final opt in options)
                  ListTile(
                    title: Text(opt.$2, style: TextStyle(color: Colors.white, fontSize: 15)),
                    trailing: app.ipStrategy == opt.$1 ? Icon(Icons.check, color: Colors.white) : null,
                    onTap: () {
                      app.setIpStrategy(opt.$1);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPingServiceSheet(BuildContext context) {
    final s = app.strings;
    final customCtrl = TextEditingController(text: TunnelSettings.pingUrl);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.pingService,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                      IconButton(icon: Icon(Icons.close, color: AppColors.textMid), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Divider(color: AppColors.divider),
                for (final preset in kPingServicePresets)
                  ListTile(
                    title: Text(preset.$2, style: TextStyle(color: Colors.white, fontSize: 15)),
                    subtitle: Text(
                      preset.$3.replaceFirst('https://', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textMid, fontSize: 12),
                    ),
                    trailing: TunnelSettings.pingUrl == preset.$3 ? Icon(Icons.check, color: Colors.white) : null,
                    onTap: () {
                      app.setPingUrl(preset.$3);
                      Navigator.pop(ctx);
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.link_rounded, color: Colors.white, size: 22),
                  title: Text(s.customUrl, style: TextStyle(color: Colors.white, fontSize: 15)),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        backgroundColor: AppColors.dialogBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text(s.customUrl, style: TextStyle(color: Colors.white, fontSize: 16)),
                        content: TextField(
                          controller: customCtrl,
                          autofocus: true,
                          keyboardType: TextInputType.url,
                          style: TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: s.customPingHint,
                            hintStyle: TextStyle(color: AppColors.textLow),
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dctx), child: Text(s.cancel, style: TextStyle(color: AppColors.textMid))),
                          TextButton(
                            onPressed: () {
                              final u = customCtrl.text.trim();
                              if (u.startsWith('http')) {
                                app.setPingUrl(u);
                              }
                              Navigator.pop(dctx);
                            },
                            child: Text(s.save, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPingMethodSheet(BuildContext context) {
    final s = app.strings;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(s.pingMethod, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                      Spacer(),
                      IconButton(icon: Icon(Icons.close, color: AppColors.textMid), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Divider(color: AppColors.divider),
                ListTile(
                  title: Text(s.pingTcp, style: TextStyle(color: Colors.white, fontSize: 15)),
                  subtitle: Text(s.pingTcpSub, style: TextStyle(color: AppColors.textMid, fontSize: 12)),
                  trailing: !app.pingCoreMethod ? Icon(Icons.check, color: Colors.white) : null,
                  onTap: () {
                    app.setPingMethod(false);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  title: Text(s.pingCore, style: TextStyle(color: Colors.white, fontSize: 15)),
                  subtitle: Text(s.pingCoreSub, style: TextStyle(color: AppColors.textMid, fontSize: 12)),
                  trailing: app.pingCoreMethod ? Icon(Icons.check, color: Colors.white) : null,
                  onTap: () {
                    app.setPingMethod(true);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPingThreadsSheet(BuildContext context) {
    final counts = [4, 8, 12, 16, 20, 24, 32];
    final s = app.strings;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        s.isRu ? 'Потоков сканирования' : 'Scan Threads',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      Spacer(),
                      IconButton(icon: Icon(Icons.close, color: AppColors.textMid), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Divider(color: AppColors.divider),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final n in counts)
                        ListTile(
                          title: Text('$n', style: TextStyle(color: Colors.white, fontSize: 15)),
                          trailing: app.pingThreads == n ? Icon(Icons.check, color: Colors.white) : null,
                          onTap: () {
                            app.setPingThreads(n);
                            Navigator.pop(ctx);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Full-screen per-app proxy editor: mode + searchable app list.
  Future<void> _openAppProxyEditor(BuildContext context) async {
    final (apps, self) = await getInstalledApps();
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AppProxyEditorScreen(app: app, apps: apps, selfPackage: self),
      ),
    );
  }

  String _pingIntervalLabel() {
    final s = app.strings;
    return switch (app.pingCacheMinutes) {
      5 => s.every5min,
      10 => s.every10min,
      30 => s.every30min,
      60 => s.everyHour,
      _ => '${app.pingCacheMinutes} min',
    };
  }

  void _showPingIntervalSheet(BuildContext context) {
    final s = app.strings;
    final options = <(int, String)>[
      (5, s.every5min),
      (10, s.every10min),
      (30, s.every30min),
      (60, s.everyHour),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.pingCacheInterval,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                      IconButton(icon: Icon(Icons.close, color: AppColors.textMid), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Divider(color: AppColors.divider),
                for (final opt in options)
                  ListTile(
                    title: Text(opt.$2, style: TextStyle(color: Colors.white, fontSize: 15)),
                    trailing: app.pingCacheMinutes == opt.$1 ? Icon(Icons.check, color: Colors.white) : null,
                    onTap: () {
                      app.setPingCacheMinutes(opt.$1);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _emojiLabel(EmojiFilterMode mode) {
    final s = app.strings;
    return switch (mode) {
      EmojiFilterMode.none => s.emojiShowAll,
      EmojiFilterMode.hideFlags => s.emojiHideFlags,
      EmojiFilterMode.hideAll => s.emojiHideAll,
    };
  }

  void _showEmojiSheet(BuildContext context, {required bool isInApp}) {
    final s = app.strings;
    final current = isInApp ? app.inAppEmojiMode : app.notificationEmojiMode;
    final title = isInApp ? s.emojiInApp : s.emojiNotification;
    final options = [
      (EmojiFilterMode.none, s.emojiShowAll),
      (EmojiFilterMode.hideFlags, s.emojiHideFlags),
      (EmojiFilterMode.hideAll, s.emojiHideAll),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.textMid),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Divider(color: AppColors.divider),
                for (final opt in options)
                  ListTile(
                    title: Text(opt.$2, style: TextStyle(color: Colors.white, fontSize: 15)),
                    trailing: current == opt.$1 ? Icon(Icons.check, color: Colors.white) : null,
                    onTap: () {
                      if (isInApp) {
                        app.setInAppEmojiMode(opt.$1);
                      } else {
                        app.setNotificationEmojiMode(opt.$1);
                      }
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportConfig(BuildContext context) async {
    final s = app.strings;
    try {
      final data = await app.exportConfig();
      final json = jsonEncode(data);
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().substring(0, 16).replaceAll(':', '-');
      final file = File('${dir.path}/develvpn_config_$stamp.json');
      await file.writeAsString(json, flush: true);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: s.isRu ? 'Экспорт DevelVpn' : 'DevelVpn export',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text('${s.subError}: $e')),
        );
      }
    }
  }

  Future<void> _importConfig(BuildContext context) async {
    final s = app.strings;
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = (res != null && res.files.isNotEmpty) ? res.files.single.path : null;
    if (path == null) return;
    try {
      final raw = await File(path).readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      await app.applyExportedConfig(data);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(s.subAdded)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text('${s.subError}: $e')),
        );
      }
    }
  }

  void _showThemeSheet(BuildContext context) {
    final s = app.strings;
    final options = <(String, String)>[
      ('system', s.isRu ? 'Как в системе' : 'Follow system'),
      ('dark', s.isRu ? 'Тёмная' : 'Dark'),
      ('light', s.isRu ? 'Светлая' : 'Light'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(s.themeRow, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textHi)),
                    ),
                    IconButton(icon: Icon(Icons.close, color: AppColors.textMid), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              Divider(color: AppColors.divider, height: 1),
              for (final opt in options)
                ListTile(
                  title: Text(opt.$2, style: TextStyle(color: AppColors.textHi, fontSize: 15)),
                  trailing: app.themeMode == opt.$1 ? Icon(Icons.check, color: AppColors.textHi) : null,
                  onTap: () {
                    app.setThemeMode(opt.$1);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAutoRefreshSheet(BuildContext context) {
    final s = app.strings;
    final options = <(int, String)>[
      (0, s.isRu ? 'Выключено' : 'Off'),
      (3, s.isRu ? 'Каждые 3 часа' : 'Every 3 hours'),
      (12, s.isRu ? 'Каждые 12 часов' : 'Every 12 hours'),
      (24, s.isRu ? 'Раз в сутки' : 'Once a day'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.isRu ? 'Автообновление подписок' : 'Auto-Refresh Subscriptions',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textHi),
                      ),
                    ),
                    IconButton(icon: Icon(Icons.close, color: AppColors.textMid), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              Divider(color: AppColors.divider, height: 1),
              for (final opt in options)
                ListTile(
                  title: Text(opt.$2, style: TextStyle(color: AppColors.textHi, fontSize: 15)),
                  trailing: app.autoRefreshHours == opt.$1 ? Icon(Icons.check, color: AppColors.textHi) : null,
                  onTap: () {
                    app.setAutoRefreshHours(opt.$1);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  /// Per-app autoswitch exemptions: pick apps where the server must stay put.
  Future<void> _openAutoswitchExemptEditor(BuildContext context) async {
    final s = app.strings;
    final hasPerm = await hasUsageStatsPermission();
    if (!hasPerm && context.mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(
          backgroundColor: AppColors.dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            s.isRu ? 'Доступ к статистике' : 'Usage Access',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Text(
            s.isRu
                ? 'Чтобы определять открытое приложение, разрешите DevelVpn доступ к статистике использования, затем вернитесь и выберите приложения.'
                : 'To detect the foreground app, grant DevelVpn usage access, then come back and pick the apps.',
            style: const TextStyle(color: const Color(0xFFC9C9CE), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: Text(s.cancel, style: TextStyle(color: AppColors.textMid)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.whiteOrBlack,
                foregroundColor: AppColors.isLight ? Colors.white : Colors.black,
              ),
              onPressed: () => Navigator.pop(dctx, true),
              child: Text(s.isRu ? 'Открыть' : 'Open'),
            ),
          ],
        ),
      );
      if (go == true) {
        _pendingExemptEditor = true;
        await openUsageStatsSettings();
      }
      return;
    }

    final apps = await getInstalledApps();
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _AppExemptEditorScreen(app: app, apps: apps.$1)),
    );
  }

  void _showThresholdSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ThresholdSheet(app: app),
    );
  }

  void _showDnsSheet(BuildContext context) {
    final servers = [
      ('Cloudflare (1.1.1.1)', '1.1.1.1'),
      ('Google (8.8.8.8)', '8.8.8.8'),
      ('AdGuard DNS (94.140.14.14)', '94.140.14.14'),
      ('Quad9 (9.9.9.9)', '9.9.9.9'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text('Custom DNS', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                      Spacer(),
                    ],
                  ),
                ),
                Divider(color: AppColors.divider),
                for (final dns in servers)
                  ListTile(
                    title: Text(dns.$1, style: TextStyle(color: Colors.white, fontSize: 15)),
                    trailing: app.customDns == dns.$2 ? Icon(Icons.check, color: Colors.white) : null,
                    onTap: () {
                      app.setCustomDns(dns.$2);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showResetDialog(BuildContext context) {
    final s = app.strings;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.resetAllData, style: TextStyle(color: Colors.white, fontSize: 17)),
        content: Text(
          s.resetConfirm,
          style: TextStyle(color: AppColors.textMid, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
            onPressed: () async {
              await app.clearAllData();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(s.delete, style: TextStyle(color: Color(0xFFFF5252))),
          ),
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  final String currentLang;
  final VoidCallback onTap;
  final String title;
  final String subtitle;

  _LanguageRow({
    required this.currentLang,
    required this.onTap,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isRu = currentLang == 'ru';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider, width: 0.8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.rowName),
                    SizedBox(height: 2),
                    Text(subtitle, style: AppText.rowSub),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleFlag(isRu ? 'ru' : 'us', size: 18),
                  SizedBox(width: 8),
                  Text(isRu ? 'Русский' : 'English', style: AppText.rowValue.copyWith(color: AppColors.textHi)),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 20, color: AppColors.textMid),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------- per-app proxy editor ---------------- */

class _AppProxyEditorScreen extends StatefulWidget {
  final AppState app;
  final List<(String, String)> apps; // (package, label)
  final String selfPackage;

  _AppProxyEditorScreen({
    required this.app,
    required this.apps,
    required this.selfPackage,
  });

  @override
  State<_AppProxyEditorScreen> createState() => _AppProxyEditorScreenState();
}

class _AppProxyEditorScreenState extends State<_AppProxyEditorScreen> {
  late Set<String> _selected;
  late String _mode;
  String _query = '';
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.app.appProxyList.toSet();
    _mode = widget.app.appProxyMode;
  }

  void _save() {
    widget.app.setAppProxyList(_selected.toList());
  }

  List<(String, String)> get _filtered {
    if (_query.isEmpty) return widget.apps;
    final q = _query.toLowerCase();
    return widget.apps.where((a) => a.$2.toLowerCase().contains(q) || a.$1.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.app.strings;
    final list = _filtered;
    return Scaffold(
      backgroundColor: AppColors.blackBg,
      appBar: AppBar(
        backgroundColor: AppColors.blackBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(s.appProxy, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () {
              _save();
              Navigator.pop(context);
            },
            child: Text(s.save, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: _modeChip(
                    label: s.isRu ? 'Все кроме выбранных' : 'All except selected',
                    selected: _mode == 'exclude',
                    onTap: () {
                      setState(() => _mode = 'exclude');
                      widget.app.setAppProxyMode('exclude');
                    },
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _modeChip(
                    label: s.isRu ? 'Только выбранные' : 'Only selected',
                    selected: _mode == 'include',
                    onTap: () {
                      setState(() => _mode = 'include');
                      widget.app.setAppProxyMode('include');
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: AppColors.dialogBg, borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: _ctrl,
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        icon: Icon(Icons.search_rounded, size: 18, color: AppColors.textMid),
                        hintText: s.isRu ? 'Поиск приложений' : 'Search apps',
                        hintStyle: TextStyle(color: AppColors.textLow, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_selected.length} ${s.isRu ? 'выбрано' : 'selected'}',
                  style: TextStyle(color: AppColors.textMid, fontSize: 12),
                ),
                Spacer(),
                TextButton(
                  onPressed: () {
                    widget.app.setAppProxyEnabled(_selected.isNotEmpty);
                    Navigator.pop(context);
                  },
                  child: Text(
                    s.isRu ? 'Готово' : 'Done',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: AppColors.divider, height: 1),
          Expanded(
            child: ListView.builder(
              physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final (pkg, label) = list[i];
                final checked = _selected.contains(pkg);
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.cardSelected,
                    child: Text(
                      label.isNotEmpty ? label.characters.first.toUpperCase() : '?',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  title: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textHi, fontSize: 14),
                  ),
                  subtitle: Text(
                    pkg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textLow, fontSize: 11),
                  ),
                  trailing: Checkbox(
                    value: checked,
                    activeColor: Colors.white,
                    checkColor: Color(0xFF141416),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(pkg);
                        } else {
                          _selected.remove(pkg);
                        }
                      });
                      _save();
                      widget.app.setAppProxyEnabled(_selected.isNotEmpty);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.cardSelected : AppColors.dialogBg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: selected ? Colors.white38 : Colors.transparent),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textMid,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ThresholdSheet extends StatefulWidget {
  final AppState app;
  _ThresholdSheet({required this.app});

  @override
  State<_ThresholdSheet> createState() => _ThresholdSheetState();
}

class _ThresholdSheetState extends State<_ThresholdSheet> {
  late double _currentVal;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _currentVal = widget.app.autoSwitchThreshold.toDouble().clamp(50.0, 3000.0);
    _controller = TextEditingController(text: widget.app.autoSwitchThreshold.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateFromSlider(double v) {
    setState(() {
      _currentVal = v;
      _controller.text = v.round().toString();
    });
  }

  void _updateFromText(String t) {
    final parsed = int.tryParse(t);
    if (parsed != null) {
      setState(() {
        _currentVal = parsed.toDouble().clamp(50.0, 3000.0);
      });
    }
  }

  void _apply() {
    final v = int.tryParse(_controller.text) ?? _currentVal.round();
    widget.app.setAutoSwitchThreshold(v.clamp(50, 5000));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.app.strings;
    final presets = [300, 500, 650, 800, 1000, 1500];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.maxPingThreshold,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textMid),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(color: AppColors.divider),
            SizedBox(height: 12),
            // Input field with ms
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Color(0xFF1B1B1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.graySwitch),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: _updateFromText,
                          ),
                        ),
                        Text(
                          'ms',
                          style: TextStyle(color: AppColors.textMid, fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.white,
                inactiveTrackColor: AppColors.graySwitch,
                thumbColor: Colors.white,
                overlayColor: Color(0x26FFFFFF),
                trackHeight: 4,
              ),
              child: Slider(
                value: _currentVal,
                min: 50,
                max: 2000,
                divisions: 39,
                onChanged: _updateFromSlider,
              ),
            ),
            SizedBox(height: 10),
            // Presets
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in presets) ...[
                    GestureDetector(
                      onTap: () {
                        _updateFromSlider(p.toDouble());
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        margin: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: (_currentVal.round() == p) ? Colors.white : Color(0xFF1B1B1E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (_currentVal.round() == p) ? Colors.white : AppColors.graySwitch,
                          ),
                        ),
                        child: Text(
                          '$p ms',
                          style: TextStyle(
                            color: (_currentVal.round() == p) ? Color(0xFF141416) : Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.whiteOrBlack,
                foregroundColor: AppColors.isLight ? Colors.white : const Color(0xFF141416),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                s.apply,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- autoswitch exempt apps editor ---------------- */

class _AppExemptEditorScreen extends StatefulWidget {
  final AppState app;
  final List<(String, String)> apps;

  const _AppExemptEditorScreen({required this.app, required this.apps});

  @override
  State<_AppExemptEditorScreen> createState() => _AppExemptEditorScreenState();
}

class _AppExemptEditorScreenState extends State<_AppExemptEditorScreen> {
  late Set<String> _selected;
  String _query = '';
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.app.autoswitchExemptApps.toSet();
  }

  void _save() {
    widget.app.setAutoswitchExemptApps(_selected.toList());
  }

  List<(String, String)> get _filtered {
    if (_query.isEmpty) return widget.apps;
    final q = _query.toLowerCase();
    return widget.apps.where((a) => a.$2.toLowerCase().contains(q) || a.$1.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.app.strings;
    final list = _filtered;
    return Scaffold(
      backgroundColor: AppColors.blackBg,
      appBar: AppBar(
        backgroundColor: AppColors.blackBg,
        foregroundColor: AppColors.textHi,
        elevation: 0,
        title: Text(
          s.isRu ? 'Без автосмены' : 'No Auto-Switch',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _save();
              Navigator.pop(context);
            },
            child: Text(s.save, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _ctrl,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(color: AppColors.textHi, fontSize: 13),
                decoration: InputDecoration(
                  icon: Icon(Icons.search_rounded, size: 18, color: AppColors.textMid),
                  hintText: s.isRu ? 'Поиск приложений' : 'Search apps',
                  hintStyle: TextStyle(color: AppColors.textLow, fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s.isRu
                    ? 'Выбранные приложения: сервер не переключается, пока они открыты'
                    : 'Selected apps: the server never switches while they are open',
                style: TextStyle(color: AppColors.textLow, fontSize: 11.5),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final (pkg, label) = list[i];
                final checked = _selected.contains(pkg);
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.cardSelected,
                    child: Text(
                      label.isNotEmpty ? label.characters.first.toUpperCase() : '?',
                      style: TextStyle(color: AppColors.textHi, fontSize: 12),
                    ),
                  ),
                  title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textHi, fontSize: 14)),
                  subtitle: Text(pkg, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textLow, fontSize: 11)),
                  trailing: Checkbox(
                    value: checked,
                    activeColor: AppColors.whiteOrBlack,
                    checkColor: AppColors.isLight ? Colors.white : const Color(0xFF141416),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(pkg);
                        } else {
                          _selected.remove(pkg);
                        }
                      });
                      _save();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
