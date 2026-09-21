# device - Manage Physical Devices

Manage physical Apple devices connected via USB or WiFi: `list`, `install`, `uninstall`, `launch`.

> **`install`, `uninstall`, and `launch` take the device UDID as the first positional argument** — there is no `-d`/`--device` flag on those subcommands. Always run `flowdeck device list --json` first to get the `udid`, then pass it positionally. For everyday simulator/macOS work prefer `flowdeck run -D ...` / `flowdeck build -D ...`, which resolve the target for you.

### JSON Output Shape

`flowdeck device list --json` returns an object with `type: "device_list"` and `data.devices`. Each entry has:

- `platform` — `iOS` / `iPadOS` / `watchOS` / `tvOS` / `visionOS`
- `name` — human-readable device name
- `udid` — present for physical devices only
- `isVirtual` — `true` for `My Mac` / `My Mac Catalyst` entries; `false` for physical devices
- `isAvailable` — whether the device is currently reachable
- `connectionType` — `USB` or `Network` for physical devices

**Addressing:** physical devices use `udid` (e.g. with `flowdeck run -D <udid>`); virtual macOS targets use `name` (e.g. `flowdeck run -D "My Mac"`).

#### device list

List connected physical devices and virtual macOS targets.

```bash
flowdeck device list
flowdeck device list --platform iOS
flowdeck device list --available-only
flowdeck device list --json
flowdeck device list --examples
```

**Options:**
| Option | Description |
|--------|-------------|
| `-P, --platform <platform>` | Filter by platform: `iOS`, `iPadOS`, `watchOS`, `tvOS`, `visionOS` |
| `-A, --available-only` | Show only available devices |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

**Note:** JSON output can include virtual targets like `My Mac` and `My Mac Catalyst`.

#### device install

Install an app bundle (`.app`) on a physical device.

```bash
flowdeck device install <udid> /path/to/MyApp.app
flowdeck device install <udid> /path/to/MyApp.app --json
flowdeck device install <udid> /path/to/MyApp.app --examples
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<udid>` | Device UDID |
| `<app-path>` | Path to the `.app` bundle |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output (default: FlowDeck messages only) |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### device uninstall

Remove an installed app from a physical device.

```bash
flowdeck device uninstall <udid> com.example.MyApp
flowdeck device uninstall <udid> com.example.MyApp --json
flowdeck device uninstall <udid> com.example.MyApp --examples
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<udid>` | Device UDID |
| `<bundle-id>` | App bundle identifier |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output (default: FlowDeck messages only) |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### device launch

Launch an installed app on a physical device.

```bash
flowdeck device launch <udid> com.example.MyApp
flowdeck device launch <udid> com.example.MyApp --json
flowdeck device launch <udid> com.example.MyApp --examples
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<udid>` | Device UDID |
| `<bundle-id>` | App bundle identifier |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output (default: FlowDeck messages only) |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

**Tip:** Use `flowdeck device list --json` to get device UDIDs.

### End-to-End: Deploy and Run on a Device

```bash
flowdeck device list -A                                  # find the udid of an available device
flowdeck build -D <udid>                                 # build for that device
flowdeck device install <udid> .build/MyApp.app          # install the built .app
flowdeck device launch <udid> com.company.MyApp          # launch by bundle id
```

Or let `flowdeck run` do build + install + launch in one step:

```bash
flowdeck run -D <udid>
```

> The `flowdeck device list --examples` help text shows an older `device install MyApp.app -d "..."` form and a `device launch ... --wait-for-debugger` flag. Those do not match the current binary: `install`/`uninstall`/`launch` take `<udid>` positionally and accept only `-v`, `-j`, `-e`. Follow the contracts documented above.

### See Also

For device logs, use `flowdeck logs`. For screenshots / UI capture on a device, use `flowdeck ui` (which dispatches to the device via UDID).

---
