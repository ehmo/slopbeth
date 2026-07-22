#!/usr/bin/env python3
"""Diagnostic self-instrument for competitor outputs on shared benchmark cases.

READ THIS BEFORE QUOTING ANY NUMBER THIS SCRIPT PRINTS.

The composite `score` is built from Slopbeth's own instruments (`deslop_lint`,
`density_report`, `signature_score`, `preservation_check`). Scoring other tools
with it is circular: it measures how closely their output matches what Slopbeth
optimizes for, not which text is better written. Treat every score here as a
DIAGNOSTIC on Slopbeth's own rules, never as a comparative quality verdict.

Two things this script deliberately does NOT do any more:

1. It does not award ties. When several tools tie at the top score the case has
   no winner, and every tied tool is listed. An earlier version used
   `max(items, key=...)`, which silently returns the FIRST maximum; because
   Slopbeth is listed first in every case, it collected every tie as a "win".
2. It does not let a per-case win rate replace the average-score gate. The gate
   is now a PARITY gate (`--max-average-deficit`): Slopbeth must stay within a
   tolerance of the best peer. Parity is what the evidence supports; superiority
   is not.

Panel provenance matters as much as the score. `source_type` is reported per
panel because a panel of `public-rule-proxy` rows is text written in-house to
another project's published rules, not that project's actual output, and must
never be presented as a competitor result.
"""

from __future__ import annotations

import argparse
import calendar
import json
import re
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from statistics import mean

import deslop_lint
import density_report
import preservation_check
import signature_score

MONTHS = {name.lower(): index for index, name in enumerate(calendar.month_name) if name}
PROXY_SOURCE_TYPES = ("public-rule-proxy", "shipped-v2-output")


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


def normalize(text: str) -> str:
    """Fold quote characters and list commas so punctuation is not a fact drop."""
    return re.sub(r"[“”‘’\"',]", "", text.lower())


def date_variants(fact: str) -> set[str] | None:
    """Equivalent spellings of a date-like fact, or None when it is not a date."""
    text = fact.strip()
    iso = re.match(r"^(\d{4})-(\d{2})-(\d{2})$", text)
    if iso:
        year, month, day = int(iso[1]), int(iso[2]), int(iso[3])
    else:
        written = re.match(r"^([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})$", text)
        if not written or written[1].lower() not in MONTHS:
            return None
        year, month, day = int(written[3]), MONTHS[written[1].lower()], int(written[2])
    if not 1 <= month <= 12:
        return None
    name = calendar.month_name[month].lower()
    return {
        f"{year}-{month:02d}-{day:02d}",
        f"{name} {day} {year}",
        f"{name} {day}",
        f"{day} {name} {year}",
    }


def fact_retained(fact: str, output: str) -> bool:
    """True when the fact survives in meaning, not merely as an exact substring.

    A raw substring test counts faithful paraphrase as a dropped fact: a date
    reformatted to "May 11, 2026", a quoted term whose quote character changed,
    or a clause reordered inside a list all read as losses when nothing was
    lost. Each -12 penalty those artifacts produce is unearned.
    """
    haystack = normalize(output)
    if normalize(fact) in haystack:
        return True
    variants = date_variants(fact)
    if variants and any(normalize(variant) in haystack for variant in variants):
        return True
    tokens = [token for token in re.findall(r"[a-z0-9]+", normalize(fact)) if len(token) > 2]
    return bool(tokens) and all(token in haystack for token in tokens)


