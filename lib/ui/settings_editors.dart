import 'dart:async';

import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import 'error_text.dart';
import 'theme.dart';
import 'widgets/eh_card.dart';
import 'widgets/job_actions.dart' show confirmDialog;
import 'widgets/section_header.dart';
import 'widgets/tone_chip.dart';

/// 后端 `/api/v1/settings/{section}` 里有写入端点的三个分区（EhBot R67–R69）。
const Set<String> kWritableSettingsSections = <String>{
  kSettingsConnections,
  kSettingsSystem,
  kSettingsPasswords,
};

/// 分区编辑器的公共外壳：负责 busy 状态、错误提示与「保存后刷新」。
///
/// 三个分区共用它，是为了让「写失败要看见原因」只有一份实现——
/// 凭据写错的响应（`CODE_OR_PASSWORD_REQUIRED` 之类）必须原样透出来。
mixin SettingsWriteMixin<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? notice;

  /// 后端 `PUT` 的返回值**就是**该分区写后的快照，不用再拉一次。
  Future<Map<String, dynamic>?> write(
    String section,
    Map<String, Object?> body,
  ) async {
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final Map<String, dynamic> snapshot = await api.putSettingsSection(
        section,
        body,
      );
      if (mounted) {
        setState(() => busy = false);
      }
      return snapshot;
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          busy = false;
          notice = describeError(error);
        });
      }
      return null;
    }
  }

  EhBotApi get api;

  Widget noticeCard() => notice == null
      ? const SizedBox.shrink()
      : EhCard(
          tone: EhCardTone.warning,
          dense: true,
          child: Text(notice!),
        );
}

// ---------------------------------------------------------------- 外部连接

/// 连接区（`PUT /api/v1/settings/connections`，7 个 action）。
///
/// 凭据只上行、不回显：后端返回的快照只说「配没配」，所以表单里永远是空输入框，
/// 不会假装把已存的 token 填回去。
class ConnectionsEditor extends StatefulWidget {
  const ConnectionsEditor({
    super.key,
    required this.api,
    required this.snapshot,
    required this.onSaved,
  });

  final EhBotApi api;
  final Map<String, dynamic> snapshot;
  final ValueChanged<Map<String, dynamic>> onSaved;

  @override
  State<ConnectionsEditor> createState() => _ConnectionsEditorState();
}

