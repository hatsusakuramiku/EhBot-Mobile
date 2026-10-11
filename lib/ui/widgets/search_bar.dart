import 'package:flutter/material.dart';

import '../theme.dart';

/// M3 `SearchBar` 包装：固定 hint、可控 controller、空 / 非空态。
class EhSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final String hint;

  const EhSearchBar({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.hint = '搜索',
  });

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      controller: controller,
      hintText: hint,
      leading: const Padding(
        padding: EdgeInsets.symmetric(horizontal: EhSpacing.s),
        child: Icon(Icons.search),
      ),
      padding: WidgetStateProperty.all<EdgeInsets>(
        const EdgeInsets.symmetric(horizontal: EhSpacing.m),
      ),
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
    );
  }
}
