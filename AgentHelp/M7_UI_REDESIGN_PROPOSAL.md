# M7 提案 — 移动端 UI 重构（Flutter UI/UX skill 流程版）

> 状态：**草稿，待运营者审阅**。
> 本期只动 UI：组件库、设计 token、页面骨架、导航结构、动效、可达性。
> 业务功能复刻走 M8，本提案不替。
> 编写方法论：`~/.codex/skills/flutter-ui-ux/SKILL.md` 5-Phase 流程（分析 → 架构 → 实现 → 动效 → 优化）。
> 参考资料：`flutter-ui-ux/references/{widget-patterns,theme-templates,animation-patterns,performance-optimization}.md`、`assets/app-template.md`。

## 1. Phase 1 — 需求分析（Analyze Requirements）

### 1.1 现有 App 结构盘点

| 路径 | 现状 | 缺什么 |
|---|---|---|
| `lib/main.dart` | `MaterialApp` + 自建 `theme`（仅 light，未接 `colorSchemeSeed`） | 浅深双 theme、`useMaterial3: true`、系统跟随 |
| `lib/ui/app.dart` / `home_shell.dart` | `IndexedStack + NavigationBar` 四 tab | nav 走 `go_router`（M8 才上）；先在 M7 把**页面**写好 |
| `lib/ui/dashboard_page.dart` | `RefreshIndicator + ListView`，所有 chip 都是文本色 | 2x2 grid 数字卡、大标题、MetricStrip |
| `lib/ui/candidates_page.dart` | `TextField + Wrap(ChoiceChip)` 平铺 + `ListView.builder` | `SearchBar`（M3）、`SegmentedButton` 退化为 `ChoiceChip` 滚动、`BottomSheet` 筛选、空态、可滑动批量 |
| `lib/ui/activity_page.dart` | 三段平铺 `ListView` | `SegmentedButton` 切段、`SectionHeader` 分组、`EmptyState` |
| `lib/ui/downloaded_page.dart` | 同上 | 同上 + 文件改名 sheet |
| `lib/ui/candidate_detail_page.dart` | `Scaffold + SafeArea + Padding`，按钮塞 `Wrap` | `SliverAppBar.large`、主操作 sticky、危险操作独立卡 |
| `lib/ui/settings_page.dart` | `ListView` 一统天下 | `NavigationRail`（宽屏）/`Drawer`（窄屏）；分页子页 |
| `lib/ui/login_page.dart` | `SingleChildScrollView + Padding` | `SliverAppBar.medium` + 卡片化表单 + 密码/Key 双 tab |
| `lib/ui/widgets/` 现仅 | `async_view / error_view / status_chip / thumbnail_image / live_status_banner` | 见 §4 组件库（至少 12 个） |

### 1.2 设计系统审查

- M3 默认色板，无 `colorSchemeSeed`；颜色直接 `Colors.green.shade100` 等 — **硬编码**，**Fail** skill §"Custom Themes"。
- 字号走 `Theme.of(context).textTheme.*`，但 M6 加了几处 `fontSize: 12` 直接覆盖 — **Fail** §"Custom Themes"。
- 现有 `StatusChip` 用本地 `_toneColor()` 维护 5 个三元组 — **重复劳动**，应当交给 ThemeData。

### 1.3 平台与性能约束

- Android target 6.0 (API 23+)，Android 14 默认启用 predictive back（edge-swipe），iOS 17+ 启用 interactive pop。
- 60 fps 必须；Janky 列表要靠 `ListView.builder` + `RepaintBoundary` 隔离大封面（每行封面单独一 Repaint）。
- 真机不在开发机 — 重构只能靠 widget test + 黄金图片 + 视觉断言；运营者自己跑端到端。

### 1.4 输出

需求拆解 → §3 widget 架构（Phase 2 输出）→ §4 组件库 + §5 页面结构（Phase 3 输出）→ §6 动效（Phase 4 输出）→ §7 性能与可达性（Phase 5 输出）→ §8 阶段切分。

## 2. 原则（不可破）

