#!/usr/bin/env node
/**
 * Exercise the documented claude-reflect queue and AGENTS.md workflow with a
 * small fixture. This is a test-only simulator, not an installed helper.
 */
import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const START = "<!-- claude-reflect:start -->";
const END = "<!-- claude-reflect:end -->";
const HERE = path.dirname(fileURLToPath(import.meta.url));

function readJson(file) {
  return JSON.parse(readFileSync(file, "utf8"));
}

function writeJson(file, value) {
  writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function normalize(text) {
  return text
    .trim()
    .replace(/\s+/g, " ")
    .replace(/[.!?;:,]+$/g, "")
    .toLowerCase();
}

function normalizeBullet(bullet) {
  return normalize(
    bullet
      .trim()
      .replace(/^-+\s*/, "")
      .replace(/\s*\(\d{4}-\d{2}-\d{2}\)\s*$/, "")
  );
}

function parseBulletKeys(body) {
  return body
    .split("\n")
    .filter((line) => line.trim().startsWith("- "))
    .map((line) => line.trim().slice(2).replace(/\s*\(\d{4}-\d{2}-\d{2}\)\s*$/, ""))
    .map(normalize);
}

function groupPending(queue) {
  const groups = new Map();
  for (const item of queue.items) {
    if (item.status !== "pending") continue;
    const key = normalize(item.text);
    const current = groups.get(key);
    if (!current) {
      groups.set(key, {
        text: item.text.trim(),
        date: item.date,
        items: [item],
      });
    } else {
      current.items.push(item);
      if (item.date > current.date) {
        current.date = item.date;
        current.text = item.text.trim();
      }
    }
  }
  return [...groups.values()];
}

function groupTarget(group) {
  if (group.items.every((item) => item.scope === "global")) return "global";
  if (
    group.items.every((item) => item.scope === "project") &&
    group.items.every(
      (item) => path.resolve(item.project).toLowerCase() === path.resolve(group.items[0].project).toLowerCase()
    )
  ) {
    return "project";
  }
  return "global";
}

function appendBullets(file, bullets) {
  let content = existsSync(file) ? readFileSync(file, "utf8") : "";
  const startIdx = content.indexOf(START);
  const endIdx = startIdx >= 0 ? content.indexOf(END, startIdx) : -1;

  if ((startIdx >= 0) !== (endIdx >= 0) || (startIdx >= 0 && endIdx < startIdx)) {
    throw new Error(`Malformed claude-reflect markers in ${file}`);
  }

  if (startIdx < 0) {
    const existing = [];
    const fresh = bullets.filter((bullet) => !existing.includes(normalizeBullet(bullet)));
    if (fresh.length === 0) return false;

    let prefix = content;
    if (prefix.length > 0 && !prefix.endsWith("\n")) prefix += "\n";
    if (prefix.length > 0 && !prefix.endsWith("\n\n")) prefix += "\n";
    const block = `${START}\n## Learned Corrections (claude-reflect)\n\n${fresh.join("\n")}\n${END}\n`;
    writeFileSync(file, prefix + block, "utf8");
    return true;
  }

  const body = content.slice(startIdx + START.length, endIdx);
  const existing = new Set(parseBulletKeys(body));
  const fresh = bullets.filter((bullet) => !existing.has(normalizeBullet(bullet)));
  if (fresh.length === 0) return false;

  let updatedBody = body;
  if (!updatedBody.endsWith("\n")) updatedBody += "\n";
  if (!updatedBody.endsWith("\n\n")) updatedBody += "\n";
  updatedBody += `${fresh.join("\n")}\n`;

  const updated = content.slice(0, startIdx + START.length) + updatedBody + content.slice(endIdx);
  writeFileSync(file, updated, "utf8");
  return true;
}

function applyQueue(queue, roots, dryRun = false) {
  const groups = groupPending(queue);
  const byTarget = new Map();

  for (const group of groups) {
    const scope = groupTarget(group);
    const target =
      scope === "global"
        ? roots.global
        : path.join(path.resolve(group.items[0].project), "AGENTS.md");
    if (!byTarget.has(target)) byTarget.set(target, []);
    byTarget.get(target).push({
      group,
      bullet: `- ${group.text} (${group.date.slice(0, 10)})`,
    });
  }

  if (dryRun) {
    return {
      groups,
      targets: [...byTarget.entries()],
      appliedIds: [],
    };
  }

  const appliedIds = [];
  for (const [file, entries] of byTarget) {
    appendBullets(
      file,
      entries.map((entry) => entry.bullet)
    );
    for (const entry of entries) {
      for (const item of entry.group.items) appliedIds.push(item.id);
    }
  }

  if (appliedIds.length > 0) {
    queue.items = queue.items.filter((item) => !appliedIds.includes(item.id));
    writeJson(roots.queue, queue);
  }

  return { groups, targets: [...byTarget.entries()], appliedIds };
}

function clearQueue(queueFile) {
  const queue = readJson(queueFile);
  const count = queue.items.filter((item) => item.status === "pending").length;
  writeJson(queueFile, { version: 1, items: [] });
  return count;
}

function prepareFixture() {
  const root = mkdtempSync(path.join(tmpdir(), "claude-reflect-test-"));
  const project = path.join(root, "project");
  const other = path.join(root, "other-project");
  const config = path.join(root, "config");
  const globalFile = path.join(config, "AGENTS.md");
  const queueFile = path.join(config, "reflect-queue.json");

  for (const dir of [project, other, config]) {
    mkdirSync(dir, { recursive: true });
  }

  const projectFile = path.join(project, "AGENTS.md");
  writeFileSync(projectFile, readFileSync(path.join(HERE, "fixtures", "AGENTS.sample.md"), "utf8"), "utf8");
  writeFileSync(
    globalFile,
    readFileSync(path.join(HERE, "fixtures", "AGENTS.global.sample.md"), "utf8"),
    "utf8"
  );

  const queueText = readFileSync(path.join(HERE, "fixtures", "queue.sample.json"), "utf8")
    .replaceAll("__PROJECT__", project.replaceAll("\\", "\\\\"))
    .replaceAll("__OTHER_PROJECT__", other.replaceAll("\\", "\\\\"));
  writeFileSync(queueFile, queueText, "utf8");

  return { root, project, other, config, projectFile, otherFile: path.join(other, "AGENTS.md"), globalFile, queueFile };
}

const fixture = prepareFixture();
try {
  const queue = readJson(fixture.queueFile);
  assert.equal(queue.version, 1);
  assert.equal(queue.items.length, 4);
  for (const item of queue.items) {
    assert.equal(typeof item.text, "string");
    assert.ok(["project", "global"].includes(item.scope));
    assert.equal(typeof item.source, "string");
    assert.equal(typeof item.date, "string");
    assert.equal(item.status, "pending");
    if (item.scope === "project") assert.equal(typeof item.project, "string");
  }

  const groups = groupPending(queue);
  assert.equal(groups.length, 3, "two pnpm items must collapse into one group");

  const projectBefore = readFileSync(fixture.projectFile, "utf8");
  const globalBefore = readFileSync(fixture.globalFile, "utf8");

  const built = applyQueue(queue, {
    global: fixture.globalFile,
    queue: fixture.queueFile,
  });
  assert.equal(built.appliedIds.length, 4);

  const projectAfter = readFileSync(fixture.projectFile, "utf8");
  assert.ok(projectAfter.startsWith(projectBefore), "content outside the section must be preserved");
  assert.equal(projectAfter.split(START).length - 1, 1);
  assert.equal(projectAfter.split(END).length - 1, 1);
  assert.equal(
    (projectAfter.match(/pnpm instead of npm/gi) || []).length,
    1,
    "duplicate learnings must produce one bullet"
  );
  assert.ok(projectAfter.includes("(2026-11-21)"), "the newest capture date wins");
  assert.ok(projectAfter.includes("## Learned Corrections (claude-reflect)"));

  const globalAfter = readFileSync(fixture.globalFile, "utf8");
  assert.ok(globalAfter.startsWith("# Global fixture rules\n"));
  assert.ok(globalAfter.includes("Keep this global note outside the managed section."));
  assert.equal(
    (globalAfter.match(/Always run tests before committing/gi) || []).length,
    1,
    "an existing global bullet must not be duplicated"
  );

  const otherAfter = readFileSync(fixture.otherFile, "utf8");
  assert.ok(otherAfter.includes("Prefer named exports in TypeScript files."));

  const queueAfter = readJson(fixture.queueFile);
  assert.equal(queueAfter.items.length, 0, "applied items must leave the queue");

  const stableProject = readFileSync(fixture.projectFile, "utf8");
  const stableGlobal = readFileSync(fixture.globalFile, "utf8");
  const stableOther = readFileSync(fixture.otherFile, "utf8");
  applyQueue(readJson(fixture.queueFile), {
    global: fixture.globalFile,
    queue: fixture.queueFile,
  });
  assert.equal(readFileSync(fixture.projectFile, "utf8"), stableProject);
  assert.equal(readFileSync(fixture.globalFile, "utf8"), stableGlobal);
  assert.equal(readFileSync(fixture.otherFile, "utf8"), stableOther);

  // Dry run on a fresh fixture must not touch files or the queue.
  const dry = prepareFixture();
  try {
    const dryQueue = readJson(dry.queueFile);
    const before = {
      project: readFileSync(dry.projectFile, "utf8"),
      global: readFileSync(dry.globalFile, "utf8"),
      queue: readFileSync(dry.queueFile, "utf8"),
    };
    const preview = applyQueue(dryQueue, { global: dry.globalFile, queue: dry.queueFile }, true);
    assert.equal(preview.groups.length, 3);
    assert.equal(preview.targets.length, 3);
    assert.equal(readFileSync(dry.projectFile, "utf8"), before.project);
    assert.equal(readFileSync(dry.globalFile, "utf8"), before.global);
    assert.equal(readFileSync(dry.queueFile, "utf8"), before.queue);
    assert.equal(readJson(dry.queueFile).items.length, 4);

    // The documented skip flow clears the queue and leaves AGENTS.md alone.
    const cleared = clearQueue(dry.queueFile);
    assert.equal(cleared, 4);
    assert.equal(readJson(dry.queueFile).items.length, 0);
    assert.equal(readFileSync(dry.projectFile, "utf8"), before.project);
    assert.equal(readFileSync(dry.globalFile, "utf8"), before.global);
  } finally {
    rmSync(dry.root, { recursive: true, force: true });
  }

  // Malformed markers must fail instead of guessing.
  const malformed = path.join(fixture.root, "malformed.md");
  writeFileSync(malformed, `# Broken\n\n${START}\n- old\n`, "utf8");
  assert.throws(() => appendBullets(malformed, ["- new (2026-11-24)"]), /Malformed/);

  console.log("OK  queue grouping, AGENTS.md markers, dry-run, skip, and malformed-marker handling");
} finally {
  rmSync(fixture.root, { recursive: true, force: true });
}
