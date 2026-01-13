# Orbit - Development Guide

---

## CRITICAL: Read Before Making Any Changes

**STOP. Before writing any code, creating any files, or making any modifications:**

Use the `workbranch` skill to manage the git worktrees.

**Why this matters:** Multiple agents may work concurrently. Working directly on `main` causes conflicts and breaks the shared codebase. The `main` branch must always be clean and deployable.

**The only exceptions** (require explicit user approval):
- Merging a completed feature branch
- Emergency hotfixes with user permission
- Documentation-only changes to CLAUDE.md itself

If you've already made changes on `main` by mistake, ask the user how to proceed before committing.

---

## Overview

Orbit is a macOS menubar utility that automatically assigns windows to specific Spaces based on configurable rules. It solves the problem of managing multiple windows from the same app (e.g., Chrome work profile vs personal profile) that need to live on different Spaces.

## Development Process

### Git Workflow

**Always use the workbranch skill for feature development.** Multiple agents may work concurrently, and workbranch prevent conflicts.

**Branch rules:**
- **NEVER work directly on `main`** — this is non-negotiable
- `main` must always be clean and working
- Use the workbranch skill to create feature branches for all work: `feature/space-mover`, `feature/window-monitor`, etc.
- Merge only after tests pass

### Multi-Agent Coordination

Multiple agents may work concurrently on different features. Each agent works in its own worktree, isolated from others.

**Project tracking:**

| File | Location | Purpose |
|------|----------|---------|
| `TODO.md` | `main` only | Project-level feature list, updated only at merge time |
| Branch commits | Each branch | History of what was done — this IS the handoff |
| Code + tests | Each branch | Current state speaks for itself |

**No separate handoff files.** Git history serves as the handoff mechanism.

**During work:**
- Commit frequently with meaningful messages
- Each commit should be a resumable checkpoint
- Message format for WIP: `WIP: completed X, next step Y`

**Conflict avoidance:**
- Agents work in separate worktrees — no file conflicts during development
- `TODO.md` only updated at merge time, not during feature work
- If two agents need the same file, coordinate via human or sequential work

### Cleanup and Rollbacks

**When to abandon and start fresh:**

If you find yourself:
- In a loop making the same changes repeatedly
- Fighting the compiler with no progress for 10+ attempts
- Realizing the approach is fundamentally flawed

**Don't keep digging.** Instead delete the workbranch and start a fresh new one.

# Update CLAUDE.md "Lessons Learned" section with what failed
# Edit the file, then commit

git add CLAUDE.md
git commit -m "docs: document failed approach for feature-name

Tried X approach, failed because Y.
See Lessons Learned section for details."

# Start fresh with a new approach

**Document failed approaches** in this file under "Lessons Learned" so future agents don't repeat the same mistakes. Always use a branch — never commit directly to main.

### Lessons Learned

_Document failed approaches here so agents don't repeat mistakes._

<!-- Example:
### SpaceMover: CGEvent timing (2024-01-15)
**What was tried:** Posting mouse and keyboard events without delays
**Why it failed:** Space switching animation takes ~300ms; events posted too fast get lost
**Solution:** Added usleep(300_000) between space switches
-->

### Testing Requirements

Include relevant tests with each major feature:
- **Unit tests** - Test individual functions/methods in isolation
- **Integration tests** - Test component interactions
- **UI tests** - Test menubar interactions (when applicable)

**Rules:**
- Tests must pass before committing/merging
- Tests should be meaningful — don't write excessive useless tests
- Test edge cases and error conditions, not just happy paths
- Each test should verify one specific behavior

```bash
# Run tests before any merge
swift test
```

### Code Quality

**Commit guidelines:**
- Commits should be meaningful in size and content
- Each commit should represent a logical unit of work
- Write clear commit messages explaining "why", not just "what"

**Refactoring:**
- Refactor often to keep the codebase clean
- Remove dead code immediately — don't leave it commented out
- Remove unused parameters, variables, and imports
- Keep functions focused and small

**Documentation (MANDATORY):**

Documentation must stay in sync with code. Outdated docs are worse than no docs — they mislead future developers and cause wasted effort.

- **Update CLAUDE.md** when you change architecture, add components, or discover new gotchas
- **Update README.md** when user-facing behavior changes
- **Update inline comments** when you change non-obvious logic
- If you change how something works, update the docs **in the same commit**

### Code Review Checklist

Before merging any feature:
- [ ] All tests pass (`swift test`)
- [ ] No dead code or unused variables
- [ ] **Documentation updated** (CLAUDE.md, README.md, comments as needed)
- [ ] Commit messages are meaningful
- [ ] Code follows existing patterns in the codebase

