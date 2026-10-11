import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import 'settings_sections_page.dart';
import 'widgets/eh_card.dart';
import 'widgets/empty_state.dart';
import 'widgets/section_header.dart';
import 'widgets/tone_chip.dart';

/// 设置：分区呈现当前会话状态（M7 只读；M8-E 起接各编辑页）。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Summary? _summary;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final EhBotApi? api = widget.state.api;
    if (api == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Summary summary = await api.summary();
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final WhoAmI? who = widget.state.identity;
    final String baseUrl = widget.state.settings.baseUrl;
    final String credentialKind = widget.state.session?.kind.name ?? 'unknown';
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            const SectionHeader(title: '账号'),
            _card(<Widget>[
              _kv('用户名', who?.username ?? '—'),
              _kv('凭据类型', credentialKind),
              _kv(
                '会话到期',
                who?.expiresAt == null
                    ? '永不过期'
                    : who!.expiresAt!.toLocal().toString(),
              ),
              _kv('需改密', who?.mustChangePassword == true ? '是' : '否'),
            ]),
            const SectionHeader(title: '服务器'),
            _card(<Widget>[
              _kv('Base URL', baseUrl.isEmpty ? '—' : baseUrl),
              _kv('允许自签证书', widget.state.settings.allowSelfSigned ? '是' : '否'),
              _kv('允许明文 HTTP', widget.state.settings.isCleartext ? '是' : '否'),
            ]),
            const SectionHeader(title: '外部服务'),
            _connections(),
            const SectionHeader(title: '分区设置'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EhCard(
                key: const ValueKey<String>('settings-open-sections'),
                dense: true,
                onTap: widget.state.api == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext _) =>
                              SettingsSectionsPage(api: widget.state.api!),
                        ),
                      ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.dashboard_customize_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '连接 / 来源 / 解析 / 自动审批 / 归档 / 路径 / AI / 密码库 / 系统',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            if (_summary != null &&
                _summary!.startupErrors.isNotEmpty) ...<Widget>[
              const SectionHeader(title: '启动告警'),
              EhCard(
                tone: EhCardTone.warning,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final String err in _summary!.startupErrors)
                      Text('· $err'),
                  ],
                ),
              ),
            ],
            const SectionHeader(title: '会话'),
            EhCard(
              child: ListTile(
                key: const ValueKey<String>('settings-logout'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout),
                title: const Text('退出登录'),
                subtitle: const Text('退出后需要重新登录'),
                onTap: _confirmLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: EhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );

  Widget _connections() {
    if (_loading && _summary == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: EhCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('无法加载连接状态'),
            subtitle: Text(_error!),
            trailing: TextButton(onPressed: _refresh, child: const Text('重试')),
          ),
        ),
      );
    }
    final Map<String, ConnectionInfo> conns =
        _summary?.connections ?? const <String, ConnectionInfo>{};
    if (conns.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: EmptyState(
          icon: Icons.cable_outlined,
          primary: '无连接数据',
          secondary: '服务端未返回外部连接状态',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: EhCard(
        child: Column(
          children: <Widget>[
            for (final MapEntry<String, ConnectionInfo> entry in conns.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  entry.value.label.isEmpty ? entry.key : entry.value.label,
                ),
                subtitle: Text(entry.value.identity ?? '—'),
                trailing: ToneChip.status(status: entry.value.state),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: 110, child: Text(k)),
        Expanded(child: Text(v.isEmpty ? '—' : v)),
      ],
    ),
  );

  Future<void> _confirmLogout() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('退出后需要重新登录。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await widget.state.logout();
    }
  }
}
