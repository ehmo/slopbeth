#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");

const root = path.resolve(__dirname, "..");
const version = require(path.join(root, "package.json")).version;

function usage() {
  console.log(`slopbeth ${version}

Usage:
  slopbeth install [target-dir]
  slopbeth doctor
  slopbeth benchmark

Default install target:
  $SLOPBETH_SKILLS_DIR/slopbeth, or ~/.codex/skills/slopbeth when the variable is unset
`);
}

function defaultTarget() {
  const base = process.env.SLOPBETH_SKILLS_DIR || path.join(os.homedir(), ".codex", "skills");
  return path.join(base, "slopbeth");
}

function copyEntry(name, target) {
  const source = path.join(root, name);
  const dest = path.join(target, name);
  if (!fs.existsSync(source)) return;
  fs.rmSync(dest, { force: true, recursive: true });
  fs.cpSync(source, dest, { recursive: true });
}

function install(target = defaultTarget()) {
  fs.mkdirSync(target, { recursive: true });
  for (const entry of ["SKILL.md", "agents", "references", "scripts", "benchmarks", "docs"]) {
    copyEntry(entry, target);
  }
  console.log(`Installed Slopbeth ${version} to ${target}`);
}

function countJsonl(file) {
  return fs.readFileSync(file, "utf8").split("\n").filter(Boolean).length;
}

function doctor() {
  const required = [
    "SKILL.md",
    "agents/openai.yaml",
    "references/evaluation.md",
    "references/slop-taxonomy.md",
    "references/density-and-unsummarizability.md",
    "references/voice-and-preservation.md",
    "benchmarks/adversarial-pack-v1.jsonl",
    "benchmarks/independent-judge-rows-v1.jsonl",
    "benchmarks/comparison-v1.md",
    "benchmarks/public-detector-panel-v1.md"
  ];

  const missing = required.filter((entry) => !fs.existsSync(path.join(root, entry)));
  if (missing.length) {
    console.error(`Missing files:\n${missing.map((m) => `- ${m}`).join("\n")}`);
    process.exit(1);
  }
  console.log(`Slopbeth ${version} package files are present.`);
}

function benchmark() {
  const pack = path.join(root, "benchmarks", "adversarial-pack-v1.jsonl");
  const judges = path.join(root, "benchmarks", "independent-judge-rows-v1.jsonl");
  const packRows = countJsonl(pack);
  const judgeRows = countJsonl(judges);
  if (packRows < 50 || judgeRows < packRows * 3) {
    console.error(`Benchmark coverage is too small: ${packRows} cases, ${judgeRows} judge rows.`);
    process.exit(1);
  }
  console.log(`Benchmark pack ready: ${packRows} adversarial cases, ${judgeRows} independent judge rows.`);
}

const [command, maybeTarget] = process.argv.slice(2);

if (!command || command === "help" || command === "--help" || command === "-h") {
  usage();
} else if (command === "install") {
  install(maybeTarget);
} else if (command === "doctor") {
  doctor();
} else if (command === "benchmark") {
  benchmark();
} else if (command === "--version" || command === "-v") {
  console.log(version);
} else {
  console.error(`Unknown command: ${command}`);
  usage();
  process.exit(1);
}
