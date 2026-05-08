# focusbm

A bookmark tool for macOS app focus management. Define app switching targets in YAML and instantly restore them with a **CLI tool** and a **menu bar app**.

## Overview

| Tool | Type | Description |
|---|---|---|
| `focusbm` | CLI | Add, restore, and manage bookmarks via subcommands |
| `FocusBMApp` | Menu bar app | Floating search panel invoked by a global hotkey |

---

## CLI Tool (focusbm)

### Subcommands

| Subcommand | Description |
|---|---|
| `add <name> <bundleId>` | Manually add a bookmark (generates YAML template) ⭐ Recommended |
| `edit` | Open the bookmark YAML in your editor ⭐ Recommended |
| `save <name>` | Save the currently focused app as a bookmark (auxiliary command) |
| `restore <name>` | Restore and focus the specified bookmark |
| `restore-context <context>` | Restore all bookmarks in a context at once |
| `switch` | Filter and select a bookmark using fzf, then restore |
| `list` | Display the list of bookmarks |
| `delete <name>` | Delete the specified bookmark |

### Usage

#### Recommended Workflow: Define in YAML → Restore

Since the `save` command can only capture the frontmost app, **manually defining bookmarks in YAML is the recommended workflow**.

##### 1. Add a bookmark (`add` command)

```sh
# Add an app bookmark
focusbm add mywork com.example.app --context work

# Specify a display name
focusbm add mywork com.example.app --app-name "My App" --context work

# Browser bookmark (URL pattern)
focusbm add pr com.microsoft.edgemac --url "github.com/pulls" --context dev

# Browser bookmark (tab index)
focusbm add slack com.google.Chrome --url "app.slack.com" --tab-index 3 --context work

# Regex pattern
focusbm add taskchute "^com\\.electron\\.taskchute" --app-name "TaskChute Cloud"
```

##### 2. Edit YAML directly

```sh
# Open YAML in $EDITOR
focusbm edit
```

##### 3. Restore a bookmark

```sh
focusbm restore mywork

# Select and restore using fzf
focusbm switch

# Restore all bookmarks in a context
focusbm restore-context work
```

#### Auxiliary: Save the current app (`save` command)

Use this to quickly bookmark the current frontmost app. Note that only the currently focused app can be captured.

```sh
# Save the current focus state as "mywork"
focusbm save mywork

# Save with a context (tag)
focusbm save mywork --context project-a
```

#### Display the bookmark list

```sh
# Default display (grouped by context)
focusbm list

# Filter by context
focusbm list --context project-a

# fzf-compatible output format (for pipe input)
focusbm list --format fzf
```

#### Delete a bookmark

```sh
focusbm delete mywork
```

---

## Menu Bar App (FocusBMApp)

### Overview

- Lives in the menu bar and brings up a Spotlight-style floating search panel via a global hotkey
- Incrementally search and select bookmarks from the panel to bring apps or browser tabs to the front
- Fully keyboard-driven (↑↓ to navigate, Enter to restore, Esc to close)

### How to Launch

```sh
# Build debug and run
swift build
.build/debug/FocusBMApp
```

### Global Hotkey

The default hotkey is **Cmd+Ctrl+B**.

You can change it in the `settings` section of your YAML (see below).

### Required Permissions

**Accessibility permission** is required to restore apps and browser tabs.

On first launch or if restoration fails, grant permission as follows:

1. System Settings → Privacy & Security → Accessibility
2. Add `FocusBMApp` (or `.build/debug/FocusBMApp`) and enable it

> Accessibility permission is required because browser tab restoration relies on System Events / AppleScript access.

---

## Supported Apps

- **Browsers** — Save and restore active tab URL patterns, titles, and tab indices
  - Microsoft Edge, Google Chrome, Brave Browser, Safari — tab search and switching by URL supported
  - Firefox — tab switching is supported **only when `tabIndex` is specified**, via the Cmd+N shortcut (see below)