| 原则 | 出处 | 行为 |
|---|---|---|
| Widget Composition | skill §"Core Philosophy" #1 | 一屏 5~9 个小组件，单组件 ≤ 80 行 |
| Responsive Design | skill §"Core Philosophy" #2 | `LayoutBuilder` + `MediaQuery` 双层，**所有页面**都给三种断点（≤ 600 / 600-840 / ≥ 840 sp） |
| Animations | skill §"Core Philosophy" #3 | 全部走 Flutter 自带（不引 third-party 动画库）；时长遵守 §"Animation Types" 表 |
| Custom Themes | skill §"Core Philosophy" #4 | 禁止再写 `Colors.green.shade100`/`fontSize: 12`；**所有色 / 字号走 ThemeData** |
| Performance | skill §"Core Philosophy" #5 | const 优先；`ListView.builder`；`RepaintBoundary` 隔离封面 / 进度条 / Hero flight |
| Mobile-first, animation-enhanced, accessible | skill top | "Add 之前先看这个" |
| 状态词仍走后端 | MOU §7 | 不硬编码"待审核/已通过"中文标签 |

## 3. Phase 2 — Widget 架构

### 3.1 路由

短期（M7）：仍走 `Navigator 1.0` + `MaterialPageRoute`/`CupertinoPageRoute`（后端 in-place 模式暂不动）。
- 详情页强制 `CupertinoPageRoute`（响应 predictive back / iOS swipe-back）。
- sheet 与 push 弹层用 `showModalBottomSheet(useSafeArea: true, isScrollControlled: true)`。

长期（M8 提案）：切 `go_router`（`flutter-setup-declarative-routing` skill）— 与 M8 §5.2 同步。

### 3.2 状态管理（保持现有）

`AppState`（`ChangeNotifier`）+ `LiveMonitor`（`Stream<int>`）+ 局部 `ValueNotifier` 已足够；M7 不引入 Provider / Riverpod / Bloc — **避免技债**。

### 3.3 新增 widget 命名 / 签名约定

- 全部 `StatelessWidget`，小写 `widgets/{kebab-case}.dart`。
- 至少一个 `Widget build(BuildContext context)` + 私有 `_Style _styleOf(BuildContext)`，把"如何漂亮"全部抽到 `_Style`，让 widget 本体只关心**结构**。
- `const` 构造 + `super.key` + 默认参数，全部走 `widget.xxx` 取值 — **不**接 `BuildContext` 进 build。
- 示例（从 skill §"Custom Widget Examples" 演化）：

```dart
class EhCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EhCardTone tone;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  const EhCard({
    super.key,
    required this.child,
    this.padding,
    this.tone = EhCardTone.neutral,
    this.onTap,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final _EhCardStyle s = _styleOf(context, tone);
    final Widget card = Card(
      elevation: s.elevation,
      color: s.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s.radius)),
      child: Padding(padding: padding ?? s.padding, child: child),
    );
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      child: onTap == null ? card : InkWell(borderRadius: BorderRadius.circular(s.radius), onTap: onTap, child: card),
    );
  }

  static _EhCardStyle _styleOf(BuildContext context, EhCardTone tone) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return switch (tone) {
      EhCardTone.neutral => _EhCardStyle(color: cs.surface, elevation: 0, padding: const EdgeInsets.all(16), radius: 16),
      EhCardTone.outlined => _EhCardStyle(color: cs.surface, elevation: 0, padding: const EdgeInsets.all(16), radius: 16),
      EhCardTone.warning => _EhCardStyle(color: cs.errorContainer, elevation: 0, padding: const EdgeInsets.all(16), radius: 16),
    };
  }
}
```

## 4. Phase 3 — 组件库与主题

### 4.1 主题（`lib/ui/theme.dart`，M3 + 动态色 + 浅深双轨）

紧贴 `references/theme-templates.md` 给的模板：

