# Architecture

> MenuBarShelf (**fuck-the-menu-bar**) internals.

---

## High-Level Overview (ASCII)

```
                          macOS Menu Bar
                 ┌──────────────────────────────┐
                 │  [Apple][App Menus]  [icons]  │
                 └──────────┬───────────────────┘
                            │ AX API + CGWindowList
                            ▼
          ┌─────────────────────────────────────────┐
          │              Discovery                  │
          │  SystemMenuBarDiscoveryService           │
          │  (scan every 5 s, cache background       │
          │   snapshots, merge dual-channel)         │
          └─────────────────┬───────────────────────┘
                            │ [MenuBarItemDescriptor]
                            ▼
          ┌─────────────────────────────────────────┐
          │              Identity                   │
          │  MenuBarIdentityBuilder                 │
          │  (AX Identifier → title → geometry sig) │
          └─────────────────┬───────────────────────┘
                            │ stable ID per icon
                            ▼
     ┌──────────────────────────────────────────────────┐
     │                  AppModel                        │
     │  (coordinator: settings, permissions, overlay)   │
     │  merges rules + descriptors → ManagedMenuBarItem │
     └────────┬─────────────┬──────────────┬────────────┘
              │             │              │
              ▼             ▼              ▼
   ┌──────────────┐ ┌─────────────┐ ┌─────────────────┐
   │ LayoutEngine │ │  Snapshot   │ │  Interaction     │
   │ (tri-split)  │ │  Provider   │ │  Router          │
   │ visible /    │ │ (CGDisplay  │ │ (AXPress or      │
   │ masked /     │ │  capture)   │ │  CGEvent click)  │
   │ shelf        │ │             │ │                  │
   └──────┬───────┘ └──────┬──────┘ └────────┬─────────┘
          │                │                 │
          └────────────────┼─────────────────┘
                           ▼
          ┌─────────────────────────────────────────┐
          │              Overlay                    │
          │  MenuBarOverlayController               │
          │  (NSPanel: frosted mask + shelf strip)  │
          └─────────────────────────────────────────┘
```

---

## Module Dependency Graph (Mermaid)

```mermaid
graph TD
    Core["Core<br/><i>Models, Protocols, AXCache, Identity</i>"]

    Localization["Localization<br/><i>L10n, .strings (en/zh-Hans/zh-Hant/ja)</i>"]
    Persistence["Persistence<br/><i>FileSettingsStore, v0 migration</i>"]
    Permissions["Permissions<br/><i>AX / ScreenRecording / LaunchAtLogin</i>"]
    Hotkey["Hotkey<br/><i>Carbon EventHotKey</i>"]
    Discovery["Discovery<br/><i>AX + CGWindowList dual-scan</i>"]
    LayoutEngine["LayoutEngine<br/><i>Tri-partition layout</i>"]
    Overlay["Overlay<br/><i>NSPanel overlay + interaction router</i>"]
    SharedUI["SharedUI<br/><i>Cross-module UI (HotkeyFormatter)</i>"]

    AppShell["AppShell<br/><i>App entry, AppDelegate, SwiftUI views</i>"]
    FixtureMenuExtras["FixtureMenuExtras<br/><i>Dev-only fake menu bar icons</i>"]

    Localization --> Core
    Persistence --> Core
    Permissions --> Core
    Hotkey --> Core
    Hotkey --> Localization
    Discovery --> Core
    Discovery --> Localization
    LayoutEngine --> Core
    Overlay --> Core
    Overlay --> LayoutEngine
    Overlay --> Localization
    SharedUI --> Core
    SharedUI --> Localization

    AppShell --> Core
    AppShell --> Localization
    AppShell --> Persistence
    AppShell --> Permissions
    AppShell --> Hotkey
    AppShell --> Discovery
    AppShell --> LayoutEngine
    AppShell --> Overlay
    AppShell --> SharedUI

    style Core fill:#2d333b,stroke:#539bf5,stroke-width:2px,color:#adbac7
    style AppShell fill:#2d333b,stroke:#e5534b,stroke-width:2px,color:#adbac7
    style FixtureMenuExtras fill:#2d333b,stroke:#636e7b,stroke-dasharray:5 5,color:#768390
```

> **Reading direction**: arrow means "depends on". `AppShell` depends on everything; `Core` depends on nothing.

---

## Data Flow (Mermaid Sequence)

