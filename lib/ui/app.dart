import 'package:flutter/material.dart';

/// 应用根组件。M0 只有骨架页，M1 起接入服务器配置与登录流程。
class EhBotApp extends StatelessWidget {
  const EhBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EhBot',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const SkeletonPage(),
    );
  }
}

/// 占位首页：证明工程可构建、可测试，不含任何业务逻辑。
class SkeletonPage extends StatelessWidget {
  const SkeletonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EhBot')),
      body: const Center(child: Text('工程骨架已就位，界面自 M1 起实现。')),
    );
  }
}
