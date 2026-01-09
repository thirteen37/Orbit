# Orbit

A macOS menubar utility that automatically assigns windows to specific Spaces based on configurable rules.

## The Problem

macOS can assign entire apps to specific Spaces (Dock → right-click → Options → Assign to This Desktop), but it can't handle **different windows from the same app** going to different Spaces.

For example:
- Chrome Work profile → Space 1
- Chrome Personal profile → Space 2
- VS Code "project-a" → Space 1
- VS Code "project-b" → Space 3

Orbit solves this by watching for new windows and moving them to their configured Space based on window title patterns.

## How It Works

Orbit uses a technique that simulates user input rather than calling restricted macOS APIs:

1. Detects new window creation via Accessibility API
2. Matches window title against your rules
3. "Grabs" the window (simulates mouse-down on title bar)
4. Switches Spaces via Ctrl+Arrow keyboard shortcut
5. "Releases" the window in the target Space

This approach works without disabling SIP (System Integrity Protection).

## Configuration

Edit `~/.config/orbit/rules.toml`:

```toml
# Chrome profiles to different spaces
[[rules]]
app = "Google Chrome"
title_contains = "Work"
space = 1

[[rules]]
app = "Google Chrome"
title_contains = "Personal"
space = 2

# Terminal dev sessions
[[rules]]
app = "Terminal"
title_pattern = "^dev-.*"
space = 3

# All VS Code windows to space 3
[[rules]]
app = "Visual Studio Code"
title_contains = "myproject"
space = 3
```

## Installation

```bash
# Build
swift build -c release

# Copy to path
cp .build/release/Orbit /usr/local/bin/

# Grant Accessibility permission when prompted
# System Settings → Privacy & Security → Accessibility → Enable Orbit
```

## Behavior

- **On launch:** Scans existing windows and applies rules
- **Ongoing:** Watches for new windows and moves them automatically
- **Manual override:** If you move a window manually, Orbit respects your choice
- **Auto-start:** Install the LaunchAgent for login startup

## Limitations

- **Visual:** You'll briefly see the window being moved and spaces switching
- **Timing:** Each space switch takes ~300ms for the animation
- **Permissions:** macOS Sequoia requires re-granting Accessibility monthly
- **Edge cases:** Full-screen and minimized windows may not move correctly

## Requirements

- macOS 14.5+ (Sonoma or later)
- Swift 5.9+
- Accessibility permission

## License

MIT
