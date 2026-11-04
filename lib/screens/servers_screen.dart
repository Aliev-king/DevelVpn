import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../add_sheet.dart';
import '../data.dart';
import '../haptics.dart';
import '../l10n.dart';
import '../ping_manager.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ServersScreen extends StatefulWidget {
  final AppState app;
  ServersScreen({super.key, required this.app});

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  bool _pingRunning = false;
  bool _subsRefreshing = false;
  final Set<String> _collapsedSubs = {};
  final Set<String> _collapsedCountries = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.inactive) {
      PingManager.cancel();
      if (_pingRunning) {
        setState(() => _pingRunning = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PingManager.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _togglePingUpdate() async {
    if (_pingRunning) {
      PingManager.cancel();
      setState(() => _pingRunning = false);
      return;
    }
    Haptics.ping();
    setState(() => _pingRunning = true);
    final app = widget.app;
    final visibleServers = app.servers.where((s) => !s.mode && s.vlessUrl != null && s.vlessUrl!.isNotEmpty).toList();
    final list = app.showFavoritesOnly ? visibleServers : visibleServers.take(30).toList();

    if (app.pingCoreMethod) {
      // Accurate core measurement — a few workers, it's heavier than a SYN.
      var cursor = 0;
      Future<void> worker() async {
        while (cursor < list.length) {
          final idx = cursor++;
          if (idx >= list.length) break;
          await app.pingServer(list[idx]);
          if (mounted) setState(() {});
        }
      }
      await Future.wait(List.generate(4, (_) => worker()));
    } else {
      await PingManager.pingAll(
        servers: list,
        concurrency: app.pingThreads,
        skipFresh: true,
        onResult: (s, ping) {
          if (mounted) setState(() {});
        },
        onDone: () {
          if (mounted) setState(() => _pingRunning = false);
        },
      );
      await PingManager.persistCache(app.servers);
    }
    Haptics.ping();
    if (mounted) setState(() => _pingRunning = false);
  }

  /// Refreshes every subscription and rebuilds the server list.
  Future<void> _refreshAllSubscriptions() async {
    if (_subsRefreshing) return;
    setState(() => _subsRefreshing = true);
    Haptics.ping();
    final app = widget.app;
    var ok = 0, failed = 0;
    for (final sub in List<Subscription>.from(app.subs)) {
      try {
        await app.refreshSubscription(sub.id);
        ok++;
      } catch (_) {
        failed++;
      }
    }
    if (mounted) {
      setState(() => _subsRefreshing = false);
      final s = app.strings;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(failed == 0 ? '${s.subsUpdated} ($ok)' : '${s.subsUpdated}: $ok, ✗ $failed'),
        ),
      );
    }
  }

  Future<void> _refreshOneSubscription(Subscription sub) async {
    final s = widget.app.strings;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(s.refreshingSubs)));
    try {
      await widget.app.refreshSubscription(sub.id);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(s.subsUpdated)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text('${s.subError}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = widget.app;
    final s = app.strings;
    final list = _visible();
    final Set<String> countryKeys;
    if (app.groupByCountry) {
      final buckets = <String, List<ServerData>>{};
      for (final server in list) {
        final key = server.flag ?? 'zz';
        (buckets[key] ??= []).add(server);
      }
      countryKeys = buckets.keys.toSet();
    } else {
      countryKeys = const {};
    }

    // Tap on empty space closes the keyboard.
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollUpdateNotification && (n.scrollDelta ?? 0).abs() > 0) {
            if (_searchFocus.hasFocus) _searchFocus.unfocus();
          }
          return false;
        },
        child: CustomScrollView(
          physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(22, 20, 14, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.servers, style: AppText.pageTitle),
                              SizedBox(height: 4),
                              Text(s.selectLocation, style: AppText.pageSub),
                            ],
                          ),
                        ),
                        _roundIcon(
                          icon: Icons.add_rounded,
                          onTap: () => PlusButtonHelper.showAddSheet(context, app),
                        ),
                        SizedBox(width: 8),
                        _roundIcon(
                          icon: _subsRefreshing ? Icons.sync_rounded : Icons.cloud_sync_rounded,
                          busy: _subsRefreshing,
                          onTap: _refreshAllSubscriptions,
                        ),
                        SizedBox(width: 8),
                        _roundIcon(
                          icon: Icons.refresh_rounded,
                          busy: _pingRunning,
                          onTap: _togglePingUpdate,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: _buildToolbar(s, countryKeys),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (list.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState(s))
            else ..._buildContentSlivers(list),
            SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _roundIcon({required IconData icon, required VoidCallback onTap, bool busy = false}) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: AppColors.iconRoundBg, shape: BoxShape.circle),
        child: busy
            ? Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 19, color: AppColors.textHi),
      ),
    );
  }

  List<ServerData> _visible() {
    final app = widget.app;
    var list = app.servers.where((s) => !s.mode).toList();
    if (app.showFavoritesOnly) {
      list = list.where((s) => s.isFavorite).toList();
    }
    if (app.searchQ.isNotEmpty) {
      final q = app.searchQ.toLowerCase();
      bool subMatches(ServerData sr) {
        for (final sub in app.subs) {
          if (sub.id == sr.subId && sub.name.toLowerCase().contains(q)) return true;
        }
        return false;
      }
      list = list.where((s) => s.searchKey.contains(q) || subMatches(s)).toList();
    }
    switch (app.sortBy) {
      case 'ping':
        list.sort((a, b) {
          if (a.pingMs <= 0 && b.pingMs <= 0) return 0;
          if (a.pingMs <= 0) return 1;
          if (b.pingMs <= 0) return -1;
          return a.pingMs.compareTo(b.pingMs);
        });
      case 'name':
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  Widget _buildToolbar(AppStrings s, Set<String> countryKeys) {
    final app = widget.app;
    // Two-row toolbar: search always has room, controls never overflow.
    return AnimatedBuilder(
      animation: _searchFocus,
      builder: (context, _) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          onChanged: app.setSearch,
                          textAlignVertical: TextAlignVertical.center,
                          style: TextStyle(color: AppColors.textHi, fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: s.searchServers,
                            hintStyle: TextStyle(color: AppColors.textLow, height: 1.0),
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                        ),
                      ),
                      // Cross while the search is active (text or focus);
                      // magnifier only when the search is idle.
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchController,
                        builder: (context, value, _) {
                          final hasText = value.text.isNotEmpty;
                          final active = hasText || _searchFocus.hasFocus;
                          return GestureDetector(
                            onTap: () {
                              if (hasText) {
                                _searchController.clear();
                                app.setSearch('');
                                _searchFocus.requestFocus();
                              } else if (_searchFocus.hasFocus) {
                                _searchFocus.unfocus();
                              } else {
                                _searchFocus.requestFocus();
                              }
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                active ? Icons.close_rounded : Icons.search_rounded,
                                size: 18,
                                color: active ? AppColors.textHi : AppColors.textLow,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: () => app.setShowFavoritesOnly(!app.showFavoritesOnly),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: app.showFavoritesOnly ? Color(0x33FFD700) : AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: app.showFavoritesOnly ? Color(0x88FFD700) : Colors.transparent),
                  ),
                  child: Icon(
                    app.showFavoritesOnly ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 20,
                    color: app.showFavoritesOnly ? Color(0xFFFFD700) : AppColors.textMid,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
                child: SortDropdown(app: app),
              ),
              if (app.groupByCountry && countryKeys.isNotEmpty) ...[
                SizedBox(width: 8),
                // Collapse / expand every country group at once.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      final allCollapsed = countryKeys.every(_collapsedCountries.contains);
                      if (allCollapsed) {
                        _collapsedCountries.clear();
                      } else {
                        _collapsedCountries.addAll(countryKeys);
                      }
                    });
                    Haptics.light();
                  },
                  child: Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
                    child: Icon(
                      countryKeys.every(_collapsedCountries.contains)
                          ? Icons.unfold_more_rounded
                          : Icons.unfold_less_rounded,
                      size: 20,
                      color: AppColors.textHi,
                    ),
                  ),
                ),
              ],
              Spacer(),
              Row(
                children: [
                  Text(s.merge, style: TextStyle(fontSize: 11.5, color: AppColors.textMid)),
                  SizedBox(width: 6),
                  _MergeSwitch(app: app),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppStrings s) {
    final app = widget.app;
    return Padding(
      padding: EdgeInsets.all(30),
      child: Text(
        app.showFavoritesOnly
            ? (s.isRu
                ? 'Нет избранных серверов.\nНажмите звёздочку ★ на любом сервере, чтобы добавить в избранное.'
                : 'No favorite servers yet.\nTap the star ★ on any server to add it to favorites.')
            : s.noServersYet,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMid, fontSize: 13, height: 1.6),
      ),
    );
  }

  /* ---------------- content slivers ---------------- */

  /// Fully virtualized card list with toolbar-aligned side margins (22px).
  Widget _serverCardsSliver(List<ServerData> group) {
    final app = widget.app;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => RepaintBoundary(
            child: _ServerCardWidget(
              app: app,
              s: group[index],
              selected: group[index].id == app.selected?.id,
              isFirst: index == 0,
              isLast: index == group.length - 1,
              onEdit: _showEditServerDialog,
              onInfo: _showServerInfoSheet,
            ),
          ),
          childCount: group.length,
        ),
      ),
    );
  }

  List<Widget> _buildContentSlivers(List<ServerData> list) {
    final app = widget.app;
    if (app.groupByCountry) {
      return _buildCountryGroups(list);
    }
    if (app.merged) {
      return [_serverCardsSliver(list)];
    }
    return _buildSubscriptionGroups(list);
  }

  /// Subscription groups: smooth animated collapse where cards slide up
  /// behind the header.
  List<Widget> _buildSubscriptionGroups(List<ServerData> list) {
    final app = widget.app;
    final slivers = <Widget>[];
    for (final sub in app.subs) {
      final subServers = list.where((sr) => sr.subId == sub.id).toList();
      if (subServers.isEmpty) continue;
      final isCollapsed = _collapsedSubs.contains(sub.id);
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: _SubHeaderWidget(
              sub: sub,
              count: subServers.length,
              collapsed: isCollapsed,
              onRefresh: () => _refreshOneSubscription(sub),
              onToggle: () => setState(() {
                if (isCollapsed) {
                  _collapsedSubs.remove(sub.id);
                } else {
                  _collapsedSubs.add(sub.id);
                }
              }),
              onOptions: () => _showSubscriptionOptions(sub),
              onInfo: () => _showSubscriptionInfoSheet(sub),
            ),
          ),
        ),
      );
      if (subServers.length <= 30) {
        slivers.add(
          SliverToBoxAdapter(
            child: _AnimatedCollapsibleCards(
              key: ValueKey('sub_${sub.id}'),
              collapsed: isCollapsed,
              servers: subServers,
              app: app,
              onEdit: _showEditServerDialog,
              onInfo: _showServerInfoSheet,
            ),
          ),
        );
      } else {
        if (!isCollapsed) {
          slivers.add(_serverCardsSliver(subServers));
        }
      }
    }
    // Servers without a subscription (edge case).
    final orphans = list.where((sr) => !app.subs.any((sub) => sub.id == sr.subId)).toList();
    if (orphans.isNotEmpty) {
      slivers.add(_serverCardsSliver(orphans));
    }
    return slivers;
  }

  /// "Group by country" mode: smooth animated collapse per country.
  List<Widget> _buildCountryGroups(List<ServerData> list) {
    final app = widget.app;
    final s = app.strings;
    final buckets = <String, List<ServerData>>{};
    for (final server in list) {
      final key = server.flag ?? 'zz';
      (buckets[key] ??= []).add(server);
    }
    final pinned = app.pinnedCountries;
    int rank(String k) {
      if (k == 'zz') return 2;
      return pinned.contains(k) ? 0 : 1;
    }

    final keys = buckets.keys.toList()
      ..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        return countryDisplayName(a == 'zz' ? null : a, s.isRu)
            .compareTo(countryDisplayName(b == 'zz' ? null : b, s.isRu));
      });

    final slivers = <Widget>[];
    for (final key in keys) {
      final group = buckets[key]!;
      final isCollapsed = _collapsedCountries.contains(key);
      final code = key == 'zz' ? null : key;
      final title = countryDisplayName(code, s.isRu);
      final isPinned = code != null && pinned.contains(code);

      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: RepaintBoundary(
              child: _CountryHeaderWidget(
                flagCode: code,
                title: title,
                count: group.length,
                collapsed: isCollapsed,
                pinned: isPinned,
                onToggle: () => setState(() {
                  if (isCollapsed) {
                    _collapsedCountries.remove(key);
                  } else {
                    _collapsedCountries.add(key);
                  }
                }),
                onPin: code == null
                    ? null
                    : () {
                        widget.app.togglePinnedCountry(code);
                        Haptics.light();
                      },
              ),
            ),
          ),
        ),
      );

      if (group.length <= 30) {
        slivers.add(
          SliverToBoxAdapter(
            child: _AnimatedCollapsibleCards(
              key: ValueKey('country_$key'),
              collapsed: isCollapsed,
              servers: group,
              app: app,
              onEdit: _showEditServerDialog,
              onInfo: _showServerInfoSheet,
            ),
          ),
        );
      } else {
        if (!isCollapsed) {
          slivers.add(_serverCardsSliver(group));
        }
      }
    }

    return slivers;
  }

  /* ---------------- actions & sheets ---------------- */

  void _showSubscriptionOptions(Subscription sub) {
    final s = widget.app.strings;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          sub.name,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                ListTile(
                  leading: Icon(Icons.info_outline_rounded, color: Colors.white),
                  title: Text(s.infoTitle, style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSubscriptionInfoSheet(sub);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: Colors.white),
                  title: Text(s.rename, style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRenameDialog(sub);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.refresh_rounded, color: Colors.white),
                  title: Text(s.updateServers, style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _refreshOneSubscription(sub);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Color(0xFFFF5252)),
                  title: Text(s.deleteSub, style: TextStyle(color: Color(0xFFFF5252))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteDialog(sub);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Full subscription details: traffic, favorite server, VPN time, description.
  void _showSubscriptionInfoSheet(Subscription initialSub) {
    final app = widget.app;
    final s = app.strings;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sheetBg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: app,
          builder: (context, _) {
            final sub = app.subs.firstWhere((x) => x.id == initialSub.id, orElse: () => initialSub);
            if ((sub.description == null || sub.description!.isEmpty) && sub.link != null) {
              app.refreshSubscription(sub.id);
            }
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(color: AppColors.mark, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sub.name,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: AppColors.textMid),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    Divider(color: AppColors.divider),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          _infoRow(s.infoTraffic, '${sub.trafficUsedStr} / ${sub.trafficTotalStr}'),
                          _infoRow(s.infoTrafficLeft, sub.trafficLeftStr),
                          _infoRow(s.infoServers, '${app.servers.where((e) => e.subId == sub.id).length}'),
                          _infoRow(s.infoFavoriteServer, app.mostUsedServerNameFor(sub.id) ?? '—'),
                          _infoRow(s.infoVpnTime, formatDuration(app.subUsageSeconds(sub.id))),
                          if (sub.description != null && sub.description!.trim().isNotEmpty) ...[
                            SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Color(0xFF161619),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Color(0xFF333338)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, size: 15, color: AppColors.textMid),
                                      SizedBox(width: 6),
                                      Text(
                                        s.infoDescription,
                                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    sub.description!,
                                    style: TextStyle(
                                      color: AppColors.textHi,
                                      fontSize: 13.5,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Server health: ping sparkline + speed test.
  void _showServerInfoSheet(ServerData server) {
    final s = widget.app.strings;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.mark, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        server.name,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textHi),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.textMid),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Divider(color: AppColors.divider),
                Text(s.isRu ? 'История пинга' : 'Ping history',
                    style: TextStyle(color: AppColors.textMid, fontSize: 12)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: CustomPaint(painter: _PingSparkline(PingManager.historyFor(server.id))),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.whiteOrBlack,
                      foregroundColor: AppColors.isLight ? Colors.white : const Color(0xFF141416),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(behavior: SnackBarBehavior.floating, content: Text(s.isRu ? 'Замер скорости…' : 'Measuring speed…')),
                      );
                      final mbps = await widget.app.runSpeedTest(server);
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(mbps > 0
                              ? (s.isRu ? 'Скорость: ${mbps.toStringAsFixed(1)} Мбит/с' : 'Speed: ${mbps.toStringAsFixed(1)} Mbps')
                              : (s.isRu ? 'Не удалось замерить скорость' : 'Speed test failed')),
                        ),
                      );
                    },
                    child: Text(
                      s.isRu ? 'Замерить скорость' : 'Run Speed Test',
                      style: const TextStyle(fontWeight: FontWeight.w600),
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

  String formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final isRu = widget.app.strings.isRu;
    if (h > 0) return isRu ? '$h ч $m мин' : '${h}h ${m}m';
    if (m > 0) return isRu ? '$m мин' : '${m}m';
    return isRu ? '$seconds с' : '${seconds}s';
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: AppColors.textMid, fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  /// Edit server: custom name, address and country flag.
  void _showEditServerDialog(ServerData server) {
    final s = widget.app.strings;
    final nameCtrl = TextEditingController(text: server.name);
    final addrCtrl = TextEditingController(text: server.city);
    final flagCtrl = TextEditingController(text: server.flag ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.editServer, style: TextStyle(color: Colors.white, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _editField(s.serverName, nameCtrl, false),
            SizedBox(height: 10),
            _editField(s.serverAddress, addrCtrl, false),
            SizedBox(height: 10),
            _editField(s.serverFlag, flagCtrl, true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel, style: TextStyle(color: AppColors.textMid))),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final addr = addrCtrl.text.trim();
              if (name.isEmpty || addr.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(s.saveError)));
                return;
              }
              widget.app.editServer(
                server.id,
                name: name,
                city: addr,
                flag: flagCtrl.text.trim().toLowerCase(),
              );
              Navigator.pop(ctx);
            },
            child: Text(s.save, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _editField(String hint, TextEditingController ctrl, bool isFlag) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: AppColors.textHi, fontSize: 14),
      maxLength: isFlag ? 2 : null,
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textLow, fontSize: 13),
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  void _showRenameDialog(Subscription sub) {
    final s = widget.app.strings;
    final controller = TextEditingController(text: sub.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.rename, style: TextStyle(color: Colors.white, fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: sub.name,
            hintStyle: TextStyle(color: AppColors.textLow),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                widget.app.renameSubscription(sub.id, newName);
              }
              Navigator.pop(ctx);
            },
            child: Text(s.save),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Subscription sub) {
    final s = widget.app.strings;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.deleteSub, style: TextStyle(color: Colors.white, fontSize: 17)),
        content: Text(
          s.deleteSubConfirm,
          style: TextStyle(color: AppColors.textMid, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
            onPressed: () {
              widget.app.deleteSubscription(sub.id);
              Navigator.pop(ctx);
            },
            child: Text(s.delete, style: TextStyle(color: Color(0xFFFF5252))),
          ),
        ],
      ),
    );
  }
}

