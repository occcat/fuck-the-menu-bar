# Liquid Glass 重构 & 存量问题清单

> 分支：`feature/liquid-glass-refactor` · 基线：`main@c23f699`
>
> 目标：让 UI 贴合 Apple macOS 26（Tahoe）的 Liquid Glass 设计语言，同时盘点存量问题并分阶段逐个解决。
> 本文档是计划的"单一事实来源"，每个阶段合入后在此勾选。

## 0. 设计原则（Liquid Glass 落地口径）

| 原则 | 在本项目中的含义 |
|------|------------------|
| 原生优先 | macOS 26 + Xcode 26 SDK 下使用 `glassEffect(_:in:)` / `GlassEffectContainer`；旧系统 / 旧 SDK 自动回退到 Material + 高光描边（`SharedUI/LiquidGlass.swift`） |
| 玻璃只用于"浮在内容之上的控件层" | 收纳气泡、遮罩高光、（后续）设置页侧栏/工具栏；列表行内部不叠玻璃，避免 glass-on-glass |
| 同心圆角 | 内层圆角 = 外层圆角 − 内边距（气泡 24 → 行 16 → 图标底 9），由 `ShelfBubbleMetrics` 统一计算 |
| 从控件中"长"出来 | 气泡以状态栏图标为锚点缩放展开 / 收起 |
| 尊重辅助功能 | 减少动态效果 → 仅淡入淡出；减少透明度 → 回退路径使用不透明背景；原生玻璃由系统自行适配 |
| 动效 token 化 | `LiquidMotion` 统一时长 / 弹簧参数，窗口收缩时机与动画时长绑定 |

## 1. 存量问题清单

严重度：P0 = 功能错误/可见缺陷，P1 = 体验或健壮性问题，P2 = 技术债/文档。

### Overlay（本 PR 已处理 ✅）

| # | 级别 | 问题 | 位置 | 处理 |
|---|------|------|------|------|
| O1 | P0 | 气泡高度按行高 48pt 计算，但实际行高为 56pt（图标 24 + padding 8×2 + 行 padding 8×2），导致背景溢出 `bubbleFrame`，点击气泡边缘会被判定为"外部点击"而直接收起 | `MenuBarOverlayController` | ✅ 行高由 `ShelfBubbleMetrics.rowHeight` 强制约束，气泡 frame 显式设置宽高 |
| O2 | P0 | 高度最多按 5 行计算，但 `VStack` 渲染全部条目，>5 项时被窗口裁切且不可达 | 同上 | ✅ 超过 5 项时改为内部 `ScrollView` |
| O3 | P1 | 非激活面板中的 `MouseClickCaptureView` 未实现 `acceptsFirstMouse`，首击可能被吞 | 同上 | ✅ 返回 `true` |
| O4 | P1 | `hitTest` 直接用父视图坐标判断 `bounds.contains`，在非零 origin 时会误判；`mouseUp` 不判断是否仍在行内（拖出后松手也触发） | 同上 | ✅ 坐标转换 + 松手位置校验 |
| O5 | P1 | 收起时窗口在 `max(animationDuration, 0.18)` 后缩回，但动画是固定 `response: 0.28` 的弹簧，与"动画时长"设置脱钩，收起动画被截断 | 同上 | ✅ 动画与收缩延迟均来自 `LiquidMotion`，并在收起期间沿用旧布局几何 |
| O6 | P1 | 无 hover / 按下反馈；缺少 VoiceOver 按钮语义 | 同上 | ✅ 跟踪区 hover、按压回弹、`isButton` trait + 默认 action |
| O7 | P2 | 缺失图标时显示 "❌" emoji | 同上 | ✅ 改用 SF Symbol `app.dashed` |
| O8 | P2 | 未适配 Liquid Glass：`ultraThinMaterial` + 手绘描边 + 阴影 | 同上 | ✅ 原生 `glassEffect`，回退保留近似效果 |
| I1 | P0 | 真实点击后恢复光标时用 `NSScreen.main`（键窗口所在屏）高度翻转坐标；CG 全局坐标基于主显示器（`NSScreen.screens[0]`），多显示器时光标会跳到错误位置 | `DefaultMenuBarInteractionRouter` | ✅ 改用 `NSScreen.screens.first` |
| C1 | P1 | CI 仅使用 Xcode 16.3，无法编译/验证 macOS 26 原生玻璃路径 | `.github/workflows/ci.yml` | ✅ 新增 `macos-26` 任务；旧任务继续验证回退路径 |
| T1 | P2 | Overlay 模块无任何测试 | `Tests/` | ✅ 新增 `OverlayTests`（几何与动效 token） |

