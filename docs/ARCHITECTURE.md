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
     │  deduplicates by app name, keeps best entry      │
     └────────┬─────────────┬──────────────┬────────────┘
              │             │              │
              ▼             ▼              ▼
   ┌──────────────┐ ┌─────────────┐ ┌─────────────────┐
   │ LayoutEngine │ │  Snapshot   │ │  Interaction     │
   │ (tri-split)  │ │  Provider   │ │  Router          │
   │ visible /    │ │ (app icon   │ │ (AXPress or      │
   │ masked /     │ │  from .app  │ │  CGEvent click   │
   │ shelf        │ │  bundle)    │ │  L/R button)     │
   └──────┬───────┘ └──────┬──────┘ └────────┬─────────┘
          │                │                 │
          └────────────────┼─────────────────┘
                           ▼
          ┌─────────────────────────────────────────┐
          │              Overlay                    │
          │  MenuBarOverlayController               │
          │  (NSPanel: glass mask + glass bubble)   │
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
    SharedUI["SharedUI<br/><i>Liquid Glass design system, HotkeyFormatter</i>"]

    AppShell["AppShell<br/><i>App entry, AppDelegate, SwiftUI settings & onboarding</i>"]
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
    Overlay --> SharedUI
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
    Model->>Model: deduplicateManagedItems() — merge by app name
    Model->>LE: computeLayout(input)
    LE-->>Model: MenuBarLayoutResult {visible, masked, shelf}

    Model->>Snap: snapshot(for: item)
    Snap->>Snap: resolveIcon from .app bundle (CFBundleIconFile)
    Snap-->>Model: ManagedItemSnapshot

    Model->>OC: update(layout, appearance, ...)
    OC->>Panel: setFrame + orderFrontRegardless
    Panel-->>Panel: SwiftUI OverlayRootView renders mask + bubble card

    Note over Model,Panel: User clicks a shelf item

    alt AXPress available (proxyPreferred + canPerformPress)
        Model->>Model: tryAccessibilityPress(item) → true
        Model->>OC: collapseReveal()
    else CGEvent fallback
        Model->>Model: collapseReveal()
        Model->>Model: asyncAfter(150ms)
        Model->>Model: interactionRouter.activate(item, button) + cursor restore
    end
```

---

## Pipeline: Discovery to Interaction

```mermaid
flowchart LR
    A["1. Discover<br/>AX + CGWindow"] --> B["2. Identify<br/>stableID()"]
    B --> C["3. Dedupe<br/>by app name"]
    C --> D["4. Layout<br/>tri-partition"]
    D --> E["5. Render<br/>NSPanel overlay"]
    E --> F["6. Interact<br/>AXPress / CGEvent<br/>L+R click"]

    style A fill:#347d39,stroke:#57ab5a,color:#fff
    style B fill:#347d39,stroke:#57ab5a,color:#fff
    style C fill:#347d39,stroke:#57ab5a,color:#fff
    style D fill:#347d39,stroke:#57ab5a,color:#fff
    style E fill:#347d39,stroke:#57ab5a,color:#fff
    style F fill:#347d39,stroke:#57ab5a,color:#fff
