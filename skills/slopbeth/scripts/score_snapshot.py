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


def competitor_summary(panel: str, min_competitors: int, min_cases: int, max_deficit: float | None) -> dict[str, object]:
    return competitor_output_score.run(
        ROOT / "benchmarks" / "benchmark-v2.jsonl",
        ROOT / "benchmarks" / panel,
        min_competitors=min_competitors,
        min_cases=min_cases,
        max_average_deficit=max_deficit,
    )


def markdown() -> str:
    version = json.loads((REPO_ROOT / "package.json").read_text(encoding="utf-8"))["version"]
    v2_cases = count_jsonl(ROOT / "benchmarks" / "benchmark-v2.jsonl")
    v2_judges = count_jsonl(ROOT / "benchmarks" / "independent-judge-rows-v2.jsonl")
    spans = count_jsonl(ROOT / "benchmarks" / "span-annotations-v1.jsonl")
    false_positives = count_jsonl(ROOT / "benchmarks" / "false-positive-tracker-v1.jsonl")
    proxy = competitor_summary("competitor-output-runs-v1.jsonl", 4, 5, 2.0)
    agent = competitor_summary("competitor-agent-runs-v1.jsonl", 5, 25, 2.0)

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
        "Diagnostic parity gates, not a quality ranking. The composite score is built from",
        "Slopbeth's own instruments, so scoring other tools with it is circular. The gate asks",
        "whether Slopbeth stays within 2.0 points of the best peer, not whether it wins.",
        "Ties are reported as ties: on the real-agent panel almost every case is a five-way tie,",
        "so outright wins is the honest count and a per-case win rate carries no signal.",
        "",
        "| Panel | Cases | Competitors | Gate | Slopbeth avg | Best peer avg | Deficit | Outright wins | Tied at top |",
        "| --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: |",
        (
            f"| public-rule proxy | {proxy['case_count']} | {proxy['competitor_count']} | "
            f"{'pass' if proxy['gate_pass'] else 'fail'} | {proxy['slopbeth_average']} | "
            f"{proxy['best_average']} | {proxy['slopbeth_average_deficit']:.2f} | "
            f"{proxy['slopbeth_outright_wins']} | {proxy['slopbeth_tied_top']} |"
        ),
        (
            f"| real agent outputs | {agent['case_count']} | {agent['competitor_count']} | "
            f"{'pass' if agent['gate_pass'] else 'fail'} | {agent['slopbeth_average']} | "
            f"{agent['best_average']} | {agent['slopbeth_average_deficit']:.2f} | "
            f"{agent['slopbeth_outright_wins']} | {agent['slopbeth_tied_top']} |"
        ),
        "",
        f"The public-rule panel is {proxy['panel_source_types'].get('public-rule-proxy', 0)} in-house rows written to other",
        f"projects' published rules plus {proxy['panel_source_types'].get('shipped-v2-output', 0)} shipped Slopbeth outputs. It illustrates",
        "rulesets; it is not a competitor result, and its wide spread is an artifact of that.",
        "Only the real-agent panel contains outputs those tools produced.",
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
            "## real agent top scorers",
            "",
            "A tie means the tools scored identically on this diagnostic, so the case has no",
            "winner. Near-identical peer output makes ties the norm here, not the exception.",
            "",
            "| Case | Top scorer |",
            "| --- | --- |",
        ]
    )
    for case_id, winners in agent["case_winners"].items():
        cell = winners[0] if len(winners) == 1 else f"tie ({len(winners)}-way): {', '.join(winners)}"
        lines.append(f"| {case_id} | {cell} |")
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