### 设置页 / AppShell（Phase 2，待处理）

| # | 级别 | 问题 | 计划 |
|---|------|------|------|
| S1 | P1 | 设置窗口 `backgroundColor = .clear` + 自绘 `GlassBackdrop` 渐变 + 自绘 `glassPanel`，在 macOS 26 上与系统窗口玻璃/侧栏玻璃冲突 | 改为 `NavigationSplitView` + 系统侧栏（macOS 26 自动获得 Liquid Glass 侧栏），删除 `GlassBackdrop`；`glassPanel`/`softRowBackground` 迁移到 `SharedUI.liquidGlass` |
| S2 | P1 | 卡片层层嵌套半透明背景（glass-on-glass），对比度在浅色模式下不足 | 内容区使用 `Form(.grouped)` / 不透明分组背景，玻璃只留给导航层与浮动控件 |
| S3 | P1 | `Views.swift` 单文件 45KB，混合所有页面与组件 | 拆分为 `Settings/Items`、`Settings/Appearance`、`Settings/Shortcuts`、`Settings/General`、`Onboarding`、`Components` |
| S4 | P1 | 外观页的"显示标签 / 间距"在纵向气泡改版后不再被 Overlay 消费（`showLabels`、`itemSpacing`、`stripPadding` 为死配置） | 二选一：接入气泡（标签开关 → 仅图标网格模式；间距 → 行距）或下线设置项并在迁移中保留字段 |
| S5 | P2 | `.alert(isPresented: .constant(...))` 反模式 | 改为基于 `Binding(get:set:)` 的错误状态 |
| S6 | P2 | 字体统一使用 `.rounded` 设计，偏离 macOS 26 系统字体规范 | 改用默认 SF Pro 与语义字号（`.title2`、`.headline`、`.callout`） |
| S7 | P1 | 重新扫描时调用 `NSRunningApplication.current.hide()` 隐藏自身窗口，再重开设置页，体验跳动 | 评估在后台线程直接触发 AX 扫描、仅冻结 UI 列表，不再隐藏应用 |
| S8 | P2 | 状态栏图标使用通用 SF Symbol，展开/收起只切 fill 状态 | 使用 `symbolEffect` 过渡（macOS 14+），macOS 26 下配合系统菜单栏透明外观校准 |

### Core / Persistence / Discovery（Phase 3，待处理）

| # | 级别 | 问题 | 计划 |
|---|------|------|------|
| D1 | P0? | 坐标系不统一：Discovery 同时接受 top-origin 与 bottom-origin 的 bounds（`isMenuBarCandidate` 双判定），Overlay 定位用 `rect.midY - windowFrame.minY`（底部原点算法）喂给 SwiftUI 的 top-origin `position`，Router 又把 bounds 直接当 CG 坐标使用。需要本地多显示器 + 刘海屏验证遮罩/气泡是否精确对齐 | 引入 `ScreenGeometry` 值类型，在 Discovery 边界一次性规范化为 AppKit 全局坐标，Overlay/Router 各自显式转换，并补单测 |
| D2 | P1 | `ManagedMenuBarItem` 的 `==`/`hash` 只比较 `id + rule`，快照/显示名变化不会触发 `onChange(of:)` 刷新 | 拆分"身份相等"与"内容相等"，SwiftUI 侧使用内容相等 |
| D3 | P1 | `AppSettings` 解码对顶层字段使用 `decode`（非 `decodeIfPresent`），未来新增字段时旧配置会误走 v0 迁移（与已修复的 `AppearanceSettings` 同类问题） | 全字段容错解码 + 迁移测试 |
| D4 | P1 | `VisibilityRuleKind.title` 硬编码英文 | 删除，统一使用 `localizedTitle` |
| D5 | P1 | AX 辅助函数中存在 `as!` 强转（`value as! AXUIElement?`、`as! AXValue`），遇到异常类型会崩溃 | 改为 `CFGetTypeID` 校验后转换 |
| D6 | P1 | 基于几何签名的 ID（`minX`）在图标位置变化后失配，导致 AXPress 回退到真实点击、规则丢失 | 引入次级匹配（bundleID + role + 序号）与 ID 迁移 |
| D7 | P2 | 去重键只用应用名，同一应用的多个独立菜单栏项（如多个状态图标）会被合并成一个 | 对拥有不同 AX identifier 的项不去重，或提供"展开同应用项目"开关 |

