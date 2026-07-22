#!/usr/bin/env python3
"""Score higher-level AI-writing signature residue in deslop outputs."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from statistics import mean


WORD = re.compile(r"\b[\w'-]+\b")
SENTENCE_BOUNDARY = re.compile(r"(?<=[.!?])\s+")
FIRST_WORDS = re.compile(r"^[^A-Za-z0-9]*((?:[A-Za-z0-9']+\W+){0,3}[A-Za-z0-9']+)")

PROMOTIONAL_TERMS = [
    "unlock",
    "elevate",
    "empower",
    "supercharge",
    "game-changing",
    "transformative",
    "seamless",
    "robust",
    "dynamic",
    "comprehensive",
    "meaningful",
    "valuable",
    "powerful",
    "innovative",
    "landscape",
    "ecosystem",
    "journey",
    "tapestry",
    "realm",
]

BLAND_TERMS = [
    "better",
    "clearer",
    "clarity",
    "effective",
    "efficient",
    "helpful",
    "improve",
    "improved",
    "improves",
    "improvement",
    "impact",
    "outcome",
    "outcomes",
    "people",
    "process",
    "results",
    "stronger",
    "success",
    "support",
    "supports",
    "teams",
    "value",
    "work",
]

FILLER_PHRASES = [
    "it is important to note",
    "in today's fast-paced",
    "in the ever-evolving",
    "at its core",
    "plays a crucial role",
    "a crucial role",
    "more than just",
    "not just",
    "set the stage",
    "paving the way",
    "stands as a testament",
    "the possibilities are endless",
]

CANNED_OPENERS = [
    re.compile(r"^\s*in (?:today's|the) .{0,60}\b(?:landscape|world|era)\b", re.I),
    re.compile(r"^\s*(?:this|these) (?:article|guide|post|piece) (?:will|explores?)\b", re.I),
    re.compile(r"^\s*(?:when it comes to|there is no denying that)\b", re.I),
]

GENERIC_CLOSERS = [
    re.compile(r"\b(?:the future|possibilities are endless|paving the way)\b", re.I),
    re.compile(r"\b(?:in conclusion|ultimately),?\s+(?:this|these|the)\b", re.I),
    re.compile(r"\bstands as a testament\b", re.I),
]

FORMULA_PATTERNS = {
    "not_just_but": re.compile(r"\bnot\s+(?:just|only)\b.{0,90}\bbut\b", re.I | re.S),
    "whether_or": re.compile(r"\bwhether\b.{0,90}\bor\b", re.I | re.S),
    "from_to": re.compile(r"\bfrom\b.{1,60}\bto\b", re.I | re.S),
    "here_is": re.compile(r"\bhere'?s (?:why|how|what)\b", re.I),
}

PROBLEM_CONTEXT = re.compile(
    r"\b(?:claim|claims|claimed|claiming|copy|draft|pitch|slogan|phrase|word|"
    r"language|should prove|needs proof|needs evidence|before claiming|rather than|"
    r"do not need|does not need|without evidence|unsupported|source|sourced)\b",
    re.I,
)
DATE_OR_RANGE_CONTEXT = re.compile(r"\b\d{4}-\d{2}-\d{2}\b|\b\d+(?:\.\d+)?%?\b", re.I)
CAPITALIZED_TERM = re.compile(r"\b(?:[A-Z][a-z0-9]+(?:[- ][A-Z][a-z0-9]+){0,4}|[A-Z]{2,})\b")
CAPITALIZED_STOPWORDS = {
    "A",
    "An",
    "And",
    "As",
    "At",
    "But",
    "By",
    "For",
    "From",
    "I",
    "If",
    "In",
    "It",
    "Its",
    "On",
    "Or",
    "That",
    "The",
    "This",
    "To",
    "We",
    "When",
    "With",
    "Without",
    "You",
}
LOAD_MARKER = re.compile(
    r"\b(?:because|but|unless|if|when|except|requires?|must|cannot|risk|cost|"
    r"constraint|evidence|proof|metric|owner|deadline|failure|tradeoff|specific|"
    r"number|example|workflow|source|sourced)\b",
    re.I,
)


def words(text: str) -> list[str]:
    return WORD.findall(text)


def canonical(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip().lower())


def sentences(text: str) -> list[str]:
    return [sentence.strip() for sentence in SENTENCE_BOUNDARY.split(text.strip()) if sentence.strip()]


def count_literal_terms(sentence: str, terms: list[str]) -> list[str]:
    lower = sentence.lower()
    return [term for term in terms if re.search(rf"(?<!\w){re.escape(term)}(?!\w)", lower)]


def sentence_anchor_count(sentence: str, required_facts: list[str]) -> int:
    lower = canonical(sentence)
    count = 0
    for fact in required_facts:
        if canonical(fact) in lower:
            count += 1
    count += len(re.findall(r"\b\d+(?:[.,:]\d+)*(?:%| percent|x|ms|s|m|h| days| years)?\b", sentence, re.I))
    count += sum(1 for term in CAPITALIZED_TERM.findall(sentence) if term not in CAPITALIZED_STOPWORDS)
    count += len(LOAD_MARKER.findall(sentence))
    return count


def sentence_signature(
    sentence: str, is_first: bool, is_last: bool, required_facts: list[str]
) -> dict[str, object]:
    hits: list[str] = []
    review_hits: list[str] = []
    problem_context = bool(PROBLEM_CONTEXT.search(sentence))
    bland_terms = count_literal_terms(sentence, BLAND_TERMS)
    anchors = sentence_anchor_count(sentence, required_facts)

    for term in count_literal_terms(sentence, PROMOTIONAL_TERMS):
        (review_hits if problem_context else hits).append(f"promotional:{term}")
    for phrase in count_literal_terms(sentence, FILLER_PHRASES):
        (review_hits if problem_context else hits).append(f"filler:{phrase}")
    if is_first:
        for pattern in CANNED_OPENERS:
            if pattern.search(sentence):
                hits.append("canned_opener")
    if is_last:
        for pattern in GENERIC_CLOSERS:
            if pattern.search(sentence):
                (review_hits if problem_context else hits).append("generic_closer")
    for name, pattern in FORMULA_PATTERNS.items():
        if not pattern.search(sentence):
            continue
        if name == "from_to" and DATE_OR_RANGE_CONTEXT.search(sentence):
            review_hits.append(f"formula:{name}")
        elif problem_context:
            review_hits.append(f"formula:{name}")
        else:
            hits.append(f"formula:{name}")
    if len(words(sentence)) >= 8 and len(bland_terms) >= 2 and anchors == 0:
        hits.append("bland_clean_sentence")

    return {
        "sentence": sentence,
        "hard_hits": sorted(hits),
        "review_hits": sorted(review_hits),
        "problem_context": problem_context,
        "anchor_count": anchors,
        "bland_terms": sorted(bland_terms),
    }


def first_start(sentence: str, size: int = 3) -> str:
    tokens = [token.lower() for token in WORD.findall(sentence)[:size]]
    return " ".join(tokens)


def anchor_count(text: str, required_facts: list[str]) -> int:
    lower = canonical(text)
    count = 0
    for fact in required_facts:
        if canonical(fact) in lower:
            count += 1
    count += len(re.findall(r"\b\d+(?:[.,:]\d+)*(?:%| percent|x|ms|s|m|h| days| years)?\b", text, re.I))
    count += len(CAPITALIZED_TERM.findall(text))
    count += len(LOAD_MARKER.findall(text))
    return count


def score_text(sample_id: str, text: str, required_facts: list[str]) -> dict[str, object]:
    sentence_rows = sentences(text)
    scored_sentences = [
        sentence_signature(sentence, index == 0, index == len(sentence_rows) - 1, required_facts)
        for index, sentence in enumerate(sentence_rows)
    ]
    hard_hits = [hit for row in scored_sentences for hit in row["hard_hits"]]
    review_hits = [hit for row in scored_sentences for hit in row["review_hits"]]
    token_count = len(words(text))
    hard_per_100 = round(len(hard_hits) / max(1, token_count) * 100, 3)
    anchors = anchor_count(text, required_facts)
    anchor_rate = round(anchors / max(1, token_count) * 100, 3)
    return {
        "sample": sample_id,
        "word_count": token_count,
        "sentence_count": len(sentence_rows),
        "hard_signature_count": len(hard_hits),
        "hard_signatures_per_100_words": hard_per_100,
        "review_signature_count": len(review_hits),
        "bland_clean_sentence_count": sum(
            1 for row in scored_sentences if "bland_clean_sentence" in row["hard_hits"]
        ),
        "anchor_count": anchors,
        "anchor_rate_per_100_words": anchor_rate,
        "first_sentence_start": first_start(sentence_rows[0]) if sentence_rows else "",
        "hard_hits": sorted(Counter(hard_hits).items()),
        "review_hits": sorted(Counter(review_hits).items()),
        "flagged_sentences": [
            row for row in scored_sentences if row["hard_hits"] or row["review_hits"]
        ][:8],
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


def required_facts(row: dict[str, object]) -> list[str]:
    facts = row.get("required_exact_facts", [])
    if not isinstance(facts, list):
        return []
    return [fact for fact in facts if isinstance(fact, str) and fact.strip()]


def records_from_corpus(path: Path) -> list[tuple[str, str, list[str]]]:
    records = []
    for line_number, row in enumerate(read_jsonl(path), start=1):
        text = row.get("output", "")
        if not isinstance(text, str) or not text.strip():
            continue
        records.append((str(row.get("id", f"line-{line_number}")), text, required_facts(row)))
    return records


def records_from_text(paths: list[Path]) -> list[tuple[str, str, list[str]]]:
    return [(path.name, path.read_text(encoding="utf-8"), []) for path in paths]


def gate_summary(
    rows: list[dict[str, object]],
    max_hard_per_100: float,
    max_row_hard_count: int,
    max_row_bland_clean_sentences: int,
    max_repeated_start: int,
) -> dict[str, object]:
    hard_rates = [float(row["hard_signatures_per_100_words"]) for row in rows]
    row_hard_failures = [
        str(row["sample"])
        for row in rows
        if int(row["hard_signature_count"]) > max_row_hard_count
    ]
    bland_clean_failures = [
        str(row["sample"])
        for row in rows
        if int(row["bland_clean_sentence_count"]) > max_row_bland_clean_sentences
    ]
    repeated_starts = Counter(
        str(row["first_sentence_start"])
        for row in rows
        if str(row.get("first_sentence_start", "")).strip()
    )
    repeated_start_failures = {
        start: count
        for start, count in sorted(repeated_starts.items())
        if count > max_repeated_start and len(start.split()) >= 2
    }
    average_hard_per_100 = round(mean(hard_rates), 3) if hard_rates else 0.0
    failures = []
    if not rows:
        failures.append("no_rows")
    if average_hard_per_100 > max_hard_per_100:
        failures.append("average_hard_signature_rate")
    if row_hard_failures:
        failures.append("row_hard_signature_count")
    if bland_clean_failures:
        failures.append("bland_clean_sentence_count")
    if repeated_start_failures:
        failures.append("repeated_sentence_start")
    return {
        "rows": len(rows),
        "average_hard_signatures_per_100_words": average_hard_per_100,
        "max_hard_signatures_per_100_words": max_hard_per_100,
        "max_row_hard_signature_count": max_row_hard_count,
        "row_hard_signature_failures": row_hard_failures,
        "max_row_bland_clean_sentences": max_row_bland_clean_sentences,
        "bland_clean_sentence_failures": bland_clean_failures,
        "max_repeated_start": max_repeated_start,
        "repeated_start_failures": repeated_start_failures,
        "top_repeated_starts": repeated_starts.most_common(10),
        "total_hard_signatures": sum(int(row["hard_signature_count"]) for row in rows),
        "total_review_signatures": sum(int(row["review_signature_count"]) for row in rows),
        "failures": failures,
        "gate_pass": not failures,
    }


def run(
    records: list[tuple[str, str, list[str]]],
    max_hard_per_100: float,
    max_row_hard_count: int,
    max_row_bland_clean_sentences: int,
    max_repeated_start: int,
) -> dict[str, object]:
    rows = [score_text(sample_id, text, facts) for sample_id, text, facts in records]
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "sample_count": len(rows),
        "gate_summary": gate_summary(
            rows,
            max_hard_per_100=max_hard_per_100,
            max_row_hard_count=max_row_hard_count,
            max_row_bland_clean_sentences=max_row_bland_clean_sentences,
            max_repeated_start=max_repeated_start,
        ),
        "rows": rows,
    }


def markdown(result: dict[str, object]) -> str:
    gate = result["gate_summary"]
    lines = [
        "# Signature Score",
        "",
        f"- Generated: {result['generated_at']}",
        f"- Samples: {result['sample_count']}",
        f"- Gate pass: `{str(gate['gate_pass']).lower()}`",
        f"- Average hard signatures per 100 words: `{gate['average_hard_signatures_per_100_words']}` "
        f"(maximum `{gate['max_hard_signatures_per_100_words']}`)",
        f"- Total hard signatures: `{gate['total_hard_signatures']}`",
        f"- Total review signatures: `{gate['total_review_signatures']}`",
        f"- Row hard-signature failures: `{', '.join(gate['row_hard_signature_failures']) or 'none'}`",
        f"- Bland-clean failures: `{', '.join(gate['bland_clean_sentence_failures']) or 'none'}`",
        f"- Repeated-start failures: `{gate['repeated_start_failures'] or 'none'}`",
        f"- Failures: `{', '.join(gate['failures']) or 'none'}`",
        "",
        "## Top Repeated Starts",
        "",
        "| Start | Count |",
        "| --- | ---: |",
    ]
    for start, count in gate["top_repeated_starts"]:
        lines.append(f"| {start} | {count} |")
    lines.extend(
        [
            "",
            "## Rows",
            "",
            "| Sample | Words | Hard | Hard/100 | Review | Anchors/100 | First start |",
            "| --- | ---: | ---: | ---: | ---: | ---: | --- |",
        ]
    )
    for row in result["rows"]:
        lines.append(
            f"| {row['sample']} | {row['word_count']} | {row['hard_signature_count']} | "
            f"{row['hard_signatures_per_100_words']} | {row['review_signature_count']} | "
            f"{row['anchor_rate_per_100_words']} | {row['first_sentence_start']} |"
        )
    flagged = [row for row in result["rows"] if row["flagged_sentences"]][:20]
    if flagged:
        lines.extend(["", "## Flagged Sentences", ""])
        for row in flagged:
            lines.append(f"### {row['sample']}")
            for sentence in row["flagged_sentences"]:
                hard = ", ".join(sentence["hard_hits"]) or "none"
                review = ", ".join(sentence["review_hits"]) or "none"
                lines.append(f"- Hard: `{hard}`; review: `{review}`; {sentence['sentence']}")
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", help="JSONL corpus; checks each row's output field")
    parser.add_argument("--text", nargs="*", help="plain text files to check")
    parser.add_argument("--format", choices=["json", "markdown"], default="json")
    parser.add_argument("--fail-gate", action="store_true")
    parser.add_argument("--max-hard-per-100", type=float, default=0.55)
    parser.add_argument("--max-row-hard-count", type=int, default=2)
    parser.add_argument("--max-row-bland-clean-sentences", type=int, default=1)
    parser.add_argument("--max-repeated-start", type=int, default=8)
    args = parser.parse_args()

    if bool(args.corpus) == bool(args.text):
        parser.error("provide exactly one of --corpus or --text")
    records = (
        records_from_corpus(Path(args.corpus))
        if args.corpus
        else records_from_text([Path(path) for path in args.text])
    )
    result = run(
        records,
        max_hard_per_100=args.max_hard_per_100,
        max_row_hard_count=args.max_row_hard_count,
        max_row_bland_clean_sentences=args.max_row_bland_clean_sentences,
        max_repeated_start=args.max_repeated_start,
    )
    if args.format == "json":
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(markdown(result))
    if args.fail_gate and not result["gate_summary"]["gate_pass"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