```

| Stage | Module | Input | Output | Key Implementation |
|-------|--------|-------|--------|-------------------|
| **1. Discover** | `Discovery` | Running apps, screen geometry | `[MenuBarItemDescriptor]` | `scanAccessibilityItems()` enumerates `AXExtrasMenuBar` / `AXMenuBar` with recursive child traversal (depth 2); `scanWindowServerCandidates()` calls `CGWindowListCopyWindowInfo`; results merged with AX-preferred strategy. Empty AX titles are filtered via `nonEmptyStringAttribute()` |
| **2. Identify** | `Core` | `ItemIdentitySeed` | Stable `String` ID | Priority: AX Identifier > title > geometry signature (`minX:width:height`). Enables persistent rules even when icon positions shift |
| **3. Dedupe** | `AppShell` | `[ManagedMenuBarItem]` | Deduplicated `[ManagedMenuBarItem]` | `deduplicateManagedItems()` groups items by normalized app name (case-insensitive, trimmed). Scoring: user-defined rule (+100), `canPerformPress` (+20), AX source (+10), visibility rule weight (+2/+4). Keeps highest-scoring entry per app |
| **4. Layout** | `LayoutEngine` | `[ManagedMenuBarItem]` + rules + hidden order | `MenuBarLayoutResult` | Items sorted by screen X. Three buckets: `alwaysVisible` (untouched), `hiddenInBar` + `alwaysHidden` (masked), `hiddenInBar` (shelf). Shelf respects user drag-order |
| **5. Render** | `Overlay` | Layout result + appearance settings | On-screen NSPanel | Borderless `NSPanel` at `.statusBar` level, dynamic height based on shelf item count (44 pt collapsed, expands for bubble). Masked items get capsule-shaped opaque covers with a `liquidGlassHighlight` sheen on top, so hiding strength is unchanged. Shelf rendered as a vertical bubble card on a `liquidGlass` surface (native `glassEffect` on macOS 26 built with the Xcode 26 SDK, Material + specular rim fallback otherwise) with concentric corner radii 24 → 16 → 9 computed by `ShelfBubbleMetrics`. Rows have a fixed 48 pt height; at most 5 rows are shown and longer shelves scroll inside the bubble. The bubble scales out of the status item anchor, and its expand/collapse timing comes from `LiquidMotion` (driven by `animationDuration`, simple fades under Reduce Motion). Bubble offset from menu bar is configurable via `bubbleVerticalOffset` (default 58 pt). Global/local click monitors auto-collapse on outside click. Settings shelf order supports drag-and-drop reordering; the dragged source row is visually hidden during drag to prevent ghosting, and the final visual order is persisted directly via `setShelfOrder(_:)`, ensuring the bubble card always reflects the user's intended order |
| **6. Interact** | `Overlay` | User click on shelf item | Menu bar action triggered | `AppModel.activate()` first attempts `tryAccessibilityPress()` for left-click + `proxyPreferred` items — on success, collapses overlay via `collapseReveal()`. On failure (or right-click), collapses overlay first via `collapseReveal()`, delays 150 ms, then `DefaultMenuBarInteractionRouter.activate()` routes by `ProxyInteractionMode` and `MenuBarClickButton`: left-click tries AXPress then falls back to synthesized `CGEvent`; right-click always synthesizes `CGEvent` right-mouse-down/up at item midpoint. Cursor position is saved before CGEvent synthesis and restored via `CGWarpMouseCursorPosition` after, preventing visible cursor jumps |

---

## Module Details

### Core

Foundation types shared by every module. Zero dependencies.

| Type | Role |
|------|------|
| `MenuBarItemDescriptor` | Value type describing a single menu bar icon (bounds, bundle ID, capabilities, discovery source) |
| `VisibilityRule` / `VisibilityRuleKind` | Per-item user preference: `alwaysVisible`, `hiddenInBar`, `alwaysHidden` |
| `ProxyInteractionMode` | How clicks are routed: `proxyPreferred`, `revealBeforeAction`, `realClickOnly` |
| `MenuBarClickButton` | Which mouse button was used: `.left` or `.right` |
| `AppSettings` | Top-level config container with schema version, rules, appearance, hotkey, language, and app metadata |
| `AppMetadataEntry` | Human-readable metadata per item (`displayName`, `bundleID`), stored alongside rules for config file clarity |
| `MenuBarIdentityBuilder` | Deterministic stable-ID generator from `ItemIdentitySeed` |
| `AXElementCache` | `nonisolated(unsafe)` singleton cache mapping item IDs to live `AXUIElement` refs for fast re-press; thread-safe via `NSLock` |
| `ManagedMenuBarItem` | Composite: descriptor + rule + optional snapshot. Primary UI data source. Supports `withDisplayName(_:)` for deduplication |
| `ManagedItemSnapshot` | Snapshot with resolved app icon image and `iconFilePath` from `.app` bundle |
| `MenuBarLayoutInput` / `MenuBarLayoutResult` | Layout engine I/O |

### Discovery

Dual-channel menu bar scanner running on a 5-second `Timer`. Fresh scan results are only published while the application is in the background. When the app is active, the settings UI keeps showing the last background snapshot instead of replacing it with foreground-biased results. Manual refresh from settings performs a controlled background scan by briefly yielding activation (`NSApp.deactivate()`) — the settings window stays on screen — and re-activates settings once the refreshed snapshot is published.

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

1. **`MenuBarOverlayController`** — Manages a borderless `NSPanel` at `.statusBar` window level. Panel spans full screen width with dynamic height: 44 pt when collapsed, expanding based on shelf item count when revealed. Contains SwiftUI `OverlayRootView` via `NSHostingView`. Renders capsule-shaped opaque masks over hidden items (topped with `liquidGlassHighlight`) and a vertical Liquid Glass bubble card showing `ShelfItemRow`s with resolved app icons. Bubble geometry (48 pt rows, max 5 visible rows with internal scrolling, concentric radii 24 → 16 → 9) comes from `ShelfBubbleMetrics`; rows have hover highlight, press feedback, `acceptsFirstMouse`, and VoiceOver button traits. The bubble scales from the status item anchor; animation and the delayed frame shrink on collapse share `LiquidMotion` timing so the collapse is never clipped. Bubble vertical offset from the menu bar is driven by `appearance.bubbleVerticalOffset` (default 58 pt, range 30–120 pt), with a `minimumMenuBarClearance` ensuring the bubble never overlaps the menu bar. Registers global and local click monitors to auto-collapse when clicking outside the bubble. Supports `temporarilyReveal(itemID:)` for brief reveal animations.

2. **`MenuBarSnapshotProvider`** — Resolves app icons from `.app` bundles by reading `CFBundleIconFile` / `CFBundleIconName` / `CFBundleIcons` from `Info.plist`, then searching the bundle's `Resources` directory for `.icns`, `.png`, or `.pdf` files. Falls back to enumerating the Resources directory for any icon file. Cache keyed by item ID with bundle-ID + icon-file-path signature.

3. **`DefaultMenuBarInteractionRouter`** — Implements `MenuBarInteractionRouterProtocol`. Exposes `tryAccessibilityPress(item:) -> Bool` for callers to attempt an AXPress without hiding the overlay first. Accepts a `MenuBarClickButton` parameter (`.left` / `.right`). Saves cursor position before CGEvent synthesis and restores it via `CGWarpMouseCursorPosition` afterward (with AppKit-to-CG coordinate conversion based on the primary display `NSScreen.screens.first`), preventing visible cursor jumps during real-click interactions. Three strategies for left-click:
   - `proxyPreferred`: Try `AXUIElementPerformAction("AXPress")` from cache, re-scan on miss, fall back to real click
   - `revealBeforeAction` / `realClickOnly`: Synthesize `CGEvent` mouse down + mouse up at item midpoint
   Right-click always synthesizes `CGEvent` right-mouse-down + right-mouse-up, bypassing AXPress.

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

Cross-module UI utilities used by both `Overlay` and `AppShell`.

- **`LiquidGlass.swift`** — The Liquid Glass design system:
  - `View.liquidGlass(_:in:interactive:)` — glass surface clipped to a shape (`.regular`, `.clear`, `.tinted(Color)`)
  - `View.liquidGlassHighlight(in:)` — glass sheen above opaque content (used by the menu bar masks)
  - `LiquidGlassGroup` — groups glass surfaces so they can blend/morph (`GlassEffectContainer` on macOS 26)
  - `LiquidMotion` — motion tokens (`duration`, `spring`, `settleDuration`) derived from `animationDuration`
  - Native `glassEffect` is guarded by `#if compiler(>=6.2)` + `#available(macOS 26.0, *)`, so Xcode 16.x still builds. The fallback uses Material + a specular rim and switches to an opaque window background under "Reduce Transparency"
