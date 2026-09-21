# update - Update FlowDeck CLI to the Latest Version

Update the FlowDeck CLI to the latest released version.

`flowdeck update` updates the CLI first, then aligns the skill packs to the same version. Skill packs are version-coupled to the CLI, so this is the normal way to refresh them — do not reinstall packs by hand to "upgrade" them (see `ai.md`).

```bash
# Check for an update without installing anything
flowdeck update --check

# Update the CLI (and align skill packs) to the latest version
flowdeck update

# Machine-readable output
flowdeck update --json
flowdeck update --check --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `--check` | Check for updates without installing |
| `-j, --json` | Output as JSON |

There is no `--examples` flag on this command.

**Skill pack alignment:** After updating the CLI, `flowdeck update` brings project-scoped skill packs to the matching version automatically. User-level (`--mode user`) skill packs are only **notified about**, never auto-updated — when a user-level pack is out of date, the CLI reports it and the user reinstalls it with `flowdeck ai install-skill --agent <agent> --mode user` (see `ai.md`).

---
