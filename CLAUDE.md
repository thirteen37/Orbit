# Orbit - Development Guide

## Overview

Orbit is a macOS menubar utility that automatically assigns windows to specific Spaces based on configurable rules. It solves the problem of managing multiple windows from the same app (e.g., Chrome work profile vs personal profile) that need to live on different Spaces.

## Development Process

### Git Workflow

**Always use git worktrees for feature development.** Multiple agents may work concurrently, and worktrees prevent conflicts.

```bash
# Create a worktree for a new feature
git worktree add ../Orbit-feature-name -b feature/feature-name

# Work in the worktree directory
cd ../Orbit-feature-name

# When complete, merge back to main
cd ../Orbit
git merge feature/feature-name

# Clean up
git worktree remove ../Orbit-feature-name
git branch -d feature/feature-name
```

**Branch rules:**
- **Never work directly on `main`** without explicit approval
- `main` must always be clean and working
- Create feature branches for all work: `feature/space-mover`, `feature/window-monitor`, etc.
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

**Starting a session:**
```bash
# 1. Check TODO.md on main for available work
git show main:TODO.md

# 2. Create worktree for your feature
git worktree add ../Orbit-feature-name -b feature/feature-name

# 3. Read recent commits if resuming existing branch
git log --oneline -10
```

**During work:**
- Commit frequently with meaningful messages
- Each commit should be a resumable checkpoint
- Message format for WIP: `WIP: completed X, next step Y`

**Ending a session (incomplete work):**
```bash
# Commit current state with clear next-step message
git add -A
git commit -m "WIP: implemented basic rule matching

Done:
- Rule struct with app/title matching
- TOML parsing for rules array

Next:
- Add regex support for title_pattern
- Write unit tests for edge cases"
```

**Resuming someone else's work:**
```bash
# Read recent commits to understand state
git log --oneline -10
git log -1  # Full message of last commit

# Look at current code
# Continue from where they left off
```

**Completing a feature:**
```bash
# 1. Ensure all tests pass
swift test

# 2. Update TODO.md to mark feature complete
# 3. Request merge to main (requires approval)
```

**Conflict avoidance:**
- Agents work in separate worktrees — no file conflicts during development
- `TODO.md` only updated at merge time, not during feature work
- If two agents need the same file, coordinate via human or sequential work

### Cleanup and Rollbacks

**Worktree cleanup (after successful merge):**
```bash
# 1. Merge the feature (from main worktree)
cd ~/Documents/Orbit
git merge feature/feature-name

# 2. Remove the worktree from filesystem
git worktree remove ../Orbit-feature-name

# 3. Delete the branch
git branch -d feature/feature-name

# 4. Verify cleanup
git worktree list   # Should not show the removed worktree
git branch          # Should not show the deleted branch
```

**All three steps are required.** Don't leave orphaned worktrees or branches.

**When to abandon and start fresh:**

If you find yourself:
- In a loop making the same changes repeatedly
- Fighting the compiler with no progress for 10+ attempts
- Realizing the approach is fundamentally flawed

**Don't keep digging.** Instead:

```bash
# 1. Document what didn't work (in main worktree)
cd ~/Documents/Orbit
# Add notes to CLAUDE.md or a LEARNINGS.md file

# 2. Abandon the broken worktree
git worktree remove --force ../Orbit-feature-name
git branch -D feature/feature-name  # Force delete

# 3. Start fresh with a new approach
git worktree add ../Orbit-feature-name-v2 -b feature/feature-name-v2
```

**Document failed approaches** in this file under "Lessons Learned" so future agents don't repeat the same mistakes.

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

**Documentation:**
- Keep documentation up to date with code changes
- Update CLAUDE.md when architecture changes
- Update README.md when user-facing behavior changes
- Document non-obvious code with comments

### Code Review Checklist

Before merging any feature:
- [ ] All tests pass (`swift test`)
- [ ] No dead code or unused variables
- [ ] Documentation updated if needed
- [ ] Commit messages are meaningful
- [ ] Code follows existing patterns in the codebase

### Agentic Development Guidelines

**Build incrementally:**
- Build after writing each component — don't write 500 lines then discover it doesn't compile
- Run `swift build` frequently during development
- Test each piece before moving to the next

**Verify assumptions:**
- Don't assume code works — run it
- Don't assume tests pass — run them
- Don't assume permissions are granted — check

**When to stop and ask (requires human approval):**
- Architectural changes not in the plan
- Adding new dependencies
- Changing public APIs or config format
- Anything that affects user data or security
- Merging to `main`
- Deleting significant code

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
- Post mouse down → Ctrl+Arrow → mouse up events
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
# ~/.config/orbit/rules.toml

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
5. **Edge cases** - Full-screen windows, minimized windows may not work

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
