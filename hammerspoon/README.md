# focusbm Hammerspoon Module

## インストール

1. `focusbm.lua` を `~/.hammerspoon/` にコピー
2. `~/.hammerspoon/init.lua` に以下を追加:

```lua
local focusbm = require("focusbm")

-- Cmd+Ctrl+B でブックマーク選択画面を開く
focusbm.bindChooser({"cmd", "ctrl"}, "b")

-- 特定のブックマークに直接ジャンプ
focusbm.bindHotkey({"cmd", "ctrl"}, "e", "my-editor")
focusbm.bindHotkey({"cmd", "ctrl"}, "s", "slack-work")
```

3. Hammerspoonをリロード