```mermaid
sequenceDiagram
    participant Timer as Timer (5 s)
    participant Disc as Discovery
    participant AX as Accessibility API
    participant WS as CGWindowList
    participant IDBuilder as IdentityBuilder
    participant Model as AppModel
    participant LE as LayoutEngine
    participant Snap as SnapshotProvider
    participant OC as OverlayController
    participant Panel as NSPanel

    Timer->>Disc: rescan()
    par Dual-channel scan
        Disc->>AX: AXUIElementCopyAttributeValue (AXExtrasMenuBar, AXMenuBar)
        AX-->>Disc: [AXUIElement]
    and
        Disc->>WS: CGWindowListCopyWindowInfo
        WS-->>Disc: [{ownerPID, bounds, ...}]
    end

    Disc->>IDBuilder: stableID(from: ItemIdentitySeed)
    IDBuilder-->>Disc: "com.example.app#identifier"

    Disc->>Disc: merge(ax, ws) — AX preferred, WS fills gaps
    Disc-->>Model: onItemsDidChange([MenuBarItemDescriptor])

    Model->>Model: apply VisibilityRule per item → [ManagedMenuBarItem]
    Model->>LE: computeLayout(input)
    LE-->>Model: MenuBarLayoutResult {visible, masked, shelf}

    Model->>Snap: snapshot(for: item)
    Snap->>Snap: CGDisplayCreateImage or placeholder
    Snap-->>Model: ManagedItemSnapshot

    Model->>OC: update(layout, appearance, ...)
    OC->>Panel: setFrame + orderFrontRegardless
    Panel-->>Panel: SwiftUI OverlayRootView renders mask + shelf strip
```

---

## Pipeline: Discovery to Interaction

```mermaid
flowchart LR
    A["1. Discover<br/>AX + CGWindow"] --> B["2. Identify<br/>stableID()"]
    B --> C["3. Layout<br/>tri-partition"]
    C --> D["4. Render<br/>NSPanel overlay"]
    D --> E["5. Interact<br/>AXPress / CGEvent"]

    style A fill:#347d39,stroke:#57ab5a,color:#fff
    style B fill:#347d39,stroke:#57ab5a,color:#fff
    style C fill:#347d39,stroke:#57ab5a,color:#fff
    style D fill:#347d39,stroke:#57ab5a,color:#fff
    style E fill:#347d39,stroke:#57ab5a,color:#fff
```

| Stage | Module | Input | Output | Key Implementation |
|-------|--------|-------|--------|-------------------|
| **1. Discover** | `Discovery` | Running apps, screen geometry | `[MenuBarItemDescriptor]` | `scanAccessibilityItems()` enumerates `AXExtrasMenuBar` / `AXMenuBar` with recursive child traversal (depth 2); `scanWindowServerCandidates()` calls `CGWindowListCopyWindowInfo`; results merged with AX-preferred strategy |
| **2. Identify** | `Core` | `ItemIdentitySeed` | Stable `String` ID | Priority: AX Identifier > title > geometry signature (`minX:width:height`). Enables persistent rules even when icon positions shift |
| **3. Layout** | `LayoutEngine` | `[ManagedMenuBarItem]` + rules + hidden order | `MenuBarLayoutResult` | Items sorted by screen X. Three buckets: `alwaysVisible` (untouched), `hiddenInBar` + `alwaysHidden` (masked), `hiddenInBar` (shelf). Shelf respects user drag-order |
| **4. Render** | `Overlay` | Layout result + appearance settings | On-screen NSPanel | Borderless `NSPanel` at `.statusBar` level, spans full screen width x 96 pt. Masked items get `.ultraThinMaterial` rounded rectangles. Shelf strip is a `Capsule` with `HStack` of `ShelfItemView`s, each showing pixel snapshot or SF Symbol fallback |
| **5. Interact** | `Overlay` | User tap on shelf item | Menu bar action triggered | `DefaultMenuBarInteractionRouter` routes by `ProxyInteractionMode`: `proxyPreferred` tries `AXUIElementPerformAction(kAXPressAction)` first (cached, then re-scanned), falls back to synthesized `CGEvent` mouse click |

---

## Module Details

### Core

Foundation types shared by every module. Zero dependencies.

| Type | Role |
|------|------|
| `MenuBarItemDescriptor` | Value type describing a single menu bar icon (bounds, bundle ID, capabilities, discovery source) |
| `VisibilityRule` / `VisibilityRuleKind` | Per-item user preference: `alwaysVisible`, `hiddenInBar`, `alwaysHidden` |
| `ProxyInteractionMode` | How clicks are routed: `proxyPreferred`, `revealBeforeAction`, `realClickOnly` |
| `AppSettings` | Top-level config container with schema version, rules, appearance, hotkey, language |
| `MenuBarIdentityBuilder` | Deterministic stable-ID generator from `ItemIdentitySeed` |
| `AXElementCache` | `nonisolated(unsafe)` singleton cache mapping item IDs to live `AXUIElement` refs for fast re-press; thread-safe via `NSLock` |
| `ManagedMenuBarItem` | Composite: descriptor + rule + optional snapshot. Primary UI data source |
| `MenuBarLayoutInput` / `MenuBarLayoutResult` | Layout engine I/O |

