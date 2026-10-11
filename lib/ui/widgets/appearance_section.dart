import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../state/theme_store.dart';
import '../theme.dart';
import 'eh_card.dart';

/// 外观：主题模式 + 配色方案（M9-A，完全本地、立即可用）。
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ThemeSettings settings = state.themeSettings;
    return EhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('主题模式', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: EhSpacing.s),
          SegmentedButton<ThemeMode>(
            key: const ValueKey<String>('appearance-mode'),
            segments: const <ButtonSegment<ThemeMode>>[
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text('跟随系统'),
                icon: Icon(Icons.brightness_auto_outlined),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text('浅色'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text('深色'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: <ThemeMode>{settings.mode},
            showSelectedIcon: false,
            onSelectionChanged: (Set<ThemeMode> selection) =>
                state.setThemeMode(selection.first),
          ),
          const SizedBox(height: EhSpacing.l),
          Text('配色方案', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: EhSpacing.s),
          Wrap(
            spacing: EhSpacing.m,
            runSpacing: EhSpacing.m,
            children: <Widget>[
              for (final Color color in ThemeSettings.presets)
                _swatch(context, color, settings.seed),
            ],
          ),
          const SizedBox(height: EhSpacing.l),
          Text('自定义色相', style: Theme.of(context).textTheme.bodySmall),
          _HueSlider(
            seed: settings.seed,
            onChanged: (Color color) => state.setSeedColor(color),
          ),
        ],
      ),
    );
  }

  Widget _swatch(BuildContext context, Color color, Color current) {
    final bool selected = color.toARGB32() == current.toARGB32();
    return Semantics(
      label: '配色 ${color.toARGB32().toRadixString(16)}',
      selected: selected,
      child: InkWell(
        key: ValueKey<String>('appearance-swatch-${color.toARGB32()}'),
        borderRadius: BorderRadius.circular(999),
        onTap: () => state.setSeedColor(color),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}

/// 色相滑块：从 HSV 取色相，饱和度 / 明度固定到 M3 友好的区间。
class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.seed, required this.onChanged});

  final Color seed;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final HSVColor hsv = HSVColor.fromColor(seed);
    return Row(
      children: <Widget>[
        Expanded(
          child: Slider(
            key: const ValueKey<String>('appearance-hue'),
            value: hsv.hue,
            max: 360,
            divisions: 72,
            label: '${hsv.hue.round()}°',
            onChanged: (double hue) =>
                onChanged(HSVColor.fromAHSV(1, hue, 0.72, 0.85).toColor()),
          ),
        ),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: seed, shape: BoxShape.circle),
        ),
      ],
    );
  }
}
