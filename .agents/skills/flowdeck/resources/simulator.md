# simulator - Manage Simulators

Manage iOS, iPadOS, watchOS, tvOS, and visionOS simulators — lifecycle (list/boot/launch/shutdown/open/create/clone/delete/prune/erase/clear-cache/rename), runtimes (list/available/install/delete/prune) and in-place runtime upgrade (update), device-types, hardware buttons, appearance, content-size (Dynamic Type), increase-contrast, language/locale, orientation, status-bar overrides, location (set/clear), media, push notifications, privacy permissions, pasteboard, keychain, watch+phone pairing, app inspection (app container/info, list-apps), video recording (`record`), and frame capture (`frames` — contact sheet or full-res images).

**App lifecycle (don't reinvent it):**
- Start an app you build from a project → `flowdeck run` (add `--no-build` to launch the existing build without recompiling).
- Start an app FlowDeck did NOT build (system/pre-installed) → `flowdeck simulator launch <bundle-id> -S <udid>`.
- List running apps → `flowdeck apps`. Stop one → `flowdeck stop <app-id>` (the short/full ID from `run`/`apps`; `stop` does not take a bundle id).

#### simulator list

Lists all simulators installed on your system.

```bash
# List all simulators
flowdeck simulator list

# List only iOS simulators
flowdeck simulator list --platform iOS

# List only available simulators
flowdeck simulator list --available-only

# Output as JSON for scripting
flowdeck simulator list --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-P, --platform <platform>` | Filter by platform (iOS, tvOS, watchOS, visionOS) |
| `-A, --available-only` | Show only available simulators |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator boot

Boots a simulator so it's ready to run apps.

```bash
# Boot by UDID
flowdeck simulator boot <udid>
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<udid>` | Simulator UDID (get from 'flowdeck simulator list') |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator launch

Launch an **already-installed** app on a booted simulator **by bundle id**. Use this for
apps FlowDeck did NOT build — system apps (Contacts, Reminders, Settings) and any
pre-installed build. For apps you build from a project, use `flowdeck run` instead.

```bash
flowdeck simulator launch com.apple.MobileAddressBook -S <udid>
flowdeck simulator launch com.apple.reminders -S "iPhone 16" --json
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<bundle-id>` | App bundle identifier (e.g. `com.apple.Preferences`) |

**Options:**
| Option | Description |
|--------|-------------|
| `-S, --simulator <name-or-udid>` | Simulator UDID or name (must be booted) |
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON (returns `pid`) |

**Common system bundle ids:** Settings `com.apple.Preferences`, Contacts
`com.apple.MobileAddressBook`, Reminders `com.apple.reminders`, Clock `com.apple.mobiletimer`,
Notes `com.apple.mobilenotes`, Safari `com.apple.mobilesafari`, Maps `com.apple.Maps`.

#### simulator shutdown

Shuts down a running simulator.

```bash
# Shutdown by UDID
flowdeck simulator shutdown <udid>
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<udid>` | Simulator UDID |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator open

Opens the Simulator.app application.

```bash
flowdeck simulator open
```

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator create

Creates a new simulator with the specified device type and runtime.

```bash
flowdeck simulator create -n "My iPhone 16" --device-type "iPhone 16 Pro" --runtime "iOS 18.1"
```

**Options:**
| Option | Description |
|--------|-------------|
| `-n, --name <name>` | Name for the new simulator (required) |
| `--device-type <type>` | Device type (required) |
| `--runtime <runtime>` | Runtime (required) |
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator clone

Clones an existing simulator.

```bash
flowdeck simulator clone "iPhone 16 Pro" -n "iPhone 16 Pro Copy"
flowdeck simulator clone <UDID> -n "My Clone"
flowdeck simulator clone "iPhone 16" -n "Clone" --json
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<source>` | Source simulator UDID or name |

**Options:**
| Option | Description |
|--------|-------------|
| `-n, --name <name>` | Name for the cloned simulator (required) |
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator delete

Deletes a simulator by UDID or name.

```bash
flowdeck simulator delete <UDID>
flowdeck simulator delete "iPhone 16"
flowdeck simulator delete _ --unavailable
```

**Options:**
| Option | Description |
|--------|-------------|
| `--unavailable` | Delete all unavailable simulators |
| `-v, --verbose` | Show command output |
| `-e, --examples` | Show usage examples |

#### simulator prune

Deletes unused simulators (never booted).

```bash
flowdeck simulator prune --dry-run
flowdeck simulator prune
```

**Options:**
| Option | Description |
|--------|-------------|
| `--dry-run` | Show what would be deleted without deleting |
| `-v, --verbose` | Show verbose output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator erase

Erases all content and settings from a simulator.

```bash
flowdeck simulator erase <UDID>
flowdeck simulator erase <UDID> --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

**Note:** The simulator must be shutdown before erasing.

#### simulator clear-cache

Clears simulator caches.

```bash
flowdeck simulator clear-cache
flowdeck simulator clear-cache --verbose
```

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-e, --examples` | Show usage examples |

#### simulator device-types

Lists available simulator device types.

```bash
flowdeck simulator device-types
flowdeck simulator device-types --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

## simulator runtime - Manage Simulator Runtimes

Manage simulator runtimes (iOS, tvOS, watchOS, visionOS versions).

#### simulator runtime list

Lists all simulator runtimes installed on your system.

```bash
flowdeck simulator runtime list
flowdeck simulator runtime list --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator runtime available

List downloadable runtimes from Apple.

```bash
flowdeck simulator runtime available
flowdeck simulator runtime available --platform iOS
flowdeck simulator runtime available --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-P, --platform <platform>` | Filter by platform (iOS, tvOS, watchOS, visionOS) |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator runtime install

Download and install a simulator runtime. `runtime create` remains as a backward-compatibility alias; prefer `install`.

```bash
# Install latest iOS runtime
flowdeck simulator runtime install iOS

# Install specific version
flowdeck simulator runtime install iOS 18.0

# Install and prune auto-created simulators
flowdeck simulator runtime install iOS 18.0 --prune
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<platform>` | Platform: iOS, tvOS, watchOS, or visionOS |
| `<version>` | Version (e.g., 18.0). Omit for latest. |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `--prune` | Remove auto-created simulators after install |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator runtime delete

Remove a simulator runtime.

```bash
flowdeck simulator runtime delete "iOS 17.2"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<runtime>` | Runtime name (e.g., "iOS 17.2") or runtime identifier |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator runtime prune

Delete all simulators for a specific runtime.

```bash
flowdeck simulator runtime prune "iOS 18.0"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<runtime>` | Runtime name (e.g., "iOS 18.0") or runtime identifier |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show deleted simulator UDIDs |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator update

Upgrade an existing simulator to a newer runtime in place (wraps `simctl upgrade`).
The target runtime must already be installed. Emits a `SIMULATOR_UPDATED` catalog
wakeup on success so app destination pickers refresh.

```bash
flowdeck simulator update "iOS 18.4"
flowdeck simulator update "iOS 18.4" -S "iPhone 16"
flowdeck simulator update com.apple.CoreSimulator.SimRuntime.iOS-18-4 --json
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<runtime>` | Target runtime (friendly name like `iOS 18.4` or a full runtime identifier) |

**Options:**
| Option | Description |
|--------|-------------|
| `-S, --simulator <sim>` | Simulator name or UDID (defaults to the booted simulator) |
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator location set

Set simulator location coordinates.

```bash
flowdeck simulator location set 37.7749,-122.4194
flowdeck simulator location set 37.7749,-122.4194 --udid <UDID>
flowdeck simulator location set 37.7749,-122.4194 --json
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<lat,lon>` | Coordinates in `latitude,longitude` format |

**Options:**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID (defaults to first booted simulator) |
| `-j, --json` | Output as JSON |

#### simulator location clear

Clear a simulated location override (inverse of `location set`).

```bash
flowdeck simulator location clear
flowdeck simulator location clear --udid <UDID>
flowdeck simulator location clear --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID (defaults to first booted simulator) |
| `-j, --json` | Output as JSON |

#### simulator media add

Add media to a simulator (photos or videos).

```bash
flowdeck simulator media add /path/to/photo.jpg
flowdeck simulator media add /path/to/video.mov --udid <UDID>
flowdeck simulator media add /path/to/photo.jpg --json
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<file>` | Path to media file |

**Options:**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID (defaults to first booted simulator) |
| `-j, --json` | Output as JSON |

#### simulator record

Record a simulator video. Clean recording surface with no UI-automation
preflight. Without `--duration` it records until you press Ctrl+C.

```bash
flowdeck simulator record                              # Record until Ctrl+C → ~/Desktop
flowdeck simulator record --duration 10s               # Record 10 seconds
flowdeck simulator record --duration 5s --codec hevc   # HEVC encoding
flowdeck simulator record -S "iPhone 16" --output ~/Movies
```

**Options:**
| Option | Description |
|--------|-------------|
| `-o, --output <folder>` | Output folder (default `~/Desktop`); filename is generated automatically |
| `-S, --simulator <sim>` | Simulator name or UDID (defaults to the booted simulator) |
| `-t, --duration <Ns>` | Recording duration, e.g. `10s` (default: until Ctrl+C) |
| `--codec <codec>` | Video codec: `h264` or `hevc` |
| `--display <display>` | Display to capture when multiple are attached: `internal` or `external` |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### simulator frames

Capture simulator frames as a **contact sheet** (default) or as **individual
full-resolution images** (`--images`). Records a short video, then either tiles
every sampled frame (scaled to 30%, with a timestamp per cell) into one PNG, or
writes one full-res PNG per frame into a folder. Built for agents validating an
animation (e.g. driving the simulator from the home screen into an app).

```bash
flowdeck simulator frames                              # 3s / 5fps / 4 columns → one PNG
flowdeck simulator frames --duration 2s --fps 10       # Denser sampling
flowdeck simulator frames --columns 6 -S "iPhone 16"   # Wider grid, specific simulator
flowdeck simulator frames --images --duration 2s --fps 12   # Full-res PNG per frame, in a folder
```

**Options:**
| Option | Description |
|--------|-------------|
| `-o, --output <folder>` | Output folder (default `~/Desktop`); names are generated automatically |
| `-S, --simulator <sim>` | Simulator name or UDID (defaults to the booted simulator) |
| `-t, --duration <Ns>` | Recording duration, e.g. `2s` (default `3s`) |
| `--fps <n>` | Frames per second to sample (default 5) |
| `--columns <n>` | Grid columns in the contact sheet (default 4) |
| `--images` | Output full-resolution images (one PNG per frame) instead of a contact sheet |
| `--display <display>` | Display to capture when multiple are attached: `internal` or `external` |
| `-j, --json` | Output as JSON (includes `mode` and `frame_count`) |
| `-v, --verbose` | Show detailed output |

#### `flowdeck simulator button`

Press a hardware button on a simulator. `-S/--simulator` is recommended when more
than one simulator is booted; with a single booted sim it resolves automatically.

**Usage:** `flowdeck simulator button <button> [--hold <seconds>] [-S "<simulator>"]`

**Buttons:** `home`, `lock`, `siri`, `applepay`, `volumeup`, `volumedown`

**Options:**
| Option | Description |
|--------|-------------|
| `--hold <seconds>` | Hold duration in seconds |
| `-S, --simulator <sim>` | Simulator name or UDID |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

**Example:**
```bash
flowdeck simulator button home -S "iPhone 16"
flowdeck simulator button lock -S "iPhone 16" --hold 2
```

#### `flowdeck simulator appearance`

Get, set, or reset simulator appearance (light or dark). `get` is the default subcommand.

**Usage:**
- `flowdeck simulator appearance get -S "iPhone 16"` — returns current mode.
- `flowdeck simulator appearance set <mode> -S "iPhone 16"` — `<mode>` is `light` or `dark`.
- `flowdeck simulator appearance reset -S "iPhone 16"` — resets to the default (`light`).

#### `flowdeck simulator orientation`

Get or set simulator orientation. `get` is the default subcommand.

**Usage:**
- `flowdeck simulator orientation get -S "iPhone 16"`
- `flowdeck simulator orientation set <orientation> -S "iPhone 16"` — accepted values: `portrait`, `landscape-left`, `landscape-right`, `portrait-upside-down`. (There is no bare `landscape` — pick a side.)

#### `flowdeck simulator content-size`

Get, set, or reset the Dynamic Type (preferred content size) category. `get` is the default subcommand.

**Usage:**
- `flowdeck simulator content-size get -S "iPhone 16"`
- `flowdeck simulator content-size set <category> -S "iPhone 16"` — categories: `extra-small`, `small`, `medium`, `large`, `extra-large`, `extra-extra-large`, `extra-extra-extra-large`, `accessibility-medium`, `accessibility-large`, `accessibility-extra-large`, `accessibility-extra-extra-large`, `accessibility-extra-extra-extra-large`. `increment` / `decrement` step one category.
- `flowdeck simulator content-size reset -S "iPhone 16"` — resets to the default (`large`).

#### `flowdeck simulator increase-contrast`

Get, set, or reset the Increase Contrast accessibility setting. `get` is the default subcommand.

**Usage:**
- `flowdeck simulator increase-contrast get -S "iPhone 16"`
- `flowdeck simulator increase-contrast set <enabled|disabled> -S "iPhone 16"`
- `flowdeck simulator increase-contrast reset -S "iPhone 16"` — resets to the default (`disabled`).

#### `flowdeck simulator language`

Get, set, or reset the system language and locale. Setting/resetting reboots a booted simulator so the change applies; a shut-down simulator picks it up on next boot. `get` is the default subcommand.

**Usage:**
- `flowdeck simulator language get -S "iPhone 16"`
- `flowdeck simulator language set <lang> [-l/--locale <id>] -S "iPhone 16"` — e.g. `set fr`, `set de --locale de_DE`, or `set es-419`. Language code accepts forms like `en`, `fr`, `es-419`. Without `--locale`, the locale follows the language code.
- `flowdeck simulator language reset -S "iPhone 16"` — removes the overrides and reboots a booted target.

#### `flowdeck simulator status-bar`

Override, clear, or list status bar values (for clean screenshots). `simctl status_bar`. `list` is the default subcommand.

**Usage:**
- `flowdeck simulator status-bar override -S "iPhone 16" --time "9:41" --battery-level 100 --wifi-bars 3` — at least one flag required. Flags: `--time`, `--data-network` (`hide|wifi|3g|4g|lte|lte-a|lte+|5g|5g+|5g-uwb|5g-uc`), `--wifi-mode` (`searching|failed|active`), `--wifi-bars` (`0-3`), `--cellular-mode` (`notSupported|searching|failed|active`), `--cellular-bars` (`0-4`), `--operator-name` (`''` to clear), `--battery-state` (`charging|charged|discharging`), `--battery-level` (`0-100`).
- `flowdeck simulator status-bar clear -S "iPhone 16"`
- `flowdeck simulator status-bar list -S "iPhone 16"`

#### `flowdeck simulator push`

Send a simulated push notification from a JSON payload (`simctl push`).

**Usage:** `flowdeck simulator push <payload.json> [-b <bundle-id>] -S "iPhone 16"`

- `<payload.json>` must contain an `aps` key. `-b/--bundle-id` is optional when the payload has a `Simulator Target Bundle` key.

#### `flowdeck simulator privacy`

Grant, revoke, or reset app privacy permissions (`simctl privacy`).

**Usage:** `flowdeck simulator privacy <grant|revoke|reset> <service> [-b <bundle-id>] -S "iPhone 16"`

- Services: `all`, `calendar`, `contacts`, `contacts-limited`, `location`, `location-always`, `photos`, `photos-add`, `media-library`, `microphone`, `motion`, `reminders`, `siri`.
- `-b/--bundle-id` is required for `grant`/`revoke`; `reset` may target `all`.

#### `flowdeck simulator pasteboard`

Get, set, or clear the simulator pasteboard (`simctl pbpaste`/`pbcopy`). `get` is the default subcommand. `get` returns contents verbatim (no trimming).

**Usage:**
- `flowdeck simulator pasteboard get -S "iPhone 16"`
- `flowdeck simulator pasteboard set "<text>" -S "iPhone 16"`
- `flowdeck simulator pasteboard clear -S "iPhone 16"`

#### `flowdeck simulator keychain`

Reset the keychain or add a certificate (`simctl keychain`).

**Usage:**
- `flowdeck simulator keychain reset -S "iPhone 16"`
- `flowdeck simulator keychain add-cert <path> [--root] -S "iPhone 16"` — `--root` adds to the trusted root store instead of the keychain.

#### `flowdeck simulator app`

Inspect a single installed app (`simctl get_app_container`/`appinfo`).

**Usage:**
- `flowdeck simulator app container <bundle-id> [-c app|data|groups|<group-id>] -S "iPhone 16"` — `-c/--container` defaults to `app`.
- `flowdeck simulator app info <bundle-id> -S "iPhone 16"`

#### `flowdeck simulator list-apps`

List all installed apps on a simulator (`simctl listapps`).

**Usage:** `flowdeck simulator list-apps -S "iPhone 16"` (add `--json` for structured output)

#### `flowdeck simulator pair`

Manage watch+phone simulator pairs for WatchConnectivity testing (`simctl pair`/`unpair`/`pair_activate`). `list` is the default subcommand. Watch/phone are resolved by name or UDID; pair operations take a pair UDID.

**Usage:**
- `flowdeck simulator pair create <watch> <phone> [--activate]`
- `flowdeck simulator pair list`
- `flowdeck simulator pair activate <pair-id>`
- `flowdeck simulator pair delete <pair-id>`

#### `flowdeck simulator rename`

Rename a simulator (`simctl rename`). Emits a catalog-change wakeup so app pickers refresh.

**Usage:** `flowdeck simulator rename <simulator-or-udid> <new-name>` (add `--json` for structured output)

## Conventions and gotchas

- **Target selection differs by command family.** Lifecycle commands (`boot`, `shutdown`, `erase`, `delete`, `clone`, `rename`) take the simulator as a **positional** name-or-UDID. UI/state commands (`button`, `appearance`, `content-size`, `increase-contrast`, `language`, `orientation`, `status-bar`, `push`, `privacy`, `pasteboard`, `keychain`, `app`, `list-apps`, `record`, `frames`, `update`, `launch`) take `-S/--simulator`. The `location` and `media` groups use `-u/--udid` instead. When the flag/arg is omitted, these resolve the single booted simulator automatically; pass it explicitly when more than one sim is booted.
- **Default subcommands.** `appearance`, `content-size`, `increase-contrast`, `language`, `orientation`, and `pasteboard` default to `get`. `status-bar` defaults to `list`. `pair` defaults to `list`. So `flowdeck simulator appearance -S "iPhone 16"` is the same as `appearance get`.
- **`record` has no `--fps`; `frames` does.** `record` wraps `simctl io recordVideo`, which fixes the capture rate (no client-side resampling). `frames` extracts via AVFoundation, so `--fps` controls how densely it samples. Use `frames` when you need a known frame cadence for animation validation.
- **`update` upgrades a sim's runtime in place** (`simctl upgrade`); the target runtime must already be installed (use `runtime install` first). `runtime install` is the verb for downloading runtimes (`create` is a back-compat alias).
- **Get UDIDs for follow-ups from `list --json`.** Each entry exposes `udid`, `name`, `state` (e.g. `Booted`/`Shutdown`), and `isAvailable`. Pass the `udid` to any command that takes a positional simulator or `-S`.
- **Hidden `sim` alias.** `flowdeck sim ...` is an undocumented shorthand that maps to most `simulator` subcommands, but it omits several (including `launch`, `appearance`, `button`, and `clear-cache`). Prefer the full `flowdeck simulator ...` form so every subcommand is available.

---
