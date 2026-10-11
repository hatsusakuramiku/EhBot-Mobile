import 'package:flutter/material.dart';

import '../theme.dart';
import '../../media/thumbnail_loader.dart';
import 'thumbnail_image.dart';

/// 封面缩略图：三态。
/// - hash 非空：从 `ThumbnailLoader` 取（带磁盘缓存 + Bearer 头）。
/// - 失败：`X-Thumbnail-State: failed` 时退化为 `Icons.broken_image`。
/// - loading：渲染一个半透明占位块。
class CoverThumb extends StatelessWidget {
  final ThumbnailLoader loader;
  final String? hash;
  final double width;
  final double height;
  final BorderRadius? radius;

  const CoverThumb({
    super.key,
    required this.loader,
    required this.hash,
    this.width = 60,
    this.height = 84,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius r = radius ?? BorderRadius.circular(EhRadius.chip);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? h = hash;
    final Widget content = h == null || h.isEmpty
        ? _placeholder(cs)
        : ThumbnailImage(loader: loader, hash: h);
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: r,
        child: SizedBox(width: width, height: height, child: content),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => ColoredBox(
    color: cs.surfaceContainerHighest,
    child: Icon(Icons.image_outlined, color: cs.onSurfaceVariant, size: 24),
  );
}
