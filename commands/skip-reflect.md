---
description: Discard all queued claude-reflect learnings after explicit confirmation
---

Discard the pending claude-reflect queue. This is destructive, so confirm first.

## 1. Resolve and read

Use the shell tool to print absolute paths, then use the Read tool.

- Config root: `$OPENCODE_CONFIG_DIR` when set, otherwise `~/.config/opencode`
  (`%USERPROFILE%\.config\opencode` on Windows).
- Queue: `<config-root>/reflect-queue.json`

Read the queue file.

- If it is missing or has zero pending items, show
  `Queue is already empty. Nothing to skip.` and stop.
- If the JSON is invalid or `version` is not `1`, stop and report the problem.
  Do not overwrite the file.

## 2. Show what will be lost

Show the total count and list each pending item briefly:

- scope
- first 80 characters of `text`
- source
- captured date

Then ask exactly:

`Discard N queued learning(s)? This cannot be undone. [y/N]`

Use the question tool if available; otherwise wait for a plain-text answer.
Only `y`, `yes`, `sí`, or `si` count as confirmation. Anything else, including
silence, is a no.

## 3. Confirm or abort

If the user declines:

`Aborted. Run /reflect to process learnings instead.`

Make no changes.

If the user confirms:

1. Re-read the queue to avoid clobbering concurrent changes.
2. Write a valid empty queue with a trailing newline:

   ```json
   {
     "version": 1,
     "items": []
   }
   ```

3. Report:
   `Discarded N learning(s). Queue cleared.`

Do not delete the queue file itself; keep the empty file so the queue path
stays discoverable.