| 类别 | 取值 / 算法 |
|---|---|
| Seed color | `Color(0xFFE91E63)`（粉，EH 系作品强调色），固定 `const seedColor` |
| Dynamic color | Android 12+ 启用 `dynamic_color`；fallback → `ColorScheme.fromSeed(seedColor, brightness)` |
| 模式 | `ThemeMode.system`；用户可在顶栏三段 `SegmentedButton` 切：跟随系统 / 浅 / 深 |
| 字号 | `useMaterial3: true` + 自建 `_buildTextTheme` 调：`displayLarge 57 / 45 / 32 sp`（仅做大标题状态展示），`titleLarge 22 / titleMedium 16 / body* 16/14` |
| 圆角 | `cardRadius = 16`、`chipRadius = 12`、`sheetRadius = 28`、`buttonRadius = 20`（来自 skill 示例） |
| 间距 | `8 / 12 / 16 / 20 / 24 / 32`，封 `Gap` 扩展（**不引第三方**，自己包 `class Gap extends StatelessWidget`，与 `SizedBox` 等价但语义化） |
| 卡片主题 | 阴影 0/1，**靠 outline 区分层级**（`OutlinedCard` 默认）— skill §"RepaintBoundary" 也建议少 elevation |
| 按钮主题 | `FilledButton` 主 / `OutlinedButton` 次 / `TextButton` 第三档；危险 = `FilledButton.tonal(errorContainer)`；圆角 `buttonRadius` |
| Sheet 主题 | `showModalBottomSheet` 全局配 `BottomSheetThemeData`，圆角 `sheetRadius`；`useSafeArea: true` |

### 4.2 设计 token 一览（导出）

```dart
abstract final class EhSpacing {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}
abstract final class EhRadius {
  static const card = 16.0;
  static const chip = 12.0;
  static const sheet = 28.0;
  static const button = 20.0;
}
abstract final class EhAnim {
  static const fast = Duration(milliseconds: 150);   // 按钮
  static const medium = Duration(milliseconds: 250); // 切页 / sheet
  static const slow = Duration(milliseconds: 350);  // 大块入出场
}
```

### 4.3 组件库（至少 12 个；旧 `widgets/` 5 个中保留 2 个，重写 3 个）

| 组件 | 文件 | 主要职责 | skill 出处 |
|---|---|---|---|
| `EhCard` | `widgets/eh_card.dart` | 信息 / 操作 / 危险 三种 tone，圆角 + 语义 | widget-patterns §"Custom Widget Pattern" |
| `ToneChip` | `widgets/tone_chip.dart` | 渲染 `StatusView`：success/danger/warning/info/muted 5 色，**取代**硬编码的 `StatusChip` | widget-patterns §"ThemedCard" |
| `CoverThumb` | `widgets/cover_thumb.dart` | 三态（缩略图 / 占位 / 失败）+ `RepaintBoundary` 隔离 | performance §"RepaintBoundary" |
| `TagChip` | `widgets/tag_chip.dart` | tags / artist / language，可点 → 跳筛选 | widget-patterns §"Custom Widget" |
| `EmptyState` | `widgets/empty_state.dart` | 主标 + 副标 + 可选 action；含 `Semantics(role: 'image')` | widget-patterns §"Custom Widget" |
| `SectionHeader` | `widgets/section_header.dart` | 标题 + count badge + 操作；`LayoutBuilder` 防折叠 | widget-patterns §"Expandable" |
| `MenuFab` | `widgets/menu_fab.dart` | sticky bottom bar：主按钮 + OverflowMenu | widget-patterns §"Custom Widget" |
| `BottomSheet` | `widgets/bottom_sheet.dart` | 包装 `showModalBottomSheet`：`enableDrag`、`useSafeArea`、`shape: 圆角`、`isScrollControlled` | widget-patterns §"Custom Widget" |
| `SearchBar` | `widgets/search_bar.dart` | M3 `SearchBar`，`M3SearchBarController` 控 | widget-patterns |
| `LargeTitleAppBar` | `widgets/large_title_app_bar.dart` | `SliverAppBar.large` + `Medium` 双形态 | widget-patterns §"Custom Widget" |
| `MetricStrip` | `widgets/metric_strip.dart` | 横向滚动数字卡 + 数字 `TweenAnimationBuilder` | animation §"AnimatedContainer" |
| `NavBar` | `widgets/nav_bar.dart` | 底部 5 个 destination：`workbench / candidates / activity / downloaded / logs`；**多 1 个 logs**，因为 M8-D 才上，先占位隐藏 | widget-patterns |

