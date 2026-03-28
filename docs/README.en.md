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
│ 🍎  File  Edit  …                 [☁ 🔒 📶]  ≡     │  ← Menu bar (icons under frosted mask)
│                              ┌─────────────────────┐ │
│                              │  ☁   🔒   📶   ⚙️  │ │  ← Shelf strip (expanded on demand)
│                              └─────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

## Features

- **Dual-channel discovery** — Combines Accessibility API (AXPress routing) with CGWindowList (Window Server) for maximum detection coverage
- **Three visibility rules** — Per-icon: *Always Visible* / *Hidden in Shelf* / *Always Hidden*
- **Three interaction modes** — Proxy-first (AXPress), reveal-before-action, real-click-only
- **Live snapshots** — Captures pixel-accurate images of menu bar icons via Screen Recording, so the shelf shows the real thing
- **Global hotkey** — Default `⌘⌥M`, fully customizable key and modifier combination
- **Liquid glass UI** — Frosted masks + rounded capsule shelf strip + subtle animations, inspired by Apple's latest design language
- **Shelf ordering** — Drag-and-drop reordering and manual up/down controls
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
swift run MenuBarShelfApp
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
| **Screen Recording** | Capture pixel snapshots of menu bar icons for the shelf | ⬜ Recommended |

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

## How It Works

1. **Discovery** — `SystemMenuBarDiscoveryService` rescans every 2 s, walking `AXExtrasMenuBar` / `AXMenuBar` of every running app via AX API, and supplementing with `CGWindowListCopyWindowInfo` for Window-Server-only items
2. **Identity** — `MenuBarIdentityBuilder` produces a stable ID for each icon: prefers AX Identifier, falls back to title, ultimately uses a geometry signature
3. **Layout** — `DefaultMenuBarLayoutEngine` partitions items into three buckets: always-visible, masked, and shelf
4. **Rendering** — `MenuBarOverlayController` floats a borderless `NSPanel` above the menu bar, overlaying frosted masks on hidden icons and rendering the shelf strip when expanded
5. **Interaction** — `DefaultMenuBarInteractionRouter` fires AXPress for supported items and synthesizes CGEvent mouse events for the rest

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
