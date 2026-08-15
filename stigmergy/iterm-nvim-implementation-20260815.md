# itermNvim implementation facts (2026-08-15)

Confirmed by compile and unit tests. Not a live iTerm2/Automation run.

- New YAML type name is `itermNvim`. Reusing V1 `type: iterm2` collides with `migrateV1YAML`, which still rewrites that string to `type: app`.
- Display `resolveClient` still walks window → session → `fallbackClientKey`. Input must use a separate resolver that never consults the global fallback or `preferredTerminal`.
- The iTerm2 send script must place the unique-TTY guard before any `write text`. Empty TTY is rejected in Swift so no script (and no write text) is produced.
- Adding `AppState.iTermNvim` requires every exhaustive switch to compile, including `Bookmark.description` and `BookmarkRestorer.restoreAndGetTarget`.
- A public initializer default argument cannot call an internal static method. `findNvimPane` / `focusPaneForInput` are public so `NvimTmuxRestorer` can wire production defaults.
- Display `listAllPanes` stamps `fallbackClientKey` onto detached panes. Input must restamp via `attachClientsForInput` / `resolveClientForInput` and must not switch or send when only the global fallback exists.

Not confirmed here: live Automation permission, real iTerm2 TTY uniqueness, Esc mode effects. Those stay the human gate.

Do not store Ex command bodies, TTY paths from a machine, or working directories in later notes.
