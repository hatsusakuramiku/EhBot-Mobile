import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../state/app_state.dart';

/// 设置入口：只读展示当前会话状态。按 `MOBILE.md` §2.2，编辑功能不在 v0.1.0。
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
    if (api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Summary summary = await api.summary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: <Widget>[
            _section(theme, '账号'),
            _kv(theme, '用户名', who?.username ?? '—'),
            _kv(theme, '凭据类型', credentialKind),
            _kv(
              theme,
              '会话到期',
              who?.expiresAt == null
                  ? '永不过期'
                  : who!.expiresAt!.toLocal().toString(),
            ),
            _kv(theme, '需改密', who?.mustChangePassword == true ? '是' : '否'),
            const Divider(height: 32),
            _section(theme, '服务器'),
            _kv(theme, 'Base URL', baseUrl.isEmpty ? '—' : baseUrl),
            _kv(
              theme,
              '允许自签证书',
              widget.state.settings.allowSelfSigned ? '是' : '否',
            ),
            _kv(
              theme,
              '允许明文 HTTP',
              widget.state.settings.isCleartext ? '是' : '否',
            ),
            const Divider(height: 32),
            _section(theme, '外部服务'),
            if (_loading && _summary == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              ListTile(
                title: const Text('无法加载连接状态'),
                subtitle: Text(_error!),
                trailing: TextButton(
                  onPressed: _refresh,
                  child: const Text('重试'),
                ),
              )
            else if (_summary != null &&
                _summary!.connections.isNotEmpty) ...<Widget>[
              for (final MapEntry<String, ConnectionInfo> entry
                  in _summary!.connections.entries)
                _connectionTile(
                  theme,
                  entry.value.label.isEmpty ? entry.key : entry.value.label,
                  entry.value,
                ),
            ] else
              const ListTile(title: Text('无连接数据')),
            if (_summary != null &&
                _summary!.startupErrors.isNotEmpty) ...<Widget>[
              const Divider(height: 32),
              _section(theme, '启动告警', tone: theme.colorScheme.error),
              for (final String err in _summary!.startupErrors)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Text(
                    err,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
            const Divider(height: 32),
            _section(theme, '会话'),
            ListTile(
              key: const ValueKey<String>('settings-logout'),
              leading: const Icon(Icons.logout),
              title: const Text('退出登录'),
              onTap: () async {
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
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String title, {Color? tone}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(color: tone),
    ),
  );

  Widget _kv(ThemeData theme, String k, String v) => ListTile(
    dense: true,
    title: Text(k),
    subtitle: Text(v.isEmpty ? '—' : v),
  );

  Widget _connectionTile(ThemeData theme, String name, ConnectionInfo conn) {
    return ListTile(
      title: Text(name),
      subtitle: Text(conn.identity ?? '—'),
      trailing: Chip(
        label: Text(conn.state.label),
        backgroundColor: _toneColor(theme, conn.state.tone),
        labelStyle: TextStyle(
          color: _toneFg(theme, conn.state.tone),
          fontSize: 12,
        ),
      ),
    );
  }

  Color _toneColor(ThemeData theme, String tone) {
    switch (tone) {
      case 'success':
        return Colors.green.shade100;
      case 'danger':
        return theme.colorScheme.errorContainer;
      case 'warning':
        return Colors.orange.shade100;
      default:
        return theme.colorScheme.surfaceContainerHighest;
    }
  }

  Color _toneFg(ThemeData theme, String tone) {
    switch (tone) {
      case 'success':
        return Colors.green.shade900;
      case 'danger':
        return theme.colorScheme.onErrorContainer;
      case 'warning':
        return Colors.orange.shade900;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}
