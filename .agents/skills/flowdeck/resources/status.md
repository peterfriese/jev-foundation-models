# status - Current Project Status Snapshot

Shows a point-in-time snapshot of a project's build/run/test state: whether a command is in progress for that project, and whether an app is currently running. This is the macOS app's main reconciliation surface; an agent can poll it to know if a build/run/test is active and what the latest result was.

Output is always JSON — `--json` is accepted but the snapshot is JSON regardless. Pipe through `jq` for a friendlier view. `--project` is required (there is no current-status view without a project directory).

```bash
# Snapshot for a project
flowdeck status --project ~/App

# Same, scoped to the cycle (build/run/test/clean) state
flowdeck status --project ~/App --json | jq '.cycle'

# Just the active run, if any
flowdeck status --project ~/App --json | jq '.cycle.activeRun'

flowdeck status --examples
```

**Options:**
| Option | Description | Default |
|--------|-------------|---------|
| `-p, --project <project>` | Project directory (required). Accepts `~` and relative paths. | — |
| `-j, --json` | Output as JSON (output is JSON regardless) | — |
| `-e, --examples` | Show usage examples | — |

Running `flowdeck status` without `--project` (and without `--examples`) prints a validation error and the usage text; it does not emit a snapshot.

## JSON Output

A single object with `schema: "flowdeck.status"` and `schemaVersion`. Top-level fields:

- `projectPath` — resolved absolute path of the queried project.
- `branch` — current git branch of that project, or absent if not a repo.
- `generatedAt` — timestamp the snapshot was produced.
- `activity` — the project's single active command, if any (see below).
- `cycle` — the active build/run/test/clean run and any running app (see below).

When the project is idle, `activity` and `cycle` are present but empty objects (`{}`); there is no `activeCommand`, `activeRun`, or `runningApp` key. This is the "nothing in progress" signal.

### `activity.activeCommand`

Present only when a command is currently running for this project (any action). Fields:

- `commandId` — UUID of the command.
- `action` — e.g. `build`, `run`, `test`, `clean`, `simulator`, `ui`, `config`.
- `state` — `idle` / `running` / `succeeded` / `failed`.
- `stage` — latest lifecycle stage string (e.g. `RUNNING`, `LAUNCH`), if reported.
- `userMessage` / `message` — human-readable status (e.g. `Running`, `Building`).
- `errorMessage` — failure detail, if any.
- `origin` — who launched it (`agent`, `macos_app`, `third_party`).
- `sourceProgram`, `detail`, `pid`, `startedAt`, `updatedAt`, `finishedAt`.

### `cycle`

The build/run/test/clean view of the project. Fields:

- `activeRun` — same shape as `activeCommand`, but restricted to `build` / `run` / `test` / `clean` actions. Present only when one of those is in progress.
- `runningApp` — the most recently launched app still alive for this project, validated against its live PID. Same shape as a `flowdeck apps` entry (`id`, `shortId`, `bundleId`, `scheme`, `targetName`, `launchType`, `status`, `appPid`, `uptime`). Stale `running` entries are reconciled to exited/crashed/stopped before returning, so this reflects current reality.

## When To Use This

- Before starting a build/run/test, poll `cycle.activeRun` to avoid stomping an in-progress cycle for the same project.
- After kicking off work, poll until `activeRun`/`activeCommand` clears (idle) and read `state` (`succeeded` / `failed`) for the outcome.
- Check `cycle.runningApp` to know if the app is already launched (and get its app-id for `flowdeck logs` / `flowdeck stop`).
- Use `flowdeck activity` instead when you want recent command *history* across projects rather than one project's current state.

---
