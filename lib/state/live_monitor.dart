import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../api/events.dart';

/// 实时通道状态。
enum LiveStatus {
  /// 正在建立 SSE 连接。
  connecting,

  /// SSE 已连通。
  streaming,

  /// 已回退到轮询（SSE 断流 / 不可用）。
  polling,
}

/// 实时监视器：优先消费 SSE，断流按 `/meta` 的 polling 值回退轮询，并周期性重试 SSE。
///
/// 每次「可能有变化」时对外发一次 tick（[ticks]），页面订阅后各自刷新。
class LiveMonitor extends ChangeNotifier {
  LiveMonitor({
    required this.api,
    required this.openStream,
    this.reconnectDelay = const Duration(seconds: 30),
  });

  final EhBotApi api;

  /// 打开实时流（生产环境是 `SseEventSource.connect`），便于测试注入。
  final Stream<LiveEvent> Function() openStream;

  /// 轮询状态下每隔多久重试一次 SSE。
  final Duration reconnectDelay;

  final StreamController<int> _ticks = StreamController<int>.broadcast();
  StreamSubscription<LiveEvent>? _subscription;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;

  LiveStatus status = LiveStatus.connecting;
  Duration pollInterval = const Duration(seconds: 10);
  Duration idleInterval = const Duration(seconds: 60);
  int tickCount = 0;
  DateTime? lastTickAt;

  /// 每次「可能有变化」发一个计数。
  Stream<int> get ticks => _ticks.stream;

  /// 读取 `/meta` 的轮询参数并开始连接；拿不到就用默认值。
  Future<void> start() async {
    try {
      final ClientMeta meta = await api.meta();
      pollInterval = meta.pollingInterval;
      idleInterval = meta.idleInterval;
    } on Object {
      // 拿不到就用默认间隔，不影响实时能力。
    }
    if (_disposed) {
      return;
    }
    _connect();
  }

  void _setStatus(LiveStatus next) {
    if (_disposed) {
      return;
    }
    status = next;
    notifyListeners();
  }

  void _connect() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _setStatus(LiveStatus.connecting);
    _subscription = openStream().listen(
      (LiveEvent event) {
        _setStatus(LiveStatus.streaming);
        tick();
      },
      onError: (Object error) => _fallbackToPolling(),
      onDone: _fallbackToPolling,
      cancelOnError: true,
    );
  }

  void _fallbackToPolling() {
    if (_disposed || status == LiveStatus.polling) {
      return;
    }
    _subscription?.cancel();
    _subscription = null;
    _setStatus(LiveStatus.polling);
    _schedulePoll();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, _connect);
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer(pollInterval, () {
      if (_disposed) {
        return;
      }
      tick();
      _schedulePoll();
    });
  }

  /// 记一次「可能有变化」并广播。
  void tick() {
    if (_disposed) {
      return;
    }
    tickCount += 1;
    lastTickAt = DateTime.now();
    if (!_ticks.isClosed) {
      _ticks.add(tickCount);
    }
    notifyListeners();
  }

  /// 手动重试 SSE（界面上的「重试」）。
  void retryStream() {
    _pollTimer?.cancel();
    _connect();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _ticks.close();
    super.dispose();
  }
}
