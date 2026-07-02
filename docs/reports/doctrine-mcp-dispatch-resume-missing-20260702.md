# Doctrine MCP dispatch resume missing investigation log

## Summary

`x-mcp --min-cycles 2 --worktree --strct-cycle --fanout 10` で
`docs/requirements/zombie-process-refresh-plan.md` の実装を進めた際、コード実装と SwiftPM 検証は完了したが、Doctrine MCP の dispatch resume が
`F_DISPATCH_RESUME_MISSING` で失敗した。

同じ `pending state missing` が複数回再現したため、実装作業のゴールは blocked とした。

## Scope

- Workspace: `/Users/ttakeda/repos/focusbm`
- Objective:
  - `Use x-mcp --min-cycles 2 --worktree --strct-cycle --fanout 10 skill: docs/requirements/zombie-process-refresh-plan.md すべて実装してください。`
- Relevant requirement file:
  - `docs/requirements/zombie-process-refresh-plan.md`
- Relevant implementation files:
  - `Sources/FocusBMLib/ProcessProvider.swift`
  - `Sources/FocusBMApp/SearchPanel.swift`
  - `Tests/focusbmTests/ProcessProviderTests.swift`
  - `Tests/FocusBMAppTests/ShortcutBarTests.swift`

## Worktree state at blockage

```text
 M Sources/FocusBMApp/SearchPanel.swift
 M Sources/FocusBMLib/ProcessProvider.swift
 M Tests/FocusBMAppTests/ShortcutBarTests.swift
 M Tests/focusbmTests/ProcessProviderTests.swift
?? docs/requirements/
```

Diff stat:

```text
Sources/FocusBMApp/SearchPanel.swift          | 18 ++++++++++++++
Sources/FocusBMLib/ProcessProvider.swift      | 36 ++++++++++++++++++++++++---
Tests/FocusBMAppTests/ShortcutBarTests.swift  | 29 +++++++++++++++++++++
Tests/focusbmTests/ProcessProviderTests.swift | 33 ++++++++++++++++++++++++
4 files changed, 113 insertions(+), 3 deletions(-)
```

## Implemented behavior

### ProcessProvider

- Added `ProcessProvider.isProcessAlive(_:)`.
- Uses `sysctl` with `[CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]`.
- Returns `false` when the PID does not exist or `kp_proc.p_stat == SZOMB`.
- Added `ProcessProvider.isRecoverableAIProcess(_:)`.
- Returns `true` only when `AIProcess.terminalBundleId != nil`.
- `listNonTmuxAIProcesses()` now excludes:
  - tmux child processes,
  - dead or zombie PIDs,
  - daemon command lines,
  - AI processes that cannot be restored through a terminal bundle id.

### SearchPanel

- Added `SearchPanel.isManualRefreshShortcut(keyCode:flags:)`.
- `Command+R` and `Command+Shift+R` are handled before number and alphabet shortcut processing.
- Manual refresh calls `viewModel.refreshForPanelAsync()` and returns `nil`, keeping the panel open.
- `alphabetShortcutLabel(keyCode:flags:)` returns `nil` for `Command+R` and `Command+Shift+R`, preventing collision with normal `r` / `R` shortcuts.

## Verification evidence

### Targeted tests

`swift test --filter ProcessProviderTests`

```text
process_provider_exit:0
✔ Test test_recoverableAIProcess_requiresTerminalBundleId() passed
✔ Test test_recoverableAIProcess_acceptsTerminalBundleId() passed
✔ Test test_isProcessAlive_invalidPid_returnsFalse() passed
✔ Test run with 27 tests in 0 suites passed
```

`swift test --filter ShortcutBarTests`

```text
shortcutbar_exit:0
✔ Test isManualRefreshShortcut_withCommandR_returnsTrue() passed
✔ Test isManualRefreshShortcut_withCommandShiftR_returnsTrue() passed
✔ Test isManualRefreshShortcut_withoutCommandR_returnsFalse() passed
✔ Test alphabetShortcutLabel_withCommandR_returnsNilForRefreshShortcut() passed
✔ Test alphabetShortcutLabel_withCommandShiftR_returnsNilForRefreshShortcut() passed
✔ Test run with 22 tests in 0 suites passed
```

