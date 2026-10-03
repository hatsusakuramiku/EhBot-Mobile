import 'dart:async';

import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../state/live_monitor.dart';
import 'widgets/error_view.dart';
import 'widgets/status_chip.dart';

/// 已下载列表：搜索 + 加载更多。
class DownloadedListPage extends StatefulWidget {
  const DownloadedListPage({super.key, required this.api, this.monitor});

  final EhBotApi api;
  final LiveMonitor? monitor;

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
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          key: const ValueKey<String>('downloaded-search'),
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索标题 / 作者 / 来源',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (String value) {
            _search = value;
            unawaited(_reload());
          },
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
      return const Center(child: Text('没有已下载内容。'));
    }
    final bool hasMore = _hasMore;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        itemCount: _items.length + (hasMore ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index >= _items.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        key: const ValueKey<String>('downloaded-load-more'),
                        onPressed: _loadMore,
                        child: const Text('加载更多'),
                      ),
              ),
            );
          }
          return _tile(_items[index]);
        },
      ),
    );
  }

  Widget _tile(DownloadedWork work) => ListTile(
    key: ValueKey<String>('downloaded-${work.candidateId}'),
    title: Text(
      work.displayTitle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (work.artist.isNotEmpty) Text(work.artist),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            StatusChip(status: work.state),
            if (work.packLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(work.packLabel),
              ),
            if (work.providerLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(work.providerLabel),
              ),
          ],
        ),
      ],
    ),
  );
}
