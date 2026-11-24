#!/usr/bin/env node
/**
 * Read recent user prompts from the local OpenCode V2 database.
 *
 * Optional helper for /reflect-skills. It never writes to the database and
 * never sends data anywhere. Requires Node.js 22.5+ with node:sqlite.
 */
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import path from "node:path";

function parseArgs(argv) {
  const options = {
    days: 14,
    limit: 40,
    directory: null,
    allProjects: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--days") {
      const value = Number.parseInt(argv[++i], 10);
      if (Number.isFinite(value) && value > 0) options.days = value;
    } else if (arg === "--limit") {
      const value = Number.parseInt(argv[++i], 10);
      if (Number.isFinite(value) && value > 0) options.limit = Math.min(value, 200);
    } else if (arg === "--directory") {
      options.directory = argv[++i] ?? null;
    } else if (arg === "--all-projects") {
      options.allProjects = true;
    } else if (arg === "--help" || arg === "-h") {
      console.log(
        "Usage: node recent-sessions.mjs [--days N] [--limit N] [--directory PATH] [--all-projects]"
      );
      process.exit(0);
    }
  }

  return options;
}

function emitUnavailable(reason) {
  console.log(
    JSON.stringify(
      {
        available: false,
        reason,
        node: process.versions.node,
        hint: "Use Node.js 22.5 or newer, or analyze the current conversation instead.",
      },
      null,
      2
    )
  );
  process.exit(0);
}

function resolveDataDir() {
  if (process.env.OPENCODE_DATA_DIR) {
    return path.resolve(process.env.OPENCODE_DATA_DIR);
  }
  if (process.env.XDG_DATA_HOME) {
    return path.join(process.env.XDG_DATA_HOME, "opencode");
  }
  return path.join(homedir(), ".local", "share", "opencode");
}

function sameDirectory(left, right) {
  if (!left || !right) return false;
  const a = path.resolve(left);
  const b = path.resolve(right);
  if (process.platform === "win32") {
    return a.toLowerCase() === b.toLowerCase();
  }
  return a === b;
}

function extractText(data) {
  try {
    const parsed = JSON.parse(data);
    if (typeof parsed.text === "string") return parsed.text;
    if (typeof parsed.message === "string") return parsed.message;
  } catch {
    // Ignore malformed rows; one bad row must not break the scan.
  }
  return "";
}

function cleanText(text) {
  return text.replace(/\r\n/g, "\n").replace(/\u0000/g, "").trim();
}

const options = parseArgs(process.argv.slice(2));
const dataDir = resolveDataDir();
const dbPath = path.join(dataDir, "opencode.db");

if (!existsSync(dbPath)) {
  emitUnavailable(`OpenCode database not found at ${dbPath}`);
}

let DatabaseSync;
try {
  ({ DatabaseSync } = await import("node:sqlite"));
} catch {
  emitUnavailable(
    "node:sqlite is unavailable in this Node.js build. Node.js 22.5 or newer is required."
  );
}

const cutoff = Date.now() - options.days * 24 * 60 * 60 * 1000;
const scanLimit = Math.min(Math.max(options.limit * 25, 250), 5000);
const project = options.allProjects
  ? null
  : path.resolve(options.directory ?? process.cwd());

let db;
try {
  db = new DatabaseSync(dbPath, { readOnly: true });
} catch (error) {
  emitUnavailable(`Could not open the OpenCode database: ${error.message}`);
}

let rows;
try {
  rows = db
    .prepare(
      `SELECT sm.time_created AS created,
              sm.data AS data,
              s.directory AS directory,
              s.title AS title
         FROM session_message sm
         JOIN session_v2 s ON s.id = sm.session_id
        WHERE sm.type = 'user'
          AND sm.time_created >= ?
        ORDER BY sm.time_created DESC
        LIMIT ?`
    )
    .all(cutoff, scanLimit);
} catch (error) {
  emitUnavailable(`Could not read sessions: ${error.message}`);
} finally {
  try {
    db.close();
  } catch {
    // Ignore close errors.
  }
}

const seen = new Set();
const prompts = [];

for (const row of rows) {
  if (project && !sameDirectory(row.directory, project)) continue;

  const text = cleanText(extractText(row.data));
  if (text.length < 8 || text.length > 4000) continue;

  const key = `${row.created}\u0000${text}`;
  if (seen.has(key)) continue;
  seen.add(key);

  prompts.push({
    date: new Date(row.created).toISOString(),
    directory: row.directory,
    session: row.title || "",
    text: text.length > 1500 ? `${text.slice(0, 1500)}...` : text,
  });

  if (prompts.length >= options.limit) break;
}

console.log(
  JSON.stringify(
    {
      available: true,
      db: dbPath,
      days: options.days,
      directory: project,
      scanned: rows.length,
      returned: prompts.length,
      prompts,
    },
    null,
    2
  )
);
