#!/usr/bin/env python3
"""Check mechanical unsummarizability signals for deslop outputs."""

from __future__ import annotations

import argparse
import json
import math
import re
from datetime import datetime, timezone
from pathlib import Path
from statistics import mean

import semantic_drift


SENTENCE_BOUNDARY = re.compile(r"(?<=[.!?])\s+")
WORD = re.compile(r"\b[\w'-]+\b")
NUMBER_OR_DATE = re.compile(
    r"(?:\b\d+(?:[.,:]\d+)*(?:%| percent|x|ms|s|m|h|kb|mb|gb|tb| users| rows| days| weeks| months| years)?\b|"
    r"\$[0-9][0-9,]*(?:\.\d+)?|"
    r"\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?\s+\d{1,2}\b)",
    re.I,
)
QUOTE_TERM = re.compile(r"[\"']([^\"']{3,80})[\"']")
CAPITALIZED_TERM = re.compile(r"\b(?:[A-Z][a-z0-9]+(?:[- ][A-Z][a-z0-9]+){0,4}|[A-Z]{2,})\b")
LOAD_MARKERS = re.compile(
    r"\b(?:because|therefore|so|but|however|although|unless|if|when|while|before|after|"
    r"only|except|must|cannot|can't|won't|requires?|means?|causes?|prevents?|forces?|"
    r"risk|cost|gain|loss|tradeoff|constraint|evidence|mechanism|consequence|decision|"
    r"deadline|owner|scope|failure|blocks?|changes?|instead|rather|without)\b",
    re.I,
)
TOPIC_SWAP_RISK = re.compile(
    r"\b(?:important|significant|powerful|robust|seamless|dynamic|comprehensive|valuable|"
    r"meaningful|unique|innovative|transform|unlock|empower|enhance|elevate|leverage|"
    r"journey|landscape|ecosystem|alignment|stakeholders|outcomes?|impact|solution|"
    r"experience|capabilities|opportunities|potential)\b",
    re.I,
)

CAPITALIZED_STOPWORDS = {
    "A",
    "An",
    "And",
    "As",
    "At",
    "Before",
    "But",
    "By",
    "Do",
    "For",
    "From",
    "I",
    "If",
    "In",
    "It",
    "Keep",
    "Make",
    "No",
    "On",
    "Or",
    "Say",
    "Show",
    "So",
    "That",
    "The",
    "Then",
    "There",
    "These",
    "They",
    "This",
    "Those",
    "To",
    "Use",
    "We",
    "When",
    "With",
    "Without",
    "You",
    "Your",
}


def words(text: str) -> list[str]:
    return WORD.findall(text)


def sentences(text: str) -> list[str]:
    return [sentence.strip() for sentence in SENTENCE_BOUNDARY.split(text.strip()) if sentence.strip()]


def canonical(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip().lower())


def contains_fact(text: str, fact: str) -> bool:
    return semantic_drift.contains_fact(text, fact)


def required_facts(record: dict[str, object]) -> list[str]:
    facts = record.get("required_exact_facts", [])
    if not isinstance(facts, list):
        return []
    return [fact for fact in facts if isinstance(fact, str) and fact.strip()]


def capitalized_terms(text: str) -> list[str]:
    terms = []
    for match in CAPITALIZED_TERM.finditer(text):
        term = match.group(0).strip()
        if term in CAPITALIZED_STOPWORDS:
            continue
        if len(term) < 3 and not term.isupper():
            continue
        terms.append(term)
    return terms


def sentence_load_markers(sentence: str, facts: list[str]) -> list[str]:
    markers = []
    if any(contains_fact(sentence, fact) for fact in facts):
        markers.append("required_fact")
    if NUMBER_OR_DATE.search(sentence):
        markers.append("number_or_date")
    if capitalized_terms(sentence):
        markers.append("named_term")
    if LOAD_MARKERS.search(sentence):
        markers.append("claim_constraint_or_consequence")
    if ":" in sentence or ";" in sentence:
        markers.append("structured_clause")
    if "?" in sentence and len(words(sentence)) >= 6:
        markers.append("active_question")
    return markers


def sentence_load(sentence: str, facts: list[str]) -> dict[str, object]:
    marker_list = sentence_load_markers(sentence, facts)
    word_count = len(words(sentence))
    topic_swap_terms = TOPIC_SWAP_RISK.findall(sentence)
    low_load = word_count >= 7 and not marker_list
    topic_swap_risk = bool(topic_swap_terms) and "number_or_date" not in marker_list and "required_fact" not in marker_list
    return {
        "sentence": sentence,
        "word_count": word_count,
        "markers": marker_list,
        "is_loaded": bool(marker_list) or word_count <= 6,
        "low_load": low_load,
        "topic_swap_risk": topic_swap_risk,
        "topic_swap_terms": sorted(set(term.lower() for term in topic_swap_terms)),
    }


