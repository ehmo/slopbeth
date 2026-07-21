#!/usr/bin/env python3
"""Detect mechanical semantic-drift risks in deslop benchmark outputs."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


REQUIRED_FIELDS = {"id", "input", "output"}
WORD = re.compile(r"\b[\w'-]+\b")
ARTICLES = {"a", "an", "the"}
MARKER_GROUPS: dict[str, list[tuple[str, str]]] = {
    "negation": [
        ("no", r"\bno\b"),
        ("not", r"\bnot\b"),
        ("never", r"\bnever\b"),
        ("cannot", r"\bcannot\b|\bcan't\b"),
        ("without", r"\bwithout\b"),
        ("unaffected", r"\bunaffected\b"),
    ],
    "obligation_permission": [
        ("must", r"\bmust\b"),
        ("may", r"\bmay\b"),
        ("can", r"\bcan\b"),
        ("cannot", r"\bcannot\b|\bcan't\b"),
        ("required", r"\brequir(?:e|es|ed|ing)\b"),
        ("needs", r"\bneeds?\b"),
        ("should", r"\bshould\b"),
    ],
    "scope_exclusivity": [
        ("only", r"\bonly\b"),
        ("all", r"\ball\b"),
        ("every", r"\bevery\b"),
        ("each", r"\beach\b"),
        ("any", r"\bany\b"),
        ("none", r"\bnone\b"),
        ("except", r"\bexcept(?:ion|ions)?\b"),
    ],
    "condition_time": [
        ("if", r"\bif\b"),
        ("unless", r"\bunless\b"),
        ("when", r"\bwhen\b"),
        ("before", r"\bbefore\b"),
        ("after", r"\bafter\b"),
        ("until", r"\buntil\b"),
        ("from_to", r"\bfrom\b.{0,80}\bto\b"),
        ("expire", r"\bexpir(?:e|es|ed|y|ation)\b"),
    ],
    "causality": [
        ("because", r"\bbecause\b"),
        ("caused", r"\bcaus(?:e|es|ed|ing)\b"),
        ("due_to", r"\bdue to\b"),
        ("therefore", r"\btherefore\b"),
        ("means", r"\bmeans?\b"),
        ("so_that", r"\bso that\b"),
        ("failed_because", r"\bfailed because\b"),
    ],
    "uncertainty": [
        ("might", r"\bmight\b"),
        ("could", r"\bcould\b"),
        ("likely", r"\blikely\b"),
        ("possible", r"\bpossible\b"),
        ("claim", r"\bclaims?\b|\bclaimed\b"),
        ("evidence", r"\bevidence\b|\bprove\b|\bproof\b"),
    ],
    "promise_intensity": [
        ("guarantee", r"\bguarantee(?:d|s)?\b"),
        ("ensure", r"\bensure(?:s|d)?\b"),
        ("promise", r"\bpromise(?:d|s)?\b"),
        ("always", r"\balways\b"),
        ("seamless", r"\bseamless\b"),
        ("world_class", r"\bworld[- ]class\b"),
    ],
}

STRICT_TASK_TYPES = {
    "control",
    "light_edit",
}
STRICT_CATEGORIES = {
    "technical_policy",
    "human_control",
    "dense_risky",
}
REVIEW_GROUPS = {
    "negation",
    "obligation_permission",
    "scope_exclusivity",
    "condition_time",
    "causality",
}
REPORT_LIMIT = 50
NEGATION_TERMS = {
    "no",
    "not",
    "never",
    "cannot",
    "can't",
    "dont",
    "don't",
    "doesnt",
    "doesn't",
    "didnt",
    "didn't",
    "without",
}


def words(text: str) -> list[str]:
    return [word.lower() for word in WORD.findall(text)]


def word_variants(word: str) -> list[str]:
    variants = {word}
    if word.isalpha() and len(word) > 2:
        variants.add(f"{word}s")
        variants.add(f"{word}ed")
        variants.add(f"{word}ing")
        if word.endswith("y"):
            variants.add(f"{word[:-1]}ies")
        if word.endswith("e"):
            variants.add(f"{word}d")
            variants.add(f"{word[:-1]}ing")
    return sorted(variants, key=len, reverse=True)


def fact_pattern(fact: str) -> re.Pattern[str]:
    fact_words = words(fact)
    if not fact_words:
        return re.compile(r"$^")
    tokens = [re.escape(word) for word in fact_words[:-1]]
    final = "|".join(re.escape(variant) for variant in word_variants(fact_words[-1]))
    tokens.append(f"(?:{final})")
    escaped = r"[^\w]+".join(tokens)
    return re.compile(rf"(?<!\w){escaped}(?!\w)", re.I)


def contains_fact(text: str, fact: str) -> bool:
    if not fact.strip():
        return False
    return bool(fact_pattern(fact).search(text))


def negation_in_fact(fact: str) -> bool:
    return bool(set(words(fact)) & NEGATION_TERMS)


def has_negated_fact(text: str, fact: str) -> bool:
    if negation_in_fact(fact):
        return False
    text_words = words(text)
    fact_words = words(fact)
    if not text_words or not fact_words:
        return False
    width = len(fact_words)
    for index in range(0, len(text_words) - width + 1):
        if text_words[index : index + width] != fact_words:
            continue
        previous_terms = list(reversed(text_words[max(0, index - 3) : index]))
        previous_anchor = next((term for term in previous_terms if term not in ARTICLES), "")
        if previous_anchor in NEGATION_TERMS:
            return True
    return False


def load_jsonl(path: Path) -> list[dict[str, object]]:
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


def schema_errors(rows: list[dict[str, object]], path: Path) -> list[str]:
    errors = []
    seen_ids: set[str] = set()
    for row in rows:
        line_number = row.get("_line_number", "?")
        missing = sorted(REQUIRED_FIELDS - set(row))
        if missing:
            errors.append(f"{path}:{line_number}: missing fields {', '.join(missing)}")
        sample_id = row.get("id")
        if not isinstance(sample_id, str) or not sample_id.strip():
            errors.append(f"{path}:{line_number}: id must be a nonempty string")
        elif sample_id in seen_ids:
            errors.append(f"{path}:{line_number}: duplicate id {sample_id}")
        else:
            seen_ids.add(sample_id)
        for field in ("input", "output"):
            if field in row and not isinstance(row[field], str):
                errors.append(f"{path}:{line_number}: {field} must be a string")
        for field in ("required_exact_facts", "forbidden_output_terms"):
            if field in row:
                value = row[field]
                if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
                    errors.append(f"{path}:{line_number}: {field} must be a list of strings")
    return errors


def markers(text: str) -> dict[str, list[str]]:
    found: dict[str, list[str]] = {}
    for group, patterns in MARKER_GROUPS.items():
        group_hits = []
        for label, pattern in patterns:
            if re.search(pattern, text, re.I | re.S):
                group_hits.append(label)
        if group_hits:
            found[group] = sorted(set(group_hits))
    return found


def exact_fact_missing(row: dict[str, object]) -> list[str]:
    output = str(row.get("output", ""))
    facts = row.get("required_exact_facts", [])
    if not isinstance(facts, list):
        return []
    return [str(fact) for fact in facts if not contains_fact(output, str(fact))]


def forbidden_hits(row: dict[str, object]) -> list[str]:
    output = str(row.get("output", ""))
    terms = row.get("forbidden_output_terms", [])
    if not isinstance(terms, list):
        return []
    return [str(term) for term in terms if contains_fact(output, str(term))]


def negated_fact_inversions(row: dict[str, object]) -> list[str]:
    input_text = str(row.get("input", ""))
    output_text = str(row.get("output", ""))
    facts = row.get("required_exact_facts", [])
    if not isinstance(facts, list):
        return []
    inversions = []
    for fact in facts:
        fact_text = str(fact)
        if not contains_fact(output_text, fact_text):
            continue
        if has_negated_fact(output_text, fact_text) and not has_negated_fact(input_text, fact_text):
            inversions.append(fact_text)
    return inversions


def is_strict_row(row: dict[str, object]) -> bool:
    return str(row.get("task_type", "")) in STRICT_TASK_TYPES or str(row.get("category", "")) in STRICT_CATEGORIES


def group_diff(input_markers: dict[str, list[str]], output_markers: dict[str, list[str]]) -> dict[str, object]:
    input_groups = set(input_markers)
    output_groups = set(output_markers)
    missing_groups = sorted(input_groups - output_groups)
    added_groups = sorted(output_groups - input_groups)
    changed_groups = {}
    for group in sorted(input_groups & output_groups):
        missing_terms = sorted(set(input_markers[group]) - set(output_markers[group]))
        added_terms = sorted(set(output_markers[group]) - set(input_markers[group]))
        if missing_terms or added_terms:
            changed_groups[group] = {
                "missing_terms": missing_terms,
                "added_terms": added_terms,
            }
    return {
        "missing_groups": missing_groups,
        "added_groups": added_groups,
        "changed_groups": changed_groups,
    }


def classify_risk(
    row: dict[str, object],
    diff: dict[str, object],
    missing_facts: list[str],
    forbidden_terms: list[str],
    negated_facts: list[str],
) -> tuple[str, list[str]]:
    strict = is_strict_row(row)
    reasons = []
    missing_groups = set(diff["missing_groups"])
    added_groups = set(diff["added_groups"])
    changed_groups = diff["changed_groups"]
    if missing_facts:
        reasons.append("missing_required_exact_facts")
    if forbidden_terms:
        reasons.append("forbidden_output_terms")
    if negated_facts:
        reasons.append("negated_required_exact_facts")
    if strict and "promise_intensity" in added_groups:
        reasons.append("strict_row_added_promise_intensity")
    if (
        missing_facts
        or forbidden_terms
        or negated_facts
        or "strict_row_added_promise_intensity" in reasons
    ):
        return "high", reasons
    if strict and missing_groups & REVIEW_GROUPS:
        reasons.append("strict_row_lost_marker_group")
    if strict and added_groups & REVIEW_GROUPS:
        reasons.append("strict_row_added_marker_group")
    if strict:
        for group, change in changed_groups.items():
            if group in REVIEW_GROUPS and (change["missing_terms"] or change["added_terms"]):
                reasons.append(f"strict_row_changed_{group}_terms")
                break
    if missing_groups or added_groups or changed_groups:
        return "review", reasons or ["marker_distribution_changed"]
    return "none", []


def evaluate_row(row: dict[str, object]) -> dict[str, object]:
    input_text = str(row.get("input", ""))
    output_text = str(row.get("output", ""))
    input_markers = markers(input_text)
    output_markers = markers(output_text)
    diff = group_diff(input_markers, output_markers)
    missing_facts = exact_fact_missing(row)
    forbidden_terms = forbidden_hits(row)
    negated_facts = negated_fact_inversions(row)
    risk, reasons = classify_risk(row, diff, missing_facts, forbidden_terms, negated_facts)
    return {
        "id": str(row.get("id", f"line-{row.get('_line_number', '?')}")),
        "line_number": row.get("_line_number"),
        "category": str(row.get("category", "")),
        "task_type": str(row.get("task_type", "")),
        "strict_row": is_strict_row(row),
        "input_markers": input_markers,
        "output_markers": output_markers,
        "missing_groups": diff["missing_groups"],
        "added_groups": diff["added_groups"],
        "changed_groups": diff["changed_groups"],
        "missing_required_exact_facts": missing_facts,
        "forbidden_output_terms": forbidden_terms,
        "negated_required_exact_facts": negated_facts,
        "risk": risk,
        "reasons": reasons,
        "input_excerpt": str(row.get("input", ""))[:180],
        "output_excerpt": str(row.get("output", ""))[:180],
    }


def score(path: Path) -> dict[str, object]:
    raw_rows = load_jsonl(path)
    errors = schema_errors(raw_rows, path)
    rows = [evaluate_row(row) for row in raw_rows if not (REQUIRED_FIELDS - set(row))]
    risk_counts = Counter(row["risk"] for row in rows)
    strict_count = sum(1 for row in rows if row["strict_row"])
    high_rows = [row["id"] for row in rows if row["risk"] == "high"]
    review_rows = [row["id"] for row in rows if row["risk"] == "review"]
    strict_review_rows = [row["id"] for row in rows if row["risk"] == "review" and row["strict_row"]]
    hard_alarm_pass = not high_rows and not errors
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "suite": str(path),
        "sample_count": len(raw_rows),
        "scored_sample_count": len(rows),
        "strict_sample_count": strict_count,
        "risk_counts": dict(sorted(risk_counts.items())),
        "high_risk_ids": high_rows,
        "review_ids": review_rows,
        "strict_review_ids": strict_review_rows,
        "review_row_count": len(review_rows),
        "strict_review_row_count": len(strict_review_rows),
        "schema_errors": errors,
        "semantic_marker_hard_alarm_pass": hard_alarm_pass,
        "semantic_drift_gate_pass": hard_alarm_pass,
        "rows": rows,
    }


def escape_cell(value: object) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def format_changed_groups(changed_groups: dict[str, object]) -> str:
    if not changed_groups:
        return "none"
    parts = []
    for group, change in changed_groups.items():
        missing = ", ".join(change.get("missing_terms", [])) or "none"
        added = ", ".join(change.get("added_terms", [])) or "none"
        parts.append(f"{group} (missing: {missing}; added: {added})")
    return "; ".join(parts)


def markdown(result: dict[str, object]) -> str:
    lines = [
        "# Semantic Drift Report",
        "",
        f"- Generated: {result['generated_at']}",
        f"- Suite: `{result['suite']}`",
        f"- Samples: {result['sample_count']}",
        f"- Scored samples: {result['scored_sample_count']}",
        f"- Strict samples: {result['strict_sample_count']}",
        f"- Hard-alarm gate pass: `{str(result['semantic_marker_hard_alarm_pass']).lower()}`",
        f"- High-confidence drift rows: `{len(result['high_risk_ids'])}`",
        f"- Marker-review rows: `{result['review_row_count']}`",
        f"- Strict marker-review rows: `{result['strict_review_row_count']}`",
        "",
        "Interpretation: this is a marker-level semantic drift review, not proof of semantic equivalence. Passing means no configured high-confidence alarm fired; review rows still need human or judge context.",
        "",
        "## Risk Counts",
        "",
        "| Risk | Count |",
        "| --- | ---: |",
    ]
    for risk, count in result["risk_counts"].items():
        lines.append(f"| {risk} | {count} |")
    if result["schema_errors"]:
        lines.extend(["", "## Schema Errors", ""])
        lines.extend(f"- {error}" for error in result["schema_errors"])
    ordered_rows = sorted(
        [row for row in result["rows"] if row["risk"] != "none"],
        key=lambda row: (0 if row["risk"] == "high" else 1, not row["strict_row"], row["id"]),
    )
    report_rows = ordered_rows[:REPORT_LIMIT]
    if report_rows:
        lines.extend(
            [
                "",
                "## Review Rows",
                "",
                "| Sample | Risk | Strict | Missing groups | Added groups | Changed marker terms | Reasons |",
                "| --- | --- | --- | --- | --- | --- | --- |",
            ]
        )
        for row in report_rows:
            lines.append(
                f"| {escape_cell(row['id'])} | {escape_cell(row['risk'])} | "
                f"{str(row['strict_row']).lower()} | "
                f"{escape_cell(', '.join(row['missing_groups']) or 'none')} | "
                f"{escape_cell(', '.join(row['added_groups']) or 'none')} | "
                f"{escape_cell(format_changed_groups(row['changed_groups']))} | "
                f"{escape_cell(', '.join(row['reasons']) or 'none')} |"
            )
    if len(ordered_rows) > REPORT_LIMIT:
        lines.extend(["", f"_Only first {REPORT_LIMIT} non-clean rows shown._"])
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", required=True, help="JSONL corpus or forward suite with input and output fields.")
    parser.add_argument("--format", choices=["json", "markdown"], default="json")
    parser.add_argument("--json-output", help="Optional path for a JSON report.")
    parser.add_argument("--markdown-output", help="Optional path for a Markdown report.")
    parser.add_argument("--quiet", action="store_true", help="Do not print the report to stdout.")
    parser.add_argument("--fail-gate", action="store_true")
    parser.add_argument("--fail-strict-review", action="store_true")
    args = parser.parse_args()
    result = score(Path(args.corpus))
    if args.json_output:
        Path(args.json_output).write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if args.markdown_output:
        Path(args.markdown_output).write_text(markdown(result), encoding="utf-8")
    if not args.quiet:
        if args.format == "json":
            print(json.dumps(result, indent=2, sort_keys=True))
        else:
            print(markdown(result))
    if args.fail_gate and not result["semantic_marker_hard_alarm_pass"]:
        return 2
    if args.fail_strict_review and result["strict_review_ids"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
