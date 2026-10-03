import 'package:flutter/material.dart';

import '../api/auth_session.dart';
import '../state/app_state.dart';
import 'error_text.dart';

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
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('登录'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: '密码'),
              Tab(text: 'API Key'),
            ],
          ),
        ),
        body: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: colors.surfaceContainerHighest,
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(widget.state.settings.baseUrl)),
                  TextButton(
                    onPressed: widget.state.editServer,
                    child: const Text('更换服务器'),
                  ),
                ],
              ),
            ),
            if (widget.state.notice != null)
              _Banner(text: widget.state.notice!, colors: colors),
            if (_error != null)
              _Banner(text: _error!, colors: colors, isError: true),
            Expanded(
              child: TabBarView(
                children: <Widget>[_buildPasswordForm(), _buildApiKeyForm()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordForm() => ListView(
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

  Widget _buildApiKeyForm() => ListView(
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

class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.colors,
    this.isError = false,
  });

  final String text;
  final ColorScheme colors;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    color: isError ? colors.errorContainer : colors.secondaryContainer,
    child: Text(
      text,
      style: TextStyle(
        color: isError ? colors.onErrorContainer : colors.onSecondaryContainer,
      ),
    ),
  );
}
