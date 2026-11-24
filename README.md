# opencode-reflect-skill

[![CI](https://github.com/MaxiGP0/opencode-reflect-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/MaxiGP0/opencode-reflect-skill/actions/workflows/ci.yml)

[English](README.md) | [Español](README.es.md)

An unofficial OpenCode port of **[claude-reflect](https://github.com/BayramAnnakov/claude-reflect)** by Bayram Annakov. It captures corrections and explicit "remember:" notes in a local queue, then applies the ones you approve to a marked section of `AGENTS.md`.

> This is an independent port. It is not affiliated with Bayram Annakov or with OpenCode.

## What works

| Capability | Status |
| --- | --- |
| `remember: X` capture | Yes, when the agent follows the skill |
| Capture of reusable corrections ("no, use X", "X not Y", "actually...") | Yes, agent-mediated |
| `/view-queue` | Yes |
| `/reflect` with review and approval | Yes |
| `/reflect --dry-run` | Yes |
| Duplicate grouping | Semantic by the agent, plus exact normalized matches |
| `/skip-reflect` with confirmation | Yes |
| `/reflect-skills` proposals from recent sessions | Best effort; optional local session scan |
| Automatic hook capture | **No** |
| Python dependency | **None** |
| Claude Code paths or hook files | **None in installed content** |

### Why capture is not automatic

OpenCode V2 exposes plugin hooks, but shipping one here would mean adding a plugin package and changing the user's OpenCode configuration. This project could not test that path end to end without touching a real user config, so it does not ship a hook that might silently fail.

Capture is therefore **manual or agent-mediated**: the skill tells the agent to append a queue item when you say "remember: ..." or make a reusable correction. If the session ends before the agent writes the item, that item is lost. Run `/view-queue` to confirm what was captured.

## Requirements

- [OpenCode](https://opencode.ai) V2 with skills and commands support.
- **Windows:** PowerShell 5.1 or newer (built into Windows 10/11).
- **macOS / Linux:** `bash`.
- No Python. Node.js 22.5+ is optional and only used by `/reflect-skills` to scan recent sessions.

## Install

This installer copies the port's own files from the cloned repository. It does **not** download the upstream plugin, so there is no `-Ref` / `--ref` option. To pin a version, check out a tag or commit of this repository before running the installer.

### Windows (PowerShell)

```powershell
git clone https://github.com/MaxiGP0/opencode-reflect-skill.git
cd opencode-reflect-skill
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

If you use PowerShell 7, `pwsh -File .\install.ps1` works too.

### macOS / Linux

```bash
git clone https://github.com/MaxiGP0/opencode-reflect-skill.git
cd opencode-reflect-skill
bash install.sh
```

### Custom config directory

```powershell
.\install.ps1 -ConfigDir "D:\opencode-config"
```

```bash
bash install.sh --config-dir /path/to/opencode-config
```

`OPENCODE_CONFIG_DIR` works too. The default is `~/.config/opencode` (`%USERPROFILE%\.config\opencode` on Windows).

### Update and force

Without `-Force` / `--force`, the installer refuses to run when the skill or any of the four command files already exists. Re-run with force to replace only those files:

```powershell
.\install.ps1 -Force
```

```bash
bash install.sh --force
```

The queue is preserved on update. Other commands and unrelated files are never overwritten.

## Installed files

```text
<config>/skills/claude-reflect/SKILL.md
<config>/skills/claude-reflect/scripts/recent-sessions.mjs
<config>/skills/claude-reflect/LICENSE
<config>/skills/claude-reflect/NOTICE
<config>/commands/reflect.md
<config>/commands/reflect-skills.md
<config>/commands/skip-reflect.md
<config>/commands/view-queue.md
<config>/reflect-queue.json
```

The installer creates an empty queue only when no queue exists. It does not create or edit `AGENTS.md`; `/reflect` creates the marked section when you first apply a learning.

## Verify

```powershell
.\verify.ps1
```

```bash
bash verify.sh
```

For a custom directory:

```powershell
.\verify.ps1 -ConfigDir "D:\opencode-config"
```

```bash
bash verify.sh /path/to/opencode-config
```

The verifier checks that the skill and four commands exist, that `SKILL.md` declares `name: claude-reflect` and a description, that the queue path and `AGENTS.md` markers are documented, and that no installed file contains a Claude Code path or hook file reference. It exits non-zero with a specific message on failure.

## Use it

Start a new OpenCode session after installing. The skill is discovered by its description; the commands appear as `/reflect`, `/reflect-skills`, `/skip-reflect`, and `/view-queue`.

### Capture

Say any of these during a session:

- `remember: use pnpm, not npm in this repo`
- `recordá: los tests van con Vitest`
- `no, usá pnpm en vez de npm`
- `use X not Y`
- `actually, the API returns a paginated object`

The agent should append one item to `<config>/reflect-queue.json` and confirm it. Explicit "remember:" notes are always captured; corrections are captured when they contain a reusable rule.

### Review and apply

```text
/reflect --dry-run
/reflect
```

`/reflect` loads pending items, groups duplicates, shows the proposed bullets and target files, and waits for approval. Only approved groups are written. Declined items stay pending.

Bullets go inside this section:

```markdown
<!-- claude-reflect:start -->
## Learned Corrections (claude-reflect)

- Use pnpm instead of npm in this repository. (2026-11-24)
<!-- claude-reflect:end -->
```

Project-scoped items go to the `AGENTS.md` of the item's `project` directory. Global items go to `<config>/AGENTS.md`. Content outside the markers is never changed.

### Inspect and discard

```text
/view-queue
/skip-reflect
```

`/view-queue` is read-only. `/skip-reflect` lists what would be lost and requires confirmation before writing an empty queue.

### Propose reusable commands

```text
/reflect-skills
/reflect-skills --days 30 --dry-run
```

This command looks for repeated tasks and proposes new command files. It can read recent user prompts from the local OpenCode V2 database when Node.js 22.5+ and `node:sqlite` are available. If the scanner is unavailable, it falls back to the current conversation and asks you for exported context. It never writes a command without approval.

## Queue schema

The queue is one JSON file for the whole OpenCode installation. Project scope is recorded per item.

```json
{
  "version": 1,
  "items": [
    {
      "id": "2026-11-24T18-22-05Z-7f3a",
      "text": "Use pnpm instead of npm in this repository.",
      "scope": "project",
      "source": "correction",
      "date": "2026-11-24T18:22:05Z",
      "status": "pending",
      "project": "C:\\Users\\me\\code\\my-app"
    }
  ]
}
```

| Field | Type | Rules |
| --- | --- | --- |
| `version` | number | Always `1` |
| `items` | array | May be empty |
| `id` | string | Unique; timestamp plus 4 hex characters |
| `text` | string | One standalone rule, no secrets |
| `scope` | string | `project` or `global` |
| `source` | string | `user-remember`, `correction`, `reflect-skills`, or `manual` |
| `date` | string | ISO 8601 UTC capture time |
| `status` | string | `pending` |
| `project` | string | Absolute path; required when `scope` is `project` |

Applied items are removed. Declined and failed items stay `pending`.

## How it works

1. The skill resolves the OpenCode config root and the queue path.
2. On a capture trigger, the agent reads the queue, appends a structured item, and writes it back.
3. `/reflect` groups pending items, asks for approval, and edits only the marked section of the target `AGENTS.md`.
4. `/reflect` removes applied items from the queue.
5. `/reflect-skills` optionally reads recent prompts from the local OpenCode database in read-only mode and proposes command files.

There are no Python scripts, no network calls, and no background process.

## Differences from upstream

| Upstream claude-reflect | This port |
| --- | --- |
| Claude Code plugin with hooks | OpenCode skill plus commands, no hooks |
| Automatic correction detection | Manual / agent-mediated capture |
| Python scripts | None required |
| Per-project queue under a Claude data directory | One queue in the OpenCode config root, with a `project` field |
| `CLAUDE.md`, `CLAUDE.local.md`, rules, auto memory | Project and global `AGENTS.md` only |
| Confidence scores and decay | No scores or decay |
| Semantic validation through an external model call | Agent review only |
| `--scan-history`, `--targets`, `--dedupe`, `--organize` | Not ported |
| Interactive review | Yes, through `/reflect` and `/reflect-skills` |
| Dry run | Yes, `/reflect --dry-run` |

The port favors a small, inspectable workflow over feature parity. If you need the upstream feature set, use the upstream project with Claude Code.

## Update and uninstall

Update:

```powershell
git pull
.\install.ps1 -Force
```

```bash
git pull
bash install.sh --force
```

Uninstall:

```powershell
Remove-Item -Recurse -Force "$HOME\.config\opencode\skills\claude-reflect"
Remove-Item "$HOME\.config\opencode\commands\reflect.md"
Remove-Item "$HOME\.config\opencode\commands\reflect-skills.md"
Remove-Item "$HOME\.config\opencode\commands\skip-reflect.md"
Remove-Item "$HOME\.config\opencode\commands\view-queue.md"
```

```bash
rm -rf ~/.config/opencode/skills/claude-reflect
rm -f ~/.config/opencode/commands/reflect.md \
      ~/.config/opencode/commands/reflect-skills.md \
      ~/.config/opencode/commands/skip-reflect.md \
      ~/.config/opencode/commands/view-queue.md
```

The queue and the marked `AGENTS.md` sections are left in place. Remove them manually if you want a clean slate.

## Troubleshooting

**The skill does not appear in OpenCode.** Run the verifier, confirm the config root, and start a new session. OpenCode discovers skills at session start.

**The commands do not appear.** Confirm the four files are in `<config>/commands/` and start a new session. OpenCode reloads commands on file changes, but a fresh session is the simplest check.

**Nothing was captured.** Capture depends on the agent following the skill. Check `/view-queue`; if the item is missing, add it again or write the queue item manually using the schema above.

**The queue is malformed.** Back it up, then fix the JSON or replace it with `{"version": 1, "items": []}`. The commands will not overwrite a malformed queue.

**The installer refuses to run.** It found an existing skill or command. Re-run with `-Force` / `--force`.

**PowerShell blocks the script.** Use `powershell -ExecutionPolicy Bypass -File .\install.ps1`.

**`/reflect-skills` cannot read sessions.** Install Node.js 22.5+ or use the fallback: paste or export the prompts you want analyzed. The rest of the port does not need Node.js.

**A bullet is wrong.** Edit it directly inside the marked section, or remove it. `/reflect` does not rewrite existing bullets except to avoid duplicates.

## License and attribution

- **This port:** MIT, Copyright (c) 2026 Máximo Gomez Pessoa (MaxiGP0). See [LICENSE](LICENSE).
- **Upstream claude-reflect:** MIT, Copyright (c) 2025 Bayram Annakov. See [NOTICE](NOTICE) and the [upstream repository](https://github.com/BayramAnnakov/claude-reflect).

Adapted from claude-reflect, Copyright (c) 2025 Bayram Annakov, MIT.

If the idea is useful, star the original project: [BayramAnnakov/claude-reflect](https://github.com/BayramAnnakov/claude-reflect).
