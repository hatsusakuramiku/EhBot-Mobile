import 'package:ehbot_mobile/api/auth_client.dart';
import 'package:ehbot_mobile/api/auth_session.dart';
import 'package:ehbot_mobile/api/ehbot_api.dart';
import 'package:ehbot_mobile/media/thumbnail_loader.dart';
import 'package:http/http.dart' as http;

import 'in_memory_thumbnail_cache.dart';

AuthClient authClientWith(http.Client inner) => AuthClient(
  inner: inner,
  baseUri: Uri.parse('https://ehbot.example.com'),
  session: AuthSession.apiKey('ehk_x'),
  onSessionExpired: () {},
);

/// 页面测试用的 [EhBotApi]。
EhBotApi apiWith(http.Client inner) => EhBotApi(authClientWith(inner));

/// 页面测试用的缩略图加载器（内存缓存，fake-async 友好）。
ThumbnailLoader thumbnailsWith(http.Client inner) => ThumbnailLoader(
  client: authClientWith(inner),
  cache: InMemoryThumbnailCache(),
);
