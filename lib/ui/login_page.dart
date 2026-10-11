import 'package:flutter/material.dart';

import '../api/auth_session.dart';
import '../state/app_state.dart';
import 'error_text.dart';
import 'theme.dart';
import 'widgets/eh_card.dart';

/// 登录页：密码 / API Key 两个 tab（凭据族隔离，互不影响）。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.state});

  final AppState state;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _label = TextEditingController();
  final TextEditingController _apiKey = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _label.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _submit(
    Future<void> Function() action,
    CredentialKind kind,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = describeError(error, kind: kind));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool _) => <Widget>[
            SliverAppBar.large(
              title: const Text('登录'),
              pinned: true,
              bottom: const TabBar(
                tabs: <Widget>[
                  Tab(text: '密码'),
                  Tab(text: 'API Key'),
                ],
              ),
            ),
          ],
          body: Column(
            children: <Widget>[
              _serverRow(context),
              if (widget.state.notice != null)
                _banner(context, widget.state.notice!, isError: false),
              if (_error != null) _banner(context, _error!, isError: true),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _buildPasswordForm(context),
                    _buildApiKeyForm(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serverRow(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: EhCard(
      dense: true,
      child: Row(
        children: <Widget>[
          const Icon(Icons.dns_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.state.settings.baseUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: widget.state.editServer,
            child: const Text('更换服务器'),
          ),
        ],
      ),
    ),
  );

  Widget _banner(BuildContext context, String text, {required bool isError}) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(EhSpacing.m),
        decoration: BoxDecoration(
          color: isError ? cs.errorContainer : cs.secondaryContainer,
          borderRadius: BorderRadius.circular(EhRadius.chip),
        ),
        child: Text(
          text,
          style: TextStyle(
            color:
                isError ? cs.onErrorContainer : cs.onSecondaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordForm(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: <Widget>[
      const Text('用网页端的管理员密码登录。若从未改过初始密码，请先到网页端修改。'),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey<String>('login-password'),
        controller: _password,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: '密码',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey<String>('login-label'),
        controller: _label,
        decoration: const InputDecoration(
          labelText: '设备名（可选）',
          hintText: '例如 Pixel 9',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        key: const ValueKey<String>('login-submit-password'),
        onPressed: _busy
            ? null
            : () => _submit(
                () => widget.state.loginWithPassword(
                  _password.text,
                  label: _label.text.trim(),
                ),
                CredentialKind.password,
              ),
        child: const Text('登录'),
      ),
    ],
  );

  Widget _buildApiKeyForm(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: <Widget>[
      const Text(
        '在网页端「设置 › 密码库 › API 密钥（移动端）」生成后粘贴进来；'
        'Key 不过期，网页端刷新后旧 Key 立即失效。',
      ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey<String>('login-apikey'),
        controller: _apiKey,
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: 'API Key',
          hintText: 'ehk_...',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        key: const ValueKey<String>('login-submit-apikey'),
        onPressed: _busy
            ? null
            : () => _submit(
                () => widget.state.loginWithApiKey(_apiKey.text),
                CredentialKind.apiKey,
              ),
        child: const Text('登录'),
      ),
    ],
  );
}
