import 'dart:async';

import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../media/thumbnail_loader.dart';
import '../state/live_monitor.dart';
import 'candidate_detail_page.dart';
import 'widgets/eh_card.dart';
import 'widgets/empty_state.dart';
import 'widgets/error_view.dart';
import 'widgets/large_title_app_bar.dart';
import 'widgets/search_bar.dart';
import 'widgets/tone_chip.dart';

/// 已下载列表：大标题 + 搜索 + 加载更多。
class DownloadedListPage extends StatefulWidget {
  const DownloadedListPage({
    super.key,
    required this.api,
    required this.thumbnails,
    this.monitor,
    this.appBarActions = const <Widget>[],
  });

  final EhBotApi api;
  final ThumbnailLoader thumbnails;
  final LiveMonitor? monitor;

  /// 顶栏动作（由 [HomeShell] 注入设置入口等）。
  final List<Widget> appBarActions;

  @override
  State<DownloadedListPage> createState() => _DownloadedListPageState();
}

class _DownloadedListPageState extends State<DownloadedListPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<DownloadedWork> _items = <DownloadedWork>[];

  String _search = '';
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;
  bool _loading = false;
  Object? _error;
  StreamSubscription<int>? _ticks;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
    _ticks = widget.monitor?.ticks.listen((int _) => unawaited(_reload()));
  }

  @override
  void dispose() {
    _ticks?.cancel();
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
      _hasMore = false;
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
      final DownloadedPage page = await widget.api.downloaded(
        search: _search,
        page: _page,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items.addAll(page.items);
        _total = page.total;
        _hasMore = _items.length < page.total;
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
    if (_loading || !_hasMore) {
      return;
    }
    _page += 1;
    await _load();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _reload,
    child: CustomScrollView(
      slivers: <Widget>[
        EhLargeTitleAppBar(
          title: '已下载',
          actions: widget.appBarActions,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                EhSearchBar(
                  key: const ValueKey<String>('downloaded-search'),
                  controller: _searchController,
                  hint: '搜索标题 / 作者 / 来源',
                  onSubmitted: (String value) {
                    _search = value;
                    unawaited(_reload());
                  },
                ),
                const SizedBox(height: 8),
                Text('共 $_total 个'),
              ],
            ),
          ),
        ),
        ..._contentSlivers(),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
            icon: Icons.inventory_2_outlined,
            primary: '没有已下载内容',
            secondary: '通过审核并完成打包的作品会出现在这里',
          ),
        ),
      ];
    }
    return <Widget>[
      SliverList.builder(
        itemCount: _items.length,
        itemBuilder: (BuildContext context, int index) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _tile(_items[index]),
        ),
      ),
      if (_hasMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      key: const ValueKey<String>('downloaded-load-more'),
                      onPressed: _loadMore,
                      child: const Text('加载更多'),
                    ),
            ),
          ),
        ),
    ];
  }

  Widget _tile(DownloadedWork work) => EhCard(
    key: ValueKey<String>('downloaded-${work.candidateId}'),
    dense: true,
    onTap: () => unawaited(_openDetail(work)),
    semanticsLabel: work.displayTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          work.displayTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (work.artist.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(work.artist, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            ToneChip.status(status: work.state),
            if (work.packLabel.isNotEmpty) ToneChip(label: work.packLabel, tone: 'success'),
            if (work.providerLabel.isNotEmpty)
              Text(
                work.providerLabel,
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ],
    ),
  );

  Future<void> _openDetail(DownloadedWork work) async {
    final Candidate stub = Candidate(
      id: work.candidateId,
      title: work.title,
      artist: work.artist,
      category: work.category,
      language: work.language,
      tags: work.tags,
      status: work.state,
    );
    final bool changed =
        await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (BuildContext _) => CandidateDetailPage(
              api: widget.api,
              thumbnails: widget.thumbnails,
              candidate: stub,
            ),
          ),
        ) ??
        false;
    if (changed) {
      _reload();
    }
  }
}