- **Other apps** — Save window titles and bring apps to the front using bundleIdPattern (supports regex)
- **Floating window apps** — Dynamically enumerate floating windows of LSUIElement apps (such as Alter) that do not appear in Cmd+Tab, and switch between them at runtime

---

## Requirements

- macOS 13 (Ventura) or later
- Swift 6.0 or later
- Xcode (for running tests)
- fzf (for the CLI `switch` command)

---

## Building

```sh
# Debug build (builds both CLI and menu bar app)
swift build

# Run tests
swift test

# Release build
swift build -c release
```

## Installation

### Menu Bar App (FocusBMApp.app)

A bundling script generates a release-built `.app` bundle.

```sh
# Create .app bundle (release build → generates FocusBMApp.app)
./scripts/bundle.sh

# Install to /Applications
cp -r FocusBMApp.app /Applications/

# Launch
open FocusBMApp.app
```

Double-click or use the `open` command to launch it as a native app (no terminal required).

### CLI (focusbm)

```sh
swift build -c release
cp .build/release/focusbm /usr/local/bin/focusbm
```

---

## Data Storage

Bookmarks and settings are stored in YAML format at the following path:

```
~/.config/focusbm/bookmarks.yml
```

If a legacy V1 `bookmarks.yml` exists, it will be automatically migrated to V2 format on first load (the original file is preserved as `.bak`).

---

## Manual YAML Editing

You can directly edit `~/.config/focusbm/bookmarks.yml` to use regex patterns and configure advanced settings.

### Bookmark Definition Examples

```yaml
bookmarks:
  - id: taskchute
    bundleIdPattern: "^com\\.electron\\.taskchute"
    appName: TaskChute Cloud
    context: work
    state:
      type: app
      windowTitle: ""
    createdAt: "2025-02-18T09:00:00Z"

  - id: github-pr
    bundleIdPattern: com.microsoft.edgemac
    appName: Microsoft Edge
    context: dev
    state:
      type: browser
      urlPattern: "github.com/myorg/pull"
      title: "PR Review"
      tabIndex: 2
    createdAt: "2025-02-18T09:00:00Z"

  - id: slack-inbox
    bundleIdPattern: com.google.Chrome
    appName: Google Chrome
    context: work
    state:
      type: browser
      urlPattern: "https://app.slack.com/client/T0APA1XEE/activity-inbox"
      title: "Slack"
      urlPrefix: "https://app.slack.com/client/T0APA1XEE"  # optional
    createdAt: "2025-02-18T09:00:00Z"

  - id: rarely-used
    appName: SomeApp
    bundleIdPattern: com.example.someapp
    context: work
    noShortcut: true   # No ⌘1-9 badge; subsequent items are numbered consecutively
    lowPriority: true  # Moved to the bottom of the list when there is no query
    state:
      type: app
      windowTitle: ""
    createdAt: "2025-01-01T00:00:00Z"
```

### settings Section

Add a `settings` section to `bookmarks.yml` to configure the menu bar app behavior.

```yaml
settings:
  hotkey:
    togglePanel: "cmd+ctrl+b"
  displayNumber: 1
  listFontSize: 15.0   # Defaults to system .body size (≈13pt) if omitted
  panelWidth: 600         # 検索パネルの幅（デフォルト: 500）
  panelHeight: 500        # 検索パネルの高さ（デフォルト: 400）
  fontName: "Fira Code"   # フォント名（省略時: system monospaced）
  preferredTerminal: "com.github.wez.wezterm"  # 優先ターミナル（bundleId 形式）
  directNumberKeys: true    # 数字キー単体でブックマークにフォーカス（false: Cmd+数字のみ）
  showAIAgentShortcut: true # AI エージェント行（aiProcess / tmux ペインの AI）に番号を振る（false で非表示）

bookmarks:
  - id: ...
```