### Agentic Development Guidelines

**Before changing anything: use the workbranch skill**

**Build incrementally:**
- Build after writing each component — don't write 500 lines then discover it doesn't compile
- Run `swift build` frequently during development
- Test each piece before moving to the next

**Verify assumptions:**
- Don't assume you're on the right branch — check
- Don't assume code works — run it
- Don't assume tests pass — run them
- Don't assume permissions are granted — check

**When to stop and ask (requires human approval):**
- **Any work directly on `main` branch** — always use the workbranch skill
- Architectural changes not in the plan
- Adding obscure dependencies (see dependency policy below)
- Changing public APIs or config format
- Anything that affects user data or security
- Merging to `main`
- Deleting significant code

### Dependency Policy

**Prefer Swift standard library.** Only add external dependencies when stdlib genuinely can't do the job.

**When external deps are needed:**
1. **Popular, well-supported libraries** — can add autonomously (active maintenance, large user base, good docs)
2. **Obscure libraries** — requires approval; make the case if it's a substantially better fit

**Evaluation criteria:**
- GitHub stars / recent commits / open issues
- Does it have breaking changes often?
- Is it maintained by a reputable org or individual?
- How heavy is the dependency tree? (Prefer minimal transitive deps)

**Current approved dependencies:**

| Dependency | Purpose | Why |
|------------|---------|-----|
| TOMLKit | TOML config parsing | Stdlib has no TOML support; TOMLKit is well-maintained |

**To propose an obscure dependency:**
```
Dependency: <name>
Purpose: <what we need it for>
Why not stdlib: <why stdlib can't do this>
Why not a popular alternative: <why this obscure lib is better>
Popularity: <stars, last commit, maintainer>
```

**When to proceed autonomously:**
- Implementing features as specified in the plan
- Writing tests for new code
- Fixing bugs discovered during development
- Refactoring for clarity (without changing behavior)
- Updating documentation to match code

**Error recovery:**
- If build fails: fix the error before proceeding, don't pile on more code
- If tests fail: fix the failing test before writing new tests
- If stuck: document what was tried and ask for help
- If unclear: ask rather than guess

**Environment requirements:**
- macOS 14.5+ (Sonoma) or later
- Swift 6.0+
- Xcode Command Line Tools installed
- Accessibility permission must be granted manually in System Settings

### Building

**Debug build** (for development):
```bash
swift build
```

**App bundle** (for distribution/installation):
```bash
./scripts/build-app.sh
```

This creates `build/Orbit.app`. To install:
```bash
cp -r build/Orbit.app /Applications/
```

To run:
```bash
open build/Orbit.app
```

### File Organization

```
Orbit/
├── Sources/Orbit/
│   ├── main.swift              # Entry point only
│   ├── OrbitApp.swift          # App definition
│   ├── Core/                   # Business logic
│   ├── Config/                 # Configuration handling
│   └── UI/                     # SwiftUI views
├── Tests/OrbitTests/           # All tests here
├── examples/                   # Example configs
├── CLAUDE.md                   # This file (agent guidance)
└── README.md                   # User documentation
```

**Naming conventions:**
- Files: PascalCase matching the primary type (`SpaceMover.swift`)
- Types: PascalCase (`WindowMatcher`, `Rule`)
- Functions/variables: camelCase (`moveWindow`, `currentSpace`)
- Test files: `<Component>Tests.swift`

### Known Gotchas

1. **Accessibility permission** — Cannot be granted programmatically. User must manually enable in System Settings → Privacy & Security → Accessibility. App will fail silently without it.

2. **CGEvent posting** — Requires the app to be trusted. First run will prompt user.

3. **Space switching animation** — Takes ~300ms. Code must wait or movements will fail.

4. **Window title timing** — New windows may have empty/generic titles briefly after creation. May need short delay before matching.

5. **Full-screen windows** — Cannot be moved between spaces with our technique.

6. **Sandboxed apps** — Accessibility API doesn't work from sandboxed apps. Orbit must be distributed outside App Store or with entitlements.

---

## Technical Background

### Why This Is Hard

