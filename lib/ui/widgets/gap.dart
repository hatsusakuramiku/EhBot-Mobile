import 'package:flutter/widgets.dart';

/// 自定义 `Gap`：与 `SizedBox` 等价但语义化，专用于 flex 兄弟之间。
class Gap extends StatelessWidget {
  final double size;
  const Gap(this.size, {super.key});
  const Gap.xs({super.key}) : size = 4;
  const Gap.s({super.key}) : size = 8;
  const Gap.m({super.key}) : size = 12;
  const Gap.l({super.key}) : size = 16;
  const Gap.xl({super.key}) : size = 20;
  const Gap.xxl({super.key}) : size = 24;
  const Gap.xxxl({super.key}) : size = 32;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}

/// 横向专用的 `HGap`。
class HGap extends StatelessWidget {
  final double size;
  const HGap(this.size, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox(width: size);
}

/// 纵向专用的 `VGap`。
class VGap extends StatelessWidget {
  final double size;
  const VGap(this.size, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox(height: size);
}