| Key | Type | Default | Description |
|---|---|---|---|
| `settings.hotkey.togglePanel` | string | `"cmd+ctrl+b"` | Global hotkey to invoke the search panel |
| `settings.displayNumber` | integer | `1` | Display number where the panel appears (1-based) |
| `settings.listFontSize` | float | `nil` (≈13pt) | Font size (pt) for the candidate list. Uses system default if omitted |
| `settings.panelWidth` | integer | `500` | 検索パネルの幅（px） |
| `settings.panelHeight` | integer | `400` | 検索パネルの高さ（px） |
| `settings.fontName` | string | `nil`（システム等幅フォント） | リスト表示のフォント名。省略時はシステムの等幅フォントを使用 |
| `settings.preferredTerminal` | string | `nil` | tmux ペインを開く際に使用するターミナルの bundleId（例: `"com.github.wez.wezterm"`）。設定すると自動検出より優先される |
| `settings.directNumberKeys` | bool | `true` | `true`: 数字キー単体でブックマークにフォーカス。`false`: Cmd+数字のみ |
| `settings.showAIAgentShortcut` | bool? | `nil`（= `true` 相当） | `true`/未指定: AI エージェント行（`aiProcess` および tmux ペインの AI エージェント）にも ⌘1–⌘9 番号を振る（現行動作）。`false`: AI エージェント行に番号を振らず、ブックマーク側の番号が 1,2,3... と詰まる。数字キーによるジャンプも AI 行には効かなくなる |

### Field Descriptions

- **bundleIdPattern** — Specifies the app's bundle ID as a regex pattern. Supports prefix or exact match, e.g., `^com\.electron\.taskchute`
- **urlPattern** — Partial match pattern for the active browser tab's URL
- **tabIndex** — Browser tab index (1-based). If specified, restoration jumps directly to that tab. When used together with `urlPattern`, `tabIndex` takes priority but falls back to URL search if the URL does not match. If omitted and `urlPattern` is set, the URL is opened directly via `open location` (the `https://` prefix is added automatically). If neither is set, the app is simply activated
- **urlPrefix** — (Optional) If a tab whose URL starts with this prefix is already open, switches to that tab instead of opening a new one. Useful for apps like Slack where the URL changes per page/channel. If omitted, `urlPattern` is used for exact matching as usual
- **noShortcut** — (Optional) If `true`, the item is not assigned a ⌘1–⌘9 shortcut badge. Subsequent items are numbered consecutively without skipping. Defaults to `false` (or omit the field)
- **lowPriority** — (Optional) If `true`, the item is moved to the bottom of the list when there is no search query. In search mode it appears in score order like any other item. Defaults to `false` (or omit the field)

### Notes on Using Firefox

Firefox does not have an AppleScript API for enumerating tabs or searching by URL (`tabs of windows`), so its behavior differs from Chrome/Safari.

| Condition | Behavior |
|------|------|
| `tabIndex` specified | Sends Cmd+N shortcut via System Events to jump to the Nth tab |
| `tabIndex: 9` or higher | Jumps to Cmd+9 (last tab) per Firefox's official behavior |
| No `tabIndex` / `urlPattern` specified | Opens the URL in a new tab via `open location` (`https://` is added automatically) |
| Neither `tabIndex` nor `urlPattern` | Simply activates Firefox (no tab switching) |

**Recommended Firefox bookmark configuration:**

```yaml
- id: github
  appName: Firefox
  bundleIdPattern: org.mozilla.firefox
  context: dev
  state:
    type: browser
    urlPattern: github.com   # Informational only (not used for search)
    title: GitHub
    tabIndex: 3              # Tab position from the left (1-based)
  createdAt: "2025-01-01T00:00:00Z"
```

> **Note**: `tabIndex` will stop working if the tab position changes. It is recommended to keep tabs in fixed positions or pin them.

### Floating Window Apps (e.g., Alter)

