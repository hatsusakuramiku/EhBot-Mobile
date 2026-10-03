import 'dart:convert';

import 'package:ehbot_mobile/api/auth_client.dart';
import 'package:ehbot_mobile/api/auth_session.dart';
import 'package:ehbot_mobile/media/thumbnail_loader.dart';
import 'package:ehbot_mobile/ui/widgets/thumbnail_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/in_memory_thumbnail_cache.dart';

/// 1x1 PNG（测试用最小合法位图）。
const String kTinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  final Uri base = Uri.parse('https://ehbot.example.com');

  ThumbnailLoader loaderWith(http.Client inner) => ThumbnailLoader(
    client: AuthClient(
      inner: inner,
      baseUri: base,
      session: AuthSession.apiKey('ehk_x'),
      onSessionExpired: () {},
    ),
    cache: InMemoryThumbnailCache(),
  );

  Future<void> pump(WidgetTester tester, ThumbnailLoader loader) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80,
              height: 80,
              child: ThumbnailImage(loader: loader, hash: 'hash-1'),
            ),
          ),
        ),
      );

  testWidgets('成功时渲染位图', (WidgetTester tester) async {
    final ThumbnailLoader loader = loaderWith(
      MockClient(
        (http.Request request) async => http.Response.bytes(
          base64Decode(kTinyPngBase64),
          200,
          headers: <String, String>{'content-type': 'image/png'},
        ),
      ),
    );

    await pump(tester, loader);
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('failed 占位时渲染本地占位图标，不解码 SVG', (WidgetTester tester) async {
    final ThumbnailLoader loader = loaderWith(
      MockClient(
        (http.Request request) async => http.Response.bytes(
          utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"/>'),
          200,
          headers: <String, String>{'x-thumbnail-state': 'failed'},
        ),
      ),
    );

    await pump(tester, loader);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
