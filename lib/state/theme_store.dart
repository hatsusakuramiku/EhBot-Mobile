import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 界面外观偏好（M9-A）：主题模式 + seed 配色。纯本地，与服务端无关。
class ThemeSettings {
  const ThemeSettings({this.mode = ThemeMode.system, this.seed = kDefaultSeed});

  /// seed 默认为粉红 EH 强调色。
  static const Color kDefaultSeed = Color(0xFFE91E63);

  /// 预设配色（也可用色相滑块自定义）。
  static const List<Color> presets = <Color>[
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF3F51B5),
    Color(0xFF2196F3),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF607D8B),
  ];

  final ThemeMode mode;
  final Color seed;

  ThemeSettings copyWith({ThemeMode? mode, Color? seed}) =>
      ThemeSettings(mode: mode ?? this.mode, seed: seed ?? this.seed);
}

/// 外观偏好的持久化。
class ThemeStore {
  static const String modeKey = 'ehbot.theme_mode';
  static const String seedKey = 'ehbot.seed_color';

  Future<ThemeSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return ThemeSettings(
      mode: _modeFrom(prefs.getString(modeKey)),
      seed: _colorFrom(prefs.getInt(seedKey)),
    );
  }

  Future<void> save(ThemeSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(modeKey, _modeName(settings.mode));
    await prefs.setInt(seedKey, settings.seed.toARGB32());
  }

  static String _modeName(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  static ThemeMode _modeFrom(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static Color _colorFrom(int? value) =>
      value == null ? ThemeSettings.kDefaultSeed : Color(value);
}
