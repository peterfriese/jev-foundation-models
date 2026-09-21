# apps - List Running Apps

List apps launched by FlowDeck, including status and identifiers.

```bash
flowdeck apps
flowdeck apps --all
flowdeck apps --prune
flowdeck apps --json
flowdeck apps --examples
```

**Options:**
| Option | Description |
|--------|-------------|
| `-a, --all` | Show all apps including stopped ones |
| `--prune` | Validate and prune stale entries |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

**Status legend (text output):**
- 🟢 Running &nbsp; 🔴 Stopped &nbsp; 💥 Crashed &nbsp; ⏸️ Waiting for debugger

Each running entry shows the bundle id, `ID` (short id), `Target`, `PID`, `Uptime`, `Scheme`, and `Type` (`simulator` / `device` / `macOS`).

**JSON Output:**
- Use `--json` for parsing/automation. To extract identifiers, pipe through `jq`:

```bash
flowdeck apps --json | jq '.[].bundleId'    # bundle IDs for logs/stop/uninstall
```

### Identifier Formats

- `id`: full UUID (e.g. `EEBA57FB-7C76-...`)
- `shortId`: first 8 hex chars of `id`, the typical CLI argument
- `bundleId`: e.g. `com.example.MyApp`

Any of the three is accepted as `<app-id>` by `logs`, `stop`, and `uninstall`.

**Next Steps:**
- `flowdeck logs <app-id>` to stream logs
- `flowdeck stop <app-id>` to stop the app
- `flowdeck uninstall <app-id>` to uninstall from a simulator or device

---
