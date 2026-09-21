# ai - Manage FlowDeck Skill Packs for Agents

Use `flowdeck ai` to install or remove the FlowDeck skill pack for a supported AI agent.

Skill packs are version-coupled to the FlowDeck CLI: each pack matches the CLI release it shipped with. You do not upgrade a skill pack on its own — run `flowdeck update` (see `update.md`), which updates the CLI and then aligns installed skill packs to the same version.

#### ai install-skill

Install the FlowDeck skill pack for an agent.

Both `--agent` and `--mode` are required.

```bash
flowdeck ai install-skill --agent codex --mode user
flowdeck ai install-skill --agent claude --mode project
flowdeck ai install-skill --agent codex --mode user --json
flowdeck ai install-skill --agent codex --mode user --examples
```

**Options:**
| Option | Description |
|--------|-------------|
| `--agent <agent>` | Agent to install the skill for. Values: `codex`, `claude`, `opencode`, `cursor`, `gemini`. Required. |
| `--mode <mode>` | Install mode. Values: `user`, `project`. Required. |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### ai uninstall-skill

Remove the FlowDeck skill pack for an agent. Mirrors `install-skill`: same `--agent` and `--mode` values, both required.

```bash
flowdeck ai uninstall-skill --agent codex --mode user
flowdeck ai uninstall-skill --agent claude --mode project
flowdeck ai uninstall-skill --agent codex --mode user --json
flowdeck ai uninstall-skill --agent codex --mode user --examples
```

**Options:**
| Option | Description |
|--------|-------------|
| `--agent <agent>` | Agent to uninstall the skill for. Values: `codex`, `claude`, `opencode`, `cursor`, `gemini`. Required. |
| `--mode <mode>` | Uninstall mode. Values: `user`, `project`. Required. |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

**Mode semantics:**
`--mode user` installs the skill into the agent's user-scope config (e.g. `~/.codex/`, `~/.claude/`). `--mode project` installs into the current repo's `.<agent>/` directory.

**When to Use:**
- Reinstall the FlowDeck skill pack after a CLI upgrade
- Remove the FlowDeck skill pack from a repo or user profile
- Switch between user-wide and project-local skill installation

Because skill packs are version-coupled to the CLI, the normal way to refresh a stale pack is `flowdeck update`, not a manual reinstall.

---