def idea_units(text: str, facts: list[str]) -> list[str]:
    units = []
    for fact in facts:
        if contains_fact(text, fact):
            units.append(fact)
    units.extend(match.group(0) for match in NUMBER_OR_DATE.finditer(text))
    units.extend(match.group(1).strip() for match in QUOTE_TERM.finditer(text))
    units.extend(capitalized_terms(text))

    seen = set()
    unique_units = []
    for unit in units:
        key = canonical(unit)
        if len(key) < 2 or key in seen:
            continue
        seen.add(key)
        unique_units.append(unit)
    return unique_units


def prefix_half_text(text: str) -> str:
    token_list = words(text)
    if not token_list:
        return ""
    half_count = max(1, math.ceil(len(token_list) * 0.5))
    return " ".join(token_list[:half_count])


def summary_loss(text: str, facts: list[str]) -> dict[str, object]:
    units = idea_units(text, facts)
    word_count = len(words(text))
    if word_count < 40 or len(units) < 4:
        return {
            "applicable": False,
            "reason": "needs_at_least_40_words_and_4_idea_units",
            "word_count": word_count,
            "idea_unit_count": len(units),
            "loss_ratio": None,
            "lost_units": [],
        }
    compressed = canonical(prefix_half_text(text))
    lost = [unit for unit in units if canonical(unit) not in compressed]
    return {
        "applicable": True,
        "word_count": word_count,
        "idea_unit_count": len(units),
        "loss_ratio": round(len(lost) / max(1, len(units)), 3),
        "lost_units": lost,
    }


def evaluate_text(sample_id: str, text: str, facts: list[str]) -> dict[str, object]:
    sentence_rows = [sentence_load(sentence, facts) for sentence in sentences(text)]
    sentence_count = len(sentence_rows)
    loaded_count = sum(1 for row in sentence_rows if row["is_loaded"])
    low_load = [row for row in sentence_rows if row["low_load"]]
    topic_swap = [row for row in sentence_rows if row["topic_swap_risk"]]
    loss = summary_loss(text, facts)
    return {
        "sample": sample_id,
        "word_count": len(words(text)),
        "sentence_count": sentence_count,
        "sentence_load_rate": round(loaded_count / max(1, sentence_count), 3),
        "low_load_sentence_count": len(low_load),
        "low_load_sentences": [row["sentence"] for row in low_load[:5]],
        "topic_swap_risk_count": len(topic_swap),
        "topic_swap_risk_sentences": [row["sentence"] for row in topic_swap[:5]],
        "summary_loss": loss,
    }


def read_jsonl(path: Path) -> list[dict[str, object]]:
    records = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        record = json.loads(line)
        if not isinstance(record, dict):
            raise ValueError(f"{path}:{line_number} must contain a JSON object")
        records.append(record)
    return records


def records_from_corpus(path: Path) -> list[tuple[str, str, list[str]]]:
    rows = []
    for line_number, record in enumerate(read_jsonl(path), start=1):
        text = record.get("output", "")
        if not isinstance(text, str) or not text.strip():
            continue
        sample_id = record.get("id", f"line-{line_number}")
        rows.append((str(sample_id), text, required_facts(record)))
    return rows


def records_from_text_files(paths: list[Path]) -> list[tuple[str, str, list[str]]]:
    return [(path.name, path.read_text(encoding="utf-8"), []) for path in paths]


def gate_summary(
    rows: list[dict[str, object]],
    min_sentence_load_rate: float,
    min_summary_loss_ratio: float,
    require_summary_loss: bool,
) -> dict[str, object]:
    sentence_rows = [row for row in rows if row["sentence_count"]]
    load_rates = [float(row["sentence_load_rate"]) for row in sentence_rows]
    summary_rows = [row for row in rows if row["summary_loss"]["applicable"]]
    summary_loss_ratios = [float(row["summary_loss"]["loss_ratio"]) for row in summary_rows]
    low_load_total = sum(int(row["low_load_sentence_count"]) for row in rows)
    topic_swap_total = sum(int(row["topic_swap_risk_count"]) for row in rows)
    failures = []
    warnings = []
    overall_sentence_load_rate = round(mean(load_rates), 3) if load_rates else 0.0
    avg_summary_loss_ratio = round(mean(summary_loss_ratios), 3) if summary_loss_ratios else 0.0
    if not rows:
        failures.append("no_rows")
    if overall_sentence_load_rate < min_sentence_load_rate:
        failures.append("sentence_load_rate_below_threshold")
    if not summary_rows:
        warning = "no_summary_loss_applicable_rows"
        if require_summary_loss:
            failures.append(warning)
        else:
            warnings.append(warning)
    elif avg_summary_loss_ratio < min_summary_loss_ratio:
        failures.append("summary_loss_ratio_below_threshold")
    return {
        "rows": len(rows),
        "overall_sentence_load_rate": overall_sentence_load_rate,
        "min_sentence_load_rate": min_sentence_load_rate,
        "summary_loss_applicable_rows": len(summary_rows),
        "avg_summary_loss_ratio": avg_summary_loss_ratio,
        "min_summary_loss_ratio": min_summary_loss_ratio,
        "low_load_sentence_total": low_load_total,
        "topic_swap_risk_total": topic_swap_total,
        "warnings": warnings,
        "failures": failures,
        "gate_pass": not failures,
    }


