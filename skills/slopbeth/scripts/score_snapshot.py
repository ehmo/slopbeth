#!/usr/bin/env python3
"""Write a compact benchmark score snapshot for CI summaries and release notes."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


# Payload root (skills/slopbeth) holds scripts/ and benchmarks/; the repo root
# (parents[3]) holds package.json.
ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))

import competitor_output_score  # noqa: E402


def count_jsonl(path: Path) -> int:
    return sum(1 for line in path.read_text(encoding="utf-8").splitlines() if line.strip())


def competitor_summary(panel: str, min_competitors: int, min_cases: int, win_rate: float | None) -> dict[str, object]:
    return competitor_output_score.run(
        ROOT / "benchmarks" / "benchmark-v2.jsonl",
        ROOT / "benchmarks" / panel,
        min_competitors=min_competitors,
        min_cases=min_cases,
        min_slopbeth_case_win_rate=win_rate,
    )


def markdown() -> str:
    version = json.loads((REPO_ROOT / "package.json").read_text(encoding="utf-8"))["version"]
    v2_cases = count_jsonl(ROOT / "benchmarks" / "benchmark-v2.jsonl")
    v2_judges = count_jsonl(ROOT / "benchmarks" / "independent-judge-rows-v2.jsonl")
    spans = count_jsonl(ROOT / "benchmarks" / "span-annotations-v1.jsonl")
    false_positives = count_jsonl(ROOT / "benchmarks" / "false-positive-tracker-v1.jsonl")
    proxy = competitor_summary("competitor-output-runs-v1.jsonl", 4, 5, None)
    agent = competitor_summary("competitor-agent-runs-v1.jsonl", 5, 25, 0.7)

    lines = [
        "# Slopbeth score snapshot",
        "",
        f"- Generated: {datetime.now(timezone.utc).isoformat()}",
        f"- Version: `{version}`",
        f"- v2 output-bearing cases: `{v2_cases}`",
        f"- v2 judge rows: `{v2_judges}`",
        f"- span annotation rows: `{spans}`",
        f"- false-positive rows: `{false_positives}`",
        "",
        "## competitor gates",
        "",
        "| Panel | Cases | Competitors | Gate | Slopbeth wins | Slopbeth win rate |",
        "| --- | ---: | ---: | --- | ---: | ---: |",
        (
            f"| public-rule outputs | {proxy['case_count']} | {proxy['competitor_count']} | "
            f"{'pass' if proxy['gate_pass'] else 'fail'} | {proxy['slopbeth_case_wins']} | "
            f"{proxy['slopbeth_case_win_rate']} |"
        ),
        (
            f"| real agent outputs | {agent['case_count']} | {agent['competitor_count']} | "
            f"{'pass' if agent['gate_pass'] else 'fail'} | {agent['slopbeth_case_wins']} | "
            f"{agent['slopbeth_case_win_rate']} |"
        ),
        "",
        "## real agent summary",
        "",
        "| Competitor | Cases | Average diagnostic score | Missing facts | Forbidden hits | Hard signatures |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for name, row in agent["summary"].items():
        lines.append(
            f"| {name} | {row['case_count']} | {row['average_score']} | "
            f"{row['missing_required_facts']} | {row['forbidden_output_hits']} | {row['hard_signatures']} |"
        )
    lines.extend(
        [
            "",
            "## real agent case winners",
            "",
            "| Case | Winner |",
            "| --- | --- |",
        ]
    )
    for case_id, winner in agent["case_winners"].items():
        lines.append(f"| {case_id} | {winner} |")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", help="write markdown to this path instead of stdout")
    args = parser.parse_args()
    text = markdown()
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
    else:
        print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
