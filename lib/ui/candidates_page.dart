import 'dart:async';

import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../media/thumbnail_loader.dart';
import '../state/live_monitor.dart';
import 'candidate_detail_page.dart';
import 'error_text.dart';
import 'theme.dart';
import 'widgets/cover_thumb.dart';
import 'widgets/eh_card.dart';
import 'widgets/empty_state.dart';
import 'widgets/error_view.dart';
import 'widgets/job_actions.dart';
import 'widgets/large_title_app_bar.dart';
import 'widgets/search_bar.dart';
import 'widgets/selection_bar.dart';
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

  /// 多选：非空即进入选择模式（M8-F）。
  final Set<String> _selected = <String>{};
  bool _batchBusy = false;

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
    _selected.clear();
    setState(() => _tab = tab);
    unawaited(_reload());
  }

  void _toggleSelection(Candidate candidate) {
    setState(() {
      if (!_selected.remove(candidate.id)) {
        _selected.add(candidate.id);
      }
    });
  }

  void _clearSelection() => setState(_selected.clear);

  Future<void> _batchReview(String action) async {
    if (_selected.isEmpty || _batchBusy) {
      return;
    }
    setState(() => _batchBusy = true);
    try {
      final ReviewBatchResult result = await widget.api.review(
        action: action,
        candidateIds: _selected.toList(),
      );
      if (!mounted) {
        return;
      }
      final String verb = action == 'approve' ? '通过' : '驳回';
      final String message = result.skipped.isEmpty
          ? '已$verb ${result.applied} 个候选。'
          : '已$verb ${result.applied} 个；${result.skipped.length} 个被跳过。';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      _clearSelection();
      await _reload();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(describeError(error))));
    } finally {
      if (mounted) {
        setState(() => _batchBusy = false);
      }
    }
  }

  /// 彻底删除选中的候选；[deleteFiles] 为真时连压缩包与 CBZ 一起删。
  ///
  /// 与通过 / 驳回同一个端点（后端按 `delete` / `delete-files` 分派），
  /// 两次确认的文案不同——「删不删文件」必须在按下的那个按钮上看得出来。
  Future<void> _batchDelete({required bool deleteFiles}) async {
    if (_selected.isEmpty || _batchBusy) {
      return;
    }
    final bool ok = await confirmDialog(
      context,
      title: deleteFiles ? '彻底删除并删除文件' : '彻底删除选中的作品',
      message: deleteFiles
          ? '除候选的全部记录外，还会删除已下载的压缩包与已归档的 CBZ；此操作不可恢复。'
          : '候选记录、消息、元数据与审核历史都会删除，已下载的压缩包与已归档的 CBZ 保留；'
                '此操作不可恢复。',
      confirmLabel: deleteFiles ? '确认删除文件' : '确认彻底删除',
    );
    if (!ok || !mounted) {
      return;
    }
    setState(() => _batchBusy = true);
    try {
      final ReviewBatchResult result = await widget.api.deleteCandidates(
        candidateIds: _selected.toList(),
        deleteFiles: deleteFiles,
      );
      if (!mounted) {
        return;
      }
      final String message = result.skipped.isEmpty
          ? '已删除 ${result.applied} 个候选。'
          : '已删除 ${result.applied} 个；${result.skipped.length} 个被跳过：'
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
        setState(() => _batchBusy = false);
      }
    }
  }

  Future<void> _openDetail(Candidate candidate) async {
    if (_selected.isNotEmpty) {
      _toggleSelection(candidate);
      return;
    }
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

  Widget _selectionBar(BuildContext context) => SelectionBar(
    count: _selected.length,
    busy: _batchBusy,
    clearKey: const ValueKey<String>('candidate-batch-cancel'),
    onClear: _clearSelection,
    actions: <Widget>[
      FilledButton(
        key: const ValueKey<String>('candidate-batch-approve'),
        onPressed: _batchBusy
            ? null
            : () => unawaited(_batchReview('approve')),
        child: const Text('通过'),
      ),
      OutlinedButton(
        key: const ValueKey<String>('candidate-batch-reject'),
        onPressed: _batchBusy
            ? null
            : () => unawaited(_batchReview('reject')),
        child: const Text('驳回'),
      ),
      OutlinedButton(
        key: const ValueKey<String>('candidate-batch-delete'),
        onPressed: _batchBusy
            ? null
            : () => unawaited(_batchDelete(deleteFiles: false)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        child: const Text('彻底删除'),
      ),
      OutlinedButton(
        key: const ValueKey<String>('candidate-batch-delete-files'),
        onPressed: _batchBusy
            ? null
            : () => unawaited(_batchDelete(deleteFiles: true)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        child: const Text('彻底删除并删文件'),
      ),
    ],
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
    final Widget card = _candidateCardBody(candidate);
    if (_selected.isNotEmpty) {
      return card;
    }
    // 滑动手势（M8-F）：右滑通过、左滑驳回；动作走回调，条目本身不消失
    // （状态由后端刷新决定，避免界面先斩后奏）。
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey<String>('candidate-swipe-${candidate.id}'),
      background: _swipeBackground(
        cs.primaryContainer,
        cs.onPrimaryContainer,
        Icons.check,
        Alignment.centerLeft,
      ),
      secondaryBackground: _swipeBackground(
        cs.errorContainer,
        cs.onErrorContainer,
        Icons.close,
        Alignment.centerRight,
      ),
      confirmDismiss: (DismissDirection direction) async {
        await _swipeReview(
          candidate,
          direction == DismissDirection.startToEnd ? 'approve' : 'reject',
        );
        return false;
      },
      child: card,
    );
  }

  Widget _swipeBackground(
    Color bg,
    Color fg,
    IconData icon,
    Alignment alignment,
  ) => Container(
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: EhSpacing.xl),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(EhRadius.card),
    ),
    child: Icon(icon, color: fg),
  );

  Future<void> _swipeReview(Candidate candidate, String action) async {
    try {
      final ReviewBatchResult result = await widget.api.review(
        action: action,
        candidateIds: <String>[candidate.id],
      );
      if (!mounted) {
        return;
      }
      final String verb = action == 'approve' ? '通过' : '驳回';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已$verb ${result.applied} 个候选。')));
      await _reload();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(describeError(error))));
    }
  }

  Widget _candidateCardBody(Candidate candidate) {
    final CoverRef? cover = candidate.cover;
    return EhCard(
      key: ValueKey<String>('candidate-${candidate.id}'),
      dense: true,
      onTap: () => unawaited(_openDetail(candidate)),
      onLongPress: () => _toggleSelection(candidate),
      semanticsLabel: candidate.displayTitle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_selected.isNotEmpty) ...<Widget>[
            Icon(
              _selected.contains(candidate.id)
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              color: _selected.contains(candidate.id)
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            const SizedBox(width: EhSpacing.s),
          ],
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
