#!/usr/bin/env python3
"""Score an Orwell before/after benchmark corpus.

Reads a JSONL corpus with `before` and `after` fields, runs orwell_lint on
each, and reports per-rule deltas plus a preservation check. This measures one
dimension only: whether a rewrite follows Orwell's five mechanical rules more
closely while keeping the declared facts. It does not judge meaning, voice, or
density. A rewrite can win every rule delta and still be worse prose.

Rule six is not scored. Rows tagged `rules_targeted: []` are controls where the
correct output is little or no change; the gate treats a near-zero delta on
those rows as expected, not as a failure.
"""

from __future__ import annotations

import argparse
import json
import statistics
from pathlib import Path

import orwell_lint

RULE_KEYS = [
    "rule1_dead_metaphor",
    "rule2_long_word",
    "rule3_deletable_words",
    "rule4_passive_voice",
    "rule5_jargon_foreign",
]


def load(path: Path) -> list[dict]:
    rows = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        record = json.loads(line)
        for field in ("id", "before", "after"):
            if field not in record:
                raise ValueError(f"{path}:{line_number} missing {field}")
        rows.append(record)
    return rows


def score_row(record: dict) -> dict:
    before = orwell_lint.lint(record["before"])
    after = orwell_lint.lint(record["after"])
    facts = record.get("preserved_facts", [])
    after_lower = record["after"].lower()
    missing_facts = [f for f in facts if f.lower() not in after_lower]
    is_control = not record.get("rules_targeted")
    rule_deltas = {
        key: after["rule_counts"][key] - before["rule_counts"][key] for key in RULE_KEYS
    }
    return {
        "id": record["id"],
        "category": record.get("category", "uncategorized"),
        "is_control": is_control,
        "before_score": before["orwell_score"],
        "after_score": after["orwell_score"],
        "score_delta": after["orwell_score"] - before["orwell_score"],
        "before_passive_ratio": before["passive_ratio"],
        "after_passive_ratio": after["passive_ratio"],
        "rule_deltas": rule_deltas,
        "total_violation_delta": sum(rule_deltas.values()),
        "missing_facts": missing_facts,
        "note": record.get("note", ""),
    }


def run(path: Path) -> dict:
    rows = [score_row(r) for r in load(path)]
    targeted = [r for r in rows if not r["is_control"]]
    controls = [r for r in rows if r["is_control"]]

    rule_delta_totals = {k: sum(r["rule_deltas"][k] for r in rows) for k in RULE_KEYS}

    failures = []
    # Targeted rows must reduce total violations and must not drop declared facts.
    worsened = [r["id"] for r in targeted if r["total_violation_delta"] > 0]
    if worsened:
        failures.append(f"targeted_rows_added_violations:{','.join(worsened)}")
    no_improvement = [r["id"] for r in targeted if r["total_violation_delta"] == 0]
    if no_improvement:
        failures.append(f"targeted_rows_no_improvement:{','.join(no_improvement)}")
    dropped_facts = [r["id"] for r in rows if r["missing_facts"]]
    if dropped_facts:
        failures.append(f"rows_dropped_declared_facts:{','.join(dropped_facts)}")
    # Controls must not be heavily edited: large positive score jumps mean the
    # "already good" input was actually slop, or the control is mislabeled.
    over_edited_controls = [
        r["id"] for r in controls if abs(r["score_delta"]) > 3 or r["total_violation_delta"] < -2
    ]
    if over_edited_controls:
        failures.append(f"controls_over_edited:{','.join(over_edited_controls)}")

    return {
        "corpus": str(path),
        "row_count": len(rows),
        "targeted_count": len(targeted),
        "control_count": len(controls),
        "avg_before_score": round(statistics.mean(r["before_score"] for r in rows), 2),
        "avg_after_score": round(statistics.mean(r["after_score"] for r in rows), 2),
        "avg_targeted_before_score": round(statistics.mean(r["before_score"] for r in targeted), 2) if targeted else None,
        "avg_targeted_after_score": round(statistics.mean(r["after_score"] for r in targeted), 2) if targeted else None,
        "rule_delta_totals": rule_delta_totals,
        "avg_passive_ratio_before": round(statistics.mean(r["before_passive_ratio"] for r in rows), 3),
        "avg_passive_ratio_after": round(statistics.mean(r["after_passive_ratio"] for r in rows), 3),
        "gate_pass": not failures,
        "failures": failures,
        "rows": rows,
    }


def markdown(result: dict) -> str:
    lines = [
        "# Orwell Writing-System Benchmark",
        "",
        f"- Corpus: `{result['corpus']}`",
        f"- Rows: {result['row_count']} ({result['targeted_count']} targeted, {result['control_count']} control)",
        f"- Avg Orwell score before -> after: {result['avg_before_score']} -> {result['avg_after_score']}",
        f"- Targeted rows before -> after: {result['avg_targeted_before_score']} -> {result['avg_targeted_after_score']}",
        f"- Gate pass: `{str(result['gate_pass']).lower()}`",
        f"- Failures: `{', '.join(result['failures']) or 'none'}`",
        "",
        "## Rule violation deltas (after minus before, negative is better)",
        "",
        "| Rule | Total delta |",
        "| --- | ---: |",
    ]
    labels = {
        "rule1_dead_metaphor": "1 dead metaphor",
        "rule2_long_word": "2 long word",
        "rule3_deletable_words": "3 deletable words",
        "rule4_passive_voice": "4 passive voice",
        "rule5_jargon_foreign": "5 jargon/foreign",
    }
    for key in RULE_KEYS:
        lines.append(f"| {labels[key]} | {result['rule_delta_totals'][key]} |")
    lines.extend(
        [
            "",
            "## Rows",
            "",
            "| ID | Category | Control | Score before -> after | Passive before -> after | Violation delta | Missing facts |",
            "| --- | --- | :---: | --- | --- | ---: | --- |",
        ]
    )
    for r in result["rows"]:
        lines.append(
            f"| {r['id']} | {r['category']} | {'yes' if r['is_control'] else ''} | "
            f"{r['before_score']} -> {r['after_score']} | "
            f"{r['before_passive_ratio']} -> {r['after_passive_ratio']} | "
            f"{r['total_violation_delta']} | {', '.join(r['missing_facts']) or '-'} |"
        )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", required=True)
    parser.add_argument("--format", choices=["json", "markdown"], default="markdown")
    parser.add_argument("--fail-gate", action="store_true")
    args = parser.parse_args()

    result = run(Path(args.corpus))
    if args.format == "json":
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(markdown(result))
    if args.fail_gate and not result["gate_pass"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