To switch between floating windows of LSUIElement apps that do not appear in Cmd+Tab, use `type: floatingWindows`. Window titles are automatically retrieved at app launch, so you do not need to specify them in YAML.

```yaml
- id: alter
  appName: Alter            # App name (used for CGWindowList matching)
  bundleIdPattern: ""       # bundleId not required
  context: tools
  state:
    type: floatingWindows   # Dynamically enumerated at runtime
  createdAt: "2025-01-01T00:00:00Z"
```

Floating windows that exist when the panel is opened are listed as candidates (e.g., `Alter - Search the web - Hello`).

---

## tmux Integration

focusbm now supports discovering and focusing tmux panes running AI agents.

### Supported AI agents

- Claude Code (`claude`)
- Aider (`aider`)
- Gemini (`gemini`)
- Hermes (`hermes`)

### Status indicators

| Emoji | Status |
|-------|--------|
| ● | Running (thinking/generating) |
| ○ | Idle (waiting for input) |
| ⏸ | Plan mode |
| ⏵ | Accept edits mode |

### Terminal detection

| Terminal | Emoji |
|----------|-------|
| Ghostty | 👻 |
| iTerm2 / Terminal.app | 🍎 |
| WezTerm | ⚡ |
| Alacritty | 🔲 |

### CLI verification

```bash
focusbm tmux-list
# Found 3 AI agent session(s):
#   [0] 👻 ● Claude Code — focusbm
#   [1] 👻 ○ Claude Code — tmux-hint
```

---

## Project Structure

```
focusbm/
├── Package.swift
├── Sources/
│   ├── FocusBMLib/              # Shared library (core logic)
│   │   ├── Models.swift         # Data models and AppSettings
│   │   ├── BookmarkRestorer.swift  # Bookmark restoration logic
│   │   ├── AppleScriptBridge.swift # AppleScript / System Events bridge
│   │   ├── FloatingWindowProvider.swift # Floating window enumeration for LSUIElement apps
│   │   └── YAMLStorage.swift    # YAML read/write and migration
│   ├── focusbm/                 # CLI entry point
│   │   └── focusbm.swift
│   └── FocusBMApp/              # Menu bar app
│       ├── main.swift           # Entry point
│       ├── FocusBMApp.swift     # AppDelegate and menu bar management
│       ├── SearchPanel.swift    # Floating panel window
│       ├── SearchView.swift     # SwiftUI search UI
│       ├── SearchViewModel.swift # Search logic and state management
│       └── BookmarkRow.swift    # Bookmark row component
└── Tests/
    └── focusbmTests/
```

### Dependencies

- [swift-argument-parser](https://github.com/apple/swift-argument-parser) — CLI subcommand definitions
- [Yams](https://github.com/jpsim/Yams) — YAML encoding and decoding

---

## Bookmark List Layout (List Columns)

`~/.config/focusbm/bookmarks.yml` の `bookmarkListColumns` キーで、メニューバーアプリの一覧表示を 1 列／2 列に切替できます。

### 設定値

| 値 | 動作 |
|----|------|
| 未指定 | 縦 1 列（既存動作） |
| 1 | 縦 1 列 |
| 2 | 横 2 列（推奨 panelWidth: 800 以上） |
| その他（0, 3, 負数） | 縦 1 列にフォールバック（WARN ログ） |

### 推奨 panelWidth

2 列表示時に `panelWidth` を未指定にすると 800px が自動適用されます。明示指定した場合はユーザー値を優先します。

### キー操作

- `↑↓` / `kj`: 上下移動（1 列: ±1 / 2 列: ±列数）
- `←→` / `hl`: 左右移動（1 列: 無効 / 2 列: ±1 境界クランプ）
- `1`〜`9`: 直接実行（2 列レイアウトでも正しい項目に対応）

設定例は [`bookmarks.example.yml`](./bookmarks.example.yml) を参照してください。

---

## License

MIT
