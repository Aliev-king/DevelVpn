import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'theme.dart';

import 'services.dart';

/// Full-screen Xray core log viewer. The new core logs to logcat; the plugin
/// exposes `getLogs()` which collects those lines.
class LogsSheet extends StatefulWidget {
  final bool isRu;
  final VpnController? vpn;

  LogsSheet({super.key, required this.isRu, this.vpn});

  static Future<void> show(BuildContext context, {required bool isRu, VpnController? vpn}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LogsSheet(isRu: isRu, vpn: vpn)),
    );
  }

  @override
  State<LogsSheet> createState() => _LogsSheetState();
}

class _LogsSheetState extends State<LogsSheet> {
  List<String> _lines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final v2 = widget.vpn?.core;
      if (v2 != null) {
        final logs = await v2.getLogs().timeout(Duration(seconds: 5), onTimeout: () => <String>[]);
        _lines = logs.take(400).toList();
      } else {
        _lines = [];
      }
    } catch (_) {
      _lines = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.isRu;
    return Scaffold(
      backgroundColor: AppColors.blackBg,
      appBar: AppBar(
        backgroundColor: AppColors.blackBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(s ? 'Логи' : 'Logs', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            tooltip: widget.isRu ? 'Поделиться' : 'Share',
            onPressed: () async {
              final text = _lines.join(String.fromCharCode(10));
              if (text.isEmpty) return;
              await Share.share(text, subject: widget.isRu ? 'Логи DevelVpn' : 'DevelVpn logs');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : _lines.isEmpty
              ? Center(
                  child: Text(
                    s ? 'Логи пусты' : 'No log entries',
                    style: TextStyle(color: AppColors.textMid, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(14),
                  itemCount: _lines.length,
                  separatorBuilder: (_, __) => Divider(color: AppColors.dialogBg, height: 1),
                  itemBuilder: (context, i) {
                    final line = _lines[i];
                    final isError = line.toLowerCase().contains('error') || line.toLowerCase().contains('failed');
                    return SelectableText(
                      line,
                      style: TextStyle(
                        color: isError ? Color(0xFFFF8A80) : AppColors.textMid,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    );
                  },
                ),
    );
  }
}
