#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const root = path.resolve(__dirname, "..");
const version = require(path.join(root, "package.json")).version;

// --- Skill registry -------------------------------------------------------
// slopkit ships two skills that install by the same means. Each ships from
// skills/<name>/ (the installer's source of truth) and mirrors into
// plugins/<name>/skills/<name>/ for plugin installs. installEntries lists the
// top-level files/dirs copied into an install target; copyEntry no-ops on any
// entry a given skill does not carry, so the copy loop is shared.

const SKILLS = [
  {
    name: "slopbeth",
    displayName: "Slopbeth",
    description: "Remove AI-writing tells while preserving meaning, voice, and density.",
    keywords: ["writing", "skill", "anti-slop", "editing", "rewriting"],
    installEntries: [
      "SKILL.md",
      "README.md",
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
    ],
    marketplaceShort: "Remove AI-writing tells while preserving meaning and voice.",
    codexInterface: {
      shortDescription: "Remove AI-writing tells while preserving meaning and voice.",
      longDescription: "Slopbeth rewrites and reviews prose by preserving sourced facts, cutting unsupported claims, protecting voice, and avoiding detector-chasing tricks.",
      developerName: "ehmo",
      category: "Productivity",
      capabilities: ["Read", "Write"],
      websiteURL: "https://github.com/ehmo/slopkit",
      defaultPrompt: [
        "Use Slopbeth to rewrite this while preserving facts, dates, numbers, uncertainty, and my voice.",
        "Use Slopbeth to review this for unsupported claims, bland-clean sentences, and AI-writing tells."
      ],
      brandColor: "#111827"
    },
    doctorFiles: [
      "skills/slopbeth/README.md",
      "skills/slopbeth/BENCHMARKS.md",
      "skills/slopbeth/CONTRIBUTING.md",
      "skills/slopbeth/SECURITY.md",
      "skills/slopbeth/SKILL.md",
      "skills/slopbeth/SUPPORT.md",
      "skills/slopbeth/assets/slopbeth.png",
      "skills/slopbeth/agents/claude-code.yaml",
      "skills/slopbeth/agents/codex.yaml",
      "skills/slopbeth/agents/hermes.yaml",
      "skills/slopbeth/agents/openclaw.yaml",
      "skills/slopbeth/agents/openai.yaml",
      "skills/slopbeth/agents/opencode.yaml",
      "skills/slopbeth/agents/pi.yaml",
      "skills/slopbeth/references/evaluation.md",
      "skills/slopbeth/references/slop-taxonomy.md",
      "skills/slopbeth/references/density-and-unsummarizability.md",
      "skills/slopbeth/references/voice-and-preservation.md",
      "skills/slopbeth/references/writing-system.md",
      "skills/slopbeth/benchmarks/benchmark-v2.jsonl",
      "skills/slopbeth/benchmarks/orwell-writing-system-v1.jsonl",
      "skills/slopbeth/benchmarks/independent-judge-rows-v2.jsonl",
      "skills/slopbeth/benchmarks/span-annotations-v1.jsonl",
      "skills/slopbeth/benchmarks/false-positive-tracker-v1.jsonl",
      "skills/slopbeth/benchmarks/competitor-output-runs-v1.jsonl",
      "skills/slopbeth/benchmarks/competitor-agent-runs-v1.jsonl",
      "skills/slopbeth/benchmarks/score-snapshot.md",
      "skills/slopbeth/benchmarks/competitor-matrix-v2.md",
      "skills/slopbeth/benchmarks/public-detector-panel-v1.md",
      "skills/slopbeth/docs/branch-protection.md",
      "skills/slopbeth/docs/false-positive-tracker.md",
      "skills/slopbeth/docs/literature-basis.md",
      "skills/slopbeth/scripts/Compare-Preservation.ps1",
      "skills/slopbeth/scripts/Get-DensityReport.ps1",
      "skills/slopbeth/scripts/Measure-Deslop.ps1",
      "skills/slopbeth/scripts/Measure-Orwell.ps1",
      "skills/slopbeth/scripts/Measure-OrwellBenchmark.ps1",
      "skills/slopbeth/scripts/Run-Benchmark.ps1",
      "skills/slopbeth/scripts/SlopBeth.Common.ps1",
      "skills/slopbeth/scripts/Test-Install.ps1",
      "skills/slopbeth/scripts/attribution_scan.py",
      "skills/slopbeth/scripts/ci_secret_scan.py",
      "skills/slopbeth/scripts/orwell_lint.py",
      "skills/slopbeth/scripts/orwell_benchmark.py",
      "skills/slopbeth/scripts/score_snapshot.py"
    ],
    benchmark: benchmarkSlopbeth
  },
  {
    name: "slopgent",
    displayName: "Slopgent",
    description: "Shape the agent's own replies so they are honest about what ran, action-first, and plain — without dropping load-bearing precision.",
    keywords: ["conversation", "skill", "anti-slop", "honesty", "agent-replies"],
    installEntries: [
      "SKILL.md",
      "README.md",
      "agents",
      "scripts",
      "benchmarks"
    ],
    marketplaceShort: "Honest, action-first, plain agent replies.",
    codexInterface: {
      shortDescription: "Honest, action-first, plain agent replies.",
      longDescription: "Slopgent shapes the agent's own replies to the user — status reports, explanations, errors, completion claims — so they are honest about what actually ran, lead with the action, and stay plain, without dropping load-bearing precision or real uncertainty. It does not rewrite the user's text; that is slopbeth.",
      developerName: "ehmo",
      category: "Productivity",
      capabilities: ["Read", "Write"],
      websiteURL: "https://github.com/ehmo/slopkit",
      defaultPrompt: [
        "Use Slopgent to keep your replies honest about what actually ran, action-first, and plain.",
        "Turn on Slopgent and shape every reply until I say stop slopgent."
      ],
      brandColor: "#0B3D2E"
    },
    doctorFiles: [
      "skills/slopgent/SKILL.md",
      "skills/slopgent/README.md",
      "skills/slopgent/agents/claude-code.yaml",
      "skills/slopgent/agents/codex.yaml",
      "skills/slopgent/agents/hermes.yaml",
      "skills/slopgent/agents/openai.yaml",
      "skills/slopgent/agents/openclaw.yaml",
      "skills/slopgent/agents/opencode.yaml",
      "skills/slopgent/agents/pi.yaml",
      "skills/slopgent/scripts/comms_lint.py",
      "skills/slopgent/scripts/slopgent-memory.js",
      "skills/slopgent/benchmarks/corpus.jsonl",
      "skills/slopgent/benchmarks/corpus_gates.jsonl",
      "skills/slopgent/benchmarks/decoys.jsonl",
      "skills/slopgent/benchmarks/run_comms_benchmark.py",
      "skills/slopgent/benchmarks/decoy_rejection.py",
      "skills/slopgent/benchmarks/README.md",
      "skills/slopgent/benchmarks/judge/judge_aggregate.py"
    ],
    benchmark: benchmarkSlopgent
  }
];

