import 'dart:async';

import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/events.dart';
import '../api/models.dart';
import 'error_text.dart';
import 'widgets/eh_card.dart';
import 'widgets/empty_state.dart';
import 'widgets/large_title_app_bar.dart';
import 'widgets/tone_chip.dart';

/// 运行日志：历史 + 实时流（SSE），可切级别、可暂停。
class LogsPage extends StatefulWidget {
  const LogsPage({super.key, required this.api});

  final EhBotApi api;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  static const List<LogLevelOption> _defaultLevels = <LogLevelOption>[
    LogLevelOption(code: '', label: '全部'),
    LogLevelOption(code: 'DEBUG', label: '调试'),
    LogLevelOption(code: 'INFO', label: '信息'),
    LogLevelOption(code: 'WARNING', label: '警告'),
    LogLevelOption(code: 'ERROR', label: '错误'),
  ];

  final List<LogEntry> _entries = <LogEntry>[];
  List<LogLevelOption> _levels = _defaultLevels;
  String _level = '';
  bool _paused = false;
  bool _loading = true;
  bool _liveUnavailable = false;
  Object? _error;
  StreamSubscription<LiveEvent>? _stream;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
    _openStream();
  }

  @override
  void dispose() {
    unawaited(_stream?.cancel());
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final LogsPageData data = await widget.api.logs(level: _level);
      if (!mounted) {
        return;
      }
      setState(() {
        _entries
          ..clear()
          ..addAll(_visible(data.entries));
        if (data.levels.isNotEmpty) {
          _levels = data.levels;
        }
        _loading = false;
        _liveUnavailable = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
        _liveUnavailable = isEndpointMissing(error);
      });
    }
  }

  void _openStream() {
    _stream = widget.api.logsStream().listen(
      (LiveEvent event) {
        if (!mounted || _paused) {
          return;
        }
        final Map<String, dynamic>? json = event.json;
        if (json == null) {
          return;
        }
        final LogEntry entry = LogEntry.fromJson(json);
        if (!_passesLevel(entry)) {
          return;
        }
        setState(() => _entries.insert(0, entry));
      },
      onError: (Object _) {
        if (mounted) {
          setState(() => _liveUnavailable = true);
        }
      },
      cancelOnError: false,
    );
  }

  List<LogEntry> _visible(List<LogEntry> entries) =>
      entries.where(_passesLevel).toList().reversed.toList();

  static const List<String> _order = <String>[
    'DEBUG',
    'INFO',
    'WARNING',
    'ERROR',
    'CRITICAL',
  ];

  bool _passesLevel(LogEntry entry) {
    if (_level.isEmpty) {
      return true;
    }
    final int floor = _order.indexOf(_level);
    final int at = _order.indexOf(entry.level.code.toUpperCase());
    if (floor < 0 || at < 0) {
      return true;
    }
    return at >= floor;
  }

  Future<void> _selectLevel(String code) async {
    setState(() => _level = code);
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: RefreshIndicator(
      onRefresh: _loadHistory,
      child: CustomScrollView(
        slivers: <Widget>[
          EhLargeTitleAppBar(
            title: '运行日志',
            subtitle: _paused ? '已暂停' : '实时',
            actions: <Widget>[
              IconButton(
                key: const ValueKey<String>('logs-pause'),
                tooltip: _paused ? '继续' : '暂停',
                icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                onPressed: () => setState(() => _paused = !_paused),
              ),
            ],
          ),
          SliverToBoxAdapter(child: _levelBar()),
          if (_liveUnavailable)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: EhCard(
                  tone: EhCardTone.warning,
                  dense: true,
                  child: Text(kEndpointMissingHint),
                ),
              ),
            ),
          ..._listSlivers(),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    ),
  );

  Widget _levelBar() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: <Widget>[
        for (final LogLevelOption option in _levels)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: ValueKey<String>('logs-level-${option.code}'),
              label: Text(option.label),
              selected: _level == option.code,
              onSelected: (bool _) => unawaited(_selectLevel(option.code)),
            ),
          ),
      ],
    ),
  );

  List<Widget> _listSlivers() {
    if (_loading && _entries.isEmpty) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null && _entries.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: EhCard(
              tone: EhCardTone.warning,
              child: Text(
                isEndpointMissing(_error!)
                    ? kEndpointMissingHint
                    : describeError(_error!),
              ),
            ),
          ),
        ),
      ];
    }
    if (_entries.isEmpty) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.receipt_long_outlined,
            primary: '暂无日志',
            secondary: '当前级别下没有记录',
          ),
        ),
      ];
    }
    return <Widget>[
      SliverList.builder(
        itemCount: _entries.length,
        itemBuilder: (BuildContext context, int index) =>
            RepaintBoundary(child: _logRow(_entries[index])),
      ),
    ];
  }

  Widget _logRow(LogEntry entry) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: EhCard(
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ToneChip.status(status: entry.level),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatTime(entry.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (entry.logger.isNotEmpty)
                Text(
                  entry.logger,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(entry.message),
          if (entry.errorMessage.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              entry.errorMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
  );
}

String _formatTime(DateTime? time) {
  if (time == null) {
    return '';
  }
  final DateTime local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
