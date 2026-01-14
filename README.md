# Orbit

A macOS menubar utility that automatically assigns windows to specific Spaces based on configurable rules.

## The Problem

macOS can assign entire apps to specific Spaces (Dock > right-click > Options > Assign to This Desktop), but it cannot handle **different windows from the same app** going to different Spaces.

For example:
- Chrome Work profile -> Space 1
- Chrome Personal profile -> Space 2
- VS Code "project-a" -> Space 1
- VS Code "project-b" -> Space 3

Orbit solves this by watching for new windows and moving them to their configured Space based on window title patterns.

## How It Works

Orbit uses a technique that simulates user input rather than calling restricted macOS APIs:

1. Detects new window creation via Accessibility API
2. Matches window title against your rules
3. "Grabs" the window (simulates mouse-down on title bar)
4. Switches Spaces via keyboard shortcut (Ctrl+Number or Ctrl+Arrow)
5. "Releases" the window in the target Space

This approach works without disabling SIP (System Integrity Protection).

## Installation

### Build from Source

```bash
git clone https://github.com/user/Orbit.git
cd Orbit
swift build -c release
```

The executable will be at `.build/release/Orbit`.

### First Run

1. Run Orbit - it will appear in your menubar
2. Grant Accessibility permission when prompted (required for window management)
3. Edit the config file at `~/.config/orbit/config.toml`
4. Reload config from the menubar menu

### Optional: Copy to PATH

```bash
cp .build/release/Orbit /usr/local/bin/
```

## Configuration

On first run, Orbit creates `~/.config/orbit/config.toml` with a sample configuration.

```toml
# Settings
[settings]
log_level = "info"  # error, warning, info, debug

# Keyboard shortcuts (must match your macOS Mission Control settings)
[shortcuts]
# Direct jump to specific space (preferred)
space_1 = "ctrl+1"
space_2 = "ctrl+2"
space_3 = "ctrl+3"
space_4 = "ctrl+4"
space_5 = "ctrl+5"

# Fallback for relative movement
space_left = "ctrl+left"
space_right = "ctrl+right"

# Window rules
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
title_pattern = "^dev-.*"    # regex pattern
space = 3

[[rules]]
app = "Visual Studio Code"
title_contains = "myproject"
space = 3
```

### Rule Format

| Field | Description |
|-------|-------------|
| `app` | Application name (display name or bundle ID) |
| `title_contains` | Simple substring match (case-insensitive) |
| `title_pattern` | Regex pattern (use one or the other, not both) |
| `space` | Target space number (1 = leftmost, 2 = next, etc.) |

### Keyboard Shortcuts

For direct jumps to work, enable "Switch to Desktop N" shortcuts in:
**System Settings > Keyboard > Keyboard Shortcuts > Mission Control**

By default, macOS has Ctrl+Arrow enabled but Ctrl+Number disabled.

## Menubar Interface

Orbit appears in your menubar with the following menu:

| Menu Item | Description |
|-----------|-------------|
| Status line | Shows rule count or error state |
| Pause/Resume | Temporarily stop watching without quitting |
| Reload Config | Re-read config.toml without restart |
| **Settings...** | Open the visual settings window (Cmd+,) |
| Open Config... | Opens config file in your default editor (Cmd+Shift+,) |
| Recent Activity | Submenu showing last 3 window moves |
| About Orbit | Version information |
| Quit | Exit the application |

## Settings Window

The Settings window provides a visual interface for configuring Orbit. Open it from the menubar menu or press Cmd+,.

### General Tab

- **Launch at Login** - Toggle automatic startup via LaunchAgent
- **Log Level** - Set logging verbosity (error, warning, info, debug)

### Shortcuts Tab

Configure keyboard shortcuts for switching spaces. These must match your system shortcuts in:
**System Settings > Keyboard > Keyboard Shortcuts > Mission Control**

- **Direct Jumps** - Shortcuts for spaces 1-9 (e.g., ctrl+1, ctrl+2)
- **Relative Movement** - Shortcuts for moving left/right (e.g., ctrl+left, ctrl+right)

### Rules Tab

Create and manage window-to-space rules visually:

- **Add** - Click + to create a new rule
- **Edit** - Select a rule and click Edit to modify it
- **Delete** - Select a rule and click - to remove it
- **Reorder** - Drag and drop rules to change their priority (first match wins)

For each rule, you can specify:
- **Application** - Name or bundle ID of the app
- **Title Matching** - Match any title, substring, or regex pattern
- **Target Space** - Which space (1-9) to move matching windows to

Click **Save** to write changes to config.toml. Click **Revert** to discard changes.

### Icon States

- **Filled icon** - Orbit is watching for windows
- **Outline icon** - Orbit is paused
- **Warning badge** - Configuration error

## Behavior

- **On launch:** Scans existing windows and applies rules
- **Ongoing:** Watches for new windows and moves them automatically
- **Manual override:** If you move a window manually, Orbit respects your choice
- **Auto-start:** Enable "Start at Login" in the menubar for automatic startup

## Troubleshooting

### Accessibility Permission

Orbit requires Accessibility permission to move windows. If not prompted:

1. Open System Settings > Privacy & Security > Accessibility
2. Add Orbit to the allowed apps
3. Restart Orbit

### Windows Not Moving

- Check that your keyboard shortcuts match System Settings > Keyboard > Shortcuts > Mission Control
- Ensure the target space exists (spaces are numbered left to right: 1, 2, 3...)
- Check the log: `log stream --predicate 'subsystem == "com.orbit.Orbit"'`
- Verify the window title matches your rule (check with title_contains or title_pattern)

### Config Not Loading

- Validate your TOML syntax (use an online TOML validator)
- Check for error message in the menubar status
- View logs for details: `log stream --predicate 'subsystem == "com.orbit.Orbit"'`
- Orbit keeps the last valid config if the new one is malformed

### Common Issues

| Issue | Solution |
|-------|----------|
| "Space not found" warning | Target space number exceeds actual space count |
| Window briefly flickers | Normal - this is the grab-and-move animation |
| Full-screen window not moving | Full-screen windows cannot be moved between spaces |
| Minimized window not moving | Minimized windows cannot be moved between spaces |
| Permission denied monthly | macOS Sequoia requires re-granting Accessibility permission |

## Limitations

- **Visual disruption:** You will briefly see the window being moved and spaces switching
- **Timing:** Each space switch takes ~300ms for the animation
- **Single monitor:** Multiple monitor support is not included in v1
- **Permissions:** macOS Sequoia requires re-granting Accessibility monthly
- **Edge cases:** Full-screen and minimized windows cannot be moved

## Requirements

- macOS 14.5+ (Sonoma or later)
- Swift 6.0+
- Accessibility permission

## Logging

Logs are written to the unified logging system. View with:

```bash
log stream --predicate 'subsystem == "com.orbit.Orbit"'
```

Or for historical logs:

```bash
log show --predicate 'subsystem == "com.orbit.Orbit"' --last 1h
```

Set log level in config.toml:

```toml
[settings]
log_level = "debug"  # error, warning, info, debug
```

## License

MIT License - Copyright (c) 2026 Lim Yu-Xi
