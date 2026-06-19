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


ROOT = Path(__file__).resolve().parents[1]


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

        home = temp / "home"
        config_home = home / ".config"
        home.mkdir()
        env = os.environ.copy()
        env["HOME"] = str(home)
        env["XDG_CONFIG_HOME"] = str(config_home)
        env.pop("SLOPBETH_SKILLS_DIR", None)

        result = run_install(["installnpx"], env=env)
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

        print(f"Install smoke passed: {custom_target} and {len(REQUIRED_AGENT_TARGETS)} agent targets")
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
