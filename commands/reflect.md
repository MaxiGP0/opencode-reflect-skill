---
description: Process pending claude-reflect learnings and write approved bullets to AGENTS.md
---

Process the pending learnings in the claude-reflect queue.

Arguments: `$ARGUMENTS`

Supported argument:

- `--dry-run`: show every proposed bullet and target file, then stop. Do not
  prompt, write, or change the queue.

Required approval: without `--dry-run`, do not edit any file until the user
explicitly approves the exact groups to apply.

## 1. Resolve paths

Use the shell tool to print absolute paths, then use those absolute paths with
the Read, Write, and Edit tools.

- Config root: `$OPENCODE_CONFIG_DIR` when set, otherwise `~/.config/opencode`
  (`%USERPROFILE%\.config\opencode` on Windows).
- Queue: `<config-root>/reflect-queue.json`
- Global target: `<config-root>/AGENTS.md`
- Project target: `<item.project>/AGENTS.md`, or `AGENTS.md` in the current
  working directory when an item has no `project`.

Do not guess a path. If the config root cannot be resolved, stop and report it.

## 2. Load the queue

Read `<config-root>/reflect-queue.json`.

- If the file is missing, report "No pending learnings. Use `remember: ...` to
  add one." and stop.
- If the JSON is invalid or `version` is not `1`, stop and report the problem.
  Do not rewrite the file.
- Collect only items with `status` equal to `pending`.

If there are no pending items, report that and stop. Do not create an empty
queue as a side effect.

## 3. Group duplicates

Group items that express the same rule. Use semantic grouping first, then
normalize case, surrounding whitespace, and trailing punctuation for exact
matches.

For each group, keep:

- The clearest `text`.
- The newest `date`.
- The target: global, or a specific project directory.
- The set of source ids.

If a group contains items for different targets (different projects, or a mix
of project and global), split it into one subgroup per target. Do not silently
move a project rule into the global file or the other way around.

Show a numbered table:

| # | Learning | Scope | Project | Captured | Items |
| --- | --- | --- | --- | --- | --- |

Below the table, list any items that look like secrets, one-off task state, or
non-rules. Mark them "recommend discard" but let the user decide.

## 4. Dry run

If `$ARGUMENTS` contains `--dry-run`:

1. For each group, compute the exact target file and bullet:
   `- <text> (YYYY-MM-DD)`.
2. Show the target path and the line that would be appended.
3. Show which existing bullets were detected as duplicates and would be
   skipped.
4. End with:
   `Dry run complete. Run /reflect without --dry-run to apply.`
5. Do not ask questions, write files, or modify the queue.

## 5. Ask for approval

Ask one clear question. If the question tool is available, use it. Otherwise ask
in plain text and wait for the answer.

Offer these choices:

- Apply all groups.
- Apply a subset (the user names the numbers).
- Apply nothing.
- Discard specific groups instead of keeping them pending.

A reply that does not clearly approve is a "no". Do not apply on silence or
ambiguity.

## 6. Apply approved groups

Process one target file at a time so a failure does not corrupt the rest.

1. Read the target file if it exists. If it does not exist, start with empty
   content.
2. Check for the markers:
   - `<!-- claude-reflect:start -->`
   - `<!-- claude-reflect:end -->`
3. If both markers are absent, append this block at the end of the file, with
   one blank line before it:

   ```markdown
   <!-- claude-reflect:start -->
   ## Learned Corrections (claude-reflect)

   - <text> (YYYY-MM-DD)
   <!-- claude-reflect:end -->
   ```

4. If both markers exist, replace only the content between them. Keep the
   markers and everything outside them unchanged. Keep the heading and existing
   bullets; append new bullets just before the end marker.
5. If only one marker exists, or the end marker appears before the start marker,
   stop for that file. Report the malformed section and leave the file
   untouched.
6. Skip a bullet when an equivalent bullet already exists inside the section.
   Compare case-insensitively, trim whitespace, and ignore a trailing period or
   other surrounding punctuation.
7. Use the date from the group in `YYYY-MM-DD` form. Replace line breaks in the
   text with spaces. Escape nothing else; the text is a normal Markdown bullet.

If every bullet in an approved group already exists in the target section,
treat the group as processed: report it as a duplicate and remove its items
from the queue. Do not create or rewrite the file just for a duplicate.

Preserve the file's existing line endings. Do not reformat unrelated content.
Do not create an `AGENTS.md` for a target with no approved bullets.

If a project directory no longer exists, do not create it. Keep those items
pending and report the missing path.

## 7. Update the queue

Only after all approved writes succeed:

1. Re-read the queue to avoid clobbering concurrent changes.
2. Remove the applied item ids from `items`.
3. Keep declined, recommended-discard, and failed items as `pending`.
4. Write the full queue back as valid JSON with `version` and `items`, plus a
   trailing newline.

If a write failed, keep the affected items pending and say exactly which file
failed.

## 8. Report

Finish with a short report:

- Applied: N learnings to M files.
- Skipped as duplicates: N.
- Declined or left pending: N.
- Queue now contains: N pending items.

Do not claim success for a file you did not write.
