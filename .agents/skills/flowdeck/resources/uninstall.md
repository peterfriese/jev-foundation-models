# uninstall - Remove an Installed App

Use the top-level `uninstall` command to remove an app from a simulator or a connected device by FlowDeck app ID or bundle ID.

```bash
flowdeck uninstall <app-id>
flowdeck uninstall com.example.MyApp
flowdeck uninstall com.example.MyApp --simulator "iPhone 16"
flowdeck uninstall com.example.MyApp --device "John's iPhone"
flowdeck uninstall com.example.MyApp --examples
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<identifier>` | **Required.** App identifier (short/full ID) or bundle ID (e.g. `com.company.MyApp`). Running `uninstall` with no identifier errors with "Missing expected argument '<identifier>'". |

**Options:**
| Option | Default | Description |
|--------|---------|-------------|
| `-s, --simulator <simulator>` | Booted simulator | Simulator UDID or name |
| `-d, --device <device>` | — | Device UDID or name |
| `-j, --json` | — | Output as JSON |
| `-v, --verbose` | — | Show verbose output |
| `-e, --examples` | — | Show usage examples |

**Notes:**
- **Destructive — requires explicit user consent.** `uninstall` removes the app and its data. It is not part of the automatic validation loop; only run it when the user explicitly asks (see SKILL.md → AUTOMATION BOUNDARIES).
- If you omit both `--simulator` and `--device`, the target defaults to the currently booted simulator.
- `uninstall` is not available for macOS apps. Use `flowdeck stop <app-id>` for macOS launches.
- For physical devices, `flowdeck device uninstall <udid> <bundle-id>` is the lower-level alternative.

---
