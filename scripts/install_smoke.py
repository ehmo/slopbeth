#!/usr/bin/env python3
"""Smoke-test the package installer in a temporary skill directory."""

from __future__ import annotations

import argparse
import json
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


def smoke_test(keep: bool) -> int:
    version = json.loads((ROOT / "package.json").read_text(encoding="utf-8"))["version"]
    temp = Path(tempfile.mkdtemp(prefix="slopbeth-install-"))
    target = temp / "skills" / "slopbeth"
    try:
        result = subprocess.run(
            ["node", "bin/slopbeth.js", "install", str(target)],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if result.returncode != 0:
            print(result.stdout, end="")
            print(result.stderr, end="")
            return result.returncode or 1

        missing = [name for name in REQUIRED_INSTALLED_FILES if not (target / name).exists()]
        if missing:
            print("Missing installed files:")
            for name in missing:
                print(f"- {name}")
            return 1

        skill_text = (target / "SKILL.md").read_text(encoding="utf-8")
        if f"version: {version}" not in skill_text:
            print(f"Installed SKILL.md does not report version {version}")
            return 1

        print(f"Install smoke passed: {target}")
        return 0
    finally:
        if keep:
            print(f"Kept temporary install: {target}")
        else:
            shutil.rmtree(temp, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keep", action="store_true", help="keep the temporary install directory")
    args = parser.parse_args()
    return smoke_test(args.keep)


if __name__ == "__main__":
    raise SystemExit(main())