- **`HotkeyFormatter`** — human-readable key combinations for the settings UI

Glass is reserved for layers that float above content (shelf bubble, mask sheen, onboarding action bar); list rows and settings content never stack glass on glass.

### AppShell

Application entry point and coordination hub.

- **`AppDelegate`** — `NSApplicationDelegate`, creates `NSStatusItem`, wires `AppModel`
- **`StatusItemController`** — Manages the status bar button (the `≡` toggle). The symbol is drawn by an embedded `NSImageView` so expand/collapse can use an SF Symbols `.replace.downUp` content transition (plain swap under Reduce Motion). The image stays a template so the system tints it for the current menu bar appearance, including the transparent menu bar on macOS 26
- **`SettingsWindowController`** — Hosts the SwiftUI settings and onboarding windows as regular opaque windows (no clear background), so the system provides sidebar materials — Liquid Glass on macOS 26 (`isMovableByWindowBackground` disabled to prevent conflicts with drag-and-drop reordering)
- **SwiftUI views**:
  - `Settings/SettingsRootView` — `NavigationSplitView` with a system sidebar; error alert bound via `Binding(get:set:)`
  - `Settings/Items`, `Settings/Appearance`, `Settings/Shortcuts`, `Settings/General` — one page each, built on `Form` + `.formStyle(.grouped)` with system fonts and semantic text styles
  - `Onboarding/OnboardingRootView` — permission onboarding; the bottom action bar is the window's only glass surface
  - `Components/` — shared rows (`SettingsSection`, `SettingsRow`, `PermissionRow`, `StatusBadge`, `InfoTooltipButton`, `MenuExtraPreview`, …) and localized titles for model enums
  - The appearance page intentionally does not expose `showLabels` / `itemSpacing` / `stripPadding`: the vertical bubble does not consume them, and the fields stay in `AppearanceSettings` for config compatibility