const skillNames = SKILLS.map((s) => s.name).join(", ");

function skillRootOf(skill) {
  return path.join(root, "skills", skill.name);
}

function usage() {
  console.log(`slopkit ${version}

slopkit ships two anti-slop skills that install by the same means:
  slopbeth  cleans the writing you ship (rewrites and reviews an artifact)
  slopgent  cleans the conversation (shapes the agent's own replies)

Usage:
  slopkit install [--all]            install into agent skill dirs (see below)
  slopkit install <target-dir>       install into <target-dir> (see below)
  slopkit installnpx [target-dir]    install into all supported agents (or a dir)
  slopkit install-plugin [all|claude|codex]
  slopkit plugin install [all|claude|codex]
  slopkit doctor
  slopkit benchmark
  slopkit smoke

Default install (no arguments):
  Installs both skills only into agent skill directories that already exist
  under your home (for example ~/.claude/skills/). Agents you do not use are
  skipped. Add --all to install into every supported agent (Codex, Claude Code,
  Hermes, OpenClaw, OpenCode, Pi) whether or not their directories exist yet.
  Both skills land as sibling subdirs (skills/slopbeth and skills/slopgent).

Custom install:
  slopkit install /path/to/dir
  If <dir> already contains agent config dirs (.claude, .codex, .agents,
  .hermes, .openclaw, .config/opencode, .pi), slopkit installs both skills into
  each of their skills/ subdirs. Otherwise <dir> is treated as a skills parent
  and both skills are written into <dir>/slopbeth and <dir>/slopgent.

Plugin install:
  Installs both skills as Claude Code skills-directory plugins and/or Codex
  personal plugins with marketplace metadata.
`);
}

function xdgConfigHome() {
  return process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config");
}

