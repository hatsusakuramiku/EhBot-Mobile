import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';

/// 一台服务器的配置档案（M7-C）。
///
/// EhBot 没有多用户概念——多份档案只是「多台服务器」，切换即换后端，
/// 不做账号体系；凭据依旧按「当前服务器」单份存放。
class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.label,
    required this.settings,
  });

  final String id;
  final String label;
  final AppSettings settings;

  factory ServerProfile.fromJson(Map<String, dynamic> json) => ServerProfile(
    id: json['id'] as String? ?? '',
    label: json['label'] as String? ?? '',
    settings: AppSettings.fromJson(
      (json['settings'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    ),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'settings': settings.toJson(),
  };

  ServerProfile copyWith({String? label, AppSettings? settings}) =>
      ServerProfile(
        id: id,
        label: label ?? this.label,
        settings: settings ?? this.settings,
      );

  /// 未显式命名时，用主机名当标签，列表里能一眼认出来。
  String get effectiveLabel {
    if (label.trim().isNotEmpty) {
      return label.trim();
    }
    final Uri? uri = settings.baseUri;
    if (uri == null) {
      return '未命名服务器';
    }
    return uri.host;
  }
}

/// 多服务器档案的持久化：`shared_preferences` 里一段 JSON 数组 + 一个 active id。
class ServerStore {
  static const String storageKey = 'ehbot.servers';
  static const String activeKey = 'ehbot.active_server_id';

  Future<List<ServerProfile>> loadAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return const <ServerProfile>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (Map<dynamic, dynamic> item) =>
                  ServerProfile.fromJson(item.cast<String, dynamic>()),
            )
            .where((ServerProfile p) => p.id.isNotEmpty)
            .toList();
      }
    } on FormatException {
      // 存储损坏时当作空列表，下次保存覆盖。
    }
    return const <ServerProfile>[];
  }

  Future<void> saveAll(List<ServerProfile> profiles) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(
        profiles.map((ServerProfile p) => p.toJson()).toList(),
      ),
    );
  }

  Future<String?> loadActiveId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? id = prefs.getString(activeKey);
    return (id == null || id.isEmpty) ? null : id;
  }

  Future<void> saveActiveId(String? id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(activeKey);
    } else {
      await prefs.setString(activeKey, id);
    }
  }
}

/// 生成一个稳定的档案 id（时间戳 + 计数，够本地唯一）。
String newServerId([int? nowMillis]) =>
    'srv_${(nowMillis ?? DateTime.now().millisecondsSinceEpoch)}';