- **`AppModel`** — `@MainActor ObservableObject`, the central coordinator:
  - Owns instances of all service types
  - Reacts to `onItemsDidChange` from Discovery
  - Deduplicates discovered items by app name via `deduplicateManagedItems()` with scoring-based selection
  - Filters out self-referencing items via `isCurrentAppItem()` (PID, bundle ID, and display name matching)
  - `activate()` uses a two-phase strategy: first attempts `tryAccessibilityPress()` (no overlay hide needed), falls back to `collapseReveal()` + delayed CGEvent with cursor save/restore
  - `rescan()` from the settings window yields activation (`NSApp.deactivate()`) instead of hiding the app, waits for the resign-active callback (or a 0.35 s timeout), runs a forced background scan, then re-opens the same settings tab
  - Populates `appMetadata` in settings during `rebuildManagedItems()` for config file readability
  - `setShelfOrder(_:)` directly persists a new shelf item order from the drag-and-drop visual state, replacing error-prone index arithmetic
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
├── appMetadata: { [itemID]: AppMetadataEntry }
│   ├── displayName: String      ← human-readable name
│   └── bundleID: String         ← source bundle identifier
├── appearance: AppearanceSettings
│   ├── collapsedMaskOpacity: 1.0
│   ├── animationDuration: 0.18
│   └── bubbleVerticalOffset: 58
├── hotkey: HotkeyConfiguration
│   ├── keyCode: 46 (M)
│   ├── modifiers: 2304 (Cmd+Opt)
│   └── isEnabled: false
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
| `SharedUI` | Library | Liquid Glass design system + cross-module UI helpers |
| `CoreTests` | Test | Identity builder tests |
| `LayoutEngineTests` | Test | Layout tri-partition tests |
| `PersistenceTests` | Test | Settings serialization + migration tests |
| `OverlayTests` | Test | Shelf bubble geometry + `LiquidMotion` token tests |
