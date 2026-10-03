import 'dart:async';

import 'package:flutter/material.dart';

import 'api/http_factory.dart';
import 'api/token_store.dart';
import 'media/thumbnail_cache.dart';
import 'state/app_state.dart';
import 'state/settings.dart';
import 'ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final AppState state = AppState(
    settingsStore: SettingsStore(),
    tokenStore: SecureTokenStore(),
    clientFactory: (AppSettings settings) => createHttpClient(
      allowSelfSigned: settings.allowSelfSigned,
      certFingerprint: settings.certFingerprint,
    ),
    thumbnailCache: DefaultThumbnailCache(),
  );
  unawaited(state.bootstrap());
  runApp(EhBotApp(state: state));
}
