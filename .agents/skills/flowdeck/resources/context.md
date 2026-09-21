# context - Discover Project Structure

Inspect a project and return the workspace, schemes, build configurations, simulators, and derived data path.

```bash
flowdeck context
flowdeck context --json
flowdeck context --project /path/to/project
flowdeck context --examples
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

**What it shows:**
- If a config is saved: the selected workspace/project path
- If unconfigured: discovered projects/workspaces in the folder
- Available schemes (grouped by type)
- Workspace build configurations plus per-scheme configuration lists
- Available simulators (grouped by platform/OS)
- macOS as a build target (when the workspace supports it; addressed via `-D "My Mac"`, not as a simulator)
- Derived data path

---

## JSON Output (preferred for agents)

`flowdeck context --json` is the discovery source agents parse before building a config. Top-level fields:

| Field | Meaning |
|-------|---------|
| `workspace` | Absolute path to the workspace / project FlowDeck resolved |
| `schemes` | Array of scheme objects (see below) |
| `simulators` | Array of simulator objects (see below) |
| `buildConfigurations` | Workspace-level configurations, e.g. `["Debug", "Release"]` |
| `projects` | Per-project breakdown, each with its own `schemes`, `simulators`, and `buildConfigurations` |
| `derivedDataPath` | Absolute path to this project's DerivedData |
| `schema` / `schemaVersion` | Output contract identifiers |

Each entry in `schemes`:

| Field | Meaning |
|-------|---------|
| `name` | Scheme name — pass to `-s` on `config set` / `build` / `run` / `test` |
| `platform` | `iOS`, `macOS`, `tvOS`, `watchOS`, `visionOS` |
| `category` | Platform grouping label |
| `defaultConfiguration` | Default build configuration for the scheme |
| `availableConfigurations` | All configurations the scheme can build |
| `actionConfigurations` | Configurations bound to the scheme's run/test actions |

Each entry in `simulators`:

| Field | Meaning |
|-------|---------|
| `name` | Simulator name — pass to `-S` (or use `udid`) |
| `udid` | Resolved simulator identifier — pass to `-S` for an exact match |
| `platform` | `iOS`, `tvOS`, `watchOS`, etc. |
| `osVersion` | Runtime OS version |
| `state` | `Booted` or `Shutdown` |

```bash
# All scheme names
flowdeck context --json | jq -r '.schemes[].name'

# iOS simulators only
flowdeck context --json | jq -r '.simulators[] | select(.platform == "iOS") | .name'
```

---

## Examples

```bash
flowdeck context                          # Uses saved config if available
flowdeck context --json                   # JSON output for agents
flowdeck context -p ~/MyApp               # Inspect a different project directory
flowdeck context --project /path/to/proj
```

**Agent discovery workflow:**

1. `flowdeck context --json`
2. If multiple projects/schemes are found, choose one, then save it:
   `flowdeck config set -w <workspace> -s <scheme> -S "<simulator>"`
3. `flowdeck build` / `run` / `test` (now flag-free — see `config.md`)

---
