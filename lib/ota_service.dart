import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'theme.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UpdateInfo {
  final String version;
  final int build;
  final String downloadUrl;
  final String changelog;
  final String size;
  final bool mandatory;

  UpdateInfo({
    required this.version,
    required this.build,
    required this.downloadUrl,
    required this.changelog,
    required this.size,
    this.mandatory = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String? ?? '1.0.0',
      build: (json['build'] as num?)?.toInt() ?? (json['build_number'] as num?)?.toInt() ?? 1,
      downloadUrl: (json['download_url'] ?? json['downloadUrl'] ?? json['url']) as String? ?? '',
      changelog: json['changelog'] as String? ?? 'Bug fixes and performance improvements.',
      size: json['size'] as String? ?? json['file_size'] as String? ?? '72 MB',
      mandatory: json['mandatory'] as bool? ?? false,
    );
  }
}

class OtaService {
  static String currentVersion = '1.0.8';
  static int currentBuild = 8;

  static String defaultUpdateUrl = 'https://develvpn.app/version.json';
  static String fallbackUpdateUrl = 'https://raw.githubusercontent.com/develvpn/releases/main/version.json';

  static MethodChannel _channel = MethodChannel('devel_vpn/ota');

  static Future<String> getUpdateUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ota_update_url') ?? defaultUpdateUrl;
  }

  static Future<void> setUpdateUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ota_update_url', url.trim());
  }

  static Future<bool> canInstallPackages() async {
    try {
      final res = await _channel.invokeMethod<bool>('canInstallPackages');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod('openInstallSettings');
    } catch (_) {}
  }

  static Future<String> getCacheDir() async {
    try {
      final res = await _channel.invokeMethod<String>('getCacheDir');
      if (res != null && res.isNotEmpty) return res;
    } catch (_) {}
    return Directory.systemTemp.path;
  }

  static Future<void> triggerInstall(String apkPath) async {
    await _channel.invokeMethod('installApk', {'path': apkPath});
  }

  /// Checks remote endpoint for a newer version
  static Future<UpdateInfo?> checkForUpdate({String? overrideUrl}) async {
    final url = overrideUrl ?? await getUpdateUrl();
    try {
      var uri = Uri.parse(url);
      var res = await http.get(uri).timeout(Duration(seconds: 7));
      if (res.statusCode != 200 && url == defaultUpdateUrl) {
        // Fallback to secondary endpoint
        uri = Uri.parse(fallbackUpdateUrl);
        res = await http.get(uri).timeout(Duration(seconds: 7));
      }
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final info = UpdateInfo.fromJson(data);
        if (info.build > currentBuild || _isVersionGreater(info.version, currentVersion)) {
          return info;
        }
      }
    } catch (e) {
      debugPrint('OTA check error: $e');
    }
    return null;
  }

  static bool _isVersionGreater(String newV, String oldV) {
    try {
      final nParts = newV.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final oParts = oldV.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (var i = 0; i < 3; i++) {
        final n = i < nParts.length ? nParts[i] : 0;
        final o = i < oParts.length ? oParts[i] : 0;
        if (n > o) return true;
        if (n < o) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Downloads the APK with real-time percentage and byte progress
  static Future<File> downloadApk(
    UpdateInfo info, {
    required void Function(double progress, String status) onProgress,
  }) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(info.downloadUrl));
      final res = await client.send(req);
      if (res.statusCode != 200) {
        throw Exception('Server returned HTTP ${res.statusCode}');
      }

      final totalBytes = res.contentLength ?? 0;
      final cacheDir = await getCacheDir();
      final targetFile = File('$cacheDir/develvpn_update.apk');
      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }

      final sink = targetFile.openWrite();
      var receivedBytes = 0;

      await for (final chunk in res.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final p = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          final recMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
          onProgress(p, '$recMb MB / $totalMb MB (${(p * 100).toInt()}%)');
        } else {
          final recMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          onProgress(0.5, '$recMb MB downloaded');
        }
      }

      await sink.flush();
      await sink.close();
      return targetFile;
    } finally {
      client.close();
    }
  }
}

/* ---------------- OTA UI Modal Sheet ---------------- */

class OtaSheet extends StatefulWidget {
  final bool isRu;
  OtaSheet({super.key, required this.isRu});

  static Future<void> show(BuildContext context, {bool isRu = false}) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.inputFill,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => OtaSheet(isRu: isRu),
    );
  }

  @override
  State<OtaSheet> createState() => _OtaSheetState();
}