### Discovery

Dual-channel menu bar scanner running on a 5-second `Timer`. Fresh scan results are only published while the application is in the background. When the app is active, the settings UI keeps showing the last background snapshot instead of replacing it with foreground-biased results. Manual refresh from settings performs a controlled background scan by briefly hiding the app, then reopening settings with the refreshed snapshot.

- **AX channel**: Iterates all running applications via `NSWorkspace.shared.runningApplications`, creates `AXUIElementCreateApplication`, reads `AXExtrasMenuBar` and `AXMenuBar`, recursively walks children (depth 2), filters by `isLikelyMenuBarItem(bounds:)` (top-of-screen heuristic +-4 to 40 pt).
- **Window Server channel**: `CGWindowListCopyWindowInfo` with on-screen-only filter, width 10..180 pt guard.
- **Merge strategy**: Window Server items indexed first; AX items overwrite or fill gaps. Capabilities union-merged (`canPerformPress` OR'd, `requiresRealHitTarget` AND'd). Final list sorted left-to-right by `bounds.minX`.

### LayoutEngine

Pure function: `computeLayout(input:) -> MenuBarLayoutResult`.

```
┌──────────┬──────────────────────┬───────────────┐
│ visible  │       masked         │    shelf      │
│ (passed  │  (frosted overlay    │ (shown in     │
│  through)│   hides these)       │  capsule bar) │
└──────────┴──────────────────────┴───────────────┘
```

- `visible` = items with rule `.alwaysVisible`
- `masked` = items NOT `.alwaysVisible` (both `.hiddenInBar` and `.alwaysHidden` get the frosted mask)
- `shelf` = items with rule `.hiddenInBar` only, sorted by user's explicit `hiddenOrder`, fallback by screen X

### Overlay

Three co-located types in the `Overlay` module:

1. **`MenuBarOverlayController`** — Manages a borderless `NSPanel` at `.statusBar` window level. Panel spans full screen width, 96 pt tall, positioned at top. Contains SwiftUI `OverlayRootView` via `NSHostingView`. Renders frosted mask rectangles over hidden items and an expandable shelf strip capsule. Supports `temporarilyReveal(itemID:)` for brief reveal animations.

2. **`MenuBarSnapshotProvider`** — Captures pixel snapshots of menu bar icons via `CGDisplayCreateImage`. Cache keyed by item ID with geometric + permission signature. Falls back to SF Symbol placeholder when Screen Recording is unavailable.

3. **`DefaultMenuBarInteractionRouter`** — Implements `MenuBarInteractionRouterProtocol`. Three strategies:
   - `proxyPreferred`: Try `AXUIElementPerformAction("AXPress")` from cache, re-scan on miss, fall back to real click
   - `revealBeforeAction` / `realClickOnly`: Synthesize `CGEvent` mouse down + mouse up at item midpoint

### Persistence

`FileSettingsStore` reads/writes `AppSettings` as pretty-printed JSON.

- **Default path**: `~/.config/fuck-the-menu-bar/settings.json`
- **Legacy path**: `~/Library/Application Support/MenuBarShelf/settings.json` (auto-detected for migration)
- **Schema migration**: Attempts v1 decode first; falls back to `LegacyAppSettingsV0` (maps `itemOrder` to `hiddenOrder`)

### Permissions

`PermissionCoordinator` wraps three macOS permission APIs:

| Permission | API | Purpose |
|------------|-----|---------|
| Accessibility | `AXIsProcessTrusted()` / `AXIsProcessTrustedWithOptions()` | Item enumeration & AXPress |
| Screen Recording | `CGPreflightScreenCaptureAccess()` / `CGRequestScreenCaptureAccess()` | Icon pixel capture |
| Launch at Login | `SMAppService.mainApp` | Login item registration |

Returns `PermissionSnapshot` — a frozen value type consumed by UI and decision logic.

### Hotkey

`GlobalHotkeyMonitor` registers a system-wide hotkey via Carbon `RegisterEventHotKey`.