> 现有 `widgets/async_view.dart` 保留（已是用 `FutureBuilder` 的示范），`widgets/error_view.dart` 保留但升级为接 `EmptyState`。

### 4.4 每页都用 `Theme.of(context).colorScheme.*`

不允许的写法（M0—M6 出现的）：

```dart
// ❌ Future code
Colors.green.shade100     // → use colorScheme.tertiaryContainer / errorContainer / etc.
fontSize: 12              // → use textTheme.labelSmall / bodySmall
elevation: 4              // → cardTheme.elevation (skill 默认 0/1)
BoxShadow(color: black26, blurRadius: 8)  // → shadow theme token
```

```dart
// ✅ Future code
final colorScheme = Theme.of(context).colorScheme;
final textTheme = Theme.of(context).textTheme;
color: colorScheme.surfaceContainerHigh
fontSize: textTheme.labelLarge?.fontSize
elevation: Theme.of(context).cardTheme.elevation ?? 0
```

## 5. Phase 3 (续) — 各页重做要点

### 5.1 工作台（`dashboard_page.dart`）

- 顶部 `LargeTitleAppBar`：「工作台」+ 副标「当前：服务器 A · 需处理 N」。
- 候选计数：2x2 grid（`LayoutBuilder` → ≥ 600 sp 改 4x1）；每格 `EhCard(tone: neutral)`：色块 + 中文标签 + 数量大字（`displaySmall`，`AnimatedSwitcher` + `TweenAnimationBuilder` 数字滚动 350 ms）+ 右下角 `Icons.arrow_outward`。
- "活动" 一行 `MetricStrip`（下载 / 打包 / 需干预），点击切到对应 tab。
- "需干预" 用 `SectionHeader` + 可点 `ListTile`（`ToneChip` 状态词，封面 `CoverThumb` 60x84）。
- 启动告警：`EhCard(tone: warning)`，底部"查看日志"按钮跳 `/logs`（M8-D 才接，先用占位）。

### 5.2 候选列表（`candidates_page.dart`）

- `LargeTitleAppBar` + 右上角 `IconButton(Icons.tune)` → 拉起 `BottomSheet` 筛选 + 排序。
- 顶部：水平滚 `ChoiceChip`（tab + 计数）→ 选中 chip 用 `AnimatedContainer`（200 ms 弹性）；搜索框改 M3 `SearchBar` 而非 `TextField`。
- 列表行：3 列结构（`CoverThumb(60x84)` + 标题 + 元数据）；每行套 `RepaintBoundary`；长按弹出 `showModalBottomSheet`（通过 / 驳回菜单）。
- 分页：底部 `PaginationStrip`（"已加载 X/Y · 加载更多"），数字变化 `AnimatedSwitcher`。
- 空态：`EmptyState(icon: Icons.search_off, primary: '没有匹配的候选', action: '清除筛选')`。

### 5.3 活动（`activity_page.dart`）

- 顶部 `SegmentedButton`（队列 / 打包 / 历史 三段）→ 切换不重建（`IndexedStack`）。
- 每段：`SectionHeader`（"需干预（3）" 之类）+ 该组 `ListView.builder`。
- Job 行：左小封面（来源退化图标）+ `ToneChip` + 进度条（`AnimatedProgress` 800 ms，参考 `animation-patterns`）。

### 5.4 已下载（`downloaded_page.dart`）

- 同 5.3；额外 FAB"打包"，长按行弹批量菜单（"重新打包 / 改名移动 / 移除"走 `BottomSheet`，每项确认弹 `AlertDialog`）。

### 5.5 详情（`candidate_detail_page.dart`）

