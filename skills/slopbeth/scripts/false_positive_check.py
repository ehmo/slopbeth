#!/usr/bin/env python3
"""Check examples that Slopbeth should leave alone or edit lightly."""

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path

import deslop_lint
import preservation_check


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


def word_count(text: str) -> int:
    return len(re.findall(r"\b[\w']+\b", text))


def check_row(row: dict[str, object]) -> dict[str, object]:
    sample_id = str(row.get("id", f"line-{row.get('_line_number', '?')}"))
    input_text = str(row.get("input", ""))
    output_text = str(row.get("expected_output", ""))
    action = row.get("expected_action")
    forbidden = row.get("forbidden_additions", [])
    failures = []
    if action not in {"leave_alone", "light_copyedit"}:
        failures.append("bad_expected_action")
    if not input_text.strip() or not output_text.strip():
        failures.append("missing_text")
    if not isinstance(forbidden, list) or not all(isinstance(item, str) and item for item in forbidden):
        failures.append("bad_forbidden_additions")

    input_words = word_count(input_text)
    output_words = word_count(output_text)
    growth = round(output_words / max(1, input_words), 3)
    if action == "leave_alone" and input_text != output_text:
        failures.append("changed_leave_alone_text")
    if action == "light_copyedit" and growth > 1.15:
        failures.append("light_edit_grew_too_much")

    lower_output = output_text.lower()
    added_forbidden = [
        term for term in forbidden if isinstance(term, str) and term.lower() in lower_output
    ]
    if added_forbidden:
        failures.append("forbidden_addition")

    preservation = preservation_check.compare(input_text, output_text)
    if preservation["critical_missing_count"]:
        failures.append("critical_missing_facts")
    return {
        "id": sample_id,
        "expected_action": action,
        "input_words": input_words,
        "output_words": output_words,
        "growth_ratio": growth,
        "input_slop_score": deslop_lint.lint(input_text)["slop_score"],
        "output_slop_score": deslop_lint.lint(output_text)["slop_score"],
        "added_forbidden": added_forbidden,
        "critical_missing_count": preservation["critical_missing_count"],
        "failures": failures,
    }


def run(path: Path, min_rows: int) -> dict[str, object]:
    rows = [check_row(row) for row in read_jsonl(path)]
    failures = []
    failing_rows = [row["id"] for row in rows if row["failures"]]
    actions = {str(row["expected_action"]) for row in rows}
    if len(rows) < min_rows:
        failures.append("too_few_rows")
    if "leave_alone" not in actions or "light_copyedit" not in actions:
        failures.append("missing_action_mix")
    if failing_rows:
        failures.append("row_failures")
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "tracker": str(path),
        "row_count": len(rows),
        "failing_rows": failing_rows,
        "failures": failures,
        "gate_pass": not failures,
        "rows": rows,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tracker", required=True)
    parser.add_argument("--min-rows", type=int, default=10)
    parser.add_argument("--format", choices=["json"], default="json")
    parser.add_argument("--fail-gate", action="store_true")
    args = parser.parse_args()

    result = run(Path(args.tracker), args.min_rows)
    print(json.dumps(result, indent=2, sort_keys=True))
    if args.fail_gate and not result["gate_pass"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
