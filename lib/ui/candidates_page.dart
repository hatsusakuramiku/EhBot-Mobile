import 'dart:async';

import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../media/thumbnail_loader.dart';
import '../state/live_monitor.dart';
import 'candidate_detail_page.dart';
import 'widgets/error_view.dart';
import 'widgets/status_chip.dart';
import 'widgets/thumbnail_image.dart';

/// 候选 tab（`CANDIDATE_TABS`）→ 中文标签。
const Map<String, String> kCandidateTabs = <String, String>{
  'all': '全部',
  'pending': '待审核',
  'needs_info': '待补充',
  'approved': '已通过',
  'rejected': '已驳回',
  'failed': '失败',
};

/// 候选列表：tab + 搜索 + 分页（加载更多）。
class CandidatesPage extends StatefulWidget {
  const CandidatesPage({
    super.key,
    required this.api,
    required this.thumbnails,
    this.monitor,
  });

  final EhBotApi api;
  final ThumbnailLoader thumbnails;
  final LiveMonitor? monitor;

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
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            for (final MapEntry<String, String> tab in kCandidateTabs.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
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
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          key: const ValueKey<String>('candidate-search'),
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '搜索标题 / 作者',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (String value) {
            _search = value;
            unawaited(_reload());
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('共 $_total 个'),
        ),
      ),
      Expanded(child: _buildList()),
    ],
  );

  Widget _buildList() {
    if (_error != null) {
      return ErrorView(error: _error!, onRetry: _reload);
    }
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(child: Text('没有匹配的候选。'));
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        itemCount: _items.length + (_page < _pages ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index >= _items.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        key: const ValueKey<String>('candidate-load-more'),
                        onPressed: _loadMore,
                        child: const Text('加载更多'),
                      ),
              ),
            );
          }
          return _candidateTile(_items[index]);
        },
      ),
    );
  }

  Widget _candidateTile(Candidate candidate) {
    final CoverRef? cover = candidate.cover;
    return ListTile(
      key: ValueKey<String>('candidate-${candidate.id}'),
      onTap: () => unawaited(_openDetail(candidate)),
      leading: SizedBox(
        width: 48,
        height: 64,
        child: cover == null
            ? const ColoredBox(color: Colors.black12)
            : ThumbnailImage(loader: widget.thumbnails, hash: cover.hash),
      ),
      title: Text(
        candidate.displayTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (candidate.artist.isNotEmpty) Text(candidate.artist),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              StatusChip(status: candidate.status),
              if (candidate.tags.isNotEmpty)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      candidate.tags.take(3).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
