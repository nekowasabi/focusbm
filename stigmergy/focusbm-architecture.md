# focusbm アーキテクチャ知見

## プロジェクト構成

```
Sources/
├── FocusBMLib/          # 共有ライブラリ（CLI + GUI 共通）
│   ├── Models.swift     # Bookmark, BookmarkStore, AppSettings, HotkeySettings
│   ├── BookmarkRestorer.swift  # 復元ロジック
│   ├── AppleScriptBridge.swift # AppleScript 実行
│   ├── YAMLStorage.swift       # YAML 読み書き + V1→V2 マイグレーション
│   ├── BookmarkSearcher.swift  # 検索フィルタリング
│   └── HotkeyParser.swift      # ホットキー文字列パース
├── focusbm/             # CLI エントリポイント
└── FocusBMApp/          # メニューバーアプリ
    ├── main.swift       # NSApplication 手動起動（@main 不使用）
    ├── FocusBMApp.swift # AppDelegate + CGEventTap ホットキー
    ├── SearchPanel.swift    # NSPanel + ローカルキーモニター
    ├── SearchView.swift     # SwiftUI 検索 UI
    ├── SearchViewModel.swift # 検索状態管理
    └── BookmarkRow.swift    # ブックマーク行表示
```

## 重要な設計判断

### エントリポイント: main.swift vs @main
- `@main` struct ではなく `main.swift` で `NSApplication.shared` を手動管理
- 理由: AppDelegate パターンで CGEventTap のライフサイクルを直接制御するため

### ホットキー: CGEventTap vs NSEvent
- CGEventTap（`.cgSessionEventTap`）を採用
- NSEvent.addGlobalMonitorForEvents は `.accessory` アプリで不安定だったため

### キーイベント: Local Monitor vs NSViewRepresentable
- SearchPanel で `NSEvent.addLocalMonitorForEvents` を使用
- NSViewRepresentable の background 配置は TextField とのフォーカス競合で不安定

### UI: ScrollView + LazyVStack vs List
- ScrollView + LazyVStack を採用
- List は macOS で scrollTo の挙動が不安定（2番目の項目選択時にズレる）

## データフロー

```
bookmarks.yml → BookmarkStore.loadYAML() → SearchViewModel.bookmarks
                                          → SearchViewModel.filtered (query でフィルタ)
                                          → BookmarkRow (表示)
                                          → BookmarkRestorer.restore() (復元)
```

## 既知の制約

- Sandbox 非対応（osascript 実行のため）
- アクセシビリティ権限が必須（CGEventTap + AppleScript）
- 初回権限付与後にアプリ自動再起動が必要
