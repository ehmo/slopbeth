#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

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

function readJsonl(file) {
  return fs.readFileSync(file, "utf8")
    .split("\n")
    .filter(Boolean)
    .map((line, index) => {
      try {
        return JSON.parse(line);
      } catch (error) {
        throw new Error(`${file}:${index + 1}: invalid JSON`);
      }
    });
}

function runCheck(command, args) {
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: "utf8",
    stdio: "pipe"
  });
  if (result.status !== 0) {
    if (result.stdout) process.stderr.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    process.exit(result.status || 1);
  }
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
    "benchmarks/benchmark-v2.jsonl",
    "benchmarks/independent-judge-rows-v2.jsonl",
    "benchmarks/span-annotations-v1.jsonl",
    "benchmarks/false-positive-tracker-v1.jsonl",
    "benchmarks/competitor-output-runs-v1.jsonl",
    "benchmarks/comparison-v1.md",
    "benchmarks/competitor-matrix-v2.md",
    "benchmarks/public-detector-panel-v1.md",
    "docs/literature-basis.md"
  ];

  const missing = required.filter((entry) => !fs.existsSync(path.join(root, entry)));
  if (missing.length) {
    console.error(`Missing files:\n${missing.map((m) => `- ${m}`).join("\n")}`);
    process.exit(1);
  }
  console.log(`Slopbeth ${version} package files are present.`);
}

function benchmark() {
  const v1Pack = path.join(root, "benchmarks", "adversarial-pack-v1.jsonl");
  const v1Judges = path.join(root, "benchmarks", "independent-judge-rows-v1.jsonl");
  const v2Pack = path.join(root, "benchmarks", "benchmark-v2.jsonl");
  const v2Judges = path.join(root, "benchmarks", "independent-judge-rows-v2.jsonl");
  const v1Rows = countJsonl(v1Pack);
  const v1JudgeRows = countJsonl(v1Judges);
  if (v1Rows < 50 || v1JudgeRows < v1Rows * 3) {
    console.error(`Benchmark v1 coverage is too small: ${v1Rows} cases, ${v1JudgeRows} judge rows.`);
    process.exit(1);
  }

  const v2Rows = readJsonl(v2Pack);
  const v2JudgeRows = readJsonl(v2Judges);
  if (v2Rows.length < 80 || v2Rows.length > 100) {
    console.error(`Benchmark v2 must contain 80-100 cases; found ${v2Rows.length}.`);
    process.exit(1);
  }
  const caseIds = new Set(v2Rows.map((row) => row.id));
  const judgesByCase = new Map();
  const scoreShapes = new Set();
  for (const row of v2JudgeRows) {
    if (!caseIds.has(row.case_id)) {
      console.error(`Judge row references unknown case: ${row.case_id}`);
      process.exit(1);
    }
    judgesByCase.set(row.case_id, (judgesByCase.get(row.case_id) || 0) + 1);
    scoreShapes.add([
      row.meaning_preservation_score,
      row.voice_score,
      row.density_score,
      row.slop_removal_score
    ].join("/"));
  }
  const underJudged = [...caseIds].filter((id) => (judgesByCase.get(id) || 0) < 3);
  if (underJudged.length) {
    console.error(`Benchmark v2 cases with fewer than three judge rows: ${underJudged.join(", ")}`);
    process.exit(1);
  }
  if (scoreShapes.size < 3) {
    console.error("Benchmark v2 judge rows are too uniform to be useful.");
    process.exit(1);
  }

  runCheck("python3", ["scripts/run_benchmark.py", "--corpus", "benchmarks/benchmark-v2.jsonl", "--summary-only", "--fail-release-gate"]);
  runCheck("python3", ["scripts/semantic_drift.py", "--corpus", "benchmarks/benchmark-v2.jsonl", "--quiet", "--fail-gate"]);
  runCheck("python3", ["scripts/signature_score.py", "--corpus", "benchmarks/benchmark-v2.jsonl", "--fail-gate", "--format", "json"]);
  runCheck("python3", ["scripts/cadence_score.py", "--corpus", "benchmarks/benchmark-v2.jsonl", "--fail-gate", "--format", "json"]);
  runCheck("python3", ["scripts/unsummarizability_check.py", "--corpus", "benchmarks/benchmark-v2.jsonl", "--fail-gate", "--require-summary-loss", "--format", "json"]);
  runCheck("python3", ["scripts/span_annotation_check.py", "--corpus", "benchmarks/benchmark-v2.jsonl", "--annotations", "benchmarks/span-annotations-v1.jsonl", "--fail-gate", "--format", "json"]);
  runCheck("python3", ["scripts/false_positive_check.py", "--tracker", "benchmarks/false-positive-tracker-v1.jsonl", "--fail-gate", "--format", "json"]);
  runCheck("python3", ["scripts/competitor_output_score.py", "--corpus", "benchmarks/benchmark-v2.jsonl", "--panel", "benchmarks/competitor-output-runs-v1.jsonl", "--fail-gate", "--format", "json"]);

  console.log(`Benchmark packs ready: ${v1Rows} v1 prompt cases, ${v2Rows.length} v2 output-bearing cases, ${v2JudgeRows.length} v2 judge rows, plus span, false-positive, cadence, and competitor-output gates.`);
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
