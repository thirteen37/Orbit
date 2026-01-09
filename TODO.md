# Orbit - Project TODO

> **Note:** This file lives on `main` only. Update it when merging completed features.
> Check feature status before starting work. Claim features by creating a worktree.

## Status Legend
- [ ] Not started
- [~] In progress (check branch for details)
- [x] Complete

---

## Phase 1: Core Movement (Proof of Concept)

- [x] `feature/package-setup` — Create Swift Package structure, Package.swift with dependencies
- [x] `feature/space-mover` — CGEvent-based window movement (SpaceMover.swift)
- [x] `feature/space-tracker` — Track current space number (SpaceTracker.swift)

## Phase 2: Window Monitoring

- [x] `feature/window-monitor` — AXObserver for window creation (WindowMonitor.swift)

## Phase 3: Rule System

- [x] `feature/config` — Rule model and TOML parsing (Rule.swift, ConfigManager.swift)
- [x] `feature/matcher` — Window-to-rule matching logic (WindowMatcher.swift)

## Phase 4: App Shell

- [x] `feature/app-shell` — SwiftUI menubar app (OrbitApp.swift, MenuBarView.swift)
- [x] `feature/permissions` — Accessibility permission request flow

## Phase 5: Polish

- [x] `feature/launch-agent` — LaunchAgent for auto-start at login
- [x] `feature/error-handling` — Edge cases, error recovery
- [x] `feature/docs` — Final documentation pass

---

## Completed Features

All phases complete. See README.md for usage.
