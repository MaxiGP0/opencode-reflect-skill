---
description: Show pending claude-reflect learnings without processing or changing the queue
---

Show the current claude-reflect queue in a readable form. This command is
read-only.

Arguments: `$ARGUMENTS` (optional; ignored)

## 1. Resolve the queue

Use the shell tool to print absolute paths, then use the Read tool.

- Config root: `$OPENCODE_CONFIG_DIR` when set, otherwise `~/.config/opencode`
  (`%USERPROFILE%\.config\opencode` on Windows).
- Queue: `<config-root>/reflect-queue.json`

## 2. Read and validate

Read the queue file.

- If it does not exist, show:
  `Queue: <path>` and `No learnings queued. Use "remember: <learning>" to add
  items.`
- If the JSON is invalid or `version` is not `1`, show the path and the parse
  error. Do not repair or overwrite the file.
- Collect items with `status` equal to `pending`.

Do not write anything.

## 3. Display

Show:

1. The absolute queue path.
2. Total pending count, split by `project` and `global`.
3. A numbered list sorted by date, oldest first. For each item show:
   - number
   - scope
   - text
   - source
   - captured date
   - project path for project-scoped items

Example:

```text
Queue: C:\Users\me\.config\opencode\reflect-queue.json

Pending: 3 (project 2, global 1)

1. [project] Use pnpm instead of npm in this repository.
   source: correction | captured: 2026-11-21 | project: C:\Users\me\code\app
2. [global] Always run tests before committing.
   source: user-remember | captured: 2026-11-22
```

If the queue is empty, say so and show the available commands:

```text
/reflect        Process and save learnings
/reflect --dry-run  Preview without writing
/skip-reflect   Discard all queued learnings
```

Do not group, merge, apply, or discard items. Do not run `/reflect`.