### 架构 / 工程（Phase 4，待处理）

| # | 级别 | 问题 | 计划 |
|---|------|------|------|
| A1 | P1 | 遮罩方案本质是"在图标上盖一块不透明色块"。macOS 26 菜单栏默认透明，任何色块都会显得突兀 | 调研"分隔符 NSStatusItem 推挤"方案（将被隐藏项推出可视区），遮罩仅作为回退 |
| A2 | P2 | 仓库无 `AGENTS.md`，README 克隆地址为占位符，`DiscoveryTests` 未在 README 列出 | 补充贡献者/Agent 指南，修正文档 |
| A3 | P2 | 四语言 README 与 `ARCHITECTURE.md` 需要同步本次 SharedUI/Overlay 变更 | Phase 2 合入时一并同步，避免多次重复改动 |

## 2. 分阶段计划

### Phase 1 — Overlay 液态玻璃 + 正确性修复（本 PR）

- [x] 新增 `SharedUI/LiquidGlass.swift`：`liquidGlass(_:in:interactive:)`、`liquidGlassHighlight(in:)`、`LiquidGlassGroup`、`LiquidMotion`
- [x] 收纳气泡改为原生玻璃 + 同心圆角 + 以状态栏图标为锚点的展开动效
- [x] 遮罩改为胶囊形，不透明底 + 玻璃高光（遮挡能力不变）
- [x] 修复 O1–O7、I1
- [x] CI 双轨（Xcode 16.3 回退路径 / Xcode 26 原生路径）
- [x] `OverlayTests`

**本地验收清单（需在真机上完成，PR 中回填结果）**

1. `swift run FixtureMenuExtras` 注入假图标，再 `swift run fuck-the-menu-bar`
2. 将 ≥6 个图标设为"隐藏到收纳栏"：气泡最多显示 5 行且可滚动；点击气泡上下边缘不会误收起
3. 气泡从状态栏图标处缩放展开、收起动画完整不被截断；"动画时长"滑块改变后展开/收起速度随之变化
4. 悬停行有高亮与箭头，按下有回弹；面板未激活时首次点击即可触发
5. 系统设置 → 辅助功能 → 显示：开启"减少动态效果"仅淡入淡出；开启"降低透明度"（macOS 14/15）气泡为不透明背景
6. macOS 26：气泡为原生 Liquid Glass；macOS 14/15：为 Material 近似效果
7. 双显示器：在副屏触发"仅真实点击"项目后，光标回到原位置

### Phase 2 — 设置页与引导页 Liquid Glass 化（S1–S8、A3）

1. 拆分 `Views.swift`（纯移动，不改行为）→ 单独 PR，便于 review
2. 引入 `NavigationSplitView`，删除 `GlassBackdrop` 与窗口透明设置
3. `glassPanel` / `softRowBackground` 替换为 `SharedUI.liquidGlass`，内容区改为分组表单
4. 处理死配置（S4），与产品确认取舍
5. 同步四语言 README 与 `ARCHITECTURE.md`

### Phase 3 — 数据与坐标健壮性（D1–D7）

1. 先写坐标系单测锁定现状，再引入 `ScreenGeometry` 规范化（D1）
2. 解码容错 + 迁移测试（D3）
3. AX 安全转换（D5）、ID 稳定性（D6）、去重策略（D7）、相等性拆分（D2）、本地化清理（D4）

### Phase 4 — 隐藏机制演进（A1、A2）

1. 原型验证分隔符推挤方案的可行性与系统兼容性
2. 补齐 `AGENTS.md` 与文档

## 3. 兼容性说明

- 最低系统仍为 macOS 14；原生玻璃代码由 `#if compiler(>=6.2)` + `#available(macOS 26.0, *)` 双重保护，Xcode 16.x 可继续编译。
- 配置文件格式无变化，无需迁移。
- Overlay 的公开 API（`MenuBarOverlayController.update/hide/temporarilyReveal`）签名未变。
