import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'home_shell.dart';
import 'login_page.dart';
import 'server_setup_page.dart';
import 'theme.dart';

/// 应用根：按 [AppState.stage] 决定首屏。主题走 [AppTheme]（M3 + seed 粉红）。
class EhBotApp extends StatelessWidget {
  const EhBotApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (BuildContext context, Widget? _) => MaterialApp(
        title: 'EhBot',
        theme: AppTheme.light(state.themeSettings.seed),
        darkTheme: AppTheme.dark(state.themeSettings.seed),
        themeMode: state.themeSettings.mode,
        home: switch (state.stage) {
          AppStage.loading => const _LoadingPage(),
          AppStage.serverSetup => ServerSetupPage(state: state),
          AppStage.login => LoginPage(state: state),
          AppStage.ready => HomeShell(state: state),
        },
      ),
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
