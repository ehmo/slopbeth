#!/usr/bin/env python3
"""Validate span annotations against the v2 benchmark corpus."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


REQUIRED_LABELS = {
    "unsupported_claim",
    "generic_reassurance",
    "overclaim",
    "formula",
    "preserved_fact",
    "policy_boundary",
    "voice_detail",
}


def read_jsonl(path: Path) -> list[dict[str, object]]:
    rows = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        row = json.loads(line)
        if not isinstance(row, dict):
            raise ValueError(f"{path}:{line_number}: expected JSON object")
        rows.append(row)
    return rows


def load_corpus(path: Path) -> dict[str, dict[str, object]]:
    return {str(row["id"]): row for row in read_jsonl(path)}


def check_span_list(
    row: dict[str, object],
    field: str,
    source_text: str,
    line_id: str,
    errors: list[str],
) -> int:
    spans = row.get(field)
    if not isinstance(spans, list) or not spans:
        errors.append(f"{line_id}: {field} must contain at least one span")
        return 0
    checked = 0
    for index, span in enumerate(spans, start=1):
        if not isinstance(span, dict):
            errors.append(f"{line_id}: {field}[{index}] must be an object")
            continue
        text = span.get("text")
        label = span.get("label")
        reason = span.get("reason")
        if not isinstance(text, str) or not text.strip():
            errors.append(f"{line_id}: {field}[{index}] missing text")
            continue
        if text not in source_text:
            errors.append(f"{line_id}: {field}[{index}] span not found exactly: {text!r}")
        if label not in REQUIRED_LABELS:
            errors.append(f"{line_id}: {field}[{index}] unknown label {label!r}")
        if not isinstance(reason, str) or len(reason.split()) < 3:
            errors.append(f"{line_id}: {field}[{index}] needs a concrete reason")
        checked += 1
    return checked


def run(corpus_path: Path, annotations_path: Path, min_rows: int) -> dict[str, object]:
    corpus = load_corpus(corpus_path)
    rows = read_jsonl(annotations_path)
    errors: list[str] = []
    annotated_cases: set[str] = set()
    bad_count = 0
    preserved_count = 0
    label_counts: dict[str, int] = {}

    for line_number, row in enumerate(rows, start=1):
        case_id = row.get("case_id")
        line_id = f"{annotations_path}:{line_number}"
        if not isinstance(case_id, str) or case_id not in corpus:
            errors.append(f"{line_id}: unknown case_id {case_id!r}")
            continue
        annotated_cases.add(case_id)
        source = corpus[case_id]
        bad_count += check_span_list(row, "bad_spans", str(source.get("input", "")), line_id, errors)
        preserved_count += check_span_list(
            row,
            "preserved_spans",
            str(source.get("output", "")),
            line_id,
            errors,
        )
        for field in ("bad_spans", "preserved_spans"):
            for span in row.get(field, []) if isinstance(row.get(field), list) else []:
                if isinstance(span, dict) and isinstance(span.get("label"), str):
                    label = str(span["label"])
                    label_counts[label] = label_counts.get(label, 0) + 1

    failures = []
    if len(rows) < min_rows:
        failures.append("too_few_annotation_rows")
    if len(annotated_cases) < min_rows:
        failures.append("too_few_annotated_cases")
    if bad_count < min_rows * 2:
        failures.append("too_few_bad_spans")
    if preserved_count < min_rows * 2:
        failures.append("too_few_preserved_spans")
    if errors:
        failures.append("annotation_errors")
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "corpus": str(corpus_path),
        "annotations": str(annotations_path),
        "annotation_rows": len(rows),
        "annotated_cases": len(annotated_cases),
        "bad_span_count": bad_count,
        "preserved_span_count": preserved_count,
        "label_counts": label_counts,
        "errors": errors[:50],
        "failures": failures,
        "gate_pass": not failures,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", required=True)
    parser.add_argument("--annotations", required=True)
    parser.add_argument("--min-rows", type=int, default=8)
    parser.add_argument("--format", choices=["json"], default="json")
    parser.add_argument("--fail-gate", action="store_true")
    args = parser.parse_args()

    result = run(Path(args.corpus), Path(args.annotations), args.min_rows)
    print(json.dumps(result, indent=2, sort_keys=True))
    if args.fail_gate and not result["gate_pass"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
