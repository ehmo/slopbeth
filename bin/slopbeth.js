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
  slopbeth install [--all]           install into agent skill dirs (see below)
  slopbeth install <target-dir>      install into <target-dir> (see below)
  slopbeth installnpx [target-dir]   install into all supported agents (or a dir)
  slopbeth install-plugin [all|claude|codex]
  slopbeth plugin install [all|claude|codex]
  slopbeth doctor
  slopbeth benchmark
  slopbeth smoke

Default install (no arguments):
  Installs only into agent skill directories that already exist under your home
  (for example ~/.claude/skills/slopbeth). Agents you do not use are skipped.
  Add --all to install into every supported agent (Codex, Claude Code, Hermes,
  OpenClaw, OpenCode, Pi) whether or not their directories exist yet.

Custom install:
  slopbeth install /path/to/dir
  If <dir> already contains agent config dirs (.claude, .codex, .agents,
  .hermes, .openclaw, .config/opencode, .pi), Slopbeth installs into each of
  their skills/slopbeth subdirs. Otherwise <dir> is treated as the skill
  directory and files are copied directly into it.

Plugin install:
  Installs Slopbeth as a Claude Code skills-directory plugin and/or a
  Codex personal plugin with marketplace metadata.
`);
}

const installEntries = [
  "SKILL.md",
  "BENCHMARKS.md",
  "CONTRIBUTING.md",
  "SECURITY.md",
  "SUPPORT.md",
  "agents",
  "assets",
  "references",
  "scripts",
  "benchmarks",
  "docs"
];

function xdgConfigHome() {
  return process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config");
}

// Build the agent skill targets rooted at baseDir (OpenCode under xdgDir).
// Each target carries a `marker`: the agent's root dir under baseDir. Callers
// decide whether to filter by marker existence.
function agentTargets(baseDir, xdgDir) {
  const targets = [
    { agent: "codex", marker: path.join(baseDir, ".agents"), target: path.join(baseDir, ".agents", "skills", "slopbeth") },
    { agent: "codex-legacy", marker: path.join(baseDir, ".codex"), target: path.join(baseDir, ".codex", "skills", "slopbeth") },
    { agent: "claude-code", marker: path.join(baseDir, ".claude"), target: path.join(baseDir, ".claude", "skills", "slopbeth") },
    { agent: "hermes", marker: path.join(baseDir, ".hermes"), target: path.join(baseDir, ".hermes", "skills", "slopbeth") },
    { agent: "openclaw", marker: path.join(baseDir, ".openclaw"), target: path.join(baseDir, ".openclaw", "skills", "slopbeth") },
    { agent: "opencode", marker: path.join(xdgDir, "opencode"), target: path.join(xdgDir, "opencode", "skills", "slopbeth") },
    { agent: "pi", marker: path.join(baseDir, ".pi"), target: path.join(baseDir, ".pi", "agent", "skills", "slopbeth") }
  ];

  return dedupeTargets(targets);
}

function dedupeTargets(targets) {
  const seen = new Set();
  return targets.filter(({ target }) => {
    const resolved = path.resolve(target);
    if (seen.has(resolved)) return false;
    seen.add(resolved);
    return true;
  });
}

function copyEntry(name, target) {
  const source = path.join(root, name);
  const dest = path.join(target, name);
  if (!fs.existsSync(source)) return;
  fs.rmSync(dest, { force: true, recursive: true });
  fs.cpSync(source, dest, { recursive: true });
}

function installOne(target) {
  fs.mkdirSync(target, { recursive: true });
  for (const entry of installEntries) {
    copyEntry(entry, target);
  }
}

function printInstallSummary(targets, lead) {
  console.log(`${lead} ${targets.length} target${targets.length === 1 ? "" : "s"}:`);
  for (const item of targets) {
    console.log(`- ${item.agent}: ${item.target}`);
  }
}

function install(target, all) {
  if (target) {
    // If the target already contains agent config dirs, install into their
    // skills/slopbeth subdirs; otherwise treat the target as the skill dir.
    const present = agentTargets(target, path.join(target, ".config"))
      .filter(({ marker }) => fs.existsSync(marker));
    if (present.length) {
      for (const item of present) {
        installOne(item.target);
      }
      printInstallSummary(present, `Installed Slopbeth ${version} into ${target} across`);
      return;
    }
    installOne(target);
    console.log(`Installed Slopbeth ${version} to ${target}`);
    return;
  }

  let targets = agentTargets(os.homedir(), xdgConfigHome());
  if (process.env.SLOPBETH_SKILLS_DIR) {
    targets.push({
      agent: "custom",
      marker: process.env.SLOPBETH_SKILLS_DIR,
      target: path.join(process.env.SLOPBETH_SKILLS_DIR, "slopbeth")
    });
  }

  if (!all) {
    targets = targets.filter(({ agent, marker }) => agent === "custom" || fs.existsSync(marker));
    if (targets.length === 0) {
      console.log(`No known agent directories found under ${os.homedir()}.`);
      console.log("Use 'install --all' to install for every supported agent, or 'install <dir>' for a specific path.");
      return;
    }
  }

  for (const item of targets) {
    installOne(item.target);
  }
  printInstallSummary(targets, `Installed Slopbeth ${version} to`);
}

function pluginManifest(agent) {
  const base = {
    name: "slopbeth",
    version,
    description: "Remove AI-writing tells while preserving meaning, voice, and density.",
    author: {
      name: "ehmo",
      url: "https://github.com/ehmo"
    },
    homepage: "https://github.com/ehmo/slopbeth#readme",
    repository: "https://github.com/ehmo/slopbeth",
    license: "MIT",
    keywords: ["writing", "skill", "anti-slop", "editing", "rewriting"],
    skills: "./skills/"
  };

  if (agent === "claude") {
    return {
      ...base,
      displayName: "Slopbeth"
    };
  }

  return {
    ...base,
    interface: {
      displayName: "Slopbeth",
      shortDescription: "Remove AI-writing tells while preserving meaning and voice.",
      longDescription: "Slopbeth rewrites and reviews prose by preserving sourced facts, cutting unsupported claims, protecting voice, and avoiding detector-chasing tricks.",
      developerName: "ehmo",
      category: "Productivity",
      capabilities: ["Read", "Write"],
      websiteURL: "https://github.com/ehmo/slopbeth",
      defaultPrompt: [
        "Use Slopbeth to rewrite this while preserving facts, dates, numbers, uncertainty, and my voice.",
        "Use Slopbeth to review this for unsupported claims, bland-clean sentences, and AI-writing tells."
      ],
      brandColor: "#111827"
    }
  };
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(`${file}.tmp`, `${JSON.stringify(value, null, 2)}\n`);
  fs.renameSync(`${file}.tmp`, file);
}

function readJson(file, fallback) {
  if (!fs.existsSync(file)) return fallback;
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (error) {
    throw new Error(`${file}: invalid JSON: ${error.message}`);
  }
}

function installPluginSkill(target) {
  fs.rmSync(target, { force: true, recursive: true });
  fs.mkdirSync(path.join(target, "skills", "slopbeth"), { recursive: true });
  for (const entry of installEntries) {
    copyEntry(entry, path.join(target, "skills", "slopbeth"));
  }
}

function installClaudePlugin() {
  const target = path.join(os.homedir(), ".claude", "skills", "slopbeth");
  installPluginSkill(target);
  writeJson(path.join(target, ".claude-plugin", "plugin.json"), pluginManifest("claude"));
  return target;
}

function codexMarketplaceEntry() {
  return {
    name: "slopbeth",
    source: {
      source: "local",
      path: "./.codex/plugins/slopbeth"
    },
    policy: {
      installation: "INSTALLED_BY_DEFAULT",
      authentication: "ON_INSTALL"
    },
    category: "Productivity",
    interface: {
      displayName: "Slopbeth",
      shortDescription: "Remove AI-writing tells while preserving meaning and voice."
    }
  };
}

function updateCodexMarketplace() {
  const marketplaceFile = path.join(os.homedir(), ".agents", "plugins", "marketplace.json");
  const marketplace = readJson(marketplaceFile, {
    name: "personal-plugins",
    interface: {
      displayName: "Personal Plugins"
    },
    plugins: []
  });

  if (!Array.isArray(marketplace.plugins)) {
    marketplace.plugins = [];
  }

  marketplace.plugins = marketplace.plugins.filter((plugin) => plugin && plugin.name !== "slopbeth");
  marketplace.plugins.push(codexMarketplaceEntry());
  writeJson(marketplaceFile, marketplace);
  return marketplaceFile;
}

function installCodexPlugin() {
  const target = path.join(os.homedir(), ".codex", "plugins", "slopbeth");
  installPluginSkill(target);
  writeJson(path.join(target, ".codex-plugin", "plugin.json"), pluginManifest("codex"));
  const marketplaceFile = updateCodexMarketplace();

  for (const staleTarget of [
    path.join(os.homedir(), ".agents", "skills", "slopbeth"),
    path.join(os.homedir(), ".codex", "skills", "slopbeth")
  ]) {
    fs.rmSync(staleTarget, { force: true, recursive: true });
  }

  return { target, marketplaceFile };
}

function installPlugins(which = "all") {
  const normalized = (which || "all").toLowerCase();
  if (!["all", "claude", "codex"].includes(normalized)) {
    console.error(`Unknown plugin target: ${which}`);
    usage();
    process.exit(1);
  }

  const installed = [];
  if (normalized === "all" || normalized === "claude") {
    installed.push({ agent: "claude-code", target: installClaudePlugin() });
  }
  if (normalized === "all" || normalized === "codex") {
    const result = installCodexPlugin();
    installed.push({ agent: "codex", target: result.target });
    installed.push({ agent: "codex-marketplace", target: result.marketplaceFile });
  }

  console.log(`Installed Slopbeth ${version} plugin support:`);
  for (const item of installed) {
    console.log(`- ${item.agent}: ${item.target}`);
  }
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
    "BENCHMARKS.md",
    "CODE_OF_CONDUCT.md",
    "CONTRIBUTING.md",
    "LICENSE",
    "README.md",
    "SECURITY.md",
    "SKILL.md",
    "SUPPORT.md",
    ".agents/plugins/marketplace.json",
    ".claude-plugin/marketplace.json",
    "assets/slopbeth.png",
    "agents/claude-code.yaml",
    "agents/codex.yaml",
    "agents/hermes.yaml",
    "agents/openclaw.yaml",
    "agents/openai.yaml",
    "agents/opencode.yaml",
    "agents/pi.yaml",
    "references/evaluation.md",
    "references/slop-taxonomy.md",
    "references/density-and-unsummarizability.md",
    "references/voice-and-preservation.md",
    "benchmarks/benchmark-v2.jsonl",
    "benchmarks/independent-judge-rows-v2.jsonl",
    "benchmarks/span-annotations-v1.jsonl",
    "benchmarks/false-positive-tracker-v1.jsonl",
    "benchmarks/competitor-output-runs-v1.jsonl",
    "benchmarks/competitor-agent-runs-v1.jsonl",
    "benchmarks/score-snapshot.md",
    "benchmarks/competitor-matrix-v2.md",
    "benchmarks/public-detector-panel-v1.md",
    "docs/branch-protection.md",
    "docs/false-positive-tracker.md",
    "docs/literature-basis.md",
    "bin/slopbeth.ps1",
    "plugins/slopbeth/.claude-plugin/plugin.json",
    "plugins/slopbeth/.codex-plugin/plugin.json",
    "plugins/slopbeth/skills/slopbeth/SKILL.md",
    "scripts/Compare-Preservation.ps1",
    "scripts/Get-DensityReport.ps1",
    "scripts/Measure-Deslop.ps1",
    "scripts/Run-Benchmark.ps1",
    "scripts/SlopBeth.Common.ps1",
    "scripts/Test-Install.ps1",
    "scripts/attribution_scan.py",
    "scripts/ci_secret_scan.py",
    "scripts/score_snapshot.py"
  ];

  const missing = required.filter((entry) => !fs.existsSync(path.join(root, entry)));
  if (missing.length) {
    console.error(`Missing files:\n${missing.map((m) => `- ${m}`).join("\n")}`);
    process.exit(1);
  }
  console.log(`Slopbeth ${version} package files are present.`);
}

function benchmark() {
  const v2Pack = path.join(root, "benchmarks", "benchmark-v2.jsonl");
  const v2Judges = path.join(root, "benchmarks", "independent-judge-rows-v2.jsonl");

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
  runCheck("python3", ["scripts/competitor_output_score.py", "--corpus", "benchmarks/benchmark-v2.jsonl", "--panel", "benchmarks/competitor-agent-runs-v1.jsonl", "--min-competitors", "5", "--min-cases", "25", "--min-slopbeth-case-win-rate", "0.7", "--fail-gate", "--format", "json"]);

  console.log(`Benchmark pack ready: ${v2Rows.length} v2 output-bearing cases, ${v2JudgeRows.length} v2 judge rows, plus span, false-positive, cadence, competitor-output, and competitor-agent gates.`);
}

function smoke() {
  runCheck("python3", ["scripts/install_smoke.py"]);
  console.log(`Slopbeth ${version} install smoke passed.`);
}

const [command, maybeTarget, extraTarget] = process.argv.slice(2);

if (!command || command === "help" || command === "--help" || command === "-h") {
  usage();
} else if (command === "install" || command === "installnpx") {
  let all = command === "installnpx";
  let target = null;
  for (const arg of [maybeTarget, extraTarget]) {
    if (!arg) continue;
    if (arg === "--all" || arg === "-a" || arg === "-All" || arg === "-all") all = true;
    else target = arg;
  }
  install(target, all);
} else if (command === "install-plugin" || command === "plugin-install" || command === "install-plugins") {
  installPlugins(maybeTarget);
} else if (command === "plugin" && maybeTarget === "install") {
  installPlugins(extraTarget);
} else if (command === "doctor") {
  doctor();
} else if (command === "benchmark") {
  benchmark();
} else if (command === "smoke") {
  smoke();
} else if (command === "--version" || command === "-v") {
  console.log(version);
} else {
  console.error(`Unknown command: ${command}`);
  usage();
  process.exit(1);
}