- `CustomScrollView` + `SliverAppBar.large`（封面 3:4 大图，`FlexibleSpaceBar` 折叠）。
- `SliverToBoxAdapter` 内堆卡：
  1. 信息卡（`EhCard`）：标题 + stage / status `ToneChip` + artist / category / language `TagChip` + tags 流。
  2. 历史卡：元数据列表 + 时间线列表（保留 M3 + M6）。
  3. 操作卡：**主操作**（通过 / 驳回 / 重新打包，视 stage/dynamic actions 决定）一个大按钮；**次操作**进 `PopupMenuButton`；**危险操作**（彻底删除）单独 `EhCard(tone: warning)`，底部 `FilledButton.tonal(errorContainer)`。
- 底部 sticky：用一个 `MenuFab` widget（`Positioned` bottom 0，左右 inset 16，最大宽度 480，永远在拇指区）；危险按钮**绝不放这里**。

### 5.6 设置（`settings_page.dart`）

- `LayoutBuilder`：≥ 840 sp 显示 `NavigationRail` + 内容；< 840 sp 走 `NavigationDrawer`（AppBar 汉堡菜单弹出）。
- 五个分区卡（M7 只实现"账号 / 服务器 / 外部服务 / 关于"，业务分区留 M8-E）：
  - **账号**：`EhCard` 显示 username / 凭据类型 / 凭据到期 + 退出按钮。
  - **服务器**：列表 + 右侧"切换 / 编辑 / 添加"，单独 sheet 编辑（详见 §5.7）。
  - **外部服务**：调 `summary.connections` 给五条 `ListTile`。
  - **关于**：版本号 / 构建号 / GitHub link（用 `url_launcher`）。

### 5.7 登录页（`login_page.dart`）

- `SliverAppBar.medium` + 卡。
- 双 tab（密码 / API Key），下方副链接"切换服务器"打开服务器列表。
- "测试连接"按钮改 `LoadingButton`（自旋 `AnimatedRotation`，周期 1000 ms，参考 animation 加载模式）。

## 6. Phase 4 — 动效

按 skill §"Animation Types" 表的时长大表，统一参数：

| 场景 | Widget | 时长 / 曲线 | 备注 |
|---|---|---|---|
| 按钮按下 | `AnimatedScale(0.95→1)` | 100 ms, `Curves.easeOut` | 自带 |
| 选择 chip 状态切换 | `AnimatedContainer(decoration)` | 200 ms, `Curves.easeInOut` | 见 5.2 |
| sheet 进出场 | `showModalBottomSheet` | 250 ms | Material 默认 |
| 页面 push | `CupertinoPageRoute` 滑入 | 250 ms | Cupertino 默认 |
| Tab 切换 | `AnimatedSwitcher` | 200 ms, `Curves.easeInOut` | |
| Hero 转场（封面 ↔ 详情） | `Hero(tag: 'cover-'+candidateId)` | 自带 300 ms | 加 `flightShuttleBuilder` 防突变 |
| 数字滚动 | `TweenAnimationBuilder<double>` | 350 ms | 见 5.1 |
| 加载 spinner | `AnimatedRotation` (controller.repeat) | 1000 ms | 见 5.7 |
| toast / snackbar | `AnimatedSlide` (`Offset(0,1) → (0,0)`) | 250 ms | M3 默认 |

**禁止**：
- 不引第三方动画库（skill 立场也倾向自带）。
- 不在 `Opacity` 上做动画 — skill §"Performance" 警告过，但在这里强调：列表项淡入用 `AnimatedOpacity`，列表**滚动**期间禁动画。

## 7. Phase 5 — 优化与可达性

### 7.1 性能（按 `performance-optimization.md`）

每页都要做的"四个隔离"：

| 列表 | 隔离手段 |
|---|---|
| 候选行封面 | `RepaintBoundary`（一行一个） |
| 候选行进度条 / 状态色块 | `RepaintBoundary`（一行一个） |
| 活动页 job 行的进度条 | 同上 |
| 详情页大封面 | `RepaintBoundary` + `Hero` flight 加 `RepaintBoundary` |

`const` 纪律：