### Full checks

`swift build`

```text
Build complete!
```

`swift test --quiet`

```text
✔ Test run with 336 tests in 0 suites passed
```

## Doctrine MCP call sequence

### First mission

#### flag_resolve

Input:

```json
{
  "raw_args": [
    "--min-cycles",
    "2",
    "--worktree",
    "--strct-cycle",
    "--fanout",
    "10",
    "skill:",
    "docs/requirements/zombie-process-refresh-plan.md",
    "すべて実装してください。"
  ]
}
```

Output summary:

```json
{
  "task": "--strct-cycle skill: docs/requirements/zombie-process-refresh-plan.md すべて実装してください。",
  "flags": {
    "--fanout": { "values": ["10"], "source": "argv" },
    "--min-cycles": { "values": ["2"], "source": "argv" },
    "--worktree": { "source": "argv" },
    "--strict-cycle": { "source": "default" },
    "--tmux": { "source": "default" },
    "--use-dag": { "source": "default" },
    "--preset": { "values": ["research"], "source": "default" }
  }
}
```

Observation:

- `--strct-cycle` was not normalized from argv and remained in `task`.
- `--strict-cycle` was added from defaults.
- No fatal conflict was reported.

#### mission_run initial

Input summary:

```json
{
  "task": "--strct-cycle skill: docs/requirements/zombie-process-refresh-plan.md すべて実装してください。",
  "workspace": "/Users/ttakeda/repos/focusbm",
  "flags": [
    "--min-cycles",
    "2",
    "--worktree",
    "--strct-cycle",
    "--fanout",
    "10",
    "skill:",
    "docs/requirements/zombie-process-refresh-plan.md",
    "すべて実装してください。"
  ],
  "options": {}
}
```

Output summary:

```json
{
  "mission_id": "20260702-073838-88309-001",
  "status": "dispatch_required",
  "dispatch": {
    "version": "1.1.0",
    "mission_id": "20260702-073838-88309-001",
    "cycle": 1,
    "mode": "fanout"
  }
}
```

#### cop_apply

Input summary:

```json
{
  "mission_id": "20260702-073838-88309-001",
  "op": "set",
  "path": "/dispatch/results/20260702-073838-88309-001-cycle-1",
  "value": {
    "resume_token": "20260702-073838-88309-001-cycle-1",
    "wave_id": "wave-0",
    "jobs": [
      {
        "job_id": "mission-root",
        "agent_type": "doctrine-executor-light",
        "status": "completed"
      },
      {
        "job_id": "act-supervise",
        "agent_type": "doctrine-nco-supervisor",
        "status": "completed"
      }
    ],
    "changed_files": [
      "Sources/FocusBMLib/ProcessProvider.swift",
      "Sources/FocusBMApp/SearchPanel.swift",
      "Tests/focusbmTests/ProcessProviderTests.swift",
      "Tests/FocusBMAppTests/ShortcutBarTests.swift"
    ]
  }
}
```

Output:

```json
{
  "new_version": 14,
  "conflicts": []
}
```

#### mission_run resume with options.resume_token

Input summary:

```json
{
  "mission_id": "20260702-073838-88309-001",
  "task": "--strct-cycle skill: docs/requirements/zombie-process-refresh-plan.md すべて実装してください。",
  "workspace": "/Users/ttakeda/repos/focusbm",
  "options": {
    "resume_token": "20260702-073838-88309-001-cycle-1"
  }
}
```

Output:

```json
{
  "mission_id": "20260702-073838-88309-001",
  "status": "partial",
  "waves_executed": [],
  "artifacts": [],
  "drift_codes": ["F_DISPATCH_RESUME_MISSING"],
  "summary": "dispatch resume failed: pending state missing for token 20260702-073838-88309-001-cycle-1"
}
```

#### mission_run resume with top-level resume_token and options.resume_token

Input summary:

```json
{
  "mission_id": "20260702-073838-88309-001",
  "task": "--strct-cycle skill: docs/requirements/zombie-process-refresh-plan.md すべて実装してください。",
  "workspace": "/Users/ttakeda/repos/focusbm",
  "resume_token": "20260702-073838-88309-001-cycle-1",
  "options": {
    "resume_token": "20260702-073838-88309-001-cycle-1"
  }
}
```

