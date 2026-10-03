import 'package:flutter/material.dart';

import '../../media/thumbnail_cache.dart';
import '../../media/thumbnail_loader.dart';

/// 封面控件：加载中与失败都渲染**本地**占位，不显示后端 SVG 占位。
class ThumbnailImage extends StatefulWidget {
  const ThumbnailImage({
    super.key,
    required this.loader,
    required this.hash,
    this.fit = BoxFit.cover,
  });

  final ThumbnailLoader loader;
  final String hash;
  final BoxFit fit;

  @override
  State<ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<ThumbnailImage> {
  late Future<ThumbnailData> _future = widget.loader.load(widget.hash);

  @override
  void didUpdateWidget(covariant ThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hash != widget.hash || oldWidget.loader != widget.loader) {
      _future = widget.loader.load(widget.hash);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ThumbnailData>(
    future: _future,
    builder: (BuildContext context, AsyncSnapshot<ThumbnailData> snapshot) {
      final ThumbnailData? data = snapshot.data;
      if (data != null) {
        return Image.memory(data.bytes, fit: widget.fit, gaplessPlayback: true);
      }
      return _ThumbnailPlaceholder(
        icon: snapshot.hasError
            ? Icons.image_not_supported_outlined
            : Icons.image_outlined,
      );
    },
  );
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(child: Icon(icon, color: colors.onSurfaceVariant)),
    );
  }
}
