import 'package:flutter/material.dart';

import 'error_view.dart';

/// `Future` → 加载中 / 错误（带重试）/ 内容 的统一渲染。
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
  });

  final Future<T>? future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (BuildContext context, AsyncSnapshot<T> snapshot) {
      if (snapshot.hasError) {
        return ErrorView(error: snapshot.error!, onRetry: onRetry);
      }
      final T? data = snapshot.data;
      if (data == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return builder(context, data);
    },
  );
}