Output:

```json
{
  "mission_id": "20260702-073838-88309-001",
  "status": "partial",
  "waves_executed": [],
  "artifacts": [],
  "drift_codes": ["F_DISPATCH_RESUME_MISSING"],
  "summary": "dispatch resume failed: pending state missing for token 20260702-073838-88309-001-cycle-1"
}
```

### Second mission

The mission was restarted to avoid depending on a stale `mission_id`.

#### mission_run initial

Output summary:

```json
{
  "mission_id": "20260702-074153-88309-003",
  "status": "dispatch_required",
  "dispatch": {
    "version": "1.1.0",
    "mission_id": "20260702-074153-88309-003",
    "cycle": 1,
    "mode": "fanout"
  }
}
```

#### cop_apply

Input summary:

```json
{
  "mission_id": "20260702-074153-88309-003",
  "op": "set",
  "path": "/dispatch/results/20260702-074153-88309-003-cycle-1",
  "value": {
    "resume_token": "20260702-074153-88309-003-cycle-1",
    "wave_id": "wave-0",
    "jobs": [
      {
        "job_id": "mission-root",
        "agent_type": "doctrine-executor-light",
        "file": "Sources/FocusBMLib/ProcessProvider.swift",
        "symbol": "ProcessProvider",
        "status": "completed",
        "error": null
      },
      {
        "job_id": "act-supervise",
        "agent_type": "doctrine-nco-supervisor",
        "file": null,
        "symbol": null,
        "status": "completed",
        "error": null
      }
    ],
    "changed_files": [
      "Sources/FocusBMLib/ProcessProvider.swift",
      "Sources/FocusBMApp/SearchPanel.swift",
      "Tests/focusbmTests/ProcessProviderTests.swift",
      "Tests/FocusBMAppTests/ShortcutBarTests.swift"
    ]
  }
}
```

Output:

```json
{
  "new_version": 14,
  "conflicts": []
}
```

#### mission_run resume

Input summary:

```json
{
  "mission_id": "20260702-074153-88309-003",
  "task": "--strct-cycle skill: docs/requirements/zombie-process-refresh-plan.md すべて実装してください。",
  "workspace": "/Users/ttakeda/repos/focusbm",
  "options": {
    "resume_token": "20260702-074153-88309-003-cycle-1"
  }
}
```

Output:

```json
{
  "mission_id": "20260702-074153-88309-003",
  "status": "partial",
  "waves_executed": [],
  "artifacts": [],
  "drift_codes": ["F_DISPATCH_RESUME_MISSING"],
  "summary": "dispatch resume failed: pending state missing for token 20260702-074153-88309-003-cycle-1"
}
```

### Third reproduction

The same second mission was resumed again in the next continuation turn.

Input summary:

```json
{
  "mission_id": "20260702-074153-88309-003",
  "task": "--strct-cycle skill: docs/requirements/zombie-process-refresh-plan.md すべて実装してください。",
  "workspace": "/Users/ttakeda/repos/focusbm",
  "options": {
    "resume_token": "20260702-074153-88309-003-cycle-1"
  }
}
```

Output:

```json
{
  "mission_id": "20260702-074153-88309-003",
  "status": "partial",
  "waves_executed": [],
  "artifacts": [],
  "drift_codes": ["F_DISPATCH_RESUME_MISSING"],
  "summary": "dispatch resume failed: pending state missing for token 20260702-074153-88309-003-cycle-1"
}
```

## Key observations

1. `mission_run` initial returns `dispatch_required` correctly.
2. `dispatch.version` is `1.1.0`.
3. `dispatch.mode` is `fanout`.
4. `cop_apply` succeeds and returns `conflicts: []`.
5. `mission_run` resume cannot find pending state for the same token.
6. The failure occurs for two separate mission ids:
   - `20260702-073838-88309-001`
   - `20260702-074153-88309-003`
7. The failure is independent of whether `resume_token` is supplied under `options` only or both top-level and `options`.
8. Workspace search did not find persisted mission or dispatch state for the new mission under `stigmergy`, `.codex`, or `.claude`.

