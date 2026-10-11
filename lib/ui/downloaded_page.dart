import 'dart:async';

import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../media/thumbnail_loader.dart';
import '../state/live_monitor.dart';
import 'candidate_detail_page.dart';
import 'error_text.dart';
import 'theme.dart';
import 'widgets/eh_card.dart';
import 'widgets/empty_state.dart';
import 'widgets/error_view.dart';
import 'widgets/job_actions.dart';
import 'widgets/large_title_app_bar.dart';
import 'widgets/search_bar.dart';
import 'widgets/selection_bar.dart';
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
  bool _busy = false;
  Object? _error;
  StreamSubscription<int>? _ticks;

  /// 多选：非空即进入选择模式（与候选页同一套手势）。
  final Set<String> _selected = <String>{};

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

  void _toggleSelection(DownloadedWork work) {
    setState(() {
      if (!_selected.remove(work.candidateId)) {
        _selected.add(work.candidateId);
      }
    });
  }

  void _clearSelection() => setState(_selected.clear);

  /// 跑一个已下载批量动作；危险的两条先确认。
  Future<void> _runBatch(
    String action, {
    String? confirmTitle,
    String? confirmMessage,
    String? confirmLabel,
    bool deleteFiles = false,
    String done = '',
  }) async {
    if (_selected.isEmpty || _busy) {
      return;
    }
    if (confirmMessage != null) {
      final bool ok = await confirmDialog(
        context,
        title: confirmTitle ?? '',
        message: confirmMessage,
        confirmLabel: confirmLabel ?? '确认',
      );
      if (!ok || !mounted) {
        return;
      }
    }
    final List<String> ids = _selected.toList();
    setState(() => _busy = true);
    try {
      final ReviewBatchResult result = await widget.api.downloadedBatch(
        action: action,
        candidateIds: ids,
        deleteFiles: deleteFiles,
      );
      if (!mounted) {
        return;
      }
      final String message = result.skipped.isEmpty
          ? '$done ${result.applied} 件'
          : '$done ${result.applied} 件；${result.skipped.length} 件被跳过：'
                '${result.skipped.first}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      _clearSelection();
      await _reload();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error))));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// 行内动作：只对一件作品跑（`打包` / `重新打包`）。
  Future<void> _runOne(String action, DownloadedWork work, String done) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.downloadedBatch(
        action: action,
        candidateIds: <String>[work.candidateId],
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$done：${work.displayTitle}')));
      await _reload();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error))));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Expanded(child: _scrollBody()),
      if (_selected.isNotEmpty) _selectionBar(context),
    ],
  );

  Widget _scrollBody() => RefreshIndicator(
    onRefresh: _reload,
    child: CustomScrollView(
      slivers: <Widget>[
        EhLargeTitleAppBar(title: '已下载', actions: widget.appBarActions),
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

  /// 批量条：重新下载 / 重新打包 / 移除记录 / 移除并删文件。
  ///
  /// 文案与 WebUI 的批量条同义；两个移除是**两个按钮**而不是一个带勾选框的对话框——
  /// 「默认不删文件」这件事必须在按下的那个按钮上看得出来。
  Widget _selectionBar(BuildContext context) => SelectionBar(
    count: _selected.length,
    busy: _busy,
    clearKey: const ValueKey<String>('downloaded-batch-cancel'),
    onClear: _clearSelection,
    actions: <Widget>[
      FilledButton(
        key: const ValueKey<String>('downloaded-batch-repack'),
        onPressed: _busy
            ? null
            : () => unawaited(_runBatch(kDownloadedRepack, done: '已打包')),
        child: const Text('批量打包'),
      ),
      OutlinedButton(
        key: const ValueKey<String>('downloaded-batch-redownload'),
        onPressed: _busy
            ? null
            : () => unawaited(
                _runBatch(
                  kDownloadedRedownload,
                  confirmTitle: '重新下载选中的作品',
                  confirmMessage:
                      '会按原来源重新抓取一遍，下载完成后覆盖现有文件；'
                      '原任务记录会复用并累加尝试次数。打包不会自动重跑。',
                  confirmLabel: '确认重新下载',
                  done: '已重新下载',
                ),
              ),
        child: const Text('重新下载'),
      ),
      OutlinedButton(
        key: const ValueKey<String>('downloaded-batch-remove'),
        onPressed: _busy
            ? null
            : () => unawaited(
                _runBatch(
                  kDownloadedRemove,
                  confirmTitle: '移除选中作品的记录',
                  confirmMessage:
                      '只删除下载与打包记录，磁盘上已归档的 CBZ 与原始压缩包都会保留；'
                      '候选与元数据不受影响，需要时可重新下载。',
                  confirmLabel: '确认移除记录',
                  done: '已移除',
                ),
              ),
        child: const Text('移除记录'),
      ),
      OutlinedButton(
        key: const ValueKey<String>('downloaded-batch-remove-files'),
        onPressed: _busy
            ? null
            : () => unawaited(
                _runBatch(
                  kDownloadedRemove,
                  confirmTitle: '移除记录并删除文件',
                  confirmMessage:
                      '除记录外，还会删除已归档的 CBZ 与原始压缩包，此操作不可恢复。'
                      '候选与元数据会保留，但需要重新下载才能再次打包。',
                  confirmLabel: '确认删除文件',
                  deleteFiles: true,
                  done: '已移除并删文件',
                ),
              ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        child: const Text('移除并删除文件'),
      ),
    ],
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
              mainAxisExtent: 180,
            ),
            itemCount: _items.length,
            itemBuilder: (BuildContext context, int index) =>
                RepaintBoundary(child: _tile(_items[index])),
          ),
        ),
        if (_hasMore) _loadMoreSliver(),
      ];
    }
    return <Widget>[
      SliverList.builder(
        itemCount: _items.length,
        itemBuilder: (BuildContext context, int index) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: RepaintBoundary(child: _tile(_items[index])),
        ),
      ),
      if (_hasMore) _loadMoreSliver(),
    ];
  }

  Widget _loadMoreSliver() => SliverToBoxAdapter(
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
  );

  Widget _tile(DownloadedWork work) {
    final bool selected = _selected.contains(work.candidateId);
    return EhCard(
      key: ValueKey<String>('downloaded-${work.candidateId}'),
      dense: true,
      onTap: () =>
          _selected.isEmpty ? unawaited(_openDetail(work)) : _toggleSelection(work),
      onLongPress: () => _toggleSelection(work),
      semanticsLabel: work.displayTitle,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_selected.isNotEmpty) ...<Widget>[
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? Theme.of(context).colorScheme.primary : null,
              ),
              const SizedBox(width: EhSpacing.s),
            ],
            Expanded(
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
                    Text(
                      work.artist,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      ToneChip.status(status: work.state),
                      if (work.packLabel.isNotEmpty)
                        ToneChip(label: work.packLabel, tone: 'success'),
                      if (work.providerLabel.isNotEmpty)
                        Text(
                          work.providerLabel,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        // 行内动作：可见性来自后端 `actions`（在途的作品会把 remove / redownload
        // 压下去，因为那两个会和 worker 抢同一行）。
        if (_selected.isEmpty &&
            (work.canRepack || work.canRedownload || work.canRemove))
          Padding(
            padding: const EdgeInsets.only(top: EhSpacing.s),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                if (work.canRepack)
                  OutlinedButton(
                    key: ValueKey<String>('downloaded-repack-${work.candidateId}'),
                    onPressed: _busy
                        ? null
                        : () => unawaited(
                            _runOne(
                              kDownloadedRepack,
                              work,
                              work.isPacked ? '已重新打包' : '已打包',
                            ),
                          ),
                    child: Text(work.isPacked ? '重新打包' : '打包'),
                  ),
                if (work.canRedownload)
                  TextButton(
                    key: ValueKey<String>(
                      'downloaded-redownload-${work.candidateId}',
                    ),
                    onPressed: _busy
                        ? null
                        : () => unawaited(
                            _runOne(kDownloadedRedownload, work, '已重新下载'),
                          ),
                    child: const Text('重新下载'),
                  ),
              ],
            ),
          ),
      ],
      ),
    );
  }

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
