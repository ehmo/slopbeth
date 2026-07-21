#!/usr/bin/env python3
"""Smoke-test the package installer in a temporary skill directory."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path


# Repo root: skills/slopbeth/scripts/install_smoke.py -> parents[3].
# bin/slopbeth.js and package.json live at the repo root, so the installer
# smoke must run from there.
ROOT = Path(__file__).resolve().parents[3]


REQUIRED_INSTALLED_FILES = [
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
]

REQUIRED_AGENT_TARGETS = [
    ".codex/skills/slopbeth",
    ".agents/skills/slopbeth",
    ".claude/skills/slopbeth",
    ".hermes/skills/slopbeth",
    ".openclaw/skills/slopbeth",
    ".config/opencode/skills/slopbeth",
    ".pi/agent/skills/slopbeth",
]

REQUIRED_PLUGIN_FILES = [
    ".claude/skills/slopbeth/.claude-plugin/plugin.json",
    ".claude/skills/slopbeth/skills/slopbeth/SKILL.md",
    ".claude/skills/slopbeth/skills/slopbeth/references/evaluation.md",
    ".claude/skills/slopbeth/skills/slopbeth/scripts/run_benchmark.py",
    ".claude/skills/slopbeth/skills/slopbeth/scripts/Run-Benchmark.ps1",
    ".codex/plugins/slopbeth/.codex-plugin/plugin.json",
    ".codex/plugins/slopbeth/skills/slopbeth/SKILL.md",
    ".codex/plugins/slopbeth/skills/slopbeth/references/evaluation.md",
    ".codex/plugins/slopbeth/skills/slopbeth/scripts/run_benchmark.py",
    ".codex/plugins/slopbeth/skills/slopbeth/scripts/Run-Benchmark.ps1",
    ".agents/plugins/marketplace.json",
]


def run_install(args: list[str], env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["node", "bin/slopbeth.js", *args],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def validate_install(target: Path, version: str) -> list[str]:
    missing = [name for name in REQUIRED_INSTALLED_FILES if not (target / name).exists()]
    if missing:
        return [f"{target}: missing {name}" for name in missing]

    skill_text = (target / "SKILL.md").read_text(encoding="utf-8")
    if f"version: {version}" not in skill_text:
        return [f"{target}: SKILL.md does not report version {version}"]

    return []


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


def smoke_test(keep: bool) -> int:
    version = json.loads((ROOT / "package.json").read_text(encoding="utf-8"))["version"]
    temp = Path(tempfile.mkdtemp(prefix="slopbeth-install-"))
    custom_target = temp / "skills" / "slopbeth"
    try:
        result = run_install(["install", str(custom_target)])
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1

        failures = validate_install(custom_target, version)
        if failures:
            print("Custom install failed:")
            for failure in failures:
                print(f"- {failure}")
            return 1

        empty_home = temp / "empty-home"
        empty_config = empty_home / ".config"
        empty_home.mkdir()
        empty_env = os.environ.copy()
        empty_env["HOME"] = str(empty_home)
        empty_env["XDG_CONFIG_HOME"] = str(empty_config)
        empty_env.pop("SLOPBETH_SKILLS_DIR", None)

        result = run_install(["install"], env=empty_env)
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1

        failures = []
        for relative_target in REQUIRED_AGENT_TARGETS:
            failures.extend(assert_missing(empty_home / relative_target, "Default install without existing agents"))
        failures.extend(assert_missing(empty_config / "opencode", "Default install without existing OpenCode"))
        if "No known agent directories found" not in result.stdout:
            failures.append("Default install without existing agents should explain that no agent directories were found")
        if failures:
            print("Existing-agent default skip failed:")
            for failure in failures:
                print(f"- {failure}")
            return 1

        existing_home = temp / "studio-home"
        existing_config = existing_home / ".config"
        (existing_home / ".claude").mkdir(parents=True)
        existing_config.mkdir(parents=True)
        existing_env = os.environ.copy()
        existing_env["HOME"] = str(existing_home)
        existing_env["XDG_CONFIG_HOME"] = str(existing_config)
        existing_env.pop("SLOPBETH_SKILLS_DIR", None)

        result = run_install(["install"], env=existing_env)
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1

        failures = validate_install(existing_home / ".claude/skills/slopbeth", version)
        failures.extend(assert_missing(existing_home / ".agents/skills/slopbeth", "Existing-agent default"))
        failures.extend(assert_missing(existing_config / "opencode/skills/slopbeth", "Plain XDG config without opencode"))
        if failures:
            print("Existing-agent default install failed:")
            for failure in failures:
                print(f"- {failure}")
            return 1

        custom_env_target = temp / "custom-env-skills"
        env_target_env = os.environ.copy()
        env_target_env["HOME"] = str(temp / "custom-env-home")
        env_target_env["XDG_CONFIG_HOME"] = str(temp / "custom-env-config")
        env_target_env["SLOPBETH_SKILLS_DIR"] = str(custom_env_target)
        result = run_install(["install"], env=env_target_env)
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1
        failures = validate_install(custom_env_target / "slopbeth", version)
        if failures:
            print("SLOPBETH_SKILLS_DIR install failed:")
            for failure in failures:
                print(f"- {failure}")
            return 1

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
        for relative_target in [
            ".claude/skills/slopbeth",
            ".config/opencode/skills/slopbeth",
            ".pi/agent/skills/slopbeth",
        ]:
            failures.extend(validate_install(smart_target / relative_target, version))
        failures.extend(assert_missing(smart_target / "SKILL.md", "Smart custom install root"))
        if failures:
            print("Smart custom install failed:")
            for failure in failures:
                print(f"- {failure}")
            return 1

        home = temp / "home"
        config_home = home / ".config"
        home.mkdir()
        env = os.environ.copy()
        env["HOME"] = str(home)
        env["XDG_CONFIG_HOME"] = str(config_home)
        env.pop("SLOPBETH_SKILLS_DIR", None)

        result = run_install(["install", "--all"], env=env)
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1

        failures = []
        for relative_target in REQUIRED_AGENT_TARGETS:
            failures.extend(validate_install(home / relative_target, version))

        if failures:
            print("Default multi-agent install failed:")
            for failure in failures:
                print(f"- {failure}")
            return 1

        installnpx_home = temp / "installnpx-home"
        installnpx_config = installnpx_home / ".config"
        installnpx_home.mkdir()
        installnpx_env = os.environ.copy()
        installnpx_env["HOME"] = str(installnpx_home)
        installnpx_env["XDG_CONFIG_HOME"] = str(installnpx_config)
        installnpx_env.pop("SLOPBETH_SKILLS_DIR", None)
        result = run_install(["installnpx"], env=installnpx_env)
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1

        failures = []
        for relative_target in REQUIRED_AGENT_TARGETS:
            failures.extend(validate_install(installnpx_home / relative_target, version))
        if failures:
            print("installnpx multi-agent install failed:")
            for failure in failures:
                print(f"- {failure}")
            return 1

        result = run_install(["install-plugin"], env=env)
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1

        failures = []
        for relative_file in REQUIRED_PLUGIN_FILES:
            file = home / relative_file
            if not file.exists():
                failures.append(f"{file}: missing")

        for relative_file in [
            ".claude/skills/slopbeth/.claude-plugin/plugin.json",
            ".codex/plugins/slopbeth/.codex-plugin/plugin.json",
            ".agents/plugins/marketplace.json",
        ]:
            file = home / relative_file
            if file.exists():
                failures.extend(validate_json_file(file))

        marketplace = json.loads((home / ".agents/plugins/marketplace.json").read_text(encoding="utf-8"))
        slopbeth_plugins = [plugin for plugin in marketplace.get("plugins", []) if plugin.get("name") == "slopbeth"]
        if len(slopbeth_plugins) != 1:
            failures.append("Codex marketplace must contain exactly one slopbeth plugin entry")
        elif slopbeth_plugins[0].get("source", {}).get("path") != "./.codex/plugins/slopbeth":
            failures.append("Codex marketplace slopbeth source path is wrong")

        if (home / ".agents/skills/slopbeth").exists() or (home / ".codex/skills/slopbeth").exists():
            failures.append("Codex plugin install must remove plain Codex skill targets to avoid duplicate Slopbeth entries")

        if failures:
            print("Plugin install failed:")
            for failure in failures:
                print(f"- {failure}")
            return 1

        print(
            "Install smoke passed: "
            f"{custom_target}, {len(REQUIRED_AGENT_TARGETS)} agent targets, and Claude/Codex plugin targets"
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
