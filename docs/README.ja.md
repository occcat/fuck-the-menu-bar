# fuck-the-menu-bar

> **リキッドグラスで macOS メニューバーを整頓しよう。**

<p align="center">
  <a href="../README.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.en.md">English</a> ·
  <strong>日本語</strong>
</p>

---

## これは何？

macOS のメニューバーがアイコンだらけ。もう、うんざりだ。

**fuck-the-menu-bar**（内部コードネーム *MenuBarShelf*）は、純 Swift 製のメニューバー管理ユーティリティです。Accessibility API と Window Server のデュアルチャネルですべてのメニューバー項目を検出し、常に表示する必要のないアイコンをフロストガラス風の「棚（シェルフ）」に収納。ホットキー一発で展開・操作・収納できます。

```
┌──────────────────────────────────────────────────────┐
│ 🍎  File  Edit  …                 [☁ 🔒 📶]  ≡     │  ← メニューバー（アイコンにフロストマスク適用）
│                              ┌─────────────────────┐ │
│                              │  ☁   🔒   📶   ⚙️  │ │  ← 棚ストリップ（展開時に表示）
│                              └─────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

## 特徴

- **デュアルチャネル検出** — Accessibility API（AXPress ルーティング）と CGWindowList（Window Server）を併用し、検出カバレッジを最大化
- **3 種類の表示ルール** — アイコンごとに *常に表示* / *棚に隠す* / *常に隠す* を設定可能
- **3 種類の操作モード** — 代理優先（AXPress）、表示してから操作、実クリックのみ
- **ライブスナップショット** — 画面収録権限でメニューバーアイコンのピクセルをキャプチャし、棚には本物のアイコンを表示
- **グローバルホットキー** — デフォルト `⌘⌥M`、キーと修飾キーの組み合わせをカスタマイズ可能
- **リキッドグラス UI** — フロストマスク ＋ 角丸カプセル型棚ストリップ ＋ 微細アニメーション。Apple 最新のデザイン言語にインスパイア
- **棚の並べ替え** — ドラッグ＆ドロップと手動の上下移動をサポート
- **多言語対応** — 簡体字中国語、繁体字中国語、English、日本語 — アプリ内で即時切り替え
- **永続化設定** — `~/.config/fuck-the-menu-bar/settings.json` に JSON 保存。v0 フォーマットからの自動マイグレーション対応
- **ログイン時起動** — SMAppService ベースのネイティブ macOS ログイン項目
- **依存ゼロ** — 純粋な Apple フレームワークのみ、サードパーティ依存なし

## 動作環境

| 項目 | 要件 |
|------|------|
| macOS | **14.0 (Sonoma)** 以降 |
| Swift | 6.0+ |
| 権限 | Accessibility（必須）、Screen Recording（推奨） |

## クイックスタート

### ビルド & 実行

```bash
# クローン
git clone https://github.com/your-username/fuck-the-menu-bar.git
cd fuck-the-menu-bar

# ビルド
swift build

# 実行
swift run fuck-the-menu-bar
```

### テスト

```bash
swift test
```

### フィクスチャヘルパー

プロジェクトには `FixtureMenuExtras` 実行ターゲットが含まれており、開発・デバッグ用にメニューバーへ 4〜5 個のダミーアイコンを注入できます：

```bash
swift run FixtureMenuExtras
```

## 権限について

| 権限 | 用途 | 必須？ |
|------|------|--------|
| **Accessibility** | メニューバー項目の列挙、AXPress クリックルーティング | ✅ はい |
| **Screen Recording** | メニューバーアイコンのピクセルスナップショット取得 | ⬜ 推奨 |

初回起動時にオンボーディングウインドウが表示され、各権限の付与を案内します。macOS が権限変更をすぐに反映しない場合は、「状態を更新」をタップして再チェックしてください。

## プロジェクト構成

```
Sources/
├── Core/                 # モデル、プロトコル、AX キャッシュ、ID ビルダー
├── Discovery/            # Accessibility + Window Server デュアルチャネルスキャン
├── LayoutEngine/         # 表示/マスク/棚の三分割レイアウト計算
├── Overlay/              # フロストマスクウインドウ ＋ 棚ストリップオーバーレイ ＋ 操作ルーター
├── Persistence/          # JSON 設定の読み書き ＋ v0 マイグレーション
├── Permissions/          # AX / Screen Recording / ログイン項目の権限調整
├── Hotkey/               # Carbon EventHotKey グローバルショートカット
├── Localization/         # L10n 多言語エンジン ＋ .strings リソースバンドル
├── SharedUI/             # クロスモジュール UI ユーティリティ（ホットキーフォーマッタなど）
├── AppShell/             # アプリエントリ、AppDelegate、SwiftUI 設定 & オンボーディング
└── FixtureMenuExtras/    # 開発用ダミーメニューバーアイコン注入ツール

Tests/
├── CoreTests/            # MenuBarIdentityBuilder 安定性テスト
├── LayoutEngineTests/    # レイアウトエンジン分割テスト
└── PersistenceTests/     # 設定シリアライゼーション ＋ レガシーマイグレーションテスト
```

> 詳細なアーキテクチャと依存グラフについては [ARCHITECTURE.md](ARCHITECTURE.md) を参照してください。

## 設定ファイル

デフォルトパス：`~/.config/fuck-the-menu-bar/settings.json`

```jsonc
{
  "schemaVersion": 1,
  "rules": {
    "com.apple.controlcenter#wifi": {
      "itemID": "com.apple.controlcenter#wifi",
      "kind": "hiddenInBar",              // alwaysVisible | hiddenInBar | alwaysHidden
      "customName": "Wi-Fi",               // オプションの表示名
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

## 仕組み

1. **検出** — `SystemMenuBarDiscoveryService` が 5 秒ごとにスキャンし、AX API で全実行中アプリの `AXExtrasMenuBar` / `AXMenuBar` を走査。`CGWindowListCopyWindowInfo` で Window Server のみで見える項目を補完。アプリがフォアグラウンドの間は自動スキャンを一時停止し、バックグラウンドに移行すると再開
2. **アイデンティティ** — `MenuBarIdentityBuilder` が各アイコンに安定 ID を生成：AX Identifier 優先、タイトルにフォールバック、最終的にジオメトリシグネチャを使用
3. **レイアウト** — `DefaultMenuBarLayoutEngine` が表示ルールに基づき項目を 3 グループに分割：常に表示、マスク対象、棚表示
4. **レンダリング** — `MenuBarOverlayController` がボーダーレスの `NSPanel` をメニューバーの上に浮かせ、隠しアイコンにフロストマスクを重ね、展開時に棚ストリップを描画
5. **操作** — `DefaultMenuBarInteractionRouter` が AXPress 対応項目は Accessibility 経由で直接クリック、非対応項目は CGEvent マウスイベントを合成

## コントリビュート

どんな形の貢献も歓迎します！まず fork し、フィーチャーブランチで開発して、Pull Request を提出してください。

```bash
git checkout -b feature/your-feature
# コーディング、テスト
swift test
git commit -m "feat: describe your change"
git push origin feature/your-feature
```

## ライセンス

MIT — 好きに使ってください。[LICENSE](../LICENSE) を参照。

---

<p align="center">
  <sub>Swift 6 と怒りで書かれた 🖤</sub>
</p>
