import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/api_exception.dart';
import '../api/auth_api.dart';
import '../api/auth_client.dart';
import '../api/auth_session.dart';
import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../api/probe.dart';
import '../api/token_store.dart';
import '../media/thumbnail_cache.dart';
import '../media/thumbnail_loader.dart';
import 'server_store.dart';
import 'settings.dart';

/// 应用阶段：决定首屏。
enum AppStage { loading, serverSetup, login, ready }

/// 应用级状态：服务器设置 + 会话 + 数据客户端。
class AppState extends ChangeNotifier {
  AppState({
    required this.settingsStore,
    required this.tokenStore,
    required this.clientFactory,
    required this.thumbnailCache,
    ServerStore? serverStore,
  }) : serverStore = serverStore ?? ServerStore();

  final SettingsStore settingsStore;
  final ServerStore serverStore;
  final TokenStore tokenStore;
  final http.Client Function(AppSettings settings) clientFactory;
  final ThumbnailCache thumbnailCache;

  AppSettings settings = const AppSettings();
  AppStage stage = AppStage.loading;
  AuthSession? session;
  WhoAmI? identity;

  /// 已保存的服务器档案；空表示还没配过。
  List<ServerProfile> servers = const <ServerProfile>[];

  /// 当前选中的档案 id；未选中为 `null`。
  String? activeServerId;

  /// 一次性提示（例如「API Key 已失效，请重新登录」）。
  String? notice;

  http.Client? _dataClient;
  AuthClient? _authClient;
  EhBotApi? _api;
  ThumbnailLoader? _thumbnails;

  bool get isLoggedIn => _authClient != null;
  AuthClient? get client => _authClient;

  /// 数据端点；未登录为 `null`。
  EhBotApi? get api => _api;

  /// 带鉴权的封面加载器；未登录为 `null`。
  ThumbnailLoader? get thumbnails => _thumbnails;
  Uri? get baseUri => settings.baseUri;

  /// 当前选中的档案（可能为 `null`——还没配服务器时）。
  ServerProfile? get activeServer {
    final String? id = activeServerId;
    if (id == null) {
      return null;
    }
    for (final ServerProfile p in servers) {
      if (p.id == id) {
        return p;
      }
    }
    return null;
  }

  /// 启动：读设置 →（有凭据就恢复会话）→ 决定首屏。
  Future<void> bootstrap() async {
    await _loadServers();
    if (!settings.isConfigured) {
      _setStage(AppStage.serverSetup);
      return;
    }
    await _restoreSession();
  }

  /// 读多服务器档案；没有档案时把旧的单服务器设置迁成一份档案（无感升级）。
  Future<void> _loadServers() async {
    servers = await serverStore.loadAll();
    activeServerId = await serverStore.loadActiveId();

    if (servers.isEmpty) {
      final AppSettings legacy = await settingsStore.load();
      if (legacy.isConfigured) {
        final ServerProfile migrated = ServerProfile(
          id: newServerId(),
          label: legacy.baseUri?.host ?? '',
          settings: legacy,
        );
        servers = <ServerProfile>[migrated];
        activeServerId = migrated.id;
        await serverStore.saveAll(servers);
        await serverStore.saveActiveId(activeServerId);
        settings = legacy;
        return;
      }
      settings = const AppSettings();
      return;
    }

    ServerProfile? active = activeServer;
    if (active == null) {
      // active id 失效（档案被删 / 存储被清）→ 落到第一份，若都没有则空。
      active = servers.isEmpty ? null : servers.first;
      activeServerId = active?.id;
      await serverStore.saveActiveId(activeServerId);
    }
    settings = active?.settings ?? const AppSettings();
  }

  /// 更新（或新建）当前档案的服务器设置。
  Future<void> _upsertActiveProfile(AppSettings next, {String? label}) async {
    final ServerProfile? current = activeServer;
    final ServerProfile updated;
    if (current == null) {
      updated = ServerProfile(
        id: newServerId(),
        label: label ?? (next.baseUri?.host ?? ''),
        settings: next,
      );
      servers = <ServerProfile>[...servers, updated];
      activeServerId = updated.id;
    } else {
      updated = current.copyWith(label: label ?? current.label, settings: next);
      servers = <ServerProfile>[
        for (final ServerProfile p in servers)
          if (p.id == current.id) updated else p,
      ];
    }
    await serverStore.saveAll(servers);
    await serverStore.saveActiveId(activeServerId);
  }

  /// 「测试连接」：用候选设置临时建客户端探测，不落盘。
  Future<ServerProbeResult> probe(AppSettings candidate) async {
    final Uri? base = candidate.baseUri;
    if (base == null) {
      return const ServerProbeResult(
        reachable: false,
        authSupported: false,
        message: '请先填写合法的服务器地址。',
      );
    }
    final http.Client client = clientFactory(candidate);
    try {
      return await probeServer(
        client: client,
        baseUri: base,
        timeout: candidate.timeout,
      );
    } finally {
      client.close();
    }
  }

