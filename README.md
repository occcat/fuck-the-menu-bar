# fuck-the-menu-bar

> **用液态玻璃收纳你的 macOS 菜单栏。**

<p align="center">
  <strong>简体中文</strong> ·
  <a href="docs/README.zh-Hant.md">繁體中文</a> ·
  <a href="docs/README.en.md">English</a> ·
  <a href="docs/README.ja.md">日本語</a>
</p>

---

## 这是什么

macOS 菜单栏挤满图标，你受够了。

**fuck-the-menu-bar**（内部代号 *MenuBarShelf*）是一个纯 Swift 菜单栏管理工具。它通过 Accessibility API 与 Window Server 双通道发现所有菜单栏项目，让你把不需要时刻盯着的图标收进一个磨砂玻璃风格的「收纳栏」里，需要时一键展开、一键交互，用完即收。

```
┌──────────────────────────────────────────────────────┐
│ 🍎  File  Edit  …                 [░░ ░░ ░░]  ≡     │  ← 菜单栏（图标被磨砂遮罩覆盖）
│                                    ┌──────────┐      │
│                                    │ ☁ iCloud │      │
│                                    │ 🔒 1Pwd  │      │  ← 气泡卡片（展开时浮出）
│                                    │ 📶 Wi-Fi │      │
│                                    └──────────┘      │
└──────────────────────────────────────────────────────┘
```

## 特性

- **双通道发现** — 同时使用 Accessibility API（AXPress 路由）和 CGWindowList（Window Server），最大化检测覆盖率
- **智能去重** — 同一应用的多个菜单栏条目自动合并，保留交互能力最强的条目
- **三种可见性规则** — 每个图标可设为 *始终显示* / *隐藏到收纳栏* / *始终隐藏*
- **三种交互模式** — 优先代理点击（AXPress）、先显示再操作、仅真实点击
- **左键 + 右键** — 收纳栏中的项目同时支持左键激活和右键上下文菜单
- **应用图标** — 自动从 `.app` bundle 解析应用图标（CFBundleIconFile / CFBundleIconName），收纳栏显示真实应用图标
- **全局快捷键** — 默认 `⌘⌥M`（默认关闭，需在设置中手动启用），可自定义按键和修饰键组合
- **拖拽排序** — 设置中的收纳栏排序支持直接拖拽调整顺序，拖拽结果实时同步到气泡卡片展示顺序
- **液态玻璃 UI** — 磨砂遮罩 + 纵向气泡卡片收纳栏（支持自定义气泡偏移距离）+ 弹性动效，致敬 Apple 最新设计语言
- **交互提示** — AX Press / Real Click 徽章旁带有信息气泡，hover 或点击即可查看交互方式的详细说明
- **点击外部自动收起** — 展开收纳栏后，点击气泡外部任意区域自动折叠
- **多语言** — 简体中文、繁體中文、English、日本語，应用内切换即时生效
- **持久化配置** — JSON 格式存储在 `~/.config/fuck-the-menu-bar/settings.json`，支持 v0 格式自动迁移
- **开机自启** — 基于 SMAppService，原生 macOS 登录项
- **零依赖** — 纯 Apple 框架，无第三方依赖

## 系统要求

| 项目 | 要求 |
|------|------|
| macOS | **14.0 (Sonoma)** 或更高 |
| Swift | 6.0+ |
| 权限 | Accessibility（必需）、Screen Recording（推荐） |

## 快速开始

### 构建 & 运行

```bash
# 克隆仓库
git clone https://github.com/你的用户名/fuck-the-menu-bar.git
cd fuck-the-menu-bar

# 构建
swift build

# 运行
swift run fuck-the-menu-bar
```

### 测试

```bash
swift test
```

### 测试用 Fixture

项目附带一个 `FixtureMenuExtras` 可执行目标，会在菜单栏注入 4-5 个假图标，方便开发调试：

```bash
swift run FixtureMenuExtras
```

## 权限说明

| 权限 | 用途 | 必须？ |
|------|------|--------|
| **Accessibility** | 枚举菜单栏项目、触发 AXPress 点击路由 | ✅ 是 |
| **Screen Recording** | 用于发现通道中标记项目的截屏能力 | ⬜ 可选 |

首次启动会弹出引导窗口，引导你逐一授权。若 macOS 没有即时反映权限变更，可点击「刷新状态」手动检测。

## 项目结构

