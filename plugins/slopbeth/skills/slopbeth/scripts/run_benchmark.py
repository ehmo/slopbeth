#!/usr/bin/env python3
"""Run local deslop benchmark suites."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path

import deslop_lint
import density_report
import preservation_check

REQUIRED_CORPUS_FIELDS = {
    "id",
    "category",
    "task_type",
    "risk",
    "input",
    "output",
    "preserved_facts",
    "required_exact_facts",
    "voice_notes",
    "expected_edit_depth",
    "reviewer_notes",
}
KNOWN_CATEGORIES = {
    "ai_marketing",
    "ai_essay",
    "technical_policy",
    "email_memo_support",
    "paired_voice",
    "human_control",
    "dense_risky",
    "adversarial_no_phrase",
}
KNOWN_EDIT_DEPTHS = {"none", "light", "medium", "heavy"}
KNOWN_TASK_TYPES = {"faithful_rewrite", "critique", "rewrite_with_context", "control"}


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def row_for_pair(sample_name: str, original: str, rewrite: str | None = None) -> dict[str, object]:
    row: dict[str, object] = {
        "sample": sample_name,
        "input_sha256": sha256_text(original),
        "input_lint": deslop_lint.lint(original),
        "input_density": density_report.metrics(original),
    }
    if rewrite is not None:
        row.update(
            {
                "output_sha256": sha256_text(rewrite),
                "output_lint": deslop_lint.lint(rewrite),
                "density_pair": density_report.report(original, rewrite),
                "preservation": preservation_check.compare(original, rewrite),
            }
        )
    return row


def word_count(text: str) -> int:
    return len(re.findall(r"\b[\w']+\b", text))


def length_bucket(text: str) -> str:
    count = word_count(text)
    if count < 120:
        return "short"
    if count < 400:
        return "medium"
    return "long"


def declared_fact_check(facts: list[str], rewrite: str) -> dict[str, object]:
    lower = rewrite.lower()
    missing = [fact for fact in facts if fact.lower() not in lower]
    return {
        "declared_count": len(facts),
        "missing_declared_facts": missing,
        "missing_declared_count": len(missing),
        "exact_match_only": True,
    }


def unsupported_additions(preservation: dict[str, object], allow_added_facts: bool) -> dict[str, object]:
    if allow_added_facts:
        return {"count": 0, "items": {}, "allowed": True}
    added = preservation.get("added", {})
    counted_keys = ["urls", "emails", "numbers", "dates", "quoted_terms"]
    items = {key: added.get(key, []) for key in counted_keys if added.get(key)}
    return {
        "count": sum(len(values) for values in items.values()),
        "items": items,
        "allowed": False,
    }


def corpus_schema_errors(record: dict[str, object], line_number: int, seen_ids: set[str]) -> list[str]:
    errors = []
    missing = sorted(REQUIRED_CORPUS_FIELDS - set(record))
    if missing:
        errors.append(f"line {line_number}: missing fields {', '.join(missing)}")
    sample_id = record.get("id")
    if not isinstance(sample_id, str) or not sample_id:
        errors.append(f"line {line_number}: id must be a nonempty string")
    elif sample_id in seen_ids:
        errors.append(f"line {line_number}: duplicate id {sample_id}")
    category = record.get("category")
    if category not in KNOWN_CATEGORIES:
        errors.append(f"line {line_number}: unknown category {category!r}")
    depth = record.get("expected_edit_depth")
    if depth not in KNOWN_EDIT_DEPTHS:
        errors.append(f"line {line_number}: unknown expected_edit_depth {depth!r}")
    task_type = record.get("task_type")
    if task_type not in KNOWN_TASK_TYPES:
        errors.append(f"line {line_number}: unknown task_type {task_type!r}")
    facts = record.get("preserved_facts")
    if not isinstance(facts, list) or not all(isinstance(item, str) and item for item in facts):
        errors.append(f"line {line_number}: preserved_facts must be a list of nonempty strings")
    required_exact_facts = record.get("required_exact_facts")
    if not isinstance(required_exact_facts, list) or not all(
        isinstance(item, str) and item for item in required_exact_facts
    ):
        errors.append(f"line {line_number}: required_exact_facts must be a list of nonempty strings")
    return errors


def run_directory(inputs: Path, outputs: Path | None) -> dict[str, object]:
    samples = sorted(inputs.glob("*.txt"))
    rows = []
    for sample in samples:
        original = read(sample)
        rewrite = None
        if outputs:
            rewrite_path = outputs / sample.name
            if rewrite_path.exists():
                rewrite = read(rewrite_path)
        rows.append(row_for_pair(sample.name, original, rewrite))
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "mode": "directory",
        "input_dir": str(inputs),
        "output_dir": str(outputs) if outputs else None,
        "sample_count": len(rows),
        "rows": rows,
    }


def run_corpus(corpus: Path) -> dict[str, object]:
    rows = []
    schema_errors = []
    seen_ids: set[str] = set()
    for line_number, line in enumerate(corpus.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        record = json.loads(line)
        schema_errors.extend(corpus_schema_errors(record, line_number, seen_ids))
        if isinstance(record.get("id"), str):
            seen_ids.add(record["id"])
        if "input" not in record:
            raise ValueError(f"{corpus}:{line_number} missing input")
        sample_id = record.get("id", f"line-{line_number}")
        row = row_for_pair(sample_id, record["input"], record.get("output"))
        exact_facts = record.get("required_exact_facts", [])
        task_type = record.get("task_type", "")
        if row.get("preservation") and isinstance(exact_facts, list):
            row["declared_fact_check"] = declared_fact_check(exact_facts, record.get("output", ""))
            row["unsupported_additions"] = unsupported_additions(
                row["preservation"],
                bool(record.get("allow_added_facts", False))
                or task_type in {"critique", "rewrite_with_context", "control"},
            )
        row.update(
            {
                "category": record.get("category", "uncategorized"),
                "task_type": task_type,
                "risk": record.get("risk", ""),
                "expected_edit_depth": record.get("expected_edit_depth", ""),
                "preserved_facts": record.get("preserved_facts", []),
                "required_exact_facts": record.get("required_exact_facts", []),
                "voice_notes": record.get("voice_notes", ""),
                "reviewer_notes": record.get("reviewer_notes", ""),
                "length_bucket": length_bucket(record["input"]),
            }
        )
        rows.append(row)
    gate_summary = release_gate_summary(rows, schema_errors)
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "mode": "corpus",
        "corpus": str(corpus),
        "sample_count": len(rows),
        "rows": rows,
        "category_summary": category_summary(rows),
        "gate_summary": gate_summary,
        "release_gate_pass": gate_summary["release_gate_pass"],
    }


def category_summary(rows: list[dict[str, object]]) -> dict[str, dict[str, float | int]]:
    summary: dict[str, dict[str, float | int]] = {}
    for row in rows:
        category = str(row.get("category", "uncategorized"))
        bucket = summary.setdefault(
            category,
            {
                "count": 0,
                "avg_input_slop": 0.0,
                "avg_output_slop": 0.0,
                "critical_missing": 0,
            },
        )
        bucket["count"] += 1
        bucket["avg_input_slop"] += row["input_lint"]["slop_score"]
        output_lint = row.get("output_lint")
        if output_lint:
            bucket["avg_output_slop"] += output_lint["slop_score"]
        preservation = row.get("preservation")
        if preservation:
            bucket["critical_missing"] += preservation["critical_missing_count"]
    for bucket in summary.values():
        count = max(1, int(bucket["count"]))
        bucket["avg_input_slop"] = round(float(bucket["avg_input_slop"]) / count, 2)
        bucket["avg_output_slop"] = round(float(bucket["avg_output_slop"]) / count, 2)
    return summary


def release_gate_summary(rows: list[dict[str, object]], schema_errors: list[str]) -> dict[str, object]:
    length_counts = {"short": 0, "medium": 0, "long": 0}
    missing_outputs = 0
    critical_missing = 0
    missing_declared = 0
    unsupported_added = 0
    task_counts: dict[str, int] = {}
    for row in rows:
        length_counts[str(row.get("length_bucket", "short"))] += 1
        task_type = str(row.get("task_type", "unknown"))
        task_counts[task_type] = task_counts.get(task_type, 0) + 1
        if "output_lint" not in row:
            missing_outputs += 1
        if row.get("preservation"):
            critical_missing += row["preservation"]["critical_missing_count"]
        if row.get("declared_fact_check"):
            missing_declared += row["declared_fact_check"]["missing_declared_count"]
        if row.get("unsupported_additions"):
            unsupported_added += row["unsupported_additions"]["count"]
    failures = []
    if schema_errors:
        failures.append("schema_errors")
    if len(rows) < 60:
        failures.append("sample_count_below_60")
    if missing_outputs:
        failures.append("missing_outputs")
    if length_counts["medium"] == 0 or length_counts["long"] == 0:
        failures.append("missing_medium_or_long_samples")
    if critical_missing:
        failures.append("critical_missing_facts")
    if missing_declared:
        failures.append("missing_declared_facts")
    if unsupported_added:
        failures.append("unsupported_added_facts")
    return {
        "schema_errors": schema_errors,
        "length_counts": length_counts,
        "task_counts": task_counts,
        "missing_outputs": missing_outputs,
        "critical_missing": critical_missing,
        "missing_declared_facts": missing_declared,
        "unsupported_added_facts": unsupported_added,
        "failures": failures,
        "release_gate_pass": not failures,
    }


def markdown(result: dict[str, object]) -> str:
    lines = [
        "# Slopbeth Benchmark Run",
        "",
        f"- Generated: {result['generated_at']}",
        f"- Mode: `{result.get('mode', 'directory')}`",
        f"- Samples: {result['sample_count']}",
        f"- Inputs: `{result.get('input_dir', result.get('corpus'))}`",
        f"- Outputs: `{result.get('output_dir')}`",
    ]
    if "rows" in result:
        lines.extend(
            [
                "",
                "| Sample | Category | Input slop | Output slop | Suspects delta | Claim density delta | Critical missing |",
                "| --- | --- | ---: | ---: | ---: | ---: | ---: |",
            ]
        )
        for row in result["rows"]:
            input_lint = row["input_lint"]
            output_lint = row.get("output_lint")
            category = row.get("category", "")
            if output_lint:
                suspects_delta = output_lint["suspect_total"] - input_lint["suspect_total"]
                density_delta = row["density_pair"]["claim_density_delta"]
                missing = row["preservation"]["critical_missing_count"]
                lines.append(
                    f"| {row['sample']} | {category} | {input_lint['slop_score']} | {output_lint['slop_score']} | "
                    f"{suspects_delta} | {density_delta} | {missing} |"
                )
            else:
                lines.append(f"| {row['sample']} | {category} | {input_lint['slop_score']} | n/a | n/a | n/a | n/a |")
    if "category_summary" in result:
        lines.extend(["", "## Category Summary", "", "| Category | Count | Avg input slop | Avg output slop | Critical missing |", "| --- | ---: | ---: | ---: | ---: |"])
        for category, bucket in sorted(result["category_summary"].items()):
            lines.append(
                f"| {category} | {bucket['count']} | {bucket['avg_input_slop']} | "
                f"{bucket['avg_output_slop']} | {bucket['critical_missing']} |"
            )
    if "gate_summary" in result:
        gate = result["gate_summary"]
        lines.extend(
            [
                "",
                "## Release Gate Signals",
                "",
                f"- Release gate pass: `{str(result['release_gate_pass']).lower()}`",
                f"- Length counts: `{gate['length_counts']}`",
                f"- Task counts: `{gate['task_counts']}`",
                f"- Missing outputs: `{gate['missing_outputs']}`",
                f"- Critical missing facts: `{gate['critical_missing']}`",
                f"- Missing declared facts: `{gate['missing_declared_facts']}`",
                f"- Unsupported added facts: `{gate['unsupported_added_facts']}`",
                f"- Failures: `{', '.join(gate['failures']) or 'none'}`",
            ]
        )
        if gate["schema_errors"]:
            lines.extend(["", "### Schema Errors", ""])
            lines.extend(f"- {error}" for error in gate["schema_errors"][:50])
    return "\n".join(lines) + "\n"


def summary_result(result: dict[str, object]) -> dict[str, object]:
    """Return the benchmark result without per-row diagnostics."""

    return {key: value for key, value in result.items() if key != "rows"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inputs")
    parser.add_argument("--outputs")
    parser.add_argument("--corpus", help="JSONL corpus with input and optional output fields")
    parser.add_argument("--format", choices=["json", "markdown"], default="json")
    parser.add_argument("--summary-only", action="store_true", help="omit per-row diagnostics from output")
    parser.add_argument("--fail-release-gate", action="store_true")
    args = parser.parse_args()
    if bool(args.corpus) == bool(args.inputs):
        parser.error("provide exactly one of --corpus or --inputs")
    result = (
        run_corpus(Path(args.corpus))
        if args.corpus
        else run_directory(Path(args.inputs), Path(args.outputs) if args.outputs else None)
    )
    output_result = summary_result(result) if args.summary_only else result
    if args.format == "json":
        print(json.dumps(output_result, indent=2, sort_keys=True))
    else:
        print(markdown(output_result))
    if args.fail_release_gate and not result.get("release_gate_pass", True):
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