/* ---------------- list items ---------------- */

/// Header of a subscription group: highlighted with a subtle border, carries
/// a per-subscription refresh button and an info button.
class _SubHeaderWidget extends StatelessWidget {
  final Subscription sub;
  final int count;
  final bool collapsed;
  final VoidCallback onRefresh;
  final VoidCallback onToggle;
  final VoidCallback onOptions;
  final VoidCallback onInfo;

  _SubHeaderWidget({
    required this.sub,
    required this.count,
    required this.collapsed,
    required this.onRefresh,
    required this.onToggle,
    required this.onOptions,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      onLongPress: onOptions,
      child: Container(
        padding: EdgeInsets.fromLTRB(10, 6, 10, 8),
        decoration: BoxDecoration(
          color: AppColors.sheetBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.chipBorder, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sub.name,
                          style: AppText.subName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onInfo,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMid),
                        ),
                      ),
                    ],
                  ),
                  if (sub.desc.isNotEmpty) ...[
                    SizedBox(height: 2),
                    Text(
                      '${sub.desc} · $count',
                      style: AppText.subDesc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.sync_rounded, size: 18, color: AppColors.textMid),
              tooltip: 'Refresh',
              onPressed: onRefresh,
            ),
            AnimatedRotation(
              turns: collapsed ? 0.0 : 0.5,
              duration: Duration(milliseconds: 200),
              curve: Curves.easeInOutCubic,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: AppColors.textLow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- country list items ---------------- */


/// Country group header for "Group by country" mode. Long-press pins the
/// country to the top of the list.
class _CountryHeaderWidget extends StatelessWidget {
  final String? flagCode;
  final String title;
  final int count;
  final bool collapsed;
  final bool pinned;
  final VoidCallback onToggle;
  final VoidCallback? onPin;

  _CountryHeaderWidget({
    required this.flagCode,
    required this.title,
    required this.count,
    required this.collapsed,
    required this.onToggle,
    this.pinned = false,
    this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      onLongPress: onPin,
      child: Container(
        padding: EdgeInsets.fromLTRB(10, 6, 10, 8),
        decoration: BoxDecoration(
          color: AppColors.sheetBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.chipBorder, width: 1),
        ),
        child: Row(
          children: [
            CircleFlag(flagCode, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: AppText.subName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('$count', style: AppText.subDesc),
            if (pinned) ...[
              SizedBox(width: 6),
              Icon(Icons.push_pin_rounded, size: 14, color: Color(0xFFFFD700)),
            ],
            AnimatedRotation(
              turns: collapsed ? 0.0 : 0.5,
              duration: Duration(milliseconds: 200),
              curve: Curves.easeInOutCubic,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: AppColors.textLow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedCollapsibleCards extends StatefulWidget {
  final bool collapsed;
  final List<ServerData> servers;
  final AppState app;
  final void Function(ServerData) onEdit;
  final void Function(ServerData) onInfo;

  _AnimatedCollapsibleCards({
    super.key,
    required this.collapsed,
    required this.servers,
    required this.app,
    required this.onEdit,
    required this.onInfo,
  });

  @override
  State<_AnimatedCollapsibleCards> createState() => _AnimatedCollapsibleCardsState();
}

class _AnimatedCollapsibleCardsState extends State<_AnimatedCollapsibleCards>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _renderChildren = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 240),
      value: widget.collapsed ? 0.0 : 1.0,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    _renderChildren = !widget.collapsed;
  }

  @override
  void didUpdateWidget(covariant _AnimatedCollapsibleCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collapsed != widget.collapsed) {
      if (widget.collapsed) {
        _ctrl.reverse().then((_) {
          if (mounted && widget.collapsed) {
            setState(() => _renderChildren = false);
          }
        });
      } else {
        setState(() => _renderChildren = true);
        _ctrl.forward();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_renderChildren && widget.collapsed && _ctrl.value == 0) {
      return SizedBox.shrink();
    }

    // Limit animated cards to at most 10 on-screen cards during collapse transition
    // as requested: "не обязательно анимировать все карточки, пусть анимированными будут только те что на экране"
    final count = widget.collapsed ? widget.servers.length.clamp(0, 10) : widget.servers.length;
    final displayServers = widget.servers.sublist(0, count);

    return ClipRect(
      child: SizeTransition(
        sizeFactor: _anim,
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (var i = 0; i < displayServers.length; i++)
                RepaintBoundary(
                  child: _ServerCardWidget(
                    app: widget.app,
                    s: displayServers[i],
                    selected: displayServers[i].id == widget.app.selected?.id,
                    isFirst: i == 0,
                    isLast: i == displayServers.length - 1,
                    onEdit: widget.onEdit,
                    onInfo: widget.onInfo,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerCardWidget extends StatefulWidget {
  final AppState app;
  final ServerData s;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final void Function(ServerData) onEdit;
  final void Function(ServerData) onInfo;

  _ServerCardWidget({
    required this.app,
    required this.s,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.onEdit,
    required this.onInfo,
  });

  @override
  State<_ServerCardWidget> createState() => _ServerCardWidgetState();
}

class _ServerCardWidgetState extends State<_ServerCardWidget> {
  bool _testingThisPing = false;

  Future<void> _pingServer() async {
    if (_testingThisPing) return;
    setState(() => _testingThisPing = true);
    await widget.app.pingServer(widget.s);
    if (mounted) {
      Haptics.ping();
      setState(() => _testingThisPing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.vertical(
      top: widget.isFirst ? Radius.circular(16) : Radius.zero,
      bottom: widget.isLast ? Radius.circular(16) : Radius.zero,
    );

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: borderRadius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: () => widget.app.select(widget.s.id),
            onLongPress: () => widget.onEdit(widget.s),
            child: Container(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 11),
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border(
                  top: widget.isFirst ? BorderSide.none : BorderSide(color: AppColors.divider, width: 0.8),
                  left: widget.selected ? BorderSide(color: Colors.white, width: 1.5) : BorderSide.none,
                  right: widget.selected ? BorderSide(color: Colors.white, width: 1.5) : BorderSide.none,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Selection check moved next to the flag so the favorite
                      // star stays at the far right edge in all cases.
                      CircleFlag(widget.s.flag, serverName: widget.s.name, size: 24),
                      if (widget.selected) ...[
                        SizedBox(width: 8),
                        WhiteCheck(size: 17),
                      ],
                      Spacer(),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.app.toggleFavorite(widget.s.id),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(
                            widget.s.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 21,
                            color: widget.s.isFavorite ? Colors.white : AppColors.textLow,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.s.displayName(widget.app.inAppEmojiMode),
                          style: AppText.cardName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _pingServer,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(widget.s.pingMs > 0 ? '${widget.s.pingMs} ms' : '-- ms', style: AppText.cardPing),
                              SizedBox(width: 4),
                              _testingThisPing
                                  ? SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(strokeWidth: 1.4, color: AppColors.textMid),
                                    )
                                  : Icon(Icons.refresh_rounded, size: 14, color: AppColors.textMid),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onInfo(widget.s),
                        child: Padding(
                          padding: EdgeInsets.all(3),
                          child: Icon(Icons.insights_rounded, size: 15, color: AppColors.textMid),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(widget.s.city, style: AppText.cardSub),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- sort dropdown ---------------- */

class SortDropdown extends StatelessWidget {
  final AppState app;
  SortDropdown({super.key, required this.app});

  void _showSortSheet(BuildContext context) {
    final s = app.strings;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sheetBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  s.sortServers,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textHi),
                ),
                SizedBox(height: 16),
                _SortItem(
                  title: s.sortDefault,
                  subtitle: s.isRu ? 'Исходный порядок в подписке' : 'Default subscription order',
                  icon: Icons.sort_rounded,
                  selected: app.sortBy == 'default',
                  onTap: () {
                    app.setSort('default');
                    Navigator.pop(ctx);
                  },
                ),
                SizedBox(height: 8),
                _SortItem(
                  title: s.sortPing,
                  subtitle: s.isRu ? 'Сначала самые быстрые серверы' : 'Fastest responsive servers first',
                  icon: Icons.bolt_rounded,
                  selected: app.sortBy == 'ping',
                  onTap: () {
                    app.setSort('ping');
                    Navigator.pop(ctx);
                  },
                ),
                SizedBox(height: 8),
                _SortItem(
                  title: s.sortName,
                  subtitle: s.isRu ? 'В алфавитном порядке' : 'Alphabetical order',
                  icon: Icons.text_fields_rounded,
                  selected: app.sortBy == 'name',
                  onTap: () {
                    app.setSort('name');
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

  @override
  Widget build(BuildContext context) {
    final s = app.strings;
    final sortLabel = switch (app.sortBy) {
      'ping' => s.sortPing,
      'name' => s.sortName,
      _ => s.sortDefault,
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showSortSheet(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${s.sortLabel}: $sortLabel',
              style: TextStyle(fontSize: 12, color: AppColors.textMid),
            ),
            SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textLow),
          ],
        ),
      ),
    );
  }
}

class _SortItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  _SortItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
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
          color: selected ? AppColors.cardSelected : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.white.withValues(alpha: 0.35) : AppColors.chipBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? Colors.white : AppColors.textMid),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? AppColors.textHi : AppColors.textMid,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: AppColors.textLow),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/* ---------------- merge switch ---------------- */

class _MergeSwitch extends StatelessWidget {
  final AppState app;
  _MergeSwitch({required this.app});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => app.setMerged(!app.merged),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: 38,
        height: 22,
        padding: EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: app.merged ? Colors.white : AppColors.graySwitch,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: app.merged ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: app.merged ? Color(0xFF141416) : Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/* ---------------- ping sparkline ---------------- */

class _PingSparkline extends CustomPainter {
  final List<List<int>> points; // [epochMs, ping]
  _PingSparkline(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(text: '—', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2));
      return;
    }
    final pings = points.map((e) => e[1]).toList();
    final maxPing = pings.fold<int>(1, (m, v) => v > m ? v : m).toDouble();
    final stepX = points.length > 1 ? size.width / (points.length - 1) : size.width;

    final gridPaint = Paint()..color = const Color(0x1A888890);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), gridPaint);

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - (pings[i].clamp(0, maxPing) / maxPing) * (size.height - 6) - 3;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = const Color(0xFF7BAF8B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = const Color(0xFF2F5847);
    for (var i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - (pings[i].clamp(0, maxPing) / maxPing) * (size.height - 6) - 3;
      canvas.drawCircle(Offset(x, y), 2.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PingSparkline old) => old.points != points;
}
