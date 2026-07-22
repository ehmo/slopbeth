#!/usr/bin/env python3
"""Smoke-test the slopkit installer in temporary directories.

slopkit ships two skills (slopbeth, slopgent) that install by the same means.
Every install path drops both as sibling subdirs of a skills parent
(skills/slopbeth and skills/slopgent), so the smoke validates both everywhere.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path


# Repo root: skills/slopbeth/scripts/install_smoke.py -> parents[3].
# bin/slopkit.js and package.json live at the repo root, so the installer
# smoke must run from there.
ROOT = Path(__file__).resolve().parents[3]

SKILL_NAMES = ["slopbeth", "slopgent"]

# Files each skill must carry after an install, relative to its own skill dir.
REQUIRED_FILES = {
    "slopbeth": [
        "SKILL.md",
        "BENCHMARKS.md",
        "CONTRIBUTING.md",
        "SECURITY.md",
        "SUPPORT.md",
        "agents/claude-code.yaml",
        "agents/codex.yaml",
        "agents/hermes.yaml",
        "agents/openclaw.yaml",
        "agents/openai.yaml",
        "agents/opencode.yaml",
        "agents/pi.yaml",
        "references/evaluation.md",
        "references/slop-taxonomy.md",
        "benchmarks/benchmark-v2.jsonl",
        "benchmarks/competitor-agent-runs-v1.jsonl",
        "benchmarks/score-snapshot.md",
        "docs/false-positive-tracker.md",
        "docs/literature-basis.md",
        "scripts/Compare-Preservation.ps1",
        "scripts/Get-DensityReport.ps1",
        "scripts/Measure-Deslop.ps1",
        "scripts/Run-Benchmark.ps1",
        "scripts/SlopBeth.Common.ps1",
        "scripts/Test-Install.ps1",
        "scripts/run_benchmark.py",
        "scripts/competitor_output_score.py",
        "scripts/score_snapshot.py",
    ],
    "slopgent": [
        "SKILL.md",
        "README.md",
        "agents/claude-code.yaml",
        "agents/codex.yaml",
        "agents/hermes.yaml",
        "agents/openclaw.yaml",
        "agents/openai.yaml",
        "agents/opencode.yaml",
        "agents/pi.yaml",
        "scripts/comms_lint.py",
        "scripts/slopgent-memory.js",
        "benchmarks/corpus.jsonl",
        "benchmarks/corpus_gates.jsonl",
        "benchmarks/decoys.jsonl",
        "benchmarks/run_comms_benchmark.py",
        "benchmarks/decoy_rejection.py",
        "benchmarks/README.md",
        "benchmarks/judge/judge_aggregate.py",
    ],
}

# Agent skills-parent dirs, relative to a home. Both skills install underneath.
REQUIRED_AGENT_SKILLS_DIRS = [
    ".codex/skills",
    ".agents/skills",
    ".claude/skills",
    ".hermes/skills",
    ".openclaw/skills",
    ".config/opencode/skills",
    ".pi/agent/skills",
]


def run_install(args: list[str], env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["node", "bin/slopkit.js", *args],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def validate_skill(skill_dir: Path, skill: str, version: str) -> list[str]:
    missing = [name for name in REQUIRED_FILES[skill] if not (skill_dir / name).exists()]
    if missing:
        return [f"{skill_dir}: missing {name}" for name in missing]

    skill_text = (skill_dir / "SKILL.md").read_text(encoding="utf-8")
    if f"version: {version}" not in skill_text:
        return [f"{skill_dir}: SKILL.md does not report version {version}"]

    return []


def validate_skills_dir(skills_dir: Path, version: str) -> list[str]:
    failures: list[str] = []
    for skill in SKILL_NAMES:
        failures.extend(validate_skill(skills_dir / skill, skill, version))
    return failures


def validate_json_file(path: Path) -> list[str]:
    try:
        json.loads(path.read_text(encoding="utf-8"))
    except Exception as error:
        return [f"{path}: invalid JSON: {error}"]
    return []


def assert_missing(path: Path, label: str) -> list[str]:
    if path.exists():
        return [f"{label}: unexpectedly exists at {path}"]
    return []


def clean_env(home: Path, config: Path) -> dict[str, str]:
    env = os.environ.copy()
    env["HOME"] = str(home)
    env["XDG_CONFIG_HOME"] = str(config)
    env.pop("SLOPKIT_SKILLS_DIR", None)
    env.pop("SLOPBETH_SKILLS_DIR", None)
    return env


def report(label: str, failures: list[str]) -> int:
    if failures:
        print(f"{label}:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    return 0


def smoke_test(keep: bool) -> int:
    version = json.loads((ROOT / "package.json").read_text(encoding="utf-8"))["version"]
    temp = Path(tempfile.mkdtemp(prefix="slopkit-install-"))
    try:
        # 1. Bare-dir custom install: target is a skills parent, both skills land under it.
        custom_target = temp / "custom-skills"
        result = run_install(["install", str(custom_target)])
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1
        if report("Custom install failed", validate_skills_dir(custom_target, version)):
            return 1

        # 2. Default install with no existing agents: nothing installed, clear message.
        empty_home = temp / "empty-home"
        empty_config = empty_home / ".config"
        empty_home.mkdir()
        empty_env = clean_env(empty_home, empty_config)
        result = run_install(["install"], env=empty_env)
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1
        failures = []
        for skills_dir in REQUIRED_AGENT_SKILLS_DIRS:
            failures.extend(assert_missing(empty_home / skills_dir, "Default install without existing agents"))
        if "No known agent directories found" not in result.stdout:
            failures.append("Default install without existing agents should explain that no agent directories were found")
        if report("Existing-agent default skip failed", failures):
            return 1

        # 3. Default install with one existing agent: only that agent gets both skills.
        existing_home = temp / "studio-home"
        existing_config = existing_home / ".config"
        (existing_home / ".claude").mkdir(parents=True)
        existing_config.mkdir(parents=True)
        existing_env = clean_env(existing_home, existing_config)
        result = run_install(["install"], env=existing_env)
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1
        failures = validate_skills_dir(existing_home / ".claude/skills", version)
        failures.extend(assert_missing(existing_home / ".agents/skills/slopbeth", "Existing-agent default"))
        failures.extend(assert_missing(existing_config / "opencode/skills/slopbeth", "Plain XDG config without opencode"))
        if report("Existing-agent default install failed", failures):
            return 1

        # 4. SLOPKIT_SKILLS_DIR env override: both skills under the named parent.
        custom_env_target = temp / "custom-env-skills"
        env_target_env = clean_env(temp / "custom-env-home", temp / "custom-env-config")
        env_target_env["SLOPKIT_SKILLS_DIR"] = str(custom_env_target)
        result = run_install(["install"], env=env_target_env)
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1
        if report("SLOPKIT_SKILLS_DIR install failed", validate_skills_dir(custom_env_target, version)):
            return 1

        # 5. Back-compat SLOPBETH_SKILLS_DIR still works.
        legacy_env_target = temp / "legacy-env-skills"
        legacy_env = clean_env(temp / "legacy-env-home", temp / "legacy-env-config")
        legacy_env["SLOPBETH_SKILLS_DIR"] = str(legacy_env_target)
        result = run_install(["install"], env=legacy_env)
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1
        if report("SLOPBETH_SKILLS_DIR (back-compat) install failed", validate_skills_dir(legacy_env_target, version)):
            return 1

        # 6. Smart custom install: agent dirs present, both skills into each skills subdir.
        smart_target = temp / "smart-target"
        (smart_target / ".claude").mkdir(parents=True)
        (smart_target / ".config/opencode").mkdir(parents=True)
        (smart_target / ".pi").mkdir(parents=True)
        result = run_install(["install", str(smart_target)])
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1
        failures = []
        for skills_dir in [".claude/skills", ".config/opencode/skills", ".pi/agent/skills"]:
            failures.extend(validate_skills_dir(smart_target / skills_dir, version))
        failures.extend(assert_missing(smart_target / "slopbeth", "Smart custom install root"))
        if report("Smart custom install failed", failures):
            return 1

        # 7. Full multi-agent install (--all).
        home = temp / "home"
        config_home = home / ".config"
        home.mkdir()
        env = clean_env(home, config_home)
        result = run_install(["install", "--all"], env=env)
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1
        failures = []
        for skills_dir in REQUIRED_AGENT_SKILLS_DIRS:
            failures.extend(validate_skills_dir(home / skills_dir, version))
        if report("Default multi-agent install failed", failures):
            return 1

        # 8. installnpx alias installs into every supported agent.
        installnpx_home = temp / "installnpx-home"
        installnpx_config = installnpx_home / ".config"
        installnpx_home.mkdir()
        installnpx_env = clean_env(installnpx_home, installnpx_config)
        result = run_install(["installnpx"], env=installnpx_env)
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1
        failures = []
        for skills_dir in REQUIRED_AGENT_SKILLS_DIRS:
            failures.extend(validate_skills_dir(installnpx_home / skills_dir, version))
        if report("installnpx multi-agent install failed", failures):
            return 1

        # 9. Plugin install for both skills (Claude + Codex).
        result = run_install(["install-plugin"], env=env)
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1

        failures = []
        for skill in SKILL_NAMES:
            plugin_files = [
                f".claude/skills/{skill}/.claude-plugin/plugin.json",
                f".claude/skills/{skill}/skills/{skill}/SKILL.md",
                f".codex/plugins/{skill}/.codex-plugin/plugin.json",
                f".codex/plugins/{skill}/skills/{skill}/SKILL.md",
            ]
            for relative_file in plugin_files:
                file = home / relative_file
                if not file.exists():
                    failures.append(f"{file}: missing")
                elif file.name == "plugin.json":
                    failures.extend(validate_json_file(file))

        marketplace_file = home / ".agents/plugins/marketplace.json"
        if not marketplace_file.exists():
            failures.append(f"{marketplace_file}: missing")
        else:
            failures.extend(validate_json_file(marketplace_file))
            marketplace = json.loads(marketplace_file.read_text(encoding="utf-8"))
            plugins = marketplace.get("plugins", [])
            for skill in SKILL_NAMES:
                entries = [p for p in plugins if p.get("name") == skill]
                if len(entries) != 1:
                    failures.append(f"Codex marketplace must contain exactly one {skill} plugin entry")
                elif entries[0].get("source", {}).get("path") != f"./.codex/plugins/{skill}":
                    failures.append(f"Codex marketplace {skill} source path is wrong")

        for skill in SKILL_NAMES:
            if (home / f".agents/skills/{skill}").exists() or (home / f".codex/skills/{skill}").exists():
                failures.append(f"Codex plugin install must remove plain Codex skill targets for {skill}")

        if report("Plugin install failed", failures):
            return 1

        print(
            "Install smoke passed: both skills across "
            f"{len(REQUIRED_AGENT_SKILLS_DIRS)} agent skills dirs, env overrides, and Claude/Codex plugin targets"
        )
        return 0
    finally:
        if keep:
            print(f"Kept temporary install: {temp}")
        else:
            shutil.rmtree(temp, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keep", action="store_true", help="keep the temporary install directory")
    args = parser.parse_args()
    return smoke_test(args.keep)


if __name__ == "__main__":
    raise SystemExit(main())
