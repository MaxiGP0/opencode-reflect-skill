---
name: claude-reflect
description: Capture explicit "remember:" notes and user corrections in an OpenCode queue, then apply them to AGENTS.md with /reflect. Use when the user asks you to remember a preference, corrects you ("no, use X", "use X not Y", "actually..."), or asks about /reflect, /view-queue, /skip-reflect, or /reflect-skills.
---

# claude-reflect for OpenCode

An unofficial OpenCode port of [claude-reflect](https://github.com/BayramAnnakov/claude-reflect).
It turns corrections and explicit "remember:" notes into reviewed entries in
`AGENTS.md`.

This port is deliberately small and dependency-free:

- Capture is **manual or agent-mediated**, not a background hook. The agent
  writes queue items when the user says "remember: ..." or makes a reusable
  correction.
- `/reflect` reviews the queue and writes to a marked section of `AGENTS.md`.
- No Python is required. Every path is an OpenCode path, and every learning
  target is `AGENTS.md`.
- A separate optional capture plugin is **not** shipped. See "Limits" below.

## Paths

Resolve these paths before reading or writing anything. Use absolute paths with
the file tools.

| Purpose | Path |
| --- | --- |
| OpenCode config root | `$OPENCODE_CONFIG_DIR` when set, otherwise `~/.config/opencode` (`%USERPROFILE%\.config\opencode` on Windows) |
| Queue | `<config>/reflect-queue.json` |
| Global learnings | `<config>/AGENTS.md` |
| Project learnings | `<project>/AGENTS.md` |
| This skill | `<config>/skills/claude-reflect/SKILL.md` |

The queue is global to the OpenCode installation. Project-scoped items carry
their project directory in the `project` field, so one queue can serve every
project.

## When to capture

Capture when the user gives a rule that should change future behavior:

- Explicit markers: "remember: X", "recordá X", "tené en cuenta X",
  "from now on X", "always X", "never Y".
- Reusable corrections: "no, use pnpm", "use X not Y", "actually, the API
  returns Z", "don't edit generated files".
- A preference the user repeats or clearly wants persisted.

Do not capture:

- One-off task details, file contents, debugging state, or TODOs.
- Secrets, tokens, passwords, personal data, or anything the user marks private.
- Speculation, jokes, or positive feedback that contains no rule.
- A correction that only applies to the current sentence and has no future use.

When scope is unclear, ask one short question: "Should this apply to this
project or to all projects?" Default to `project`.

## Capture procedure

1. Resolve the queue path from the table above.
2. Read `<config>/reflect-queue.json`.
   - If it does not exist, start from `{"version": 1, "items": []}`.
   - If it exists but is not valid JSON, stop and report the problem. Never
     overwrite a malformed queue.
3. Re-read the file immediately before writing, so you do not clobber an item
   added earlier in the session.
4. Append one item using the schema below.
5. Write the whole file back as pretty-printed JSON with a trailing newline.
6. Confirm in one short line, for example:
   `Captured for /reflect (project): use pnpm instead of npm.`

Use these `source` values:

| Source | Meaning |
| --- | --- |
| `user-remember` | The user said "remember: ..." or equivalent |
| `correction` | The user corrected the agent during work |
| `reflect-skills` | A repeated pattern proposed by `/reflect-skills` |
| `manual` | Anything else the user explicitly asked to queue |

## Queue schema (version 1)

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
| `version` | number | Always `1` for this port |
| `items` | array | Queue entries; may be empty |
| `id` | string | Unique. Use `YYYY-MM-DDTHH-MM-SSZ-` plus 4 hex characters |
| `text` | string | One standalone imperative rule, one line, no secrets |
| `scope` | string | `project` or `global` |
| `source` | string | One of the source values above |
| `date` | string | ISO 8601 UTC capture time |
| `status` | string | `pending` for queued items |
| `project` | string | Absolute project directory. Required when `scope` is `project` |

On Windows, JSON-escape backslashes in `project`, for example
`"C:\\Users\\me\\code\\my-app"`.

Items stay `pending` until `/reflect` applies them or `/skip-reflect` discards
them. Applied items are removed from the queue. Declined items stay pending.

## AGENTS.md target section

Both the project file and the global file use the same marked section:

```markdown
<!-- claude-reflect:start -->
## Learned Corrections (claude-reflect)

- Use pnpm instead of npm in this repository. (2026-11-24)
<!-- claude-reflect:end -->
```

Rules:

- Read the file first. Create it only when there is at least one approved item.
- If the file has no markers, append the section at the end, with one blank
  line before the start marker.
- If the markers exist, edit **only** the text between them. Preserve
  everything outside the section byte for byte.
- If only one marker exists, or markers are out of order, stop and report the
  malformed section. Do not guess.
- Bullet format: `- <text> (YYYY-MM-DD)`. Replace line breaks in `text` with
  spaces.
- Before adding a bullet, compare it with existing bullets in the section
  (case-insensitive, ignore surrounding punctuation). Skip exact duplicates.
- Never write outside the target `AGENTS.md`, the queue, or files the user
  explicitly approves.

## Commands

| Command | Purpose |
| --- | --- |
| `/reflect` | Group pending items, ask for approval, write bullets to `AGENTS.md` |
| `/reflect --dry-run` | Show the proposed bullets and target files without writing |
| `/reflect-skills` | Propose reusable commands from recent sessions |
| `/view-queue` | List pending items without changing anything |
| `/skip-reflect` | Discard queued items after confirmation |

## Reminders

After capturing an item, mention once that `/reflect` applies it. If the queue
is non-empty at the end of a meaningful work unit, remind the user once. Do not
repeat the reminder every turn and do not run `/reflect` without being asked.

## Limits

- **No automatic hook capture.** OpenCode V2 does not expose a stable,
  testable prompt hook that this repository can install without also shipping a
  plugin and editing the user's OpenCode configuration. Instead of shipping a
  half-working hook, this port relies on the skill instructions: the agent
  queues items during the conversation. If the session ends before the agent
  writes the queue, the item is lost.
- **No Python.** All capture and processing is done with the agent's file
  tools. There are no helper scripts required by `/reflect`.
- **No confidence scores, decay, semantic model calls, rule files, or
  multi-tier memory.** The port targets project and global `AGENTS.md` only.
- **`/reflect-skills` is best effort.** It can read recent prompts from the
  local OpenCode V2 database when Node.js 22.5+ and `node:sqlite` are
  available. Otherwise it analyzes the current conversation and asks you for
  exported context.
- **Review before writing.** None of the commands apply learnings without
  explicit user approval, except that `/reflect --dry-run` writes nothing.

## Attribution

Adapted from claude-reflect, Copyright (c) 2025 Bayram Annakov, MIT.
Upstream: https://github.com/BayramAnnakov/claude-reflect

This port is unofficial and is not affiliated with the upstream author.
