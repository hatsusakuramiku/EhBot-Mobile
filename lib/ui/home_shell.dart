import 'dart:async';

import 'package:flutter/material.dart';

import '../api/auth_client.dart';
import '../api/ehbot_api.dart';
import '../api/events.dart';
import '../media/thumbnail_loader.dart';
import '../state/app_state.dart';
import '../state/live_monitor.dart';
import 'activity_page.dart';
import 'candidates_page.dart';
import 'dashboard_page.dart';
import 'downloaded_page.dart';
import 'settings_page.dart';
import 'widgets/live_status_banner.dart';

/// 登录后的四页壳：工作台 / 候选 / 活动 / 已下载，并持有实时监视器。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state, this.monitor});

  final AppState state;

  /// 实时监视器；缺省时按当前会话创建（测试可注入）。
  final LiveMonitor? monitor;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  LiveMonitor? _monitor;
  bool _ownsMonitor = false;

  /// Shared between [DashboardPage] chips and [CandidatesPage] tab strip.
  /// Updates from the dashboard are picked up by the candidates page so the
  /// same tab tap is reflected in both places (M6).
  final ValueNotifier<String> _candidatesTab = ValueNotifier<String>('pending');

  /// Switch the bottom-nav destination. When [candidateTab] is given and the
  /// destination is the candidates list, also sets its active tab.
  void setTab(int index, {String? candidateTab}) {
    setState(() {
      _index = index;
      if (candidateTab != null) {
        _candidatesTab.value = candidateTab;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final LiveMonitor? injected = widget.monitor;
    if (injected != null) {
      _monitor = injected;
      return;
    }
    final EhBotApi? api = widget.state.api;
    final AuthClient? client = widget.state.client;
    if (api == null || client == null) {
      return;
    }
    final LiveMonitor monitor = LiveMonitor(
      api: api,
      openStream: SseEventSource(client: client).connect,
    );
    _monitor = monitor;
    _ownsMonitor = true;
    unawaited(monitor.start());
  }

  @override
  void dispose() {
    _candidatesTab.dispose();
    if (_ownsMonitor) {
      _monitor?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EhBotApi? api = widget.state.api;
    final ThumbnailLoader? thumbnails = widget.state.thumbnails;
    final LiveMonitor? monitor = _monitor;
    if (api == null || thumbnails == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('EhBot'),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('shell-open-settings'),
            tooltip: '设置',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext _) => SettingsPage(state: widget.state),
              ),
            ),
          ),
          IconButton(
            tooltip: '退出登录',
            icon: const Icon(Icons.logout),
            onPressed: () => unawaited(widget.state.logout()),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (monitor != null) LiveStatusBanner(monitor: monitor),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: <Widget>[
                DashboardPage(
                  api: api,
                  thumbnails: thumbnails,
                  monitor: monitor,
                  candidatesTab: _candidatesTab,
                  onOpenCandidates: (String tab) =>
                      setTab(1, candidateTab: tab),
                ),
                CandidatesPage(
                  api: api,
                  thumbnails: thumbnails,
                  monitor: monitor,
                  candidatesTab: _candidatesTab,
                ),
                ActivityPage(
                  api: api,
                  monitor: monitor,
                  thumbnails: thumbnails,
                ),
                DownloadedListPage(
                  api: api,
                  monitor: monitor,
                  thumbnails: thumbnails,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int index) => setState(() => _index = index),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: '工作台',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: '候选',
          ),
          NavigationDestination(
            icon: Icon(Icons.downloading_outlined),
            selectedIcon: Icon(Icons.downloading),
            label: '活动',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: '已下载',
          ),
        ],
      ),
    );
  }
}