- 所有新组件的构造函数必须 `const`。
- 所有常量 widget（图标 / `SizedBox(height: 16)` / `Gap`）一律 `const`。
- ThemeData 在 `main.dart` 内只构造一次，传给 `MaterialApp`。

`ListView.builder` 纪律：

- 候选 / 活动 / 已下载三类长列表统一 `ListView.builder`。
- `key: ValueKey(item.id)`（已有）。
- `itemExtent` 在已知高度的卡片用 `itemExtent: 96` 减少布局（参考 skill §"Item Extent Caching"）。

避免重绘：

- `setState` 只包叶子节点；data → `_DataOf.build` 的两段切分（按 skill §"Rendering Performance" 改写 GoodCounter 思路）。
- 不在 build 里 `await`；不在 build 里 new `AnimationController`。

资源：

- 大封面长宽 60x84 用 `cacheWidth / cacheHeight` 解码 — 走 M2 已落地的 `ThumbnailImage`。
- 不引第三方 icon 包；用 `Material Icons` + 自带 `lucide_icons`（若需要）。

### 7.2 可达性（按 skill §"Accessibility (Required)"）

- 每个交互 widget 必须有 `Semantics(label, button: ..., role: ...)`（已有的 `IconButton` 已含，但 `ListTile.onTap` 必须加）。
- `LiveStatusBanner` 已含 status role；新 `EmptyState` 也加 `Semantics(liveRegion: true)`。
- 对比度：`ToneChip` 的 foreground/background 必须 ≥ 4.5:1；写一个 widget test 截图后断言（在 M7 验收里）。
- 字号：`MediaQuery.textScaleFactor` 自然放大；不要 hard-code 高度写死。
- 触达目标：所有 `IconButton` 至少 48×48 dp；用 `materialTapTargetSize: MaterialTapTargetSize.padded` 全局开。

### 7.3 响应式（按 skill §"Layout Patterns"）

`EhBreakpoints`：

```dart
abstract final class EhBreakpoints {
  static const compact = 600.0;        // 手机竖屏（默认）
  static const medium = 840.0;         // 大手机横 / 平板
  static const expanded = 1200.0;      // 平板横 / 桌面
}
```

- < 600 sp：M3 NavigationBar 四 tab；详情大封面 100% 宽。
- 600–840 sp：候选 / 已下载切 2 列；详情大封面 60% 居中。
- ≥ 840 sp：候选 / 已下载切 3 列 grid；详情大封面居中 60% + sticky 操作卡。

`LayoutBuilder` 用法（按 widget-patterns §"Layout Patterns"）：

```dart
@override
Widget build(BuildContext context) => LayoutBuilder(
  builder: (context, c) {
    final int cols = c.maxWidth >= EhBreakpoints.expanded ? 3
                   : c.maxWidth >= EhBreakpoints.medium   ? 2 : 1;
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: 4 / 5,
        mainAxisSpacing: EhSpacing.l, crossAxisSpacing: EhSpacing.l,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => RepaintBoundary(key: ValueKey(items[i].id), child: CandidateCard(item: items[i])),
    );
  },
);
```

### 7.4 动效顺滑度（60 fps 验收）

- 写 widget test 在 `tester.pump(Duration(milliseconds: 16))` × N 帧扫一遍；
- 关键页（候选 / 详情 / 设置 Rail）配 `flutter test --profile` 跑黄金截图（`goldens/`）。

## 8. 阶段切分（与提案 / 文档同步）

按 AGENTS.md"一期 = 一 commit" 拆 4 个 sub-PR，全部落在 M7 名下：

- **M7-A: 主题与组件库**（1 PR）
  - `lib/ui/theme.dart` + `lib/ui/widgets/*` 新增 12 件
  - 旧 `status_chip.dart` 删除并迁移
  - widget test：12 件各 1 条 + 主题切换 1 条 + 黄金截图 1 张
  - 文档：`AgentHelp/M7_UI_REDESIGN_PROPOSAL.md`（本文件）

