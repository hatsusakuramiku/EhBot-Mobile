import 'package:flutter/material.dart';

import '../api/probe.dart';
import '../state/app_state.dart';
import '../state/settings.dart';

/// 服务器配置页：地址 + TLS / 明文策略 + 测试连接。
class ServerSetupPage extends StatefulWidget {
  const ServerSetupPage({super.key, required this.state});

  final AppState state;

  @override
  State<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends State<ServerSetupPage> {
  late final TextEditingController _url = TextEditingController(
    text: widget.state.settings.baseUrl,
  );
  late final TextEditingController _fingerprint = TextEditingController(
    text: widget.state.settings.certFingerprint ?? '',
  );
  late bool _allowSelfSigned = widget.state.settings.allowSelfSigned;
  late bool _allowCleartext = widget.state.settings.allowCleartext;

  String? _urlError;
  String? _formError;
  String? _probeMessage;
  bool _testing = false;
  bool _saving = false;

  @override
  void dispose() {
    _url.dispose();
    _fingerprint.dispose();
    super.dispose();
  }

  AppSettings _collect() => AppSettings(
    baseUrl: _url.text.trim(),
    allowSelfSigned: _allowSelfSigned,
    allowCleartext: _allowCleartext,
    certFingerprint: _fingerprint.text.trim().isEmpty
        ? null
        : _fingerprint.text.trim(),
  );

  bool get _looksCleartext => Uri.tryParse(_url.text.trim())?.scheme == 'http';

  Future<void> _test() async {
    final String? invalid = validateBaseUrl(_url.text);
    if (invalid != null) {
      setState(() {
        _urlError = invalid;
        _probeMessage = null;
      });
      return;
    }
    setState(() {
      _testing = true;
      _urlError = null;
      _formError = null;
      _probeMessage = null;
    });
    final ServerProbeResult result = await widget.state.probe(_collect());
    if (!mounted) {
      return;
    }
    setState(() {
      _testing = false;
      _probeMessage = result.message;
    });
  }

  Future<void> _save() async {
    final String? invalid = validateBaseUrl(_url.text);
    if (invalid != null) {
      setState(() => _urlError = invalid);
      return;
    }
    final AppSettings next = _collect();
    if (next.isCleartext && !next.allowCleartext) {
      setState(() => _formError = '明文 http 需要勾选「允许明文（不安全）」。');
      return;
    }
    setState(() {
      _saving = true;
      _urlError = null;
      _formError = null;
    });
    await widget.state.saveSettings(next);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('连接服务器')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text('填入 EhBot 服务地址；反向代理有路径前缀时一并带上。'),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('server-url'),
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: '服务器地址',
              hintText: 'https://ehbot.example.com',
              border: const OutlineInputBorder(),
              errorText: _urlError,
            ),
            onChanged: (String _) => setState(() {}),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _allowSelfSigned,
            onChanged: (bool value) => setState(() => _allowSelfSigned = value),
            title: const Text('允许自签证书（不安全）'),
            subtitle: const Text('开启后不再校验证书链；建议同时填指纹做 pin。'),
          ),
          if (_allowSelfSigned)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                key: const ValueKey<String>('server-fingerprint'),
                controller: _fingerprint,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: '证书 SHA-1 指纹（可选）',
                  hintText: 'AB:CD:...（留空表示接受任意自签证书）',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          SwitchListTile(
            value: _allowCleartext,
            onChanged: (bool value) => setState(() => _allowCleartext = value),
            title: const Text('允许明文 http（不安全）'),
            subtitle: const Text('密码与 API Key 会明文过网，仅限可信局域网。'),
          ),
          if (_looksCleartext)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '当前是明文 http：密码与 API Key 会以明文经过网络，请仅用于可信局域网。',
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          if (_formError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_formError!, style: TextStyle(color: colors.error)),
            ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                key: const ValueKey<String>('server-test'),
                onPressed: _testing ? null : _test,
                icon: const Icon(Icons.network_check),
                label: Text(_testing ? '测试中…' : '测试连接'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                key: const ValueKey<String>('server-save'),
                onPressed: _saving ? null : _save,
                child: const Text('保存并继续'),
              ),
            ],
          ),
          if (_probeMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_probeMessage!),
            ),
        ],
      ),
    );
  }
}