  /// 保存服务器设置；换了服务器旧凭据即作废。
  Future<void> saveSettings(AppSettings next) async {
    _disposeSession();
    await tokenStore.clear();
    settings = next;
    await settingsStore.save(next);
    await _upsertActiveProfile(next);
    notice = null;
    _setStage(next.isConfigured ? AppStage.login : AppStage.serverSetup);
  }

  /// 切换到另一台服务器（多份档案之一）。凭据按当前服务器单份存放，
  /// 因此切换等价于先登出、再落到那台服务器的登录页。
  Future<void> switchServer(String id) async {
    if (id == activeServerId) {
      return;
    }
    ServerProfile? target;
    for (final ServerProfile p in servers) {
      if (p.id == id) {
        target = p;
        break;
      }
    }
    if (target == null) {
      return;
    }
    _disposeSession();
    await tokenStore.clear();
    activeServerId = target.id;
    settings = target.settings;
    await serverStore.saveActiveId(activeServerId);
    notice = null;
    _setStage(settings.isConfigured ? AppStage.login : AppStage.serverSetup);
  }

  /// 改一台档案的标签（不改其连接参数）。
  Future<void> renameServer(String id, String label) async {
    servers = <ServerProfile>[
      for (final ServerProfile p in servers)
        if (p.id == id) p.copyWith(label: label) else p,
    ];
    await serverStore.saveAll(servers);
    notifyListeners();
  }

  /// 新增一台服务器档案并切过去（用于「添加服务器」流程）。
  Future<void> addServerWith(AppSettings next, {String? label}) async {
    _disposeSession();
    await tokenStore.clear();
    final ServerProfile created = ServerProfile(
      id: newServerId(),
      label: label ?? (next.baseUri?.host ?? ''),
      settings: next,
    );
    servers = <ServerProfile>[...servers, created];
    activeServerId = created.id;
    settings = next;
    await serverStore.saveAll(servers);
    await serverStore.saveActiveId(activeServerId);
    notice = null;
    _setStage(next.isConfigured ? AppStage.login : AppStage.serverSetup);
  }

  /// 保存某台指定档案的连接参数（编辑非当前服务器时用）。
  Future<void> saveProfileSettings(
    String id,
    AppSettings next, {
    String? label,
  }) async {
    final ServerProfile target = servers.firstWhere(
      (ServerProfile p) => p.id == id,
      orElse: () =>
          const ServerProfile(id: '', label: '', settings: AppSettings()),
    );
    if (target.id.isEmpty) {
      return;
    }
    final ServerProfile updated = target.copyWith(
      label: label ?? target.label,
      settings: next,
    );
    servers = <ServerProfile>[
      for (final ServerProfile p in servers)
        if (p.id == id) updated else p,
    ];
    await serverStore.saveAll(servers);
    if (id == activeServerId) {
      _disposeSession();
      await tokenStore.clear();
      settings = next;
      notice = null;
      _setStage(next.isConfigured ? AppStage.login : AppStage.serverSetup);
      return;
    }
    notifyListeners();
  }

  /// 删除一台档案；删的若是当前服务器，则回服务器配置页。
  Future<void> removeServer(String id) async {
    final bool wasActive = id == activeServerId;
    servers = <ServerProfile>[
      for (final ServerProfile p in servers)
        if (p.id != id) p,
    ];
    await serverStore.saveAll(servers);
    if (wasActive) {
      _disposeSession();
      await tokenStore.clear();
      activeServerId = servers.isEmpty ? null : servers.first.id;
      await serverStore.saveActiveId(activeServerId);
      settings = activeServer?.settings ?? const AppSettings();
      _setStage(settings.isConfigured ? AppStage.login : AppStage.serverSetup);
    } else {
      notifyListeners();
    }
  }

  /// 回到服务器配置页（保留已填地址，方便修改）。
  void editServer() {
    _setStage(AppStage.serverSetup);
  }

  Future<void> loginWithPassword(String password, {String? label}) async {
    final Uri base = _requireBase();
    final http.Client client = clientFactory(settings);
    final AuthApi api = AuthApi(
      client: client,
      baseUri: base,
      timeout: settings.timeout,
    );
    try {
      final TokenPair pair = await api.loginWithPassword(
        password: password,
        label: label,
      );
      final WhoAmI who = await api.whoAmI(pair.accessToken);
      final AuthSession session = AuthSession.password(
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
      );
      await tokenStore.clear();
      await tokenStore.writeRefreshToken(pair.refreshToken);
      _activate(session, who, client);
    } on Object {
      client.close();
      rethrow;
    }
  }