- **M7-B: 七页重写**（1 PR）
  - `dashboard / candidates / activity / downloaded / candidate_detail / settings / login` 全部重写
  - widget test：每页 1 黄金 + 2 交互

- **M7-C: 多服务器数据层 + 迁移**（1 PR）
  - `lib/state/server_store.dart` + `AppState` 改造
  - 启动迁移 `ehbot.settings` → `ehbot.servers[0]`
  - widget test：迁移 + 多 profile bootstrap + 单 profile 直登录

- **M7-D: 动效与响应式打磨**（1 PR）
  - 全局 `RepaintBoundary` 到位
  - 三断点 layout 跑通
  - 黄金截图全数通过

## 9. 备选（否决）

| 备选 | 否决理由 |
|---|---|
| 搬 WEBUI `ui.css` | CSS + HTMX 不可移植，且桌面表单与移动表单范式不一致 |
| 引 third-party design system (Shadcn-Flutter 等) | 多一份 runtime + 学习曲线；自写 12 件已足够 M3 默认 |
| 引第三方动画库 (rive / flutter_animate / lottie) | 自带 + skill §"Animation Types" 已够 |
| 改 Bloc / Riverpod | M7 不动业务架构；M8 再讨论 |
| 一次性整页推 | 与"小步快跑"冲突；拆 4 个 sub-PR |

## 10. 后端 / 客户端状态影响

- API：不变；UI 重构只动前端。
- 存储：`SharedPreferences` 新加 `ehbot.servers`（JSON 数组）、`ehbot.active_server_id`、`ehbot.theme`。
- Token：单服务器 token 仍在 `flutter_secure_storage`，按 active server 隔离（实现留到 M8-A）。
- 启动迁移：M6 之前装的 `ehbot.settings` 在 v0.2.0 启动时一次性迁到 `ehbot.servers[0]`，老用户**无感升级**。

## 11. 测试计划（具体可数）

- 组件级（widget test，含黄金）：
  - `ToneChip` 5 色 × 2 主题 × 1 = 10
  - `EhCard` 3 tone × 2 主题 = 6
  - `CoverThumb` 三态（正常 / 失败 / 占位）= 3
  - `EmptyState` 主 / 副标按钮可见 = 1
  - `SectionHeader` 含 count badge = 1
  - `LargeTitleAppBar` 大 / 中形态 = 2
  - 主题切换（system → light → dark）不丢态 = 1
  - `LayoutBuilder` 三断点视觉黄金 = 3 张
  - **小计 ~30**
- 页面级：
  - dashboard：候选 chip 点击跳候选 + 数字卡动效 = 2
  - candidates：搜索提交 + tab 切 + 筛选 sheet = 3
  - candidate_detail：主按钮触发 snackbar + sticky 不挡 scroll = 2
  - activity：SegmentedButton 三段切换 = 1
  - settings：NavigationRail / Drawer 二形态 = 2
  - 多服务器：新增 / 切换 / 删除 / 切换触发 logout = 4
  - **小计 ~14**
- 总增量估 **`+44 cases`** → 基线从 `M6 = 105` 升到 **`M7-D ≈ 149 tests / 0 failed`**。

## 12. 验收

- `flutter analyze`：0 告警。
- `flutter test`：M6 基线 105 + M7 增量 44 = 149 全绿。
- `flutter test --update-goldens`：`goldens/` 收齐 3 断点 × 关键页。
- 端到端：运营者用自己部署的后端做真机回归（无真机/模拟器在本开发机）。

## 13. 风险 / 已知限制

- 本开发机无 `/dev/kvm` / 真机 — UI 重构只能靠 widget test + 黄金 + 视觉；端到端等运营者。
- Material 3 主题在 Flutter 3.47.6 是默认 GA；若 minor 升级后 API 变动，**先**按 `flutter --version` 对齐再改。
- 旧 widget 的 widget test 需重写（M6 的 `'dashboard-chip-...'`、`'detail-action-...'` 等 ValueKey 名称保留以免误改外部契约）。
- 多服务器 + token 隔离在 M7-C 不重写 token 流；M8-A 才扩展 `flutter_secure_storage` 索引。