```
Sources/
├── Core/                 # 模型、协议、AX 缓存、身份构建器
├── Discovery/            # Accessibility + Window Server 双通道扫描
├── LayoutEngine/         # 可见/遮罩/收纳三分区布局计算
├── Overlay/              # 磨砂遮罩窗口 + 收纳条浮层 + 交互路由
├── Persistence/          # JSON 配置读写 + v0 迁移
├── Permissions/          # AX / Screen Recording / 登录项权限协调
├── Hotkey/               # Carbon EventHotKey 全局快捷键
├── Localization/         # L10n 多语言引擎 + .strings 资源
├── SharedUI/             # 跨模块 UI 工具（如快捷键格式化）
├── AppShell/             # 应用入口、AppDelegate、SwiftUI 设置/引导界面
└── FixtureMenuExtras/    # 开发用假菜单栏图标注入器

Tests/
├── CoreTests/            # MenuBarIdentityBuilder 稳定性测试
├── LayoutEngineTests/    # 布局引擎分区测试
└── PersistenceTests/     # 配置序列化 + 旧版迁移测试
```

> 详细架构说明与依赖图请阅读 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 配置文件

默认路径：`~/.config/fuck-the-menu-bar/settings.json`

```jsonc
{
  "schemaVersion": 1,
  "rules": {
    "com.apple.controlcenter#wifi": {
      "itemID": "com.apple.controlcenter#wifi",
      "kind": "hiddenInBar",           // alwaysVisible | hiddenInBar | alwaysHidden
      "customName": "Wi-Fi",            // 可选自定义名称
      "interactionMode": "proxyPreferred" // proxyPreferred | revealBeforeAction | realClickOnly
    }
  },
  "hiddenOrder": ["com.apple.controlcenter#wifi"],
  "appMetadata": {                         // 自动维护的应用元数据（去重显示名与 bundle ID）
    "com.apple.controlcenter#wifi": {
      "displayName": "Wi-Fi",
      "bundleID": "com.apple.controlcenter"
    }
  },
  "appearance": {
    "collapsedMaskOpacity": 1.0,
    "animationDuration": 0.18,
    "bubbleVerticalOffset": 58
  },
  "hotkey": {
    "keyCode": 46,
    "modifiers": 2304,
    "isEnabled": false
  },
  "preferredLanguage": "system",
  "launchAtLogin": false,
  "completedOnboarding": true
}
```

## 工作原理

1. **发现** — `SystemMenuBarDiscoveryService` 每 5 秒扫描一次，通过 AX API 遍历所有运行中应用的 `AXExtrasMenuBar` / `AXMenuBar`，同时通过 `CGWindowListCopyWindowInfo` 补充仅 Window Server 可见的项目。应用处于前台时会冻结当前展示列表，切到后台后立即刷新；在设置页点击「重新扫描」时，应用会短暂隐藏自己以执行一次受控后台扫描
2. **身份** — `MenuBarIdentityBuilder` 为每个图标生成稳定 ID：优先用 AX Identifier，退回标题，最终用几何签名
3. **去重** — `AppModel` 按应用名称对发现结果进行智能去重，保留交互能力最强的条目（优先保留有用户自定义规则、支持 AXPress、来自 Accessibility 通道的项目）
4. **布局** — `DefaultMenuBarLayoutEngine` 根据可见性规则将项目分为三组：始终可见、遮罩覆盖、收纳栏展示
5. **渲染** — `MenuBarOverlayController` 用一个 borderless `NSPanel` 浮在菜单栏之上，对被隐藏的图标叠加磨砂遮罩，展开时渲染纵向气泡卡片；点击卡片外部区域自动折叠
6. **交互** — `DefaultMenuBarInteractionRouter` 对支持 AXPress 的项目，先尝试通过 Accessibility 直接触发点击（无需隐藏 overlay），成功则调用 `collapseReveal()` 折叠；不支持或失败时，先折叠 overlay 再延迟合成 CGEvent 鼠标事件，交互前保存光标位置、交互后自动恢复，避免鼠标跳动；收纳栏同时支持左键激活和右键上下文菜单

## 贡献

欢迎任何形式的贡献！请先 fork，在功能分支上开发，提交 Pull Request。

```bash
git checkout -b feature/你的功能名
# 编码、测试
swift test
git commit -m "feat: 你的功能描述"
git push origin feature/你的功能名
```

## 许可证

MIT — 你爱怎么用就怎么用。详见 [LICENSE](LICENSE)。

---

<p align="center">
  <sub>用 Swift 6 和愤怒写成 🖤</sub>
</p>
