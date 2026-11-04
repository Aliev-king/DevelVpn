import 'package:flutter/material.dart';
import 'theme.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'app_state.dart';

/// Shared "add subscription" sheet used from Home and Servers tabs, plus the
/// QR scanner screen and the manual (name + vless links) form.
class PlusButtonHelper {
  static void showAddSheet(BuildContext context, AppState app) {
    final s = app.strings;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sheetBg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                SizedBox(height: 16),
                Text(
                  s.addSubscription,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textHi),
                ),
                SizedBox(height: 4),
                Text(
                  s.isRu ? 'Выберите способ импорта конфигурации' : 'Choose how to import server configs',
                  style: TextStyle(fontSize: 13, color: AppColors.textMid),
                ),
                SizedBox(height: 16),
                AddSheetTile(
                  icon: Icons.content_paste_rounded,
                  title: s.importClipboard,
                  subtitle: s.isRu ? 'Импортировать скопированную ссылку' : 'Import configuration from clipboard',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    final text = data?.text?.trim() ?? '';
                    if (text.isEmpty) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(behavior: SnackBarBehavior.floating, content: Text(s.isRu ? 'Буфер обмена пуст' : 'Clipboard is empty')),
                        );
                      }
                      return;
                    }
                    if (context.mounted) processLink(context, app, text);
                  },
                ),
                SizedBox(height: 10),
                AddSheetTile(
                  icon: Icons.link_rounded,
                  title: s.enterUrlManually,
                  subtitle: s.isRu ? 'Ввести адрес подписки или vless://' : 'Type subscription or vless:// link',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddLinkSheet(context, app);
                  },
                ),
                SizedBox(height: 10),
                AddSheetTile(
                  icon: Icons.edit_note_rounded,
                  title: s.addManual,
                  subtitle: s.addManualSub,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showManualSheet(context, app);
                  },
                ),
                SizedBox(height: 10),
                AddSheetTile(
                  icon: Icons.qr_code_scanner_rounded,
                  title: s.addQr,
                  subtitle: s.addQrSub,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final code = await Navigator.of(context).push<String>(
                      MaterialPageRoute(builder: (_) => QrScannerScreen()),
                    );
                    if (code != null && code.isNotEmpty && context.mounted) {
                      processLink(context, app, code);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> processLink(BuildContext context, AppState app, String link) async {
    final s = app.strings;
    try {
      await app.addSubscription(link);
      if (context.mounted) {
        final count = app.servers.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('${s.subAdded}: ${app.subs.last.name} (${s.isRu ? 'серверов' : 'servers'}: $count)'),
          ),
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

  static void _showAddLinkSheet(BuildContext context, AppState app) {
    final s = app.strings;
    final controller = TextEditingController(text: app.pendingLink ?? '');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sheetBg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: SheetGrabber()),
              SizedBox(height: 16),
              Text(
                s.enterUrlManually,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textHi),
              ),
              SizedBox(height: 4),
              Text(
                s.isRu ? 'Вставьте ссылку формата https://... или vless://...' : 'Paste subscription link or vless:// URL',
                style: TextStyle(fontSize: 13, color: AppColors.textMid),
              ),
              SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.iconRoundBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.chipBorder),
                ),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(color: AppColors.textHi, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: s.urlPlaceholder,
                    hintStyle: TextStyle(color: AppColors.textLow),
                    border: InputBorder.none,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(s.cancel, style: TextStyle(color: AppColors.textMid)),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.whiteOrBlack,
                      foregroundColor: AppColors.isLight ? Colors.white : const Color(0xFF141416),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final text = controller.text.trim();
                      Navigator.pop(ctx);
                      if (text.isNotEmpty) processLink(context, app, text);
                    },
                    child: Text(s.add, style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static void _showManualSheet(BuildContext context, AppState app) {
    final s = app.strings;
    final nameCtrl = TextEditingController();
    final linksCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sheetBg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: SheetGrabber()),
              SizedBox(height: 16),
              Text(
                s.addManual,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textHi),
              ),
              SizedBox(height: 4),
              Text(
                s.addManualSub,
                style: TextStyle(fontSize: 13, color: AppColors.textMid),
              ),
              SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.iconRoundBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.chipBorder),
                ),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: AppColors.textHi, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: s.manualName,
                    hintStyle: TextStyle(color: AppColors.textLow),
                    border: InputBorder.none,
                  ),
                ),
              ),
              SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.iconRoundBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.chipBorder),
                ),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: TextField(
                  controller: linksCtrl,
                  maxLines: 5,
                  minLines: 3,
                  style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: s.manualLinks,
                    hintStyle: TextStyle(color: AppColors.textLow, fontSize: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(s.cancel, style: TextStyle(color: AppColors.textMid)),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.whiteOrBlack,
                      foregroundColor: AppColors.isLight ? Colors.white : const Color(0xFF141416),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final links = linksCtrl.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                      if (links.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(behavior: SnackBarBehavior.floating, content: Text(s.manualEmpty)),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        await app.addManualSubscription(nameCtrl.text, links);
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
                    },
                    child: Text(s.add, style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class SheetGrabber extends StatelessWidget {
  SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.mark,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class AddSheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  AddSheetTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.chipBorder, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textHi),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHi,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMid),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textLow),
          ],
        ),
      ),
    );
  }
}

/// Minimal, dark QR scanner with torch and zoom controls.
class QrScannerScreen extends StatefulWidget {
  QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    torchEnabled: false,
  );
  bool _torchOn = false;
  double _zoom = 0.0;
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code != null && (code.startsWith('http') || code.startsWith('vless://') || code.startsWith('happ://') || code.startsWith('develvpn://'))) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru' ||
        (ModalRoute.of(context) != null && false);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(isRu ? 'QR-код' : 'QR Code', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Dimmed mask with a rounded scanning window.
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.55),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                SizedBox.expand(),
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white70, width: 1.5),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 120,
            child: Center(
              child: Text(
                isRu ? 'Наведите камеру на QR-код' : 'Point the camera at a QR code',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
          // Torch + zoom controls.
          Positioned(
            bottom: 36,
            left: 24,
            right: 24,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    _torchOn = !_torchOn;
                    _controller.toggleTorch();
                    setState(() {});
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _torchOn ? Colors.white : Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                      color: _torchOn ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Slider(
                    value: _zoom,
                    min: 0,
                    max: 1,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    onChanged: (v) {
                      _zoom = v;
                      _controller.setZoomScale(v);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