class _ConnectionsEditorState extends State<ConnectionsEditor>
    with SettingsWriteMixin<ConnectionsEditor> {
  @override
  EhBotApi get api => widget.api;

  final TextEditingController _botToken = TextEditingController();
  final TextEditingController _apiId = TextEditingController();
  final TextEditingController _apiHash = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _twoFactor = TextEditingController();
  final TextEditingController _memberId = TextEditingController();
  final TextEditingController _passHash = TextEditingController();
  final TextEditingController _igneous = TextEditingController();

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _botToken,
      _apiId,
      _apiHash,
      _phone,
      _code,
      _twoFactor,
      _memberId,
      _passHash,
      _igneous,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send(Map<String, Object?> body) async {
    final Map<String, dynamic>? snapshot = await write(
      kSettingsConnections,
      body,
    );
    if (snapshot != null && mounted) {
      widget.onSaved(snapshot);
    }
  }

  Map<String, dynamic>? _connection(String key) =>
      asMap(widget.snapshot['connections'])?[key] is Map
      ? asMap(asMap(widget.snapshot['connections'])?[key])
      : null;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: EhSpacing.xxl),
    children: <Widget>[
      if (notice != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            EhSpacing.l,
            0,
            EhSpacing.l,
            EhSpacing.s,
          ),
          child: noticeCard(),
        ),
      if (asMap(widget.snapshot['connections']) == null)
        const Padding(
          padding: EdgeInsets.all(EhSpacing.l),
          child: Text('这个部署还没装上连接管理器，暂时没有可配置的连接。'),
        ),
      _telegramCard(context),
      _telegramUserCard(context),
      _exhentaiCard(context),
    ],
  );

  Widget _wrap(List<Widget> children) => Padding(
    padding: const EdgeInsets.fromLTRB(
      EhSpacing.l,
      0,
      EhSpacing.l,
      EhSpacing.m,
    ),
    child: EhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );

  /// 一行「状态 + 身份 / 错误」。
  Widget _status(Map<String, dynamic>? connection) => Row(
    children: <Widget>[
      ToneChip.status(status: StatusView.fromJson(connection?['state'])),
      const SizedBox(width: EhSpacing.s),
      Expanded(
        child: Text(
          asString(connection?['identity']).isEmpty
              ? (asBool(connection?['configured']) ? '已配置' : '未配置')
              : asString(connection?['identity']),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );

  Widget _field(
    String key,
    TextEditingController controller,
    String label, {
    bool obscure = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: EhSpacing.s),
    child: TextField(
      key: ValueKey<String>(key),
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _telegramCard(BuildContext context) {
    final Map<String, dynamic>? telegram = _connection('telegram');
    return _wrap(<Widget>[
      const SectionHeader(title: 'Telegram Bot'),
      _status(telegram),
      _field('connections-bot-token', _botToken, 'Bot Token', obscure: true),
      const SizedBox(height: EhSpacing.s),
      Wrap(
        spacing: EhSpacing.s,
        children: <Widget>[
          FilledButton(
            key: const ValueKey<String>('connections-telegram-save'),
            onPressed: busy
                ? null
                : () => unawaited(
                    _send(<String, Object?>{
                      'action': 'telegram',
                      'bot_token': _botToken.text.trim(),
                    }),
                  ),
            child: const Text('保存 Token'),
          ),
          if (asBool(telegram?['configured']))
            OutlinedButton(
              key: const ValueKey<String>('connections-telegram-disconnect'),
              onPressed: busy
                  ? null
                  : () => unawaited(
                      _send(<String, Object?>{'action': 'telegram-disconnect'}),
                    ),
              child: const Text('断开'),
            ),
        ],
      ),
    ]);
  }

  Widget _telegramUserCard(BuildContext context) {
    final Map<String, dynamic>? account = _connection('telegram_user');
    final bool awaitingCode = asBool(account?['awaiting_code']);
    final bool awaitingPassword = asBool(account?['awaiting_password']);
    return _wrap(<Widget>[
      const SectionHeader(title: 'Telegram 用户（MTProto）'),
      _status(account),
      if (awaitingCode || awaitingPassword) ...<Widget>[
        Padding(
          padding: const EdgeInsets.only(top: EhSpacing.s),
          child: Text(
            asString(account?['phone']).isEmpty
                ? '等验证码或两步验证密码'
                : '验证码已发往 ${asString(account?['phone'])}',
          ),
        ),
        if (awaitingCode) _field('connections-code', _code, '验证码'),
        if (awaitingPassword)
          _field('connections-2fa', _twoFactor, '两步验证密码', obscure: true),
        const SizedBox(height: EhSpacing.s),
        FilledButton(
          key: const ValueKey<String>('connections-tg-user-verify'),
          onPressed: busy
              ? null
              : () => unawaited(
                  _send(<String, Object?>{
                    'action': 'telegram-user-verify',
                    if (_code.text.trim().isNotEmpty) 'code': _code.text.trim(),
                    if (_twoFactor.text.isNotEmpty)
                      'password': _twoFactor.text,
                  }),
                ),
          child: const Text('验证'),
        ),
      ] else ...<Widget>[
        _field('connections-api-id', _apiId, 'API ID'),
        _field('connections-api-hash', _apiHash, 'API Hash', obscure: true),
        _field('connections-phone', _phone, '手机号'),
        const SizedBox(height: EhSpacing.s),
        FilledButton(
          key: const ValueKey<String>('connections-tg-user-login'),
          onPressed: busy
              ? null
              : () => unawaited(
                  _send(<String, Object?>{
                    'action': 'telegram-user-login',
                    'api_id': _apiId.text.trim(),
                    'api_hash': _apiHash.text.trim(),
                    'phone': _phone.text.trim(),
                  }),
                ),
          child: const Text('发送验证码'),
        ),
      ],
      if (asBool(account?['configured'])) ...<Widget>[
        const SizedBox(height: EhSpacing.s),
        OutlinedButton(
          key: const ValueKey<String>('connections-tg-user-disconnect'),
          onPressed: busy
              ? null
              : () => unawaited(
                  _send(<String, Object?>{
                    'action': 'telegram-user-disconnect',
                  }),
                ),
          child: const Text('断开'),
        ),
      ],
    ]);
  }

  Widget _exhentaiCard(BuildContext context) {
    final Map<String, dynamic>? exhentai = _connection('exhentai');
    return _wrap(<Widget>[
      const SectionHeader(title: 'ExHentai'),
      _status(exhentai),
      _field('connections-member-id', _memberId, 'ipb_member_id'),
      _field('connections-pass-hash', _passHash, 'ipb_pass_hash', obscure: true),
      _field('connections-igneous', _igneous, 'igneous', obscure: true),
      const SizedBox(height: EhSpacing.s),
      Wrap(
        spacing: EhSpacing.s,
        children: <Widget>[
          FilledButton(
            key: const ValueKey<String>('connections-exhentai-save'),
            onPressed: busy
                ? null
                : () => unawaited(
                    _send(<String, Object?>{
                      'action': 'exhentai',
                      'ipb_member_id': _memberId.text.trim(),
                      'ipb_pass_hash': _passHash.text.trim(),
                      'igneous': _igneous.text.trim(),
                    }),
                  ),
            child: const Text('保存 Cookie'),
          ),
          if (asBool(exhentai?['configured']))
            OutlinedButton(
              key: const ValueKey<String>('connections-exhentai-disconnect'),
              onPressed: busy
                  ? null
                  : () => unawaited(
                      _send(<String, Object?>{'action': 'exhentai-disconnect'}),
                    ),
              child: const Text('断开'),
            ),
        ],
      ),
    ]);
  }
}

// ---------------------------------------------------------------- 系统

/// 只用改动的字段组装 body：后端「只写出现过的字段」，
/// 所以一个空字段不该被当成「把它清空」发上去。
Map<String, Object?> systemPatch({
  required Map<String, dynamic> current,
  required Map<String, String> edits,
}) => <String, Object?>{
  for (final MapEntry<String, String> edit in edits.entries)
    if (edit.value.trim().isNotEmpty &&
        edit.value.trim() != asString(current[edit.key]).trim())
      edit.key: edit.value.trim(),
};

/// 系统区（`PUT /api/v1/settings/system`，R68）。
class SystemEditor extends StatefulWidget {
  const SystemEditor({
    super.key,
    required this.api,
    required this.snapshot,
    required this.onSaved,
  });

  final EhBotApi api;
  final Map<String, dynamic> snapshot;
  final ValueChanged<Map<String, dynamic>> onSaved;

  @override
  State<SystemEditor> createState() => _SystemEditorState();
}

class _SystemEditorState extends State<SystemEditor>
    with SettingsWriteMixin<SystemEditor> {
  @override
  EhBotApi get api => widget.api;

  late Map<String, dynamic> _system = asMap(widget.snapshot['system']) ??
      const <String, dynamic>{};
  late List<String> _priority = asMapList(widget.snapshot['download_sources'])
      .map((Map<String, dynamic> row) => asString(row['code']))
      .where((String code) => code.isNotEmpty)
      .toList();
  late String _logLevel = asString(_system['log_level'], 'INFO');

  @override
  void didUpdateWidget(SystemEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _system = asMap(widget.snapshot['system']) ?? const <String, dynamic>{};
  }

  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{};

  TextEditingController _controller(String key) =>
      _fields.putIfAbsent(key, () => TextEditingController());

  @override
  void dispose() {
    for (final TextEditingController c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final Map<String, String> edits = <String, String>{
      'source_concurrency': _controller('source_concurrency').text,
      'poll_interval_ms': _controller('poll_interval_ms').text,
      'timezone': _controller('timezone').text,
      'auto_approval_interval_minutes':
          _controller('auto_approval_interval_minutes').text,
      'mobile_access_ttl_seconds':
          _controller('mobile_access_ttl_seconds').text,
      'mobile_refresh_ttl_seconds':
          _controller('mobile_refresh_ttl_seconds').text,
      'log_level': _logLevel,
      'download_source_priority': _priority.join(','),
    };
    final Map<String, Object?> body = systemPatch(
      current: _system,
      edits: edits,
    );
    if (body.isEmpty) {
      setState(() => notice = '没有改动。');
      return;
    }
    final Map<String, dynamic>? snapshot = await write(kSettingsSystem, body);
    if (snapshot != null && mounted) {
      widget.onSaved(snapshot);
      setState(() => _priority = asMapList(snapshot['download_sources'])
          .map((Map<String, dynamic> row) => asString(row['code']))
          .where((String code) => code.isNotEmpty)
          .toList());
    }
  }

  Widget _numberField(BuildContext context, String key, String label) {
    final Object? value = _system[key];
    return Padding(
      padding: const EdgeInsets.only(top: EhSpacing.s),
      child: TextField(
        key: ValueKey<String>('system-$key'),
        controller: _controller(key),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          hintText: value == null ? null : '$value',
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> sources = asMapList(
      widget.snapshot['download_sources'],
    );
    final List<String> levels = asMapList(
      asMap(widget.snapshot['logs'])?['levels'],
    ).map((Map<String, dynamic> level) => asString(level['code'])).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: EhSpacing.xxl),
      children: <Widget>[
        if (notice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              EhSpacing.l,
              0,
              EhSpacing.l,
              EhSpacing.s,
            ),
            child: noticeCard(),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EhSpacing.l),
          child: EhCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionHeader(title: '系统'),
                _numberField(context, 'source_concurrency', '来源并发'),
                _numberField(context, 'poll_interval_ms', '轮询间隔（毫秒）'),
                TextField(
                  key: const ValueKey<String>('system-timezone'),
                  controller: _controller('timezone'),
                  decoration: InputDecoration(
                    labelText: '时区',
                    hintText: asString(_system['timezone']),
                    border: const OutlineInputBorder(),
                  ),
                ),
                _numberField(
                  context,
                  'auto_approval_interval_minutes',
                  '自动审批间隔（分钟）',
                ),
                _numberField(
                  context,
                  'mobile_access_ttl_seconds',
                  '移动端 access 时长（秒）',
                ),
                _numberField(
                  context,
                  'mobile_refresh_ttl_seconds',
                  '移动端 refresh 时长（秒）',
                ),
                const SizedBox(height: EhSpacing.m),
                Text('日志等级', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: EhSpacing.s),
                DropdownButtonFormField<String>(
                  key: const ValueKey<String>('system-log-level'),
                  initialValue: levels.contains(_logLevel) ? _logLevel : null,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final String level in levels)
                      DropdownMenuItem<String>(
                        value: level,
                        child: Text(level),
                      ),
                  ],
                  onChanged: (String? level) =>
                      setState(() => _logLevel = level ?? _logLevel),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            EhSpacing.l,
            EhSpacing.m,
            EhSpacing.l,
            0,
          ),
          child: EhCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionHeader(title: '下载来源优先级'),
                Text(
                  '数值越小越靠前：越靠前的来源越先被自动选择。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                for (int i = 0; i < _priority.length; i++)
                  ListTile(
                    key: ValueKey<String>('system-priority-${_priority[i]}'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Text('${i + 1}'),
                    title: Text(
                      sources
                              .where(
                                (Map<String, dynamic> row) =>
                                    asString(row['code']) == _priority[i],
                              )
                              .map((Map<String, dynamic> row) => asString(row['label']))
                              .firstOrNull ??
                          _priority[i],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          tooltip: '上移',
                          onPressed: i == 0 || busy
                              ? null
                              : () => setState(() {
                                  final String code = _priority.removeAt(i);
                                  _priority.insert(i - 1, code);
                                }),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: '下移',
                          onPressed: i == _priority.length - 1 || busy
                              ? null
                              : () => setState(() {
                                  final String code = _priority.removeAt(i);
                                  _priority.insert(i + 1, code);
                                }),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(EhSpacing.l),
          child: FilledButton(
            key: const ValueKey<String>('system-save'),
            onPressed: busy ? null : () => unawaited(_save()),
            child: const Text('保存系统设置'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 密码库

/// 密码库（`PUT /api/v1/settings/passwords`，R69）。
///
/// 明文只有一个出口：`api-key-generate` 的**响应**。它进来时立刻弹一次，
/// 不进日志、不落盘、不再回显（后端也读不回来）。
class PasswordsEditor extends StatefulWidget {
  const PasswordsEditor({
    super.key,
    required this.api,
    required this.snapshot,
    required this.onSaved,
  });

  final EhBotApi api;
  final Map<String, dynamic> snapshot;
  final ValueChanged<Map<String, dynamic>> onSaved;

  @override
  State<PasswordsEditor> createState() => _PasswordsEditorState();
}

class _PasswordsEditorState extends State<PasswordsEditor>
    with SettingsWriteMixin<PasswordsEditor> {
  @override
  EhBotApi get api => widget.api;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _priority = TextEditingController(text: '100');
  bool _enabled = true;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _priority.dispose();
    super.dispose();
  }

  Future<void> _send(Map<String, Object?> body, {bool reveal = false}) async {
    final Map<String, dynamic>? snapshot = await write(
      kSettingsPasswords,
      body,
    );
    if (snapshot == null || !mounted) {
      return;
    }
    widget.onSaved(snapshot);
    final String plaintext = asString(snapshot['api_key_plaintext']);
    if (reveal && plaintext.isNotEmpty) {
      await _reveal(plaintext);
    }
  }

  /// 一次性展示新 Key。关掉就没了——后端只在这一条响应里给过明文。
  Future<void> _reveal(String plaintext) => showDialog<void>(
    context: context,
    builder: (BuildContext c) => AlertDialog(
      title: const Text('新的 API Key'),
      content: SelectableText(
        plaintext,
        key: const ValueKey<String>('passwords-api-key-plaintext'),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(c).pop(),
          child: const Text('我已保存'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> passwords = asMapList(
      widget.snapshot['passwords'],
    );
    final Map<String, dynamic>? apiKey = asMap(widget.snapshot['api_key']);
    return ListView(
      padding: const EdgeInsets.only(bottom: EhSpacing.xxl),
      children: <Widget>[
        if (notice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              EhSpacing.l,
              0,
              EhSpacing.l,
              EhSpacing.s,
            ),
            child: noticeCard(),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EhSpacing.l),
          child: EhCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionHeader(title: '移动端 API Key'),
                Text(
                  asBool(apiKey?['configured'])
                      ? '已配置（${asString(apiKey?['label'])}，'
                            '全局同时只有一条有效）'
                      : '未配置。生成后明文只显示一次。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: EhSpacing.s),
                if (asBool(apiKey?['configured']))
                  OutlinedButton(
                    key: const ValueKey<String>('passwords-api-key-revoke'),
                    onPressed: busy
                        ? null
                        : () => unawaited(
                            _send(<String, Object?>{
                              'action': 'api-key-revoke',
                            }),
                          ),
                    child: const Text('撤销'),
                  )
                else
                  FilledButton(
                    key: const ValueKey<String>('passwords-api-key-generate'),
                    onPressed: busy
                        ? null
                        : () => unawaited(
                            _send(
                              <String, Object?>{'action': 'api-key-generate'},
                              reveal: true,
                            ),
                          ),
                    child: const Text('生成 API Key'),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            EhSpacing.l,
            EhSpacing.m,
            EhSpacing.l,
            0,
          ),
          child: EhCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionHeader(title: '归档密码'),
                if (passwords.isEmpty)
                  const Text('还没有归档密码。')
                else
                  for (final Map<String, dynamic> entry in passwords)
                    ListTile(
                      key: ValueKey<String>(
                        'passwords-entry-${asString(entry['password_id'])}',
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        asString(entry['name']).isEmpty
                            ? '未命名'
                            : asString(entry['name']),
                      ),
                      subtitle: Text(
                        '优先级 ${asInt(entry['priority'])}'
                        '${asBool(entry['enabled']) ? '' : ' · 已停用'}',
                      ),
                      trailing: IconButton(
                        tooltip: '删除',
                        onPressed: busy
                            ? null
                            : () => unawaited(
                                _confirmDelete(asInt(entry['password_id'])),
                              ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            EhSpacing.l,
            EhSpacing.m,
            EhSpacing.l,
            0,
          ),
          child: EhCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionHeader(title: '新增归档密码'),
                TextField(
                  key: const ValueKey<String>('passwords-name'),
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: EhSpacing.s),
                TextField(
                  key: const ValueKey<String>('passwords-secret'),
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: EhSpacing.s),
                TextField(
                  key: const ValueKey<String>('passwords-priority'),
                  controller: _priority,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '优先级',
                    helperText: '数值越小越先被尝试',
                    border: OutlineInputBorder(),
                  ),
                ),
                CheckboxListTile(
                  key: const ValueKey<String>('passwords-enabled'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _enabled,
                  onChanged: (bool? v) =>
                      setState(() => _enabled = v ?? false),
                  title: const Text('启用'),
                ),
                FilledButton(
                  key: const ValueKey<String>('passwords-add'),
                  onPressed: busy
                      ? null
                      : () => unawaited(
                          _send(<String, Object?>{
                            'action': 'add',
                            'name': _name.text.trim(),
                            'password': _password.text,
                            'priority':
                                int.tryParse(_priority.text.trim()) ?? 100,
                            'enabled': _enabled,
                          }),
                        ),
                  child: const Text('添加密码'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(int passwordId) async {
    final bool ok = await confirmDialog(
      context,
      title: '删除这条归档密码',
      message: '删除后打包时不再尝试这个密码；已经打好的包不受影响。',
      confirmLabel: '确认删除',
    );
    if (!ok || !mounted) {
      return;
    }
    await _send(<String, Object?>{
      'action': 'delete',
      'password_id': passwordId,
    });
  }
}

// ---------------------------------------------------------------- 只读

/// 还没有写入端点的六区：结构化只读。
///
/// 不再把整个 JSON 摊成 `a.b.c` 一条条长行，而是**按顶层 key 分组**，
/// 组内再摊平——读起来是「这一区有哪些东西」，而不是「这个对象有哪些键」。
class ReadOnlySection extends StatelessWidget {
  const ReadOnlySection({
    super.key,
    required this.title,
    required this.summary,
    required this.data,
  });

  final String title;
  final String summary;

  final Map<String, dynamic> data;

  /// 系统区里那份日志尾巴交给日志页，不在这里再摊一遍。
  static const Set<String> hiddenKeys = <String>{'logs'};

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, dynamic>> groups = data.entries
        .where((MapEntry<String, dynamic> e) => !hiddenKeys.contains(e.key))
        .toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: EhSpacing.xxl),
      children: <Widget>[
        SectionHeader(title: title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EhSpacing.l),
          child: Text(summary),
        ),
        const SizedBox(height: EhSpacing.m),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            EhSpacing.l,
            0,
            EhSpacing.l,
            EhSpacing.s,
          ),
          child: EhCard(
            tone: EhCardTone.neutral,
            dense: true,
            child: Text(
              '这一区目前只有读：写入需要后端在 /api/v1 上补端点'
              '（见 AgentHelp/CONTRACT.md §7）。',
              key: const ValueKey<String>('settings-readonly-note'),
            ),
          ),
        ),
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.all(EhSpacing.l),
            child: Text('该分区暂时没有可显示的值。'),
          ),
        for (final MapEntry<String, dynamic> group in groups)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              EhSpacing.l,
              0,
              EhSpacing.l,
              EhSpacing.s,
            ),
            child: EhCard(
              dense: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SectionHeader(title: group.key),
                  for (final (String label, String value) in leaves(
                    group.value,
                    group.key,
                  ))
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: EhSpacing.xs,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 140,
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Expanded(child: Text(value)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 把一组 JSON 摊成 (路径, 文本) 列表；列表只报条数，不整段打印。
  static List<(String, String)> leaves(Object? value, [String prefix = '']) {
    final List<(String, String)> out = <(String, String)>[];
    if (value is Map) {
      for (final MapEntry<Object?, Object?> entry in value.entries) {
        final String key = prefix.isEmpty
            ? '${entry.key}'
            : '$prefix.${entry.key}';
        out.addAll(leaves(entry.value, key));
      }
      return out;
    }
    if (value is List) {
      if (value.isEmpty) {
        out.add((prefix, '—'));
        return out;
      }
      // 列表是配置清单（来源规则、自动审批规则、AI 供应商…），
      // 只报条数等于把内容藏起来。前几条摊开，其余报个数——
      // 一个「有 50 条规则」的分区不该把页面撑成 50 行。
      for (int i = 0; i < value.length && i < _maxListItems; i++) {
        final Object? item = value[i];
        if (item is Map || item is List) {
          out.addAll(leaves(item, '$prefix[$i]'));
        } else {
          out.add(('$prefix[$i]', item == null ? '—' : '$item'));
        }
      }
      if (value.length > _maxListItems) {
        out.add((prefix, '还有 ${value.length - _maxListItems} 条'));
      }
      return out;
    }
    out.add((prefix, value == null || '$value'.isEmpty ? '—' : '$value'));
    return out;
  }

  /// 一个列表最多摊开几条。
  static const int _maxListItems = 5;
}
