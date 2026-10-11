import 'package:ehbot_mobile/api/auth_client.dart';
import 'package:ehbot_mobile/api/auth_session.dart';
import 'package:ehbot_mobile/media/thumbnail_loader.dart';
import 'package:ehbot_mobile/ui/widgets/cover_thumb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/in_memory_thumbnail_cache.dart';

void main() {
  ThumbnailLoader loaderWith(http.Client inner) => ThumbnailLoader(
    client: AuthClient(
      inner: inner,
      baseUri: Uri.parse('https://ehbot.example.com'),
      session: AuthSession.apiKey('ehk_x'),
      onSessionExpired: () {},
    ),
    cache: InMemoryThumbnailCache(),
  );

  // 缩略图端点不可达：验证 CoverThumb 会退回本地占位而不是崩。
  final http.Client offline = MockClient(
    (http.Request request) async => http.Response('', 404),
  );

  testWidgets('CoverThumb placeholder when hash is null',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoverThumb(loader: loaderWith(offline), hash: null),
        ),
      ),
    );
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });

  testWidgets('CoverThumb takes requested size', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoverThumb(
            loader: loaderWith(offline),
            hash: 'hash-1',
            width: 100,
            height: 140,
          ),
        ),
      ),
    );
    // 请求失败时占位也应撑满约定尺寸（不让列表跳动）。
    await tester.pumpAndSettle();
    final Size size = tester.getSize(find.byType(CoverThumb));
    expect(size.width, 100);
    expect(size.height, 140);
  });
}