def run(
    records: list[tuple[str, str, list[str]]],
    min_sentence_load_rate: float,
    min_summary_loss_ratio: float,
    require_summary_loss: bool,
) -> dict[str, object]:
    rows = [evaluate_text(sample_id, text, facts) for sample_id, text, facts in records]
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "sample_count": len(rows),
        "gate_summary": gate_summary(
            rows,
            min_sentence_load_rate,
            min_summary_loss_ratio,
            require_summary_loss,
        ),
        "rows": rows,
    }


def markdown(result: dict[str, object]) -> str:
    gate = result["gate_summary"]
    lines = [
        "# Unsummarizability Check",
        "",
        f"- Generated: {result['generated_at']}",
        f"- Samples: {result['sample_count']}",
        f"- Gate pass: `{str(gate['gate_pass']).lower()}`",
        f"- Sentence-load rate: `{gate['overall_sentence_load_rate']}` "
        f"(minimum `{gate['min_sentence_load_rate']}`)",
        f"- Summary-loss rows: `{gate['summary_loss_applicable_rows']}`",
        f"- Average summary-loss ratio: `{gate['avg_summary_loss_ratio']}` "
        f"(minimum `{gate['min_summary_loss_ratio']}`)",
        f"- Low-load sentences: `{gate['low_load_sentence_total']}`",
        f"- Topic-swap risk sentences: `{gate['topic_swap_risk_total']}`",
        f"- Warnings: `{', '.join(gate['warnings']) or 'none'}`",
        f"- Failures: `{', '.join(gate['failures']) or 'none'}`",
        "",
        "| Sample | Words | Sentences | Load rate | Low-load | Topic-swap risk | Summary-loss |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in result["rows"]:
        loss = row["summary_loss"]
        loss_value = "n/a" if not loss["applicable"] else str(loss["loss_ratio"])
        lines.append(
            f"| {row['sample']} | {row['word_count']} | {row['sentence_count']} | "
            f"{row['sentence_load_rate']} | {row['low_load_sentence_count']} | "
            f"{row['topic_swap_risk_count']} | {loss_value} |"
        )
    problem_rows = [
        row
        for row in result["rows"]
        if row["low_load_sentence_count"] or row["topic_swap_risk_count"]
    ][:20]
    if problem_rows:
        lines.extend(["", "## Review Flags", ""])
        for row in problem_rows:
            lines.append(f"### {row['sample']}")
            for sentence in row["low_load_sentences"]:
                lines.append(f"- Low-load: {sentence}")
            for sentence in row["topic_swap_risk_sentences"]:
                lines.append(f"- Topic-swap risk: {sentence}")
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", help="JSONL corpus; checks each row's output field")
    parser.add_argument("--text", nargs="*", help="plain text files to check")
    parser.add_argument("--format", choices=["json", "markdown"], default="json")
    parser.add_argument("--fail-gate", action="store_true")
    parser.add_argument(
        "--require-summary-loss",
        action="store_true",
        help="fail when no row is long and specific enough for the 50-percent summary-loss check",
    )
    parser.add_argument("--min-sentence-load-rate", type=float, default=0.75)
    parser.add_argument("--min-summary-loss-ratio", type=float, default=0.25)
    args = parser.parse_args()

    if bool(args.corpus) == bool(args.text):
        parser.error("provide exactly one of --corpus or --text")

    records = (
        records_from_corpus(Path(args.corpus))
        if args.corpus
        else records_from_text_files([Path(path) for path in args.text])
    )
    result = run(
        records,
        args.min_sentence_load_rate,
        args.min_summary_loss_ratio,
        args.require_summary_loss,
    )
    if args.format == "json":
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(markdown(result), end="")
    if args.fail_gate and not result["gate_summary"]["gate_pass"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