## Contract inconsistency noticed

Two local Doctrine references differ on resume token placement:

- `x-mcp` launcher reference says canonical resume is:

```json
{
  "options": {
    "resume_token": "<dispatch.resume_token>"
  }
}
```

- `doctrine-mcp-usage` says:

```json
{
  "resume_token": "<dispatch.resume_token>"
}
```

In this incident, both forms failed with the same `F_DISPATCH_RESUME_MISSING`, so the observed failure is probably not only a client-side parameter placement issue. The inconsistency is still worth resolving because it increases caller ambiguity.

## Hypotheses

### H1: Pending dispatch state is not persisted or is lost before resume

Evidence:

- Initial `mission_run` returns `dispatch_required`.
- `cop_apply` writes a result successfully.
- Resume immediately reports `pending state missing`.
- Restarting a fresh mission reproduces the same result.

Investigation target:

- Server-side store for pending dispatch state.
- Lifecycle between `mission_run(dispatch_required)` and later `mission_run(resume)`.
- Whether pending state is in memory only and lost between tool calls or server process boundaries.

### H2: `cop_apply` writes to COP but does not register or preserve dispatch pending state

Evidence:

- `cop_apply` returns `new_version` and no conflicts.
- Resume still cannot find the pending state.

Investigation target:

- Whether `/dispatch/results/<resume_token>` write-back path is the expected path for the currently running server version.
- Whether `cop_apply` and `mission_run` read from different stores or namespaces.

### H3: Caller is using the wrong resume token shape

Evidence against:

- The token used matches the observed format: `<mission_id>-cycle-1`.
- Both `options.resume_token` and top-level `resume_token` forms failed.

Investigation target:

- Compare actual `dispatch.resume_token` emitted by server with inferred token.
- In tool output viewed in the parent session, the large dispatch JSON was truncated before the explicit `resume_token` field was visible. The caller inferred the token from documented format and mission id.

### H4: `--strct-cycle` typo affects task identity or dispatch storage

Evidence:

- `flag_resolve` left `--strct-cycle` in `task`.
- `--strict-cycle` default was still added.
- Mission still reached `dispatch_required`, so this does not prevent initial dispatch.

Investigation target:

- Whether task text is part of the key for pending dispatch state.
- Whether unrecognized flags in task affect resume lookup.

## Suggested investigation checklist

1. Inspect Doctrine MCP server logs for both mission ids:
   - `20260702-073838-88309-001`
   - `20260702-074153-88309-003`
2. Locate where `dispatch_required` pending state is written.
3. Locate where `mission_run` resume reads pending state.
4. Confirm whether pending state key is:
   - `mission_id`,
   - `resume_token`,
   - `workspace`,
   - task hash,
   - COP version,
   - or a composite key.
5. Confirm whether `cop_apply` should be called before or after pending state registration.
6. Confirm whether `cop_apply` path `/dispatch/results/<resume_token>` is correct for fanout dispatch version `1.1.0`.
7. Confirm whether `mission_run` output includes an explicit `dispatch.resume_token` and whether it differs from `<mission_id>-cycle-1`.
8. Resolve documentation mismatch for resume token placement.
9. Add a regression test:
   - call `mission_run` initial,
   - assert `dispatch_required`,
   - write `/dispatch/results/<resume_token>` by `cop_apply`,
   - resume by `mission_run`,
   - assert the status is not `partial` with `F_DISPATCH_RESUME_MISSING`.

## Raw error strings

```text
dispatch resume failed: pending state missing for token 20260702-073838-88309-001-cycle-1
dispatch resume failed: pending state missing for token 20260702-074153-88309-003-cycle-1
```

## Impact

- Code implementation in `focusbm` is complete and tested.
- Doctrine MCP could not produce a successful `--min-cycles 2` terminal mission result.
- The parent goal was marked blocked only after the same `F_DISPATCH_RESUME_MISSING` condition repeated across three continuation attempts.

## Recommendation

Treat this as a Doctrine MCP dispatch lifecycle bug until server logs prove otherwise. The most likely failure area is pending dispatch state registration or lookup between initial `mission_run` and resume `mission_run`, not the `focusbm` implementation itself.
