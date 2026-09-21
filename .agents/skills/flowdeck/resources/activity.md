# activity - Recent CLI Activity

Shows what FlowDeck CLI commands are currently active and which recently completed, across all projects. Useful for seeing whether a build/test/run is still running and how recent commands turned out.

```bash
# Active + recent command activity (text)
flowdeck activity

# Structured snapshot
flowdeck activity --json

# Limit how many completed records are returned
flowdeck activity --limit 50 --json

# Read only the latest completed command
flowdeck activity --limit 1 --json

# Inspect active commands in automation
flowdeck activity --json | jq '.active'

flowdeck activity --examples
```

**Options:**
| Option | Description | Default |
|--------|-------------|---------|
| `--limit <limit>` | Maximum number of completed (`recent`) records to include. Affects only completed records — active commands are always returned in full. | `20` |
| `-j, --json` | Output as JSON | — |
| `-e, --examples` | Show usage examples | — |

Notes:
- `--limit` affects only the recent/completed records; active commands are always returned in full.
- `run` commands stay active after the app reaches `RUNNING` until lifecycle completion, so a launched-but-still-running app shows under `active`, not `recent`.

## JSON Output

A single object with two arrays:

- `active` — commands currently in progress.
- `recent` — completed commands, newest first, capped by `--limit`.

Each record (in either array) carries:

- `commandId` — UUID of the command.
- `action` — e.g. `build`, `run`, `test`, `clean`, `simulator`, `device`, `ui`, `config`.
- `detail` — finer-grained operation (e.g. `simulator.list`, `config.set`, `run`).
- `phase` — `started` (active) / `succeeded` / `failed` (completed).
- `projectPath` — project the command ran against.
- `branch` — git branch at the time, if available.
- `origin` — who launched it (`agent`, `macos_app`, `third_party`).
- `pid` — process id.
- `startedAt`, `lastUpdatedAt`, `finishedAt` — timestamps (`finishedAt` only on completed records).
- `cliVersion`, `cliBuildHash`, `executablePath`, `sourceProgram` — provenance of the CLI that ran it.
- `latestStage`, `latestMessage`, `latestOperation`, `latestEventType` — latest lifecycle info for in-progress commands (e.g. `RUNNING` / `Running` / `LAUNCH`); may be absent on simple commands.

Text mode prints an `Active` section (`- [action] projectPath — stage: message`) and a `Recent` section (`- [action] projectPath — phase: message`). When nothing is recorded it prints `No recent FlowDeck activity`.

## When To Use This

- Check whether a build/test/run you started is still active (look in `active`).
- Read the outcome of the last command with `--limit 1 --json` and inspect `recent[0].phase`.
- Get a quick cross-project picture of what FlowDeck has been doing recently.
- Use `flowdeck status --project <dir>` instead when you need the current build/run/test *state of one specific project* rather than recent command history.

---