class _OtaSheetState extends State<OtaSheet> {
  bool _checking = true;
  UpdateInfo? _update;
  String? _error;
  bool _downloading = false;
  double _progress = 0.0;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final info = await OtaService.checkForUpdate();
      if (mounted) {
        setState(() {
          _checking = false;
          _update = info;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _startDownloadAndInstall() async {
    if (_update == null || _downloading) return;

    // Check unknown sources install permission first
    final canInstall = await OtaService.canInstallPackages();
    if (!canInstall && mounted) {
      final allow = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.iconRoundBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            widget.isRu ? 'Разрешение на установку' : 'Install Permission',
            style: TextStyle(color: Colors.white, fontSize: 17),
          ),
          content: Text(
            widget.isRu
                ? 'Для автоматического обновления необходимо разрешить установку приложений из этого источника.'
                : 'To install updates, please allow installation of unknown apps for DevelVpn in settings.',
            style: TextStyle(color: AppColors.textMid, fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(widget.isRu ? 'Отмена' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.whiteOrBlack, foregroundColor: AppColors.isLight ? Colors.white : Colors.black),
              child: Text(widget.isRu ? 'Настройки' : 'Settings'),
            ),
          ],
        ),
      );
      if (allow == true) {
        await OtaService.openInstallSettings();
      }
      return;
    }

    setState(() {
      _downloading = true;
      _progress = 0.0;
      _statusText = widget.isRu ? 'Подготовка загрузки...' : 'Preparing download...';
    });

    try {
      final file = await OtaService.downloadApk(
        _update!,
        onProgress: (p, status) {
          if (mounted) {
            setState(() {
              _progress = p;
              _statusText = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _statusText = widget.isRu ? 'Запуск установки...' : 'Starting installer...';
        });
        await OtaService.triggerInstall(file.path);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _showConfigureUrlDialog() async {
    final currentUrl = await OtaService.getUpdateUrl();
    if (!mounted) return;
    final controller = TextEditingController(text: currentUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.iconRoundBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          widget.isRu ? 'URL сервера обновлений' : 'OTA Update URL',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isRu
                  ? 'Адрес файла version.json для автоматического обновления:'
                  : 'Address of version.json for over-the-air updates:',
              style: TextStyle(color: AppColors.textMid, fontSize: 12.5),
            ),
            SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.chipBorder),
              ),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: TextField(
                controller: controller,
                style: TextStyle(color: Colors.white, fontSize: 12.5),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'https://...',
                  hintStyle: TextStyle(color: AppColors.textLow),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(widget.isRu ? 'Отмена' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await OtaService.setUpdateUrl(newUrl);
                if (ctx.mounted) Navigator.pop(ctx);
                _check();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.whiteOrBlack, foregroundColor: AppColors.isLight ? Colors.white : Colors.black),
            child: Text(widget.isRu ? 'Сохранить' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 14, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isRu ? 'Обновление DevelVpn' : 'DevelVpn Updates',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.settings_outlined, size: 20, color: AppColors.textMid),
                  tooltip: 'Configure OTA URL',
                  onPressed: _showConfigureUrlDialog,
                ),
              ],
            ),
            SizedBox(height: 12),
            if (_checking) ...[
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Column(
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Checking for updates...',
                        style: TextStyle(color: AppColors.textMid, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_downloading) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.isRu ? 'Загрузка обновления...' : 'Downloading update...',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                        ),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: TextStyle(color: Color(0xFFA8E2BD), fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 7,
                        backgroundColor: Color(0xFF2C2C32),
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _statusText,
                      style: TextStyle(color: AppColors.textMid, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ] else if (_update != null) ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.iconRoundBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.chipBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.greenBadgeBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'v${_update!.version}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFA8E2BD)),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Build ${_update!.build} · ${_update!.size}',
                          style: TextStyle(color: AppColors.textMid, fontSize: 12),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      widget.isRu ? 'Что нового:' : "What's new:",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    SizedBox(height: 6),
                    Text(
                      _update!.changelog,
                      style: TextStyle(color: AppColors.textMid, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startDownloadAndInstall,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.whiteOrBlack,
                    foregroundColor: AppColors.isLight ? Colors.white : Colors.black,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    widget.isRu ? 'Скачать и установить' : 'Download & Install',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ] else ...[
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Color(0x1A4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_rounded, color: Color(0xFF4CAF50), size: 30),
                      ),
                      SizedBox(height: 14),
                      Text(
                        widget.isRu ? 'У вас установлена последняя версия' : 'You are up to date',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'DevelVpn v${OtaService.currentVersion} (Build ${OtaService.currentBuild})',
                        style: TextStyle(color: AppColors.textMid, fontSize: 13),
                      ),
                      if (_error != null) ...[
                        SizedBox(height: 10),
                        Text(
                          'Note: $_error',
                          style: TextStyle(color: Color(0xFFE57373), fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _check,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: AppColors.chipBorder),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    widget.isRu ? 'Проверить снова' : 'Check Again',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
