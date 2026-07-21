---
title: Process Visibility
summary: Process visibility knowledge covering detached tmux session visibility and sleep-wake cases where the process list may be empty or stale.
tags: []
related: [architecture/process_provider/context.md]
keywords: []
createdAt: '2026-07-15T04:49:20.740Z'
updatedAt: '2026-07-15T04:49:20.740Z'
---
## Reason
Document process visibility behavior and sleep-wake edge cases for focus management

## Raw Concept
**Task:**
Document process visibility behavior relevant to focus management and process provider reliability.

**Changes:**
- Captured detached-session process visibility concerns
- Captured sleep-wake empty or stale process list behavior

**Files:**
- Sources/FocusBMLib/TmuxProvider.swift
- Tests/focusbmTests/TmuxProviderTests.swift

**Flow:**
focus check -> process provider query -> process list inspection -> handle detached or stale results

**Timestamp:** 2026-07-15T04:49:03.854Z

## Narrative
### Structure
Focus-related process visibility behavior is organized around provider reliability and edge cases affecting process enumeration.

### Dependencies
Depends on tmux session state and system sleep-wake timing affecting process list freshness.

### Highlights
Highlights the need to account for detached sessions and empty or stale results after sleep-wake transitions.
