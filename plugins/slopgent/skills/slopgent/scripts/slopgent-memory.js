#!/usr/bin/env node

// slopgent-memory: turn slopgent always-on by injecting a marked block into an
// agent memory file (CLAUDE.md, AGENTS.md, GEMINI.md). Idempotent and reversible.
//
//   node slopgent-memory.js enable   [--global|--project|--path <file>] [--dry-run]
//   node slopgent-memory.js disable  [--global|--project|--path <file>] [--dry-run]
//   node slopgent-memory.js status   [--global|--project|--path <file>]
//
// Default scope is --global (the per-agent home memory files). --project targets
// the memory files in the current working directory. --path targets one file.

const fs = require("fs");
const os = require("os");
const path = require("path");
const crypto = require("crypto");

const BEGIN = "<!-- BEGIN SLOPGENT";
const END = "<!-- END SLOPGENT -->";
const VERSION = 1;

// The always-on block. Kept short: it lives in the user's context every turn.
const BODY = `## Output style (slopgent)

Follow the slopgent skill in every reply to me:

- Be honest about what actually ran. Separate what you changed from what you verified. Do not report untested work as done, and do not claim a tool ran or a result was observed when it was not.
- Keep the caveat that changes my next decision. Drop only empty hedges.
- Lead with the action or answer. Number multi-step work. When something is open, end with one concrete next step.
- Plain language, no decorative jargon, but keep exact commands, paths, numbers, and error codes.
- No preamble, no closer, no apology theater.

This shapes your replies to me, not any document I ask you to edit or ship. Use slopbeth for documents.`;

function blockHash(body) {
  return crypto.createHash("sha256").update(body).digest("hex").slice(0, 8);
}

function renderBlock() {
  const hash = blockHash(BODY);
  return `${BEGIN} v:${VERSION} hash:${hash} -->\n${BODY}\n${END}`;
}

function homeTargets() {
  return [
    path.join(os.homedir(), ".claude", "CLAUDE.md"),
    path.join(os.homedir(), ".codex", "AGENTS.md"),
    path.join(os.homedir(), ".gemini", "GEMINI.md")
  ];
}

function projectTargets() {
  const cwd = process.cwd();
  return ["CLAUDE.md", "AGENTS.md", "GEMINI.md"].map((f) => path.join(cwd, f));
}

function resolveTargets(opts) {
  if (opts.path) return [path.resolve(opts.path)];
  if (opts.project) return projectTargets();
  return homeTargets();
}

// Return {found, startIdx, endIdx} for an existing block, or found:false.
function locateBlock(text) {
  const start = text.indexOf(BEGIN);
  if (start === -1) return { found: false };
  const endMarker = text.indexOf(END, start);
  if (endMarker === -1) return { found: false, malformed: true };
  return { found: true, startIdx: start, endIdx: endMarker + END.length };
}

function currentHash(text) {
  const m = text.match(/BEGIN SLOPGENT v:\d+ hash:([0-9a-f]+)/);
  return m ? m[1] : null;
}

function enableFile(file, dryRun) {
  const block = renderBlock();
  const desiredHash = blockHash(BODY);
  const exists = fs.existsSync(file);
  const text = exists ? fs.readFileSync(file, "utf8") : "";
  const loc = locateBlock(text);

  if (loc.malformed) {
    return { file, action: "error", detail: "found BEGIN marker without END; leaving file untouched" };
  }

  if (loc.found) {
    if (currentHash(text) === desiredHash) {
      return { file, action: "unchanged", detail: "already current" };
    }
    const next = text.slice(0, loc.startIdx) + block + text.slice(loc.endIdx);
    if (!dryRun) writeFile(file, next);
    return { file, action: "updated", detail: "replaced existing block" };
  }

  // Append. Ensure a blank line before the block if the file has content.
  let next;
  if (!exists || text.trim() === "") {
    next = `${block}\n`;
  } else {
    const sep = text.endsWith("\n\n") ? "" : text.endsWith("\n") ? "\n" : "\n\n";
    next = `${text}${sep}${block}\n`;
  }
  if (!dryRun) writeFile(file, next);
  return { file, action: exists ? "appended" : "created", detail: exists ? "added block" : "created file with block" };
}

function disableFile(file, dryRun) {
  if (!fs.existsSync(file)) return { file, action: "absent", detail: "no file" };
  const text = fs.readFileSync(file, "utf8");
  const loc = locateBlock(text);
  if (!loc.found) return { file, action: "absent", detail: "no slopgent block" };
  let next = text.slice(0, loc.startIdx) + text.slice(loc.endIdx);
  next = next.replace(/\n{3,}/g, "\n\n").replace(/^\n+/, "");
  if (!dryRun) writeFile(file, next);
  return { file, action: "removed", detail: "removed block" };
}

function statusFile(file) {
  if (!fs.existsSync(file)) return { file, action: "absent", detail: "no file" };
  const text = fs.readFileSync(file, "utf8");
  const loc = locateBlock(text);
  if (!loc.found) return { file, action: "off", detail: "no slopgent block" };
  const stale = currentHash(text) !== blockHash(BODY);
  return { file, action: "on", detail: stale ? "present (stale, run enable to update)" : "present (current)" };
}

function writeFile(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(`${file}.tmp`, content);
  fs.renameSync(`${file}.tmp`, file);
}

function parseArgs(argv) {
  const opts = { global: true, project: false, path: null, dryRun: false };
  for (const arg of argv) {
    if (arg === "--global") { opts.global = true; opts.project = false; }
    else if (arg === "--project") { opts.project = true; opts.global = false; }
    else if (arg === "--dry-run") opts.dryRun = true;
    else if (arg.startsWith("--path=")) opts.path = arg.slice("--path=".length);
    else if (arg === "--path") opts._expectPath = true;
    else if (opts._expectPath) { opts.path = arg; opts._expectPath = false; }
  }
  return opts;
}

function run() {
  const [command, ...rest] = process.argv.slice(2);
  const opts = parseArgs(rest);
  const targets = resolveTargets(opts);

  const fn = command === "enable" ? (f) => enableFile(f, opts.dryRun)
    : command === "disable" ? (f) => disableFile(f, opts.dryRun)
    : command === "status" ? statusFile
    : null;

  if (!fn) {
    console.error("Usage: slopgent-memory <enable|disable|status> [--global|--project|--path <file>] [--dry-run]");
    process.exit(1);
  }

  const results = targets.map(fn);
  const prefix = opts.dryRun ? "[dry-run] " : "";
  for (const r of results) {
    console.log(`${prefix}${r.action.padEnd(9)} ${r.file}  (${r.detail})`);
  }
  if (results.some((r) => r.action === "error")) process.exit(2);
}

if (require.main === module) run();

module.exports = { enableFile, disableFile, statusFile, renderBlock, blockHash, BODY };
