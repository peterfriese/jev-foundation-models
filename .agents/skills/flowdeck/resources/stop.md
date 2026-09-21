# stop - Stop Running App

Terminate an app launched by FlowDeck.

```bash
flowdeck stop <app-id>
flowdeck stop com.example.MyApp
flowdeck stop --all
flowdeck stop <app-id> --force
flowdeck stop --examples
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<identifier>` | App identifier — short ID, full UUID, or bundle ID. Optional when `--all` is used; otherwise required. Get the ID from `flowdeck apps` or the output of `flowdeck run`. |

**Options:**
| Option | Description |
|--------|-------------|
| `-a, --all` | Stop all running apps |
| `-f, --force` | Force kill (`SIGKILL`) instead of graceful `SIGTERM` |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

**Notes:**
- `stop` targets a FlowDeck-launched app by its app ID (short or full) or bundle ID, not an arbitrary process.
- Default termination is `SIGTERM` (graceful shutdown); `--force` sends `SIGKILL` (immediate) for stuck apps.
- Stops both the app process and the launch process.

**Common workflows:**
```bash
flowdeck apps                 # discover app IDs
flowdeck stop abc123          # stop one app by short ID
flowdeck stop --all           # stop every running app
flowdeck stop abc123 --force  # force-kill a stuck app
flowdeck stop --all && flowdeck run   # stop all, relaunch fresh
```

---
