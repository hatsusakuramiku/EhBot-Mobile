import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/server_store.dart';
import 'server_setup_page.dart';
import 'theme.dart';
import 'widgets/eh_card.dart';
import 'widgets/empty_state.dart';

/// 服务器档案管理（M8-A）：列出所有服务器，切换 / 编辑 / 删除 / 新增。
///
/// EhBot 没有多用户概念——这里管理的是「多台服务器」，不是多个账号。
class ServersPage extends StatelessWidget {
  const ServersPage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (BuildContext context, Widget? _) => Scaffold(
      appBar: AppBar(
        title: const Text('服务器'),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('servers-add'),
            tooltip: '添加服务器',
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext _) =>
                    ServerSetupPage(state: state, isNew: true),
              ),
            ),
          ),
        ],
      ),
      body: state.servers.isEmpty
          ? const EmptyState(
              icon: Icons.dns_outlined,
              primary: '还没有服务器',
              secondary: '点右上角 + 添加一台 EhBot 服务地址',
            )
          : ListView(
              padding: const EdgeInsets.all(EhSpacing.l),
              children: <Widget>[
                for (final ServerProfile profile in state.servers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: EhSpacing.m),
                    child: _serverCard(context, profile),
                  ),
              ],
            ),
    ),
  );

  Widget _serverCard(BuildContext context, ServerProfile profile) {
    final bool active = profile.id == state.activeServerId;
    return EhCard(
      key: ValueKey<String>('server-row-${profile.id}'),
      dense: true,
      onTap: active
          ? null
          : () async {
              await state.switchServer(profile.id);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
      child: Row(
        children: <Widget>[
          Icon(
            active ? Icons.check_circle : Icons.circle_outlined,
            color: active ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: EhSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  profile.effectiveLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  profile.settings.baseUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            key: ValueKey<String>('server-menu-${profile.id}'),
            onSelected: (String value) =>
                _onMenu(context, profile, value),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'edit',
                child: Text('编辑'),
              ),
              const PopupMenuItem<String>(
                value: 'rename',
                child: Text('重命名'),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    ServerProfile profile,
    String action,
  ) async {
    switch (action) {
      case 'edit':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext _) => ServerSetupPage(
              state: state,
              editingId: profile.id,
            ),
          ),
        );
      case 'rename':
        final String? name = await _promptRename(context, profile);
        if (name != null && name.trim().isNotEmpty) {
          await state.renameServer(profile.id, name.trim());
        }
      case 'delete':
        final bool ok = await _confirmDelete(context, profile) ?? false;
        if (ok) {
          await state.removeServer(profile.id);
        }
    }
  }

  Future<String?> _promptRename(
    BuildContext context,
    ServerProfile profile,
  ) {
    final TextEditingController controller =
        TextEditingController(text: profile.label);
    return showDialog<String>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('重命名服务器'),
        content: TextField(
          key: const ValueKey<String>('server-rename-field'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名称'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(
    BuildContext context,
    ServerProfile profile,
  ) => showDialog<bool>(
    context: context,
    builder: (BuildContext c) => AlertDialog(
      title: const Text('删除服务器'),
      content: Text('确定删除「${profile.effectiveLabel}」？该服务器上的登录状态会一并清除。'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(c).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
}
