# Preview overlay redesign (design 3B, revised index placement)

Reference image: `assets/mock-preview-3b-rail.png`. HTML/CSS source: `mock/preview-3b-rail.html`.
Mac (SwiftUI, `Sources/`) and Windows (WPF, `dotnet/`) must implement the same spec.

## Data shape

`AgentScreenCapture` gains an optional agent status (nil/null when the capture is not a tmux agent pane):

- Swift: `let status: TmuxAgentStatus?` (default `nil` in init). Set from `pane.agentStatus` in `captureScreen(for:)`.
- C#: `AgentScreenCapture(string Id, string Title, string Text, int Index = 0, TmuxAgentStatus? Status = null)`. Set from `bookmark.AgentStatus` in `CaptureFromCache`.
- During live refresh, keep the status in sync with the latest known item status (Swift: `searchItems`, C#: `_all`) matched by capture id, so a pane that finishes does not keep showing 実行中.
- Delete `numberedTitle` / `NumberedTitle` if nothing references them after the change.

Status label and color come from the existing mappings. Do not invent new ones:
- Label: Swift `TmuxAgentStatus.label`, C# `AgentStatusText.Label`.
- Color: running `rgb(77,242,115)`, planMode/acceptEdits `rgb(255,204,51)`, idle `rgb(255,115,115)`. Reuse the existing mapping (Swift `BookmarkRow.statusColor`, C# `AgentStatusDisplayConverter`); move it to one shared place per platform if the preview needs it too, rather than duplicating it.
- No status: the top bar and pill use neutral `#8B949E`, and the pill is hidden.

## Palette

| token | value |
|---|---|
| backdrop / card background | `#0D1117` |
| pane background | `#161B22` |
| pane border | `#30363D` 1px |
| body inset background | `#0D1117` |
| rail divider | `#21262D` 1px |
| primary text | `#E6EDF3` |
| secondary text | `#8B949E` |
| placeholder / hint | `#6E7681` |
| accent (prompt target) | `#58A6FF` |
| error text | `#FFA198` |

## Pane (each capture, both single and tiled)

- Rounded rectangle, radius 10, background pane color, 1px border.
- 3px bar across the top edge in the status color.
- Header row (padding 12 top / 16 sides / 8 bottom): title (15pt semibold, primary text), then a status pill aligned right. The pill is a capsule with a 7px dot and the label, 12pt semibold, foreground = status color, background = status color at 14% opacity, padding 4×10. Header shows in single mode too.
- Body inset: margin 0 10 10, radius 6, inset background. Contains the capture text (existing ANSI rendering, existing preview font/size, bottom-anchored scroll kept as today) with padding 10×12. Line spacing about 1.5× the font size.
- Prompt target pane (tiled only): border becomes accent 1px plus an outer 3px accent glow at 25% opacity. Replace the old 3px stroke.

## Index number (tiled only)

Why: pane count is variable and a fixed corner is far from the text on large panes (e.g. two panes on a 4K monitor). Numbers at different heights per pane were also hard to scan.

- A left gutter beside the text (not scrolled). Every tile places its number at the same height: level with the end of the longest output among the tiles, clamped inside the body. Shared pure function `PreviewLayout.indexNumberTop` / `IndexNumberTop` (max line count × line height + 10 − number size, clamped to [0, body − number − 8]).
- Size: font size = min(96, 0.4 × body height) (`indexNumberFontSize`). Gutter width = min(80, 0.25 × body height). Two-digit numbers shrink to fit.
- Heavy/bold weight, system sans.
- Color: the agent status color (no status: `#8B949E`) at 55% opacity; the prompt-target pane's number at 100%.

## Prompt dock

- Below the grid, margin-top 16. Radius 10, pane background, 1px accent border, height about 54, padding 0×14.
- Left: target label in accent, 13pt semibold (tiled: `→ N title`; keep existing behavior for when it shows).
- Text field: plain, 15pt, primary text; placeholder in the placeholder color (keep the existing placeholder strings).
- Error line under the dock in error color, 12pt (existing behavior).
- Hint line: `Esc で閉じる`, 12pt, placeholder color.

## Keep unchanged

- The fixed tile height logic (a tile never grows past its cell, and the prompt bar is never pushed off-screen).
- Card sizing (`PreviewLayout`), click-to-dismiss, focus handling, and keyboard behavior.