- Signature: `0x4D425348` ("MBSH")
- Default: keyCode 46 (`M`), modifiers `cmdKey | optionKey` = `Cmd+Opt+M`
- `update(configuration:handler:)` unregisters previous, installs new `EventTypeSpec` + hot key
- Handler closure calls `AppModel.toggleReveal()`

### Localization

`LocalizationController` (singleton, `ObservableObject`) switches between bundled `.lproj` resources at runtime.

- Supported: `en`, `zh-Hans`, `zh-Hant`, `ja`
- `L10n.string(_:)` / `L10n.format(_:_:)` — convenience static API
- Language change triggers `objectWillChange` → all subscribed SwiftUI views re-render

### SharedUI

Cross-module UI utilities. Currently contains `HotkeyFormatter` for displaying human-readable key combinations in the settings UI.

### AppShell

Application entry point and coordination hub.

- **`AppDelegate`** — `NSApplicationDelegate`, creates `NSStatusItem`, wires `AppModel`
- **`StatusItemController`** — Manages the status bar button (the `≡` toggle)
- **`SettingsWindowController`** — Hosts the SwiftUI settings window
- **`AppModel`** — `@MainActor ObservableObject`, the central coordinator:
  - Owns instances of all service types
  - Reacts to `onItemsDidChange` from Discovery
  - Drives layout computation and overlay updates
  - Persists settings on every mutation
  - Manages hotkey registration lifecycle
  - Handles permission refresh on app/session activation

### FixtureMenuExtras

Standalone executable (`swift run FixtureMenuExtras`) that injects 4-5 fake `NSStatusItem` icons into the menu bar. Used during development to test Discovery and Layout without real third-party apps.

---

## Threading Model

| Context | Guarantee |
|---------|-----------|
| `AppModel`, all service types | `@MainActor` |
| `AXElementCache` | `nonisolated(unsafe) static let shared` — thread-safe via `NSLock` |
| `LocalizationController` | `nonisolated(unsafe) static let shared` — reads on main, apply on main |
| Discovery timer | `Timer.scheduledTimer` on main run loop (5 s interval), rescans dispatch back to `@MainActor`; fresh results are published only while app is inactive, with a cached background snapshot shown while active |
| Hotkey handler | Carbon event handler calls closure on main thread |
| Model types (`AppSettings`, `MenuBarItemDescriptor`, etc.) | `Sendable` value types |

The entire app runs on the main actor. No background queues, no concurrent data access (except `AXElementCache` which uses `NSLock` for thread safety after being decoupled from `@MainActor`). This is deliberate: Accessibility APIs (`AXUIElement*`) and AppKit UI must run on the main thread, and the workload (scanning ~50 items every 5 seconds) is trivially fast.

---

## Configuration Schema

```
settings.json (schemaVersion: 1)
├── rules: { [itemID]: VisibilityRule }
│   ├── itemID: String           ← MenuBarIdentityBuilder.stableID
│   ├── kind: VisibilityRuleKind ← alwaysVisible | hiddenInBar | alwaysHidden
│   ├── customName: String?      ← user-defined display name
│   └── interactionMode          ← proxyPreferred | revealBeforeAction | realClickOnly
├── hiddenOrder: [String]        ← ordered shelf item IDs
├── appearance: AppearanceSettings
│   ├── itemSpacing: 8.0
│   ├── showLabels: false
│   ├── collapsedMaskOpacity: 0.92
│   ├── animationDuration: 0.18
│   └── stripPadding: 10.0
├── hotkey: HotkeyConfiguration
│   ├── keyCode: 46 (M)
│   ├── modifiers: 2304 (Cmd+Opt)
│   └── isEnabled: true
├── preferredLanguage: AppLanguage
├── launchAtLogin: Bool
└── completedOnboarding: Bool
```

---

## Build Targets

| Target | Type | Description |
|--------|------|-------------|
| `fuck-the-menu-bar` | Executable | Main application (`AppShell`) |
| `FixtureMenuExtras` | Executable | Dev-only fake menu bar icons |
| `Core` | Library | Shared models and protocols |
| `Localization` | Library | L10n engine + bundled `.strings` |
| `Persistence` | Library | Settings JSON I/O |
| `Permissions` | Library | macOS permission wrappers |
| `Hotkey` | Library | Global hotkey registration |
| `Discovery` | Library | Menu bar item scanner |
| `LayoutEngine` | Library | Layout computation |
| `Overlay` | Library | Window overlay + interaction |
| `SharedUI` | Library | Cross-module UI helpers |
| `CoreTests` | Test | Identity builder tests |
| `LayoutEngineTests` | Test | Layout tri-partition tests |
| `PersistenceTests` | Test | Settings serialization + migration tests |