// Agent skills-parent directories rooted at baseDir (OpenCode under xdgDir).
// Each carries a `marker`: the agent's root dir under baseDir. Callers decide
// whether to filter by marker existence. Both skills install as subdirs of
// `skillsDir`.
function agentSkillDirs(baseDir, xdgDir) {
  const dirs = [
    { agent: "codex", marker: path.join(baseDir, ".agents"), skillsDir: path.join(baseDir, ".agents", "skills") },
    { agent: "codex-legacy", marker: path.join(baseDir, ".codex"), skillsDir: path.join(baseDir, ".codex", "skills") },
    { agent: "claude-code", marker: path.join(baseDir, ".claude"), skillsDir: path.join(baseDir, ".claude", "skills") },
    { agent: "hermes", marker: path.join(baseDir, ".hermes"), skillsDir: path.join(baseDir, ".hermes", "skills") },
    { agent: "openclaw", marker: path.join(baseDir, ".openclaw"), skillsDir: path.join(baseDir, ".openclaw", "skills") },
    { agent: "opencode", marker: path.join(xdgDir, "opencode"), skillsDir: path.join(xdgDir, "opencode", "skills") },
    { agent: "pi", marker: path.join(baseDir, ".pi"), skillsDir: path.join(baseDir, ".pi", "agent", "skills") }
  ];

  return dedupeBySkillsDir(dirs);
}

function dedupeBySkillsDir(dirs) {
  const seen = new Set();
  return dirs.filter(({ skillsDir }) => {
    const resolved = path.resolve(skillsDir);
    if (seen.has(resolved)) return false;
    seen.add(resolved);
    return true;
  });
}

// Basenames carried in a skill's own directory but excluded from the trimmed
// plugin payload: PowerShell twins (plugins run the Python scripts) and repo /
// package tooling that never runs for an installed skill. This is the single
// source of the rule — scripts/sync-plugins.js imports includeInPluginPayload,
// and Install-PluginSkill in bin/slopkit.ps1 mirrors it for the PowerShell port.
const PLUGIN_EXCLUDED_BASENAMES = new Set([
  "attribution_scan.py",
  "ci_secret_scan.py",
  "score_snapshot.py",
  "install_smoke.py",
  "__pycache__"
]);

function includeInPluginPayload(srcPath) {
  const base = path.basename(srcPath);
  if (base.endsWith(".ps1")) return false;
  if (base.endsWith(".pyc")) return false;
  return !PLUGIN_EXCLUDED_BASENAMES.has(base);
}

function copyEntry(skill, name, dest, filter) {
  const source = path.join(skillRootOf(skill), name);
  const target = path.join(dest, name);
  if (!fs.existsSync(source)) return;
  fs.rmSync(target, { force: true, recursive: true });
  const options = { recursive: true };
  if (filter) options.filter = filter;
  fs.cpSync(source, target, options);
}

// Install a single skill into <skillsDir>/<skill.name>.
function installSkillInto(skill, skillsDir) {
  const dest = path.join(skillsDir, skill.name);
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of skill.installEntries) {
    copyEntry(skill, entry, dest);
  }
  return dest;
}

function installAllSkillsInto(skillsDir) {
  for (const skill of SKILLS) {
    installSkillInto(skill, skillsDir);
  }
}

function printInstallSummary(dirs, lead) {
  console.log(`${lead} ${dirs.length} location${dirs.length === 1 ? "" : "s"} (${skillNames}):`);
  for (const item of dirs) {
    console.log(`- ${item.agent}: ${item.skillsDir}`);
  }
}

function install(target, all) {
  if (target) {
    // If the target already contains agent config dirs, install both skills
    // into their skills/ subdirs; otherwise treat the target as a skills parent.
    const present = agentSkillDirs(target, path.join(target, ".config"))
      .filter(({ marker }) => fs.existsSync(marker));
    if (present.length) {
      for (const item of present) {
        installAllSkillsInto(item.skillsDir);
      }
      printInstallSummary(present, `Installed slopkit ${version} into ${target} across`);
      return;
    }
    installAllSkillsInto(target);
    console.log(`Installed slopkit ${version} (${skillNames}) to ${target}`);
    return;
  }

  let dirs = agentSkillDirs(os.homedir(), xdgConfigHome());
  const envDir = process.env.SLOPKIT_SKILLS_DIR || process.env.SLOPBETH_SKILLS_DIR;
  if (envDir) {
    dirs.push({ agent: "custom", marker: envDir, skillsDir: envDir });
  }

  if (!all) {
    dirs = dirs.filter(({ agent, marker }) => agent === "custom" || fs.existsSync(marker));
    if (dirs.length === 0) {
      console.log(`No known agent directories found under ${os.homedir()}.`);
      console.log("Use 'install --all' to install for every supported agent, or 'install <dir>' for a specific path.");
      return;
    }
  }

  for (const item of dirs) {
    installAllSkillsInto(item.skillsDir);
  }
  printInstallSummary(dirs, `Installed slopkit ${version} to`);
}