Apple provides **no public API** for Spaces. Since macOS 14.5 (Sonoma), Apple added authorization checks to private Spaces APIs:
- `CGSMoveWindowToSpace` and similar functions verify "window ownership"
- Only Dock.app has universal window ownership permissions
- Direct API calls require SIP disabled (which we're avoiding)

### Our Approach

We use the technique documented by the Amethyst author:

> "If the mouse has hold of a window, switching to a Space via Mission Control will take the window to that Space."

Instead of calling private APIs directly, we:
1. Simulate mouse-down on the window's title bar (via CGEvent)
2. Send Ctrl+Arrow keyboard shortcut to switch spaces
3. Window follows the "grabbed" mouse to the new space
4. Simulate mouse-up

This works without SIP disabled because we're simulating user input, not calling restricted APIs.

## Architecture

```
Sources/Orbit/
├── main.swift                    # Entry point
├── OrbitApp.swift                # SwiftUI App definition, menubar
├── Core/
│   ├── SpaceMover.swift          # CGEvent-based window movement
│   ├── SpaceTracker.swift        # Track current space number
│   ├── WindowMonitor.swift       # AXObserver for window creation
│   └── WindowMatcher.swift       # Rule matching logic
├── Config/
│   ├── Rule.swift                # Rule model
│   └── ConfigManager.swift       # TOML config loading
└── UI/
    └── MenuBarView.swift         # Menubar interface
```

## Key Components

### SpaceMover.swift
Core movement logic using CGEvents:
- Get window position via Accessibility API
- Calculate title bar grab point
- Post mouse down event
- Send space switch shortcut:
  - **Direct jump (preferred):** Ctrl+Number from config (e.g., Ctrl+2 for space 2)
  - **Fallback:** Relative Ctrl+Arrow if direct jump not configured for target space
- Post mouse up event
- Handle timing delays for space switching animation

### WindowMonitor.swift
- Register `AXObserver` for each running application
- Listen for `kAXWindowCreatedNotification`
- On new window: extract title, app bundle ID, pass to matcher

### SpaceTracker.swift
- Track current space number (1-indexed)
- Subscribe to `NSWorkspace.activeSpaceDidChangeNotification`
- May use `CGSGetActiveSpace()` private API for reads (allowed without SIP)

### ConfigManager.swift
- Load rules from `~/.config/orbit/rules.toml`
- Watch for config changes and reload
- Parse TOML using TOMLKit dependency

## Configuration Format

```toml
# ~/.config/orbit/config.toml

# Keyboard shortcuts for switching spaces
# These should match your System Settings > Keyboard > Shortcuts > Mission Control
[shortcuts]
# Direct jump shortcuts (preferred - Ctrl+Number)
space_1 = "ctrl+1"
space_2 = "ctrl+2"
space_3 = "ctrl+3"
space_4 = "ctrl+4"
space_5 = "ctrl+5"
# Add more as needed for your number of spaces

# Fallback: relative movement (used if direct jump unavailable)
space_left = "ctrl+left"
space_right = "ctrl+right"

# Window-to-space rules
[[rules]]
app = "Google Chrome"
title_contains = "Work"
space = 1

[[rules]]
app = "Google Chrome"
title_contains = "Personal"
space = 2

[[rules]]
app = "Terminal"
title_pattern = "^dev-.*"    # regex
space = 3
```

### Space Numbering

Spaces are identified by position (1 = leftmost, 2 = next, etc.).

**Important:** If you reorder spaces in Mission Control, your config will need updating to match the new positions.

### Onboarding

On first run, if no config exists, Orbit creates `~/.config/orbit/config.toml` with a commented sample configuration and logs a message directing the user to edit it.

## User Interface

**Menubar app** — appears in menu bar (top right), hidden from Dock.

```
┌─────────────────────────────┐
│ Orbit                       │
├─────────────────────────────┤
│ ● Watching (3 rules)        │  ← Status indicator
├─────────────────────────────┤
│ Pause                       │  ← Toggle to "Resume" when paused
│ Reload Config               │  ← Re-read config.toml
│ Open Config...              │  ← Opens in default editor
├─────────────────────────────┤
│ Recent Activity         ▶   │  ← Submenu with last 3 moves
│   Chrome "Work" → Space 1   │
│   Terminal "dev" → Space 3  │
├─────────────────────────────┤
│ Start at Login          ☑   │  ← Toggle LaunchAgent
├─────────────────────────────┤
│ About Orbit                 │
│ Quit                        │
└─────────────────────────────┘
```

| Menu Item | Action |
|-----------|--------|
| Status line | Shows rule count; error state if config invalid |
| Pause/Resume | Temporarily stop watching without quitting |
| Reload Config | Re-read TOML without restart |
| Open Config... | Opens config file in default editor |
| Recent Activity | Submenu showing last 3 window moves |
| Start at Login | Toggle LaunchAgent on/off |
| About | Version info |
| Quit | Exit app |

## Behavior

- **On launch:** Scan all windows of configured apps, move matches
- **Ongoing:** Watch for new windows from configured apps
- **Manual override:** If user moves a window manually, respect it (don't fight back)
- **Stickiness:** Rules re-apply when apps reopen

## Known Limitations

1. **Visual disruption** - User sees window briefly "grabbed" and spaces switching
2. **Timing sensitive** - Needs delays for space switch animations (~300ms per space)
3. **Space count unknown** - Can't detect total number of spaces
4. **Sequoia re-auth** - User must re-grant Accessibility permission monthly

### v1 Scope Limitations

| Scenario | v1 Support |
|----------|------------|
| Multiple monitors | Not supported — single monitor only for v1 |
| Full-screen apps | Not supported — cannot move full-screen windows |
| Minimized windows | Not supported — cannot move minimized windows |
| Target space > actual count | Log warning, skip move |

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Accessibility permission denied | Show alert with button to open System Settings; disable watching until granted |
| Config file malformed | Show error in status line; log details; continue with last valid config |
| Target space doesn't exist | Log warning; skip the move; don't crash |
| Move fails (window busy) | Log warning; retry once after delay; then skip |

## Logging

Orbit uses **macOS unified logging** (`os.log`) with subsystem `com.orbit.Orbit`.

**Viewing logs:**

```bash
# Stream live logs
log stream --predicate 'subsystem == "com.orbit.Orbit"'

# View recent logs
log show --predicate 'subsystem == "com.orbit.Orbit"' --last 1h

# Filter by category
log stream --predicate 'subsystem == "com.orbit.Orbit" AND category == "movement"'
```

Or use **Console.app** and filter by "com.orbit.Orbit".

**Log categories:**
- `general` - App lifecycle, general info
- `movement` - Window movement operations
- `config` - Configuration loading/parsing
- `monitor` - Window monitoring events

## Config Auto-Reload

- Watch `~/.config/orbit/config.toml` for changes using FSEvents
- Debounce: wait 500ms after last change before reloading
- On reload: validate config first
  - If valid: apply new config, update status
  - If invalid: show error in status, log details, keep previous valid config

## Menubar Icon

- Use SF Symbol: `circle.grid.2x2` or similar orbit/grid glyph
- **Watching state:** Filled icon
- **Paused state:** Outline icon
- **Error state:** Icon with warning badge or different color

## Implementation Order

### Phase 1: Core Movement (Proof of Concept)
1. Create Swift Package structure
2. Implement `SpaceMover.swift`
3. Implement `SpaceTracker.swift`
4. Test: can we move a window to another space?

### Phase 2: Window Monitoring
5. Implement `WindowMonitor.swift`
6. Test: does it detect new window creation?

### Phase 3: Rule System
7. Define `Rule.swift` model
8. Implement `ConfigManager.swift` (TOML parsing)
9. Implement `WindowMatcher.swift`
10. Test end-to-end: new window → match → move

### Phase 4: App Shell
11. Create menubar app with SwiftUI
12. Add Accessibility permission request flow
13. Wire everything together

### Phase 5: Polish
14. Add LaunchAgent for auto-start
15. Error handling
16. Edge cases (minimized windows, etc.)

## Dependencies

Add to `Package.swift`:
- **TOMLKit** - TOML parsing for config files

## Permissions Required

- **Accessibility** - For AXObserver and CGEvent posting
- User must grant in System Settings → Privacy & Security → Accessibility

## Testing

### Automated Tests

Tests live in `Tests/OrbitTests/`. Run with:

```bash
swift test
```

**Test structure:**
- `SpaceMoverTests.swift` - CGEvent generation, coordinate calculations
- `WindowMatcherTests.swift` - Rule matching logic, regex patterns
- `ConfigManagerTests.swift` - TOML parsing, rule validation
- `SpaceTrackerTests.swift` - Space tracking state

### Manual Integration Tests

Some behaviors require manual verification:

1. Create 3 spaces manually in Mission Control
2. Configure rule: Chrome "Work" → Space 2
3. Open Chrome, create new window with Work profile
4. Verify window moves to Space 2
5. Quit Chrome, reopen
6. Verify new window goes to Space 2 again
7. Manually move window to Space 3 — verify Orbit doesn't move it back

## References

- [Amethyst source code](https://github.com/ianyh/Amethyst) - CGEvent technique
- [AXSwift](https://github.com/tmandry/AXSwift) - Swift Accessibility wrapper
- [Hammerspoon hs.spaces](https://github.com/asmagill/hs._asm.spaces) - Space management patterns
- [ianyh blog: Accessibility, Windows, and Spaces](https://ianyh.com/blog/accessibility-windows-and-spaces-in-os-x/)