def missing_required_facts(facts: list[str], output: str) -> list[str]:
    return [fact for fact in facts if not fact_retained(fact, output)]


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
    # Circular by construction: every term below is one of Slopbeth's own rules.
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
    max_average_deficit: float | None = None,
    min_slopbeth_case_win_rate: float | None = None,
) -> dict[str, object]:
    corpus = corpus_by_id(corpus_path)
    panel_rows = read_jsonl(panel_path)
    rows = [score_row(row, corpus) for row in panel_rows]
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

    # Ties have no winner. Listing every tied tool keeps a 5-way tie from being
    # read as a Slopbeth win just because Slopbeth appears first in the panel.
    case_winners: dict[str, list[str]] = {}
    for case_id, items in by_case.items():
        top = max(float(item["score"]) for item in items)
        case_winners[case_id] = sorted(
            str(item["competitor"]) for item in items if float(item["score"]) == top
        )
    slopbeth_outright_wins = sum(
        1 for winners in case_winners.values() if winners == ["slopbeth"]
    )
    slopbeth_tied_top = sum(
        1 for winners in case_winners.values() if "slopbeth" in winners and len(winners) > 1
    )
    case_count = max(1, len(by_case))
    slopbeth_case_win_rate = round(slopbeth_outright_wins / case_count, 3)
    slopbeth_top_or_tied_rate = round((slopbeth_outright_wins + slopbeth_tied_top) / case_count, 3)

    source_types = defaultdict(int)
    for row in panel_rows:
        source_types[str(row.get("source_type", ""))] += 1
    proxy_rows = sum(count for name, count in source_types.items() if name in PROXY_SOURCE_TYPES)

    failures = []
    deprecated_flags = []
    if len(summary) < min_competitors:
        failures.append("too_few_competitors")
    if len(by_case) < min_cases:
        failures.append("too_few_cases")
    if slopbeth_average is None:
        failures.append("missing_slopbeth")
    else:
        deficit = float(best_average) - float(slopbeth_average)
        # Parity gate. It always runs; nothing can substitute for it.
        if max_average_deficit is not None and deficit > float(max_average_deficit):
            failures.append("slopbeth_average_deficit")
    if min_slopbeth_case_win_rate is not None:
        deprecated_flags.append(
            "--min-slopbeth-case-win-rate is deprecated and non-gating: with near-identical "
            "peer outputs almost every case ties, so a per-case win rate measured tie-award "
            "order, not quality. Use --max-average-deficit."
        )
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
        "slopbeth_average": slopbeth_average,
        "best_average": best_average,
        "slopbeth_average_deficit": (
            None if slopbeth_average is None else round(float(best_average) - float(slopbeth_average), 2)
        ),
        "max_average_deficit": max_average_deficit,
        "slopbeth_outright_wins": slopbeth_outright_wins,
        "slopbeth_tied_top": slopbeth_tied_top,
        "slopbeth_case_wins": slopbeth_outright_wins,
        "slopbeth_case_win_rate": slopbeth_case_win_rate,
        "slopbeth_top_or_tied_rate": slopbeth_top_or_tied_rate,
        "panel_source_types": dict(sorted(source_types.items())),
        "panel_proxy_row_count": proxy_rows,
        "deprecated_flags": deprecated_flags,
        "interpretation": (
            "Diagnostic only. The composite score is built from Slopbeth's own instruments, so "
            "scoring other tools with it is circular and cannot rank writing quality. Ties are "
            "reported as ties. Panels whose source_type is public-rule-proxy are text written "
            "in-house to another project's published rules, not that project's own output."
        ),
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
        "--max-average-deficit",
        type=float,
        help="fail when Slopbeth's average diagnostic score trails the best peer by more than "
        "this many points; asserts parity, not superiority",
    )
    parser.add_argument(
        "--min-slopbeth-case-win-rate",
        type=float,
        help="deprecated and non-gating; retained so existing commands keep running",
    )
    parser.add_argument("--format", choices=["json"], default="json")
    parser.add_argument("--fail-gate", action="store_true")
    args = parser.parse_args()

    result = run(
        Path(args.corpus),
        Path(args.panel),
        args.min_competitors,
        args.min_cases,
        args.max_average_deficit,
        args.min_slopbeth_case_win_rate,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    if args.fail_gate and not result["gate_pass"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