  Future<void> loginWithApiKey(String apiKey) async {
    final String key = apiKey.trim();
    final Uri base = _requireBase();
    final http.Client client = clientFactory(settings);
    try {
      final WhoAmI who = await AuthApi(
        client: client,
        baseUri: base,
        timeout: settings.timeout,
      ).whoAmI(key);
      final AuthSession session = AuthSession.apiKey(key);
      await tokenStore.clear();
      await tokenStore.writeApiKey(key);
      _activate(session, who, client);
    } on Object {
      client.close();
      rethrow;
    }
  }

  /// 退出登录。[revoke] 为 true 时尽力通知后端吊销本设备族（API Key 不受影响）。
  Future<void> logout({bool revoke = true, String? notice}) async {
    final AuthSession? current = session;
    final http.Client? client = _dataClient;
    final Uri? base = settings.baseUri;
    if (revoke &&
        current != null &&
        client != null &&
        base != null &&
        current.kind == CredentialKind.password &&
        current.bearer != null) {
      try {
        await AuthApi(
          client: client,
          baseUri: base,
          timeout: settings.timeout,
        ).logout(current.bearer!);
      } on Object catch (error) {
        debugPrint('logout 通知后端失败（忽略）：${error.runtimeType}');
      }
    }
    await _clearSession(notice: notice);
  }

  Future<void> _restoreSession() async {
    final Uri base = settings.baseUri!;
    final http.Client client = clientFactory(settings);
    final AuthApi api = AuthApi(
      client: client,
      baseUri: base,
      timeout: settings.timeout,
    );

    final String? apiKey = await tokenStore.readApiKey();
    if (apiKey != null) {
      final AuthSession session = AuthSession.apiKey(apiKey);
      try {
        _activate(session, await api.whoAmI(apiKey), client);
        return;
      } on ApiException catch (error) {
        if (error.isUnauthorized) {
          client.close();
          await _clearSession(notice: 'API Key 已失效或已在网页端刷新，请重新登录。');
          return;
        }
        client.close();
        notice = '无法连接服务器：${error.message}';
        _setStage(AppStage.login);
        return;
      }
    }

    final String? refreshToken = await tokenStore.readRefreshToken();
    if (refreshToken == null) {
      client.close();
      _setStage(AppStage.login);
      return;
    }
    final AuthSession session = AuthSession.password(
      refreshToken: refreshToken,
    );
    try {
      final TokenPair pair = await api.refresh(refreshToken);
      session.updateTokens(
        access: pair.accessToken,
        refresh: pair.refreshToken,
      );
      await tokenStore.writeRefreshToken(pair.refreshToken);
      _activate(session, await api.whoAmI(pair.accessToken), client);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        client.close();
        await _clearSession(notice: '会话已过期，请重新登录。');
        return;
      }
      client.close();
      notice = '无法连接服务器：${error.message}';
      _setStage(AppStage.login);
    }
  }

  void _activate(AuthSession session, WhoAmI who, http.Client client) {
    _disposeSession();
    this.session = session;
    identity = who;
    _dataClient = client;
    _authClient = AuthClient(
      inner: client,
      baseUri: settings.baseUri!,
      session: session,
      timeout: settings.timeout,
      onSessionExpired: _handleSessionExpired,
    )..refreshHook = _refreshSession;
    _api = EhBotApi(_authClient!);
    _thumbnails = ThumbnailLoader(client: _authClient!, cache: thumbnailCache);
    notice = null;
    _setStage(AppStage.ready);
  }

  Future<void> _refreshSession(AuthSession session) async {
    final String? refreshToken = session.refreshToken;
    final Uri? base = settings.baseUri;
    final http.Client? client = _dataClient;
    if (refreshToken == null || base == null || client == null) {
      throw const ApiException(
        code: ApiException.sessionExpired,
        message: '没有可用的 refresh token。',
      );
    }
    final TokenPair pair = await AuthApi(
      client: client,
      baseUri: base,
      timeout: settings.timeout,
    ).refresh(refreshToken);
    session.updateTokens(access: pair.accessToken, refresh: pair.refreshToken);
    await tokenStore.writeRefreshToken(pair.refreshToken);
  }

  void _handleSessionExpired() {
    unawaited(logout(revoke: false, notice: '会话已过期，请重新登录。'));
  }

  Future<void> _clearSession({String? notice}) async {
    _disposeSession();
    await tokenStore.clear();
    this.notice = notice;
    _setStage(AppStage.login);
  }

  void _disposeSession() {
    _api = null;
    _thumbnails = null;
    _authClient = null;
    _dataClient?.close();
    _dataClient = null;
    session = null;
    identity = null;
  }

  Uri _requireBase() {
    final Uri? base = settings.baseUri;
    if (base == null) {
      throw StateError('服务器地址未配置');
    }
    return base;
  }

  void _setStage(AppStage next) {
    stage = next;
    notifyListeners();
  }
}
