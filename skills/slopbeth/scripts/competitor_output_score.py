#!/usr/bin/env python3
"""Score competitor outputs on shared benchmark cases."""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from statistics import mean

import deslop_lint
import density_report
import preservation_check
import signature_score


def read_jsonl(path: Path) -> list[dict[str, object]]:
    rows = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        row = json.loads(line)
        if not isinstance(row, dict):
            raise ValueError(f"{path}:{line_number}: expected JSON object")
        row["_line_number"] = line_number
        rows.append(row)
    return rows


def corpus_by_id(path: Path) -> dict[str, dict[str, object]]:
    return {str(row["id"]): row for row in read_jsonl(path)}


def required_facts(row: dict[str, object]) -> list[str]:
    facts = row.get("required_exact_facts", [])
    return [str(fact) for fact in facts if isinstance(fact, str) and fact.strip()]


def forbidden_terms(row: dict[str, object]) -> list[str]:
    terms = row.get("forbidden_output_terms", [])
    return [str(term) for term in terms if isinstance(term, str) and term.strip()]


def missing_required_facts(facts: list[str], output: str) -> list[str]:
    lower = output.lower()
    return [fact for fact in facts if fact.lower() not in lower]


def forbidden_output_hits(terms: list[str], output: str) -> list[str]:
    lower = output.lower()
    return [term for term in terms if term.lower() in lower]


def score_row(row: dict[str, object], corpus: dict[str, dict[str, object]]) -> dict[str, object]:
    case_id = str(row.get("case_id", ""))
    competitor = str(row.get("competitor", ""))
    output = str(row.get("output", ""))
    source = corpus.get(case_id)
    failures = []
    if source is None:
        failures.append("unknown_case")
        input_text = ""
        facts: list[str] = []
        forbidden: list[str] = []
    else:
        input_text = str(source.get("input", ""))
        facts = required_facts(source)
        forbidden = forbidden_terms(source)
    if not competitor:
        failures.append("missing_competitor")
    if not output.strip():
        failures.append("missing_output")
    preservation = preservation_check.compare(input_text, output) if source else {"critical_missing_count": 99}
    missing = missing_required_facts(facts, output)
    forbidden_hits = forbidden_output_hits(forbidden, output)
    schema_failures = list(failures)
    lint = deslop_lint.lint(output)
    density = density_report.metrics(output)
    signatures = signature_score.score_text(case_id, output, facts)
    hard = int(signatures["hard_signature_count"])
    total_score = (
        int(lint["slop_score"])
        + min(20, float(density["claim_markers_per_100_words"]) * 4)
        - len(missing) * 12
        - len(forbidden_hits) * 20
        - int(preservation["critical_missing_count"]) * 15
        - hard * 8
    )
    return {
        "case_id": case_id,
        "competitor": competitor,
        "source_type": row.get("source_type", ""),
        "slop_score": lint["slop_score"],
        "claim_markers_per_100_words": density["claim_markers_per_100_words"],
        "hard_signature_count": hard,
        "critical_missing_count": preservation["critical_missing_count"],
        "missing_required_facts": missing,
        "forbidden_output_hits": forbidden_hits,
        "score": round(total_score, 2),
        "schema_failures": schema_failures,
    }


def run(
    corpus_path: Path,
    panel_path: Path,
    min_competitors: int,
    min_cases: int,
    min_slopbeth_case_win_rate: float | None,
) -> dict[str, object]:
    corpus = corpus_by_id(corpus_path)
    rows = [score_row(row, corpus) for row in read_jsonl(panel_path)]
    by_competitor: dict[str, list[dict[str, object]]] = defaultdict(list)
    by_case: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        by_competitor[str(row["competitor"])].append(row)
        by_case[str(row["case_id"])].append(row)
    summary = {
        competitor: {
            "case_count": len(items),
            "average_score": round(mean(float(item["score"]) for item in items), 2),
            "missing_required_facts": sum(len(item["missing_required_facts"]) for item in items),
            "forbidden_output_hits": sum(len(item["forbidden_output_hits"]) for item in items),
            "hard_signatures": sum(int(item["hard_signature_count"]) for item in items),
        }
        for competitor, items in sorted(by_competitor.items())
    }
    slopbeth_average = summary.get("slopbeth", {}).get("average_score")
    best_average = max((item["average_score"] for item in summary.values()), default=0)
    case_winners = {
        case_id: max(items, key=lambda item: float(item["score"]))["competitor"]
        for case_id, items in by_case.items()
    }
    slopbeth_case_wins = sum(1 for winner in case_winners.values() if winner == "slopbeth")
    slopbeth_case_win_rate = round(slopbeth_case_wins / max(1, len(by_case)), 3)
    failures = []
    if len(summary) < min_competitors:
        failures.append("too_few_competitors")
    if len(by_case) < min_cases:
        failures.append("too_few_cases")
    if slopbeth_average is None:
        failures.append("missing_slopbeth")
    elif min_slopbeth_case_win_rate is not None:
        if slopbeth_case_win_rate < min_slopbeth_case_win_rate:
            failures.append("slopbeth_case_win_rate")
    elif float(slopbeth_average) < float(best_average):
        failures.append("slopbeth_not_top_average")
    if any(row["schema_failures"] for row in rows):
        failures.append("row_failures")
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "corpus": str(corpus_path),
        "panel": str(panel_path),
        "competitor_count": len(summary),
        "case_count": len(by_case),
        "summary": summary,
        "case_winners": case_winners,
        "slopbeth_case_wins": slopbeth_case_wins,
        "slopbeth_case_win_rate": slopbeth_case_win_rate,
        "min_slopbeth_case_win_rate": min_slopbeth_case_win_rate,
        "failures": failures,
        "gate_pass": not failures,
        "rows": rows,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", required=True)
    parser.add_argument("--panel", required=True)
    parser.add_argument("--min-competitors", type=int, default=4)
    parser.add_argument("--min-cases", type=int, default=5)
    parser.add_argument(
        "--min-slopbeth-case-win-rate",
        type=float,
        help="require Slopbeth to win this share of shared cases; when set, this replaces the top-average gate",
    )
    parser.add_argument("--format", choices=["json"], default="json")
    parser.add_argument("--fail-gate", action="store_true")
    args = parser.parse_args()

    result = run(
        Path(args.corpus),
        Path(args.panel),
        args.min_competitors,
        args.min_cases,
        args.min_slopbeth_case_win_rate,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    if args.fail_gate and not result["gate_pass"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
