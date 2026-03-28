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
│ 🍎  File  Edit  …                 [☁ 🔒 📶]  ≡     │  ← 菜单栏（图标被磨砂遮罩覆盖）
│                              ┌─────────────────────┐ │
│                              │  ☁   🔒   📶   ⚙️  │ │  ← 收纳栏（展开时浮出）
│                              └─────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

## 特性

- **双通道发现** — 同时使用 Accessibility API（AXPress 路由）和 CGWindowList（Window Server），最大化检测覆盖率
- **三种可见性规则** — 每个图标可设为 *始终显示* / *隐藏到收纳栏* / *始终隐藏*
- **三种交互模式** — 优先代理点击（AXPress）、先显示再操作、仅真实点击
- **实时快照** — 利用 Screen Recording 权限截取菜单栏图标像素，收纳栏里看到的就是真实图标
- **全局快捷键** — 默认 `⌘⌥M`，可自定义按键和修饰键组合
- **液态玻璃 UI** — 磨砂遮罩 + 圆角胶囊收纳条 + 微动效，致敬 Apple 最新设计语言
- **收纳排序** — 支持拖拽排序和手动上下移动
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
| **Screen Recording** | 截取菜单栏图标像素作为收纳栏快照 | ⬜ 推荐 |

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
  "appearance": {
    "itemSpacing": 8,
    "showLabels": false,
    "collapsedMaskOpacity": 0.92,
    "animationDuration": 0.18,
    "stripPadding": 10
  },
  "hotkey": {
    "keyCode": 46,
    "modifiers": 2304,
    "isEnabled": true
  },
  "preferredLanguage": "system",
  "launchAtLogin": false,
  "completedOnboarding": true
}
```

## 工作原理

1. **发现** — `SystemMenuBarDiscoveryService` 每 5 秒扫描一次，通过 AX API 遍历所有运行中应用的 `AXExtrasMenuBar` / `AXMenuBar`，同时通过 `CGWindowListCopyWindowInfo` 补充仅 Window Server 可见的项目。应用处于前台时会冻结当前展示列表，切到后台后立即刷新；在设置页点击「重新扫描」时，应用会短暂隐藏自己以执行一次受控后台扫描
2. **身份** — `MenuBarIdentityBuilder` 为每个图标生成稳定 ID：优先用 AX Identifier，退回标题，最终用几何签名
3. **布局** — `DefaultMenuBarLayoutEngine` 根据可见性规则将项目分为三组：始终可见、遮罩覆盖、收纳栏展示
4. **渲染** — `MenuBarOverlayController` 用一个 borderless `NSPanel` 浮在菜单栏之上，对被隐藏的图标叠加磨砂遮罩，展开时渲染收纳条
5. **交互** — `DefaultMenuBarInteractionRouter` 对支持 AXPress 的项目直接通过 Accessibility 触发点击，不支持的则合成 CGEvent 鼠标事件

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
