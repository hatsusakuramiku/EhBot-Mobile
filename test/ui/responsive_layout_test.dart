import 'package:ehbot_mobile/api/ehbot_api.dart';
import 'package:ehbot_mobile/media/thumbnail_loader.dart';
import 'package:ehbot_mobile/ui/candidates_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    Widget page,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
    await tester.pumpAndSettle();
  }

  testWidgets('候选列表在窄屏用列表、宽屏用网格', (WidgetTester tester) async {
    final http.Client client = fakeBackend();
    final EhBotApi api = apiWith(client);
    final ThumbnailLoader thumbnails = thumbnailsWith(client);

    await pumpAt(
      tester,
      const Size(400, 800),
      CandidatesPage(api: api, thumbnails: thumbnails),
    );
    expect(find.byType(SliverGrid), findsNothing);
    expect(find.byKey(const ValueKey<String>('candidate-11')), findsOneWidget);

    await pumpAt(
      tester,
      const Size(1000, 900),
      CandidatesPage(api: api, thumbnails: thumbnails),
    );
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('candidate-11')), findsOneWidget);
  });
}
