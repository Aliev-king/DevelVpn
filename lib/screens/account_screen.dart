import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AccountScreen extends StatefulWidget {
  final AppState app;
  AccountScreen({super.key, required this.app});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final TextEditingController _nickCtrl = TextEditingController();
  final FocusNode _nickFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _nickCtrl.text = p.getString('profile_nick') ?? '';
      });
    });
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    _nickFocus.dispose();
    super.dispose();
  }

  void _saveNick(String v) {
    SharedPreferences.getInstance().then((p) => p.setString('profile_nick', v.trim()));
  }

  String _formatSeconds(int seconds, bool isRu) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return isRu ? '$h ч $m мин' : '${h}h ${m}m';
    if (m > 0) return isRu ? '$m мин' : '${m}m';
    return isRu ? '$seconds с' : '${seconds}s';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 GB';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final s = app.strings;

    final totalTraffic = app.subs.fold<int>(0, (acc, sub) => acc + sub.usedBytes);
    final vpnSeconds = app.totalSeconds;
    final mostUsed = app.favoriteServerName ?? app.mostUsedServerName;

    return AnimatedBuilder(
      animation: Listenable.merge([app, _nickFocus]),
      builder: (context, _) {
        return ListView(
          padding: EdgeInsets.only(bottom: 40),
          physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(22, 20, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.account, style: AppText.pageTitle),
                  SizedBox(height: 4),
                  Text(s.isRu ? 'Профиль и статистика' : 'Profile and stats', style: AppText.pageSub),
                ],
              ),
            ),
            SizedBox(height: 30),
            Center(
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider),
                ),
                padding: EdgeInsets.all(10),
                child: ClipOval(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      AppColors.isLight ? const Color(0xFF1C1C1E) : Colors.white,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset('assets/logo-white.png', fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            // Plain nickname field: saved as soon as you finish editing.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: TextField(
                controller: _nickCtrl,
                focusNode: _nickFocus,
                onSubmitted: _saveNick,
                onTapOutside: (_) => _saveNick(_nickCtrl.text),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: AppColors.textHi,
                ),
                decoration: InputDecoration(
                  hintText: s.nickHint,
                  hintStyle: TextStyle(color: AppColors.textLow, fontSize: 16),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
            SizedBox(height: 30),

            /* overall stats across every subscription */
            SecTitle(s.isRu ? 'Общая статистика' : 'Overall Stats'),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _statRow(s.statsSubs, '${app.subs.length}', showDivider: false),
                  _statRow(s.statsServers, '${app.servers.length}'),
                  _statRow(s.statsTotalTraffic, _formatBytes(totalTraffic)),
                  _statRow(s.statsFavoriteServer, mostUsed ?? '—'),
                  _statRow(s.statsVpnTime, _formatSeconds(vpnSeconds, s.isRu), showDivider: false),
                ],
              ),
            ),
            SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _statRow(String label, String value, {bool showDivider = true}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: showDivider ? Border(top: BorderSide(color: AppColors.divider, width: 0.8)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: AppColors.textMid, fontSize: 13.5)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textHi, fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
