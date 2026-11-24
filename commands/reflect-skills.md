---
description: Propose reusable OpenCode commands from repeated tasks in recent sessions
---

Find repeated tasks in recent OpenCode sessions and propose reusable commands.
This command is a proposal flow: it does not write a command without approval.

Arguments: `$ARGUMENTS`

Supported arguments:

- `--days N`: analyze the last N days. Default `14`.
- `--directory PATH`: analyze sessions for a specific project directory.
  Default: the current working directory.
- `--all-projects`: do not filter by project directory.
- `--dry-run`: show proposals only; do not write command files.

## 1. Resolve paths

Use the shell tool to print absolute paths.

- Config root: `$OPENCODE_CONFIG_DIR` when set, otherwise `~/.config/opencode`
  (`%USERPROFILE%\.config\opencode` on Windows).
- Global commands: `<config-root>/commands/`
- Project commands: `<current-project>/.opencode/commands/`
- Session scanner:
  `<config-root>/skills/claude-reflect/scripts/recent-sessions.mjs`

Resolve the current project directory with the shell's working directory.

## 2. Gather recent user prompts

Run the optional scanner with Node.js:

```text
node "<scanner>" --days N --directory "<project>" --limit 40
```

Add `--all-projects` when the user passed `--all-projects`. The scanner prints
JSON. It reads the local OpenCode V2 database in read-only mode and returns
recent user prompts for the requested project.

Interpret the result:

- If `available` is `true`, use the returned prompts as evidence.
- If `available` is `false`, or Node.js is missing, or the scanner fails, do
  not pretend it worked. Say that recent session history is unavailable and
  fall back to:
  - the current conversation, and
  - any sessions or prompts the user pastes or exports.

Never invent session evidence. Never send session data over the network.

## 3. Check existing commands

List existing command names:

- `<config-root>/commands/*.md`
- `<current-project>/.opencode/commands/*.md`

If a proposed name already exists, do not propose a duplicate. You may propose
an update, but say so explicitly.

## 4. Analyze semantically

Look for repeated tasks that would genuinely save time:

- The same multi-step workflow requested with different wording.
- A repeated format, review, or release procedure.
- Corrections that recur and should become guardrails in a command.
- A task the user runs every day or every week.

Ignore one-off work and prompts that only share a keyword. Cite the evidence:
date plus a short quote or paraphrase. Prefer two or more independent examples.

## 5. Present proposals

Show at most five candidates. For each:

```text
1. /release-check (high confidence)
   What it does: Run the checks this project needs before a release.
   Evidence:
   - 2026-11-20: "check the release before tagging"
   - 2026-11-22: "run the pre-release checklist"
   Steps:
   1. ...
   2. ...
   Proposed file: C:\project\.opencode\commands\release-check.md
```

Include an "Existing commands" section when relevant.

If nothing repeats, say so and stop. Do not force a proposal.

## 6. Approve and write

Ask which proposals to create, and whether each belongs in the project or in
the global commands directory. Use the question tool if available; otherwise
ask in plain text and wait.

If `--dry-run` was passed, show the proposals and the exact target paths, then
stop without writing.

For each approved command:

1. If the target exists, read it and ask before overwriting.
2. Write a Markdown command with valid frontmatter and a useful body:

   ```markdown
   ---
   description: One line that explains when to run this command
   ---

   Do the task. Use $ARGUMENTS for the user's input.

   ## Steps

   1. ...
   2. ...

   ## Guardrails

   - ...
   ```

3. Use `$ARGUMENTS` when the task needs input.
4. Keep the steps concrete and based on the observed evidence.
5. Re-read the file after writing and confirm the frontmatter has a
   `description`.

## 7. Report

Report:

- commands created, with absolute paths;
- commands skipped because they already existed;
- evidence count used for each proposal.

Remind the user that OpenCode reloads commands automatically, and that the new
command is invoked as `/<name>`.
