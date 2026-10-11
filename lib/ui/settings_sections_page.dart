import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import 'error_text.dart';
import 'settings_editors.dart';
import 'theme.dart';
import 'widgets/async_view.dart';

/// 设置分区（M8-E）。key 与后端 `/api/v1/settings/<key>` 一一对应。
class SettingsSection {
  const SettingsSection({
    required this.code,
    required this.label,
    required this.icon,
    required this.summary,
  });

  final String code;
  final String label;
  final IconData icon;
  final String summary;
}

const List<SettingsSection> kSettingsSections = <SettingsSection>[
  SettingsSection(
    code: 'connections',
    label: '外部连接',
    icon: Icons.cable_outlined,
    summary: 'Telegram Bot / Telegram 用户 / ExHentai 会话',
  ),
  SettingsSection(
    code: 'sources',
    label: '来源规则',
    icon: Icons.rss_feed_outlined,
    summary: '监听哪些会话，以及每条来源的过滤规则',
  ),
  SettingsSection(
    code: 'parse',
    label: '解析规则',
    icon: Icons.rule_outlined,
    summary: '哪些消息够格成为候选，含 AI 候选判定',
  ),
  SettingsSection(
    code: 'auto-approval',
    label: '自动审批',
    icon: Icons.auto_mode_outlined,
    summary: '自动通过 / 自动驳回的规则与试跑',
  ),
  SettingsSection(
    code: 'archive',
    label: '归档与工具',
    icon: Icons.inventory_2_outlined,
    summary: 'qBittorrent、自动打包、安全限制、工具 profile',
  ),
  SettingsSection(
    code: 'paths',
    label: '路径与命名',
    icon: Icons.folder_outlined,
    summary: '归档路径模板、路径规则、AI 归档',
  ),
  SettingsSection(
    code: 'ai',
    label: 'AI 供应商',
    icon: Icons.smart_toy_outlined,
    summary: 'OpenAI 兼容端点、模型链（主力 + 备用）',
  ),
  SettingsSection(
    code: 'passwords',
    label: '密码库',
    icon: Icons.password_outlined,
    summary: '归档密码与移动端 API 密钥（明文永不回显）',
  ),
  SettingsSection(
    code: 'system',
    label: '系统',
    icon: Icons.tune_outlined,
    summary: '并发上限、轮询间隔、时区、日志等级',
  ),
];

/// 设置分区中心：宽屏用 `NavigationRail`，窄屏用列表。
class SettingsSectionsPage extends StatefulWidget {
  const SettingsSectionsPage({super.key, required this.api});

  final EhBotApi api;

  @override
  State<SettingsSectionsPage> createState() => _SettingsSectionsPageState();
}

class _SettingsSectionsPageState extends State<SettingsSectionsPage> {
  SettingsSection _current = kSettingsSections.first;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置分区')),
    body: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        if (c.maxWidth >= EhBreakpoints.medium) {
          return Row(
            children: <Widget>[
              NavigationRail(
                selectedIndex: kSettingsSections.indexOf(_current),
                onDestinationSelected: (int i) =>
                    setState(() => _current = kSettingsSections[i]),
                labelType: NavigationRailLabelType.all,
                destinations: <NavigationRailDestination>[
                  for (final SettingsSection s in kSettingsSections)
                    NavigationRailDestination(
                      icon: Icon(s.icon),
                      label: Text(s.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _sectionBody(context, _current)),
            ],
          );
        }
        return _sectionBody(context, _current, showPicker: true);
      },
    ),
  );

  Widget _sectionBody(
    BuildContext context,
    SettingsSection section, {
    bool showPicker = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      if (showPicker)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: <Widget>[
              for (final SettingsSection s in kSettingsSections)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey<String>('settings-section-${s.code}'),
                    label: Text(s.label),
                    selected: s.code == section.code,
                    onSelected: (bool _) => setState(() => _current = s),
                  ),
                ),
            ],
          ),
        ),
      Expanded(
        child: SettingsSectionView(api: widget.api, section: section),
      ),
    ],
  );
}

/// 单个分区的视图：拉到就渲染，404 就给「后端未就绪」。
class SettingsSectionView extends StatefulWidget {
  const SettingsSectionView({
    super.key,
    required this.api,
    required this.section,
  });

  final EhBotApi api;
  final SettingsSection section;

  @override
  State<SettingsSectionView> createState() => _SettingsSectionViewState();
}

class _SettingsSectionViewState extends State<SettingsSectionView> {
  late Future<Map<String, dynamic>> _future = widget.api.settingsSection(
    widget.section.code,
  );

  /// 写入端点返回的就是**写后的快照**，直接拿它替换当前视图，
  /// 不再多打一次 GET。
  Map<String, dynamic>? _written;

  @override
  void didUpdateWidget(SettingsSectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section.code != widget.section.code) {
      _future = widget.api.settingsSection(widget.section.code);
    }
  }

  void _reload() {
    setState(() => _future = widget.api.settingsSection(widget.section.code));
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      _reload();
      await _future;
    },
    child: AsyncView<Map<String, dynamic>>(
      future: _future,
      onRetry: _reload,
      builder: (BuildContext context, Map<String, dynamic> loaded) {
        final Map<String, dynamic> data = _written ?? loaded;
        if (kWritableSettingsSections.contains(widget.section.code)) {
          return _editor(context, data);
        }
        return ReadOnlySection(
          title: widget.section.label,
          summary: widget.section.summary,
          data: data,
        );
      },
    ),
  );

  /// 三个有写入端点的分区走各自的编辑器（EhBot R67–R69）。
  Widget _editor(BuildContext context, Map<String, dynamic> data) =>
      switch (widget.section.code) {
        kSettingsConnections => ConnectionsEditor(
          api: widget.api,
          snapshot: data,
          onSaved: _adopt,
        ),
        kSettingsSystem => SystemEditor(
          api: widget.api,
          snapshot: data,
          onSaved: _adopt,
        ),
        kSettingsPasswords => PasswordsEditor(
          api: widget.api,
          snapshot: data,
          onSaved: _adopt,
        ),
        _ => ReadOnlySection(
          title: widget.section.label,
          summary: widget.section.summary,
          data: data,
        ),
      };

  void _adopt(Map<String, dynamic> snapshot) {
    if (mounted) {
      setState(() => _written = snapshot);
    }
  }

}

/// 供设置页跳转用的入口卡片文案。
const String kSettingsSectionsHint = 'navigate-to-settings-sections';

/// 端点缺失时的兜底文案，导出以便测试引用。
String settingsMissingHint() => kEndpointMissingHint;
