# config - Project Settings (Get / Set / Reset)

Manage saved project settings. Once saved, build/run/test/clean commands work without flags.

**This is the first command to run in any project.** Check if the user has saved settings before constructing commands manually.

---

## config get - Check Saved Settings

```bash
# Human-readable
flowdeck config get

# JSON output (preferred for agents)
flowdeck config get --json

# Check a different project directory
flowdeck config get -p /path/to/project
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory (defaults to current) |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

**Returns either:**
- Saved workspace, scheme, simulator/device, and configuration
- Or `No saved config found for this project.` - meaning you need to create one

**`--json` fields agents parse:**
| Field | Meaning |
|-------|---------|
| `success` | `true` when a saved config was found |
| `workspace` | Absolute path to the saved `.xcworkspace` / `.xcodeproj` |
| `scheme` | Saved scheme name |
| `configuration` | Saved build configuration (`Debug` / `Release`) |
| `target` | Human label of the saved target (simulator name, device name, or `My Mac`) |
| `targetType` | `simulator`, `device`, or `macOS` |
| `simulator` | Object with `name` and `udid`, present when the target is a simulator |
| `device` | Object with `name`, `platform`, and `udid`, present when the target is a device or `My Mac` |

The `udid` inside the `simulator` / `device` object is the resolved identifier you can hand to `-S` / `-D` on other commands. When no config exists, `success` is `false` and `workspace` is absent.

Agents should prefer `--json` and check the `success` / `workspace` fields rather than string-matching the human-readable output.

> `flowdeck config` with no subcommand prints the config command help, not the saved settings. Use `flowdeck config get` to read settings.

---

## config set - Save Settings

```bash
# iOS Simulator
flowdeck config set -w App.xcworkspace -s MyApp -S "iPhone 16"

# iOS Simulator with an .xcodeproj
flowdeck config set -w MyApp.xcodeproj -s MyApp -S "iPhone 16"

# macOS
flowdeck config set -w App.xcworkspace -s MyApp -D "My Mac"

# Physical device
flowdeck config set -w App.xcworkspace -s MyApp -D "John's iPhone"

# With build configuration
flowdeck config set -w App.xcworkspace -s MyApp -S "iPhone 16" -C Release

# Overwrite existing config (ONLY when user explicitly requests)
flowdeck config set -w App.xcworkspace -s MyApp -S "iPhone 16" --force

# JSON output
flowdeck config set -w App.xcworkspace -s MyApp -S "iPhone 16" --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory (defaults to current) |
| `-w, --workspace <path>` | Path to .xcworkspace or .xcodeproj |
| `-s, --scheme <name>` | Scheme name |
| `-C, --configuration <name>` | Build configuration (Debug/Release) |
| `-S, --simulator <name>` | Simulator name or UDID |
| `-D, --device <name>` | Device name or UDID (use 'My Mac' for macOS) |
| `-f, --force` | Re-save even if already configured |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

**After saving, use simplified commands:**
```bash
flowdeck build                # Uses saved settings
flowdeck run                  # Uses saved settings
flowdeck test                 # Uses saved settings
flowdeck clean                # Uses saved settings
```

---

## config reset - Clear Settings

```bash
# Clear saved config
flowdeck config reset

# JSON output
flowdeck config reset --json

# Different project directory
flowdeck config reset -p /path/to/project
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory (defaults to current) |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

---

## Agent Behavior Rules

1. **Always check `config get` before any build/run/test** - respect the user's saved settings
2. **If config exists** - use bare commands (`flowdeck build`, `flowdeck run`, `flowdeck test`)
3. **If no config** - discover with `flowdeck context --json`, then create one with `config set`
4. **Never use `--force`** unless the user explicitly asks to overwrite their config. `--force` is only meaningful when a config already exists and you intend to overwrite it. On a fresh project it has no effect; do not add it defensively.
5. **Never use `config reset`** unless the user explicitly asks to clear their settings
6. **Override with CLI flags** for one-off changes - flags override saved values for that invocation only

---