function pluginManifest(skill, agent) {
  const base = {
    name: skill.name,
    version,
    description: skill.description,
    author: {
      name: "ehmo",
      url: "https://github.com/ehmo"
    },
    homepage: "https://github.com/ehmo/slopkit#readme",
    repository: "https://github.com/ehmo/slopkit",
    license: "MIT",
    keywords: skill.keywords,
    skills: "./skills/"
  };

  if (agent === "claude") {
    return {
      ...base,
      displayName: skill.displayName
    };
  }

  return {
    ...base,
    interface: {
      displayName: skill.displayName,
      ...skill.codexInterface
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

// A plugin dir mirrors the repo plugins/<name> layout: skills/<name>/ payload
// plus a manifest dir. `target` is that plugin dir.
function installPluginSkill(skill, target) {
  fs.rmSync(target, { force: true, recursive: true });
  const payload = path.join(target, "skills", skill.name);
  fs.mkdirSync(payload, { recursive: true });
  for (const entry of skill.installEntries) {
    copyEntry(skill, entry, payload, includeInPluginPayload);
  }
}

function installClaudePlugin() {
  const installed = [];
  for (const skill of SKILLS) {
    const target = path.join(os.homedir(), ".claude", "skills", skill.name);
    installPluginSkill(skill, target);
    writeJson(path.join(target, ".claude-plugin", "plugin.json"), pluginManifest(skill, "claude"));
    installed.push({ agent: `claude-code:${skill.name}`, target });
  }
  return installed;
}

function codexMarketplaceEntry(skill) {
  return {
    name: skill.name,
    source: {
      source: "local",
      path: `./.codex/plugins/${skill.name}`
    },
    policy: {
      installation: "INSTALLED_BY_DEFAULT",
      authentication: "ON_INSTALL"
    },
    category: "Productivity",
    interface: {
      displayName: skill.displayName,
      shortDescription: skill.marketplaceShort
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

  const ours = new Set(SKILLS.map((s) => s.name));
  marketplace.plugins = marketplace.plugins.filter((plugin) => plugin && !ours.has(plugin.name));
  for (const skill of SKILLS) {
    marketplace.plugins.push(codexMarketplaceEntry(skill));
  }
  writeJson(marketplaceFile, marketplace);
  return marketplaceFile;
}

function installCodexPlugin() {
  const installed = [];
  for (const skill of SKILLS) {
    const target = path.join(os.homedir(), ".codex", "plugins", skill.name);
    installPluginSkill(skill, target);
    writeJson(path.join(target, ".codex-plugin", "plugin.json"), pluginManifest(skill, "codex"));
    installed.push({ agent: `codex:${skill.name}`, target });

    // Remove skills-dir installs that would shadow the plugin.
    for (const staleTarget of [
      path.join(os.homedir(), ".agents", "skills", skill.name),
      path.join(os.homedir(), ".codex", "skills", skill.name)
    ]) {
      fs.rmSync(staleTarget, { force: true, recursive: true });
    }
  }
  const marketplaceFile = updateCodexMarketplace();
  installed.push({ agent: "codex-marketplace", target: marketplaceFile });
  return installed;
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
    installed.push(...installClaudePlugin());
  }
  if (normalized === "all" || normalized === "codex") {
    installed.push(...installCodexPlugin());
  }

  console.log(`Installed slopkit ${version} plugin support (${skillNames}):`);
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

function runCheck(command, args, cwd) {
  const result = spawnSync(command, args, {
    cwd,
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
  const infra = [
    "CODE_OF_CONDUCT.md",
    "LICENSE",
    "README.md",
    ".agents/plugins/marketplace.json",
    ".claude-plugin/marketplace.json",
    "bin/slopkit.js",
    "bin/slopkit.ps1"
  ];

  const perSkill = SKILLS.flatMap((skill) => [
    `plugins/${skill.name}/.claude-plugin/plugin.json`,
    `plugins/${skill.name}/.codex-plugin/plugin.json`,
    `plugins/${skill.name}/skills/${skill.name}/SKILL.md`,
    ...skill.doctorFiles
  ]);

  const required = [...infra, ...perSkill];
  const missing = required.filter((entry) => !fs.existsSync(path.join(root, entry)));
  if (missing.length) {
    console.error(`Missing files:\n${missing.map((m) => `- ${m}`).join("\n")}`);
    process.exit(1);
  }
  console.log(`slopkit ${version} package files are present (${skillNames}).`);
}

function benchmarkSlopbeth(skill) {
  const skillRoot = skillRootOf(skill);
  const v2Pack = path.join(skillRoot, "benchmarks", "benchmark-v2.jsonl");
  const v2Judges = path.join(skillRoot, "benchmarks", "independent-judge-rows-v2.jsonl");

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

  runCheck("python3", ["scripts/run_benchmark.py", "--corpus", "benchmarks/benchmark-v2.jsonl", "--summary-only", "--fail-release-gate"], skillRoot);
  runCheck("python3", ["scripts/semantic_drift.py", "--corpus", "benchmarks/benchmark-v2.jsonl", "--quiet", "--fail-gate"], skillRoot);
  runCheck("python3", ["scripts/signature_score.py", "--corpus", "benchmarks/benchmark-v2.jsonl", "--fail-gate", "--format", "json"], skillRoot);
  runCheck("python3", ["scripts/cadence_score.py", "--corpus", "benchmarks/benchmark-v2.jsonl", "--fail-gate", "--format", "json"], skillRoot);
  runCheck("python3", ["scripts/unsummarizability_check.py", "--corpus", "benchmarks/benchmark-v2.jsonl", "--fail-gate", "--require-summary-loss", "--format", "json"], skillRoot);
  runCheck("python3", ["scripts/span_annotation_check.py", "--corpus", "benchmarks/benchmark-v2.jsonl", "--annotations", "benchmarks/span-annotations-v1.jsonl", "--fail-gate", "--format", "json"], skillRoot);
  runCheck("python3", ["scripts/false_positive_check.py", "--tracker", "benchmarks/false-positive-tracker-v1.jsonl", "--fail-gate", "--format", "json"], skillRoot);
  runCheck("python3", ["scripts/competitor_output_score.py", "--corpus", "benchmarks/benchmark-v2.jsonl", "--panel", "benchmarks/competitor-output-runs-v1.jsonl", "--fail-gate", "--format", "json"], skillRoot);
  runCheck("python3", ["scripts/competitor_output_score.py", "--corpus", "benchmarks/benchmark-v2.jsonl", "--panel", "benchmarks/competitor-agent-runs-v1.jsonl", "--min-competitors", "5", "--min-cases", "25", "--max-average-deficit", "2.0", "--fail-gate", "--format", "json"], skillRoot);
  runCheck("python3", ["scripts/orwell_benchmark.py", "--corpus", "benchmarks/orwell-writing-system-v1.jsonl", "--fail-gate", "--format", "json"], skillRoot);

  const orwellRows = countJsonl(path.join(skillRoot, "benchmarks", "orwell-writing-system-v1.jsonl"));
  console.log(`slopbeth: ${v2Rows.length} v2 output-bearing cases, ${v2JudgeRows.length} v2 judge rows, plus span, false-positive, cadence, competitor-output, competitor-agent, and Orwell writing-system (${orwellRows} before/after rows) gates.`);
}

function benchmarkSlopgent(skill) {
  // slopgent ships Python-only gates. All three resolve their data relative to
  // their own file, so cwd only needs ../scripts on the path — run from the
  // benchmarks dir where they self-insert it.
  const benchDir = path.join(skillRootOf(skill), "benchmarks");
  runCheck("python3", ["run_comms_benchmark.py", "--fail-gate"], benchDir);
  runCheck("python3", ["decoy_rejection.py", "--fail-gate"], benchDir);
  runCheck("python3", [path.join("judge", "judge_aggregate.py"), "--fail-gate"], benchDir);

  const cases = countJsonl(path.join(benchDir, "corpus.jsonl"));
  const decoys = countJsonl(path.join(benchDir, "decoys.jsonl"));
  console.log(`slopgent: ${cases} comms cases and ${decoys} decoys, plus the deterministic lint gate, decoy-rejection gate, and blinded judge-panel gate.`);
}

function benchmark() {
  for (const skill of SKILLS) {
    skill.benchmark(skill);
  }
  console.log(`Benchmark packs ready for slopkit ${version} (${skillNames}).`);
}

function smoke() {
  runCheck("python3", ["scripts/install_smoke.py"], path.join(root, "skills", "slopbeth"));
  console.log(`slopkit ${version} install smoke passed.`);
}

// Exposed so scripts/sync-plugins.js reuses the exact plugin-payload rule
// instead of keeping a second copy of it.
module.exports = { SKILLS, includeInPluginPayload };

function main() {
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
}

if (require.main === module) {
  main();
}
