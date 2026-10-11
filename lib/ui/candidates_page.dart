import 'dart:async';

import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../media/thumbnail_loader.dart';
import '../state/live_monitor.dart';
import 'candidate_detail_page.dart';
import 'theme.dart';
import 'widgets/cover_thumb.dart';
import 'widgets/eh_card.dart';
import 'widgets/empty_state.dart';
import 'widgets/error_view.dart';
import 'widgets/large_title_app_bar.dart';
import 'widgets/search_bar.dart';
import 'widgets/tone_chip.dart';

/// 候选 tab（`CANDIDATE_TABS`）→ 中文标签。
const Map<String, String> kCandidateTabs = <String, String>{
  'all': '全部',
  'pending': '待审核',
  'needs_info': '待补充',
  'approved': '已通过',
  'rejected': '已驳回',
  'failed': '失败',
};

/// 候选列表：大标题 + 常驻 tab / 搜索条 + 分页（加载更多）。
class CandidatesPage extends StatefulWidget {
  const CandidatesPage({
    super.key,
    required this.api,
    required this.thumbnails,
    this.monitor,
    this.candidatesTab,
    this.appBarActions = const <Widget>[],
  });

  final EhBotApi api;
  final ThumbnailLoader thumbnails;
  final LiveMonitor? monitor;

  /// Shared with [DashboardPage]. The dashboard chip updates it; this page
  /// listens so the two views agree on the active filter (M6).
  final ValueNotifier<String>? candidatesTab;

  /// 顶栏动作（由 [HomeShell] 注入设置入口等）。
  final List<Widget> appBarActions;

  @override
  State<CandidatesPage> createState() => _CandidatesPageState();
}

class _CandidatesPageState extends State<CandidatesPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<Candidate> _items = <Candidate>[];

  String _tab = 'pending';
  String _search = '';
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  Map<String, int> _tabCounts = <String, int>{};
  bool _loading = false;
  Object? _error;
  StreamSubscription<int>? _ticks;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
    _ticks = widget.monitor?.ticks.listen((int _) => unawaited(_reload()));
    widget.candidatesTab?.addListener(_onTabFromDashboard);
  }

  void _onTabFromDashboard() {
    final String? notifier = widget.candidatesTab?.value;
    if (notifier == null || notifier == _tab) {
      return;
    }
    setState(() => _tab = notifier);
    unawaited(_reload());
  }

  @override
  void dispose() {
    _ticks?.cancel();
    widget.candidatesTab?.removeListener(_onTabFromDashboard);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _items.clear();
      _page = 1;
      _pages = 1;
      _error = null;
    });
    await _load();
  }

  Future<void> _load() async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final CandidatePage page = await widget.api.candidates(
        tab: _tab,
        search: _search,
        page: _page,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items.addAll(page.items);
        _pages = page.pages < 1 ? 1 : page.pages;
        _total = page.total;
        _tabCounts = page.tabCounts;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_page >= _pages || _loading) {
      return;
    }
    _page += 1;
    await _load();
  }

  void _selectTab(String tab) {
    if (tab == _tab) {
      return;
    }
    setState(() => _tab = tab);
    unawaited(_reload());
  }

  Future<void> _openDetail(Candidate candidate) async {
    final bool changed =
        await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (BuildContext context) => CandidateDetailPage(
              api: widget.api,
              thumbnails: widget.thumbnails,
              candidate: candidate,
            ),
          ),
        ) ??
        false;
    if (changed) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _reload,
    child: CustomScrollView(
      slivers: <Widget>[
        EhLargeTitleAppBar(title: '候选', actions: widget.appBarActions),
        SliverToBoxAdapter(child: _filterBar(context)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverToBoxAdapter(child: Text('共 $_total 个')),
        ),
        ..._contentSlivers(),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    ),
  );

  Widget _filterBar(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              for (final MapEntry<String, String> tab in kCandidateTabs.entries)
                Padding(
                  padding: EdgeInsets.only(
                    right: tab.key == kCandidateTabs.keys.last ? 0 : 8,
                  ),
                  child: ChoiceChip(
                    key: ValueKey<String>('candidate-tab-${tab.key}'),
                    label: Text(
                      _tabCounts[tab.key] == null
                          ? tab.value
                          : '${tab.value} ${_tabCounts[tab.key]}',
                    ),
                    selected: _tab == tab.key,
                    onSelected: (bool _) => _selectTab(tab.key),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: EhSearchBar(
            key: const ValueKey<String>('candidate-search'),
            controller: _searchController,
            hint: '搜索标题 / 作者',
            onSubmitted: (String value) {
              _search = value;
              unawaited(_reload());
            },
          ),
        ),
      ],
    ),
  );

  List<Widget> _contentSlivers() {
    if (_error != null) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorView(error: _error!, onRetry: _reload),
        ),
      ];
    }
    if (_items.isEmpty && _loading) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_items.isEmpty) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.search_off,
            primary: '没有匹配的候选',
            secondary: '换个关键词，或清除筛选条件后重试',
          ),
        ),
      ];
    }
    final int columns = ehColumnsForWidth(MediaQuery.sizeOf(context).width);
    if (columns > 1) {
      return <Widget>[
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 160,
            ),
            itemCount: _items.length,
            itemBuilder: (BuildContext context, int index) =>
                RepaintBoundary(child: _candidateCard(_items[index])),
          ),
        ),
        if (_page < _pages) _loadMoreSliver(),
      ];
    }
    return <Widget>[
      SliverList.builder(
        itemCount: _items.length,
        itemBuilder: (BuildContext context, int index) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: RepaintBoundary(child: _candidateCard(_items[index])),
        ),
      ),
      if (_page < _pages) _loadMoreSliver(),
    ];
  }

  Widget _loadMoreSliver() => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : OutlinedButton(
                key: const ValueKey<String>('candidate-load-more'),
                onPressed: _loadMore,
                child: const Text('加载更多'),
              ),
      ),
    ),
  );

  Widget _candidateCard(Candidate candidate) {
    final CoverRef? cover = candidate.cover;
    return EhCard(
      key: ValueKey<String>('candidate-${candidate.id}'),
      dense: true,
      onTap: () => unawaited(_openDetail(candidate)),
      semanticsLabel: candidate.displayTitle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CoverThumb(
            loader: widget.thumbnails,
            hash: cover?.hash,
            width: 60,
            height: 84,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  candidate.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (candidate.artist.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    candidate.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (candidate.category.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    candidate.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    ToneChip.status(status: candidate.status),
                    for (final String tag in candidate.tags.take(2))
                      Text(tag, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
