# Orbit - Development Guide

## Overview

Orbit is a macOS menubar utility that automatically assigns windows to specific Spaces based on configurable rules. It solves the problem of managing multiple windows from the same app (e.g., Chrome work profile vs personal profile) that need to live on different Spaces.

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

1. Create 3 spaces manually in Mission Control
2. Configure rule: Chrome "Work" → Space 2
3. Open Chrome, create new window with Work profile
4. Verify window moves to Space 2
5. Quit Chrome, reopen
6. Verify new window goes to Space 2 again

## References

- [Amethyst source code](https://github.com/ianyh/Amethyst) - CGEvent technique
- [AXSwift](https://github.com/tmandry/AXSwift) - Swift Accessibility wrapper
- [Hammerspoon hs.spaces](https://github.com/asmagill/hs._asm.spaces) - Space management patterns
- [ianyh blog: Accessibility, Windows, and Spaces](https://ianyh.com/blog/accessibility-windows-and-spaces-in-os-x/)
