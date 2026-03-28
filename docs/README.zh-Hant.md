# fuck-the-menu-bar

> **用液態玻璃收納你的 macOS 選單列。**

<p align="center">
  <a href="../README.md">简体中文</a> ·
  <strong>繁體中文</strong> ·
  <a href="README.en.md">English</a> ·
  <a href="README.ja.md">日本語</a>
</p>

---

## 這是什麼

macOS 選單列擠滿圖示，你受夠了。

**fuck-the-menu-bar**（內部代號 *MenuBarShelf*）是一個純 Swift 選單列管理工具。它透過 Accessibility API 與 Window Server 雙通道發現所有選單列項目，讓你把不需要時刻盯著的圖示收進一個磨砂玻璃風格的「收納列」裡，需要時一鍵展開、一鍵互動，用完即收。

```
┌──────────────────────────────────────────────────────┐
│ 🍎  File  Edit  …                 [☁ 🔒 📶]  ≡     │  ← 選單列（圖示被磨砂遮罩覆蓋）
│                              ┌─────────────────────┐ │
│                              │  ☁   🔒   📶   ⚙️  │ │  ← 收納列（展開時浮出）
│                              └─────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

## 特性

- **雙通道發現** — 同時使用 Accessibility API（AXPress 路由）和 CGWindowList（Window Server），最大化偵測覆蓋率
- **三種可見性規則** — 每個圖示可設為 *永遠顯示* / *隱藏到收納列* / *永遠隱藏*
- **三種互動模式** — 優先代理點擊（AXPress）、先顯示再操作、僅真實點擊
- **即時快照** — 利用螢幕錄製權限截取選單列圖示像素，收納列裡看到的就是真實圖示
- **全域快捷鍵** — 預設 `⌘⌥M`，可自訂按鍵和修飾鍵組合
- **液態玻璃 UI** — 磨砂遮罩 + 圓角膠囊收納條 + 微動效，致敬 Apple 最新設計語言
- **收納排序** — 支援拖放排序和手動上下移動
- **多語言** — 簡體中文、繁體中文、English、日本語，App 內切換即時生效
- **持久化設定** — JSON 格式儲存於 `~/.config/fuck-the-menu-bar/settings.json`，支援 v0 格式自動遷移
- **開機自啟** — 基於 SMAppService，原生 macOS 登入項目
- **零依賴** — 純 Apple 框架，無第三方依賴

## 系統需求

| 項目 | 需求 |
|------|------|
| macOS | **14.0 (Sonoma)** 或更高 |
| Swift | 6.0+ |
| 權限 | Accessibility（必要）、Screen Recording（建議） |

## 快速開始

### 建置 & 執行

```bash
# 複製儲存庫
git clone https://github.com/你的使用者名稱/fuck-the-menu-bar.git
cd fuck-the-menu-bar

# 建置
swift build

# 執行
swift run fuck-the-menu-bar
```

### 測試

```bash
swift test
```

### 測試用 Fixture

專案附帶一個 `FixtureMenuExtras` 可執行目標，會在選單列注入 4-5 個假圖示，方便開發除錯：

```bash
swift run FixtureMenuExtras
```

## 權限說明

| 權限 | 用途 | 必須？ |
|------|------|--------|
| **Accessibility** | 列舉選單列項目、觸發 AXPress 點擊路由 | ✅ 是 |
| **Screen Recording** | 截取選單列圖示像素作為收納列快照 | ⬜ 建議 |

首次啟動會彈出引導視窗，引導你逐一授權。若 macOS 沒有即時反映權限變更，可點選「重新整理狀態」手動偵測。

## 專案結構

```
Sources/
├── Core/                 # 模型、協定、AX 快取、身份建構器
├── Discovery/            # Accessibility + Window Server 雙通道掃描
├── LayoutEngine/         # 可見/遮罩/收納三分區佈局計算
├── Overlay/              # 磨砂遮罩視窗 + 收納條浮層 + 互動路由
├── Persistence/          # JSON 設定讀寫 + v0 遷移
├── Permissions/          # AX / Screen Recording / 登入項目權限協調
├── Hotkey/               # Carbon EventHotKey 全域快捷鍵
├── Localization/         # L10n 多語言引擎 + .strings 資源
├── SharedUI/             # 跨模組 UI 工具（如快捷鍵格式化）
├── AppShell/             # 應用程式入口、AppDelegate、SwiftUI 設定/引導介面
└── FixtureMenuExtras/    # 開發用假選單列圖示注入器

Tests/
├── CoreTests/            # MenuBarIdentityBuilder 穩定性測試
├── LayoutEngineTests/    # 佈局引擎分區測試
└── PersistenceTests/     # 設定序列化 + 舊版遷移測試
```

> 詳細架構說明與依賴圖請閱讀 [ARCHITECTURE.md](ARCHITECTURE.md)。

## 設定檔

預設路徑：`~/.config/fuck-the-menu-bar/settings.json`

```jsonc
{
  "schemaVersion": 1,
  "rules": {
    "com.apple.controlcenter#wifi": {
      "itemID": "com.apple.controlcenter#wifi",
      "kind": "hiddenInBar",              // alwaysVisible | hiddenInBar | alwaysHidden
      "customName": "Wi-Fi",               // 可選自訂名稱
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

## 運作原理

1. **發現** — `SystemMenuBarDiscoveryService` 每 5 秒掃描一次，透過 AX API 遍歷所有執行中 App 的 `AXExtrasMenuBar` / `AXMenuBar`，同時透過 `CGWindowListCopyWindowInfo` 補充僅 Window Server 可見的項目。App 處於前台時自動暫停掃描，切到背景後恢復
2. **身份** — `MenuBarIdentityBuilder` 為每個圖示產生穩定 ID：優先使用 AX Identifier，退回標題，最終使用幾何簽章
3. **佈局** — `DefaultMenuBarLayoutEngine` 根據可見性規則將項目分為三組：始終可見、遮罩覆蓋、收納列展示
4. **渲染** — `MenuBarOverlayController` 用一個 borderless `NSPanel` 浮在選單列之上，對被隱藏的圖示疊加磨砂遮罩，展開時渲染收納條
5. **互動** — `DefaultMenuBarInteractionRouter` 對支援 AXPress 的項目直接透過 Accessibility 觸發點擊，不支援的則合成 CGEvent 滑鼠事件

## 貢獻

歡迎任何形式的貢獻！請先 fork，在功能分支上開發，提交 Pull Request。

```bash
git checkout -b feature/你的功能名稱
# 編碼、測試
swift test
git commit -m "feat: 你的功能描述"
git push origin feature/你的功能名稱
```

## 授權

MIT — 你愛怎麼用就怎麼用。詳見 [LICENSE](../LICENSE)。

---

<p align="center">
  <sub>用 Swift 6 和憤怒寫成 🖤</sub>
</p>
