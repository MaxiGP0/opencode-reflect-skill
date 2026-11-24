#!/usr/bin/env node
/**
 * Test the optional /reflect-skills session scanner against a fixture database.
 * Skips cleanly when node:sqlite is unavailable.
 */
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SCANNER = path.join(HERE, "..", "skill", "claude-reflect", "scripts", "recent-sessions.mjs");

let DatabaseSync;
try {
  ({ DatabaseSync } = await import("node:sqlite"));
} catch {
  console.log("SKIP  node:sqlite is unavailable on this Node.js build");
  process.exit(0);
}

const root = mkdtempSync(path.join(tmpdir(), "claude-reflect-scan-"));
const dataDir = path.join(root, "data");
const project = path.join(root, "project");
const other = path.join(root, "other");
mkdirSync(dataDir, { recursive: true });
mkdirSync(project, { recursive: true });
mkdirSync(other, { recursive: true });

try {
  const dbPath = path.join(dataDir, "opencode.db");
  const db = new DatabaseSync(dbPath);
  db.exec(`
    CREATE TABLE session_v2 (
      id TEXT PRIMARY KEY,
      directory TEXT NOT NULL,
      title TEXT
    );
    CREATE TABLE session_message (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      type TEXT NOT NULL,
      time_created INTEGER NOT NULL,
      data TEXT NOT NULL
    );
  `);

  const now = Date.now();
  const insertSession = db.prepare("INSERT INTO session_v2 (id, directory, title) VALUES (?, ?, ?)");
  insertSession.run("ses_one", project, "Project session");
  insertSession.run("ses_two", other, "Other session");

  const insertMessage = db.prepare(
    "INSERT INTO session_message (id, session_id, type, time_created, data) VALUES (?, ?, ?, ?, ?)"
  );
  insertMessage.run(
    "msg_one",
    "ses_one",
    "user",
    now - 60_000,
    JSON.stringify({ time: { created: now - 60_000 }, text: "check the release before tagging" })
  );
  insertMessage.run(
    "msg_two",
    "ses_one",
    "user",
    now - 120_000,
    JSON.stringify({ time: { created: now - 120_000 }, text: "run the pre-release checklist" })
  );
  insertMessage.run(
    "msg_three",
    "ses_two",
    "user",
    now - 30_000,
    JSON.stringify({ time: { created: now - 30_000 }, text: "this belongs to another project" })
  );
  insertMessage.run(
    "msg_four",
    "ses_one",
    "assistant",
    now - 10_000,
    JSON.stringify({ text: "assistant output must be ignored" })
  );
  db.close();

  const result = spawnSync(
    process.execPath,
    [SCANNER, "--days", "30", "--limit", "10", "--directory", project],
    {
      encoding: "utf8",
      env: { ...process.env, OPENCODE_DATA_DIR: dataDir },
    }
  );

  assert.equal(result.status, 0, result.stderr);
  const output = JSON.parse(result.stdout);
  assert.equal(output.available, true);
  assert.equal(output.directory, project);
  assert.equal(output.prompts.length, 2);
  assert.ok(output.prompts.every((prompt) => prompt.directory === project));
  assert.ok(output.prompts.some((prompt) => prompt.text.includes("release before tagging")));
  assert.ok(output.prompts.every((prompt) => !prompt.text.includes("assistant output")));
  assert.ok(output.prompts.every((prompt) => !prompt.text.includes("another project")));

  const missing = spawnSync(
    process.execPath,
    [SCANNER, "--days", "30"],
    {
      encoding: "utf8",
      env: { ...process.env, OPENCODE_DATA_DIR: path.join(root, "missing") },
    }
  );
  assert.equal(missing.status, 0, missing.stderr);
  const missingOutput = JSON.parse(missing.stdout);
  assert.equal(missingOutput.available, false);
  assert.match(missingOutput.reason, /not found/);

  console.log("OK  recent-sessions scanner reads project prompts and fails closed");
} finally {
  rmSync(root, { recursive: true, force: true });
}
