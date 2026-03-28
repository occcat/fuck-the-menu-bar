# fuck-the-menu-bar

> **Tame your macOS menu bar with liquid glass.**

<p align="center">
  <a href="../README.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <strong>English</strong> ·
  <a href="README.ja.md">日本語</a>
</p>

---

## What Is This

Your macOS menu bar is overflowing with icons. You're done with it.

**fuck-the-menu-bar** (internal codename *MenuBarShelf*) is a pure-Swift menu bar management utility. It discovers every menu bar extra through a dual-channel approach — Accessibility API + Window Server — and lets you sweep unwanted icons into a frosted-glass "shelf" that expands on demand with a single hotkey.

```
┌──────────────────────────────────────────────────────┐
│ 🍎  File  Edit  …                 [░░ ░░ ░░]  ≡     │  ← Menu bar (icons under frosted mask)
│                                    ┌──────────┐      │
│                                    │ ☁ iCloud │      │
│                                    │ 🔒 1Pwd  │      │  ← Bubble card (expanded on demand)
│                                    │ 📶 Wi-Fi │      │
│                                    └──────────┘      │
└──────────────────────────────────────────────────────┘
```

## Features

- **Dual-channel discovery** — Combines Accessibility API (AXPress routing) with CGWindowList (Window Server) for maximum detection coverage
- **Smart deduplication** — Multiple menu bar entries from the same app are automatically merged, keeping the entry with the strongest interaction capabilities
- **Three visibility rules** — Per-icon: *Always Visible* / *Hidden in Shelf* / *Always Hidden*
- **Three interaction modes** — Proxy-first (AXPress), reveal-before-action, real-click-only
- **Left + right click** — Shelf items support both left-click activation and right-click context menus
- **App icons** — Automatically resolves app icons from `.app` bundles (CFBundleIconFile / CFBundleIconName), showing real app icons in the shelf
- **Global hotkey** — Default `⌘⌥M` (disabled by default; enable it in Settings), fully customizable key and modifier combination
- **Liquid glass UI** — Frosted masks + vertical bubble card shelf (with configurable bubble offset) + spring animations, inspired by Apple's latest design language
- **Interaction tooltips** — An info bubble next to the AX Press / Real Click badge; hover or click to see a detailed explanation of the interaction method
- **Auto-collapse on outside click** — Click anywhere outside the bubble to automatically collapse the shelf
- **Multilingual** — Simplified Chinese, Traditional Chinese, English, Japanese — switch in-app instantly
- **Persistent config** — JSON stored at `~/.config/fuck-the-menu-bar/settings.json` with automatic v0 migration
- **Launch at login** — Native macOS login item via SMAppService
- **Zero dependencies** — Pure Apple frameworks, no third-party packages

## Requirements

| Item | Requirement |
|------|-------------|
| macOS | **14.0 (Sonoma)** or later |
| Swift | 6.0+ |
| Permissions | Accessibility (required), Screen Recording (recommended) |

## Quick Start

### Build & Run

```bash
# Clone
git clone https://github.com/your-username/fuck-the-menu-bar.git
cd fuck-the-menu-bar

# Build
swift build

# Run
swift run fuck-the-menu-bar
```

### Test

```bash
swift test
```

### Fixture Helper

The project ships with a `FixtureMenuExtras` executable that injects 4–5 fake menu bar icons for development and debugging:

```bash
swift run FixtureMenuExtras
```

## Permissions

| Permission | Purpose | Required? |
|------------|---------|-----------|
| **Accessibility** | Enumerate menu bar items, trigger AXPress click routing | ✅ Yes |
| **Screen Recording** | Marks snapshot capability in discovery channel | ⬜ Optional |

On first launch, an onboarding window guides you through granting each permission. If macOS doesn't immediately reflect a permission change, tap "Refresh Status" to re-check.

## Project Structure

```
Sources/
├── Core/                 # Models, protocols, AX cache, identity builder
├── Discovery/            # Accessibility + Window Server dual-channel scanning
├── LayoutEngine/         # Visible / masked / shelf tri-partition layout
├── Overlay/              # Frosted mask window + shelf strip overlay + interaction router
├── Persistence/          # JSON config read/write + v0 migration
├── Permissions/          # AX / Screen Recording / login item coordination
├── Hotkey/               # Carbon EventHotKey global shortcut
├── Localization/         # L10n engine + .strings resource bundles
├── SharedUI/             # Cross-module UI utilities (e.g., hotkey formatter)
├── AppShell/             # App entry, AppDelegate, SwiftUI settings & onboarding
└── FixtureMenuExtras/    # Dev-only fake menu bar icon injector

Tests/
├── CoreTests/            # MenuBarIdentityBuilder stability tests
├── LayoutEngineTests/    # Layout engine partition tests
└── PersistenceTests/     # Config serialization + legacy migration tests
```

> For detailed architecture and dependency graphs, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Configuration

Default path: `~/.config/fuck-the-menu-bar/settings.json`

```jsonc
{
  "schemaVersion": 1,
  "rules": {
    "com.apple.controlcenter#wifi": {
      "itemID": "com.apple.controlcenter#wifi",
      "kind": "hiddenInBar",              // alwaysVisible | hiddenInBar | alwaysHidden
      "customName": "Wi-Fi",               // optional display name
      "interactionMode": "proxyPreferred"  // proxyPreferred | revealBeforeAction | realClickOnly
    }
  },
  "hiddenOrder": ["com.apple.controlcenter#wifi"],
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

## How It Works

1. **Discovery** — `SystemMenuBarDiscoveryService` rescans every 5 s, walking `AXExtrasMenuBar` / `AXMenuBar` of every running app via AX API, and supplementing with `CGWindowListCopyWindowInfo` for Window-Server-only items. Automatic scanning pauses while the app is in the foreground and resumes when it moves to the background
2. **Identity** — `MenuBarIdentityBuilder` produces a stable ID for each icon: prefers AX Identifier, falls back to title, ultimately uses a geometry signature
3. **Deduplication** — `AppModel` intelligently deduplicates discovered items by app name, keeping the entry with the strongest interaction capabilities (prioritizing items with user-defined rules, AXPress support, and Accessibility source)
4. **Layout** — `DefaultMenuBarLayoutEngine` partitions items into three buckets: always-visible, masked, and shelf
5. **Rendering** — `MenuBarOverlayController` floats a borderless `NSPanel` above the menu bar, overlaying frosted masks on hidden icons and rendering a vertical bubble card when expanded; clicking outside the bubble auto-collapses it
6. **Interaction** — `DefaultMenuBarInteractionRouter` first attempts an Accessibility press (AXPress) for supported items without hiding the overlay — on success, collapses immediately; on failure, hides the overlay first, then synthesizes a CGEvent mouse click after a short delay and auto-refreshes state; the shelf supports both left-click activation and right-click context menus

## Contributing

Contributions are welcome! Please fork, develop on a feature branch, and open a Pull Request.

```bash
git checkout -b feature/your-feature
# code, test
swift test
git commit -m "feat: describe your change"
git push origin feature/your-feature
```

## License

MIT — do whatever you want. See [LICENSE](../LICENSE).

---

<p align="center">
  <sub>Written in Swift 6 and rage 🖤</sub>
</p>
