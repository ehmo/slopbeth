#!/usr/bin/env python3
"""Score sentence cadence problems in benchmark outputs."""

from __future__ import annotations

import argparse
import json
import math
import re
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from statistics import mean, pstdev


WORD = re.compile(r"\b[\w']+\b")
SENTENCE_BOUNDARY = re.compile(r"(?<=[.!?])\s+")
POLISHED_TRANSITIONS = [
    "additionally",
    "moreover",
    "furthermore",
    "in addition",
    "as a result",
    "ultimately",
    "therefore",
    "this means",
    "overall",
]


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


def sentences(text: str) -> list[str]:
    return [sentence.strip() for sentence in SENTENCE_BOUNDARY.split(text.strip()) if sentence.strip()]


def word_count(text: str) -> int:
    return len(WORD.findall(text))


def transition_count(sentence: str) -> int:
    lower = sentence.lower()
    return sum(1 for term in POLISHED_TRANSITIONS if re.search(rf"\b{re.escape(term)}\b", lower))


def same_length_runs(lengths: list[int]) -> int:
    runs = 0
    current = 1
    for previous, current_length in zip(lengths, lengths[1:]):
        if abs(previous - current_length) <= 2:
            current += 1
        else:
            if current >= 3:
                runs += 1
            current = 1
    if current >= 3:
        runs += 1
    return runs


def score_text(sample_id: str, text: str) -> dict[str, object]:
    sentence_rows = sentences(text)
    lengths = [word_count(sentence) for sentence in sentence_rows]
    token_count = sum(lengths)
    average = mean(lengths) if lengths else 0.0
    deviation = pstdev(lengths) if len(lengths) > 1 else 0.0
    coefficient = deviation / average if average else 0.0
    transitions = sum(transition_count(sentence) for sentence in sentence_rows)
    starts = Counter(" ".join(WORD.findall(sentence.lower())[:2]) for sentence in sentence_rows)
    repeated_starts = {start: count for start, count in starts.items() if start and count > 1}
    monotony = same_length_runs(lengths)
    roughness = 0
    if len(lengths) >= 4 and coefficient < 0.28:
        roughness += 2
    roughness += monotony * 2
    roughness += transitions
    roughness += sum(repeated_starts.values())
    long_sentence_count = sum(1 for length in lengths if length > 34)
    roughness += long_sentence_count
    return {
        "sample": sample_id,
        "sentence_count": len(sentence_rows),
        "word_count": token_count,
        "sentence_lengths": lengths,
        "length_cv": round(coefficient, 3),
        "same_length_runs": monotony,
        "polished_transition_count": transitions,
        "repeated_starts": repeated_starts,
        "long_sentence_count": long_sentence_count,
        "cadence_roughness": roughness,
        "cadence_roughness_per_100_words": round(roughness / max(1, token_count) * 100, 3),
    }


def run(corpus: Path, max_average_roughness: float, max_row_roughness: int) -> dict[str, object]:
    scored = [
        score_text(str(row.get("id", f"row-{index}")), str(row.get("output", "")))
        for index, row in enumerate(read_jsonl(corpus), start=1)
        if str(row.get("output", "")).strip()
    ]
    rates = [float(row["cadence_roughness_per_100_words"]) for row in scored]
    average_rate = round(mean(rates), 3) if rates else math.inf
    row_failures = [
        str(row["sample"])
        for row in scored
        if int(row["cadence_roughness"]) > max_row_roughness
    ]
    failures = []
    if not scored:
        failures.append("no_rows")
    if average_rate > max_average_roughness:
        failures.append("average_cadence_roughness")
    if row_failures:
        failures.append("row_cadence_roughness")
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "corpus": str(corpus),
        "sample_count": len(scored),
        "average_cadence_roughness_per_100_words": average_rate,
        "max_average_roughness_per_100_words": max_average_roughness,
        "max_row_roughness": max_row_roughness,
        "row_failures": row_failures,
        "failures": failures,
        "gate_pass": not failures,
        "rows": scored,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", required=True)
    parser.add_argument("--max-average-roughness", type=float, default=3.5)
    parser.add_argument("--max-row-roughness", type=int, default=5)
    parser.add_argument("--format", choices=["json"], default="json")
    parser.add_argument("--fail-gate", action="store_true")
    args = parser.parse_args()

    result = run(Path(args.corpus), args.max_average_roughness, args.max_row_roughness)
    print(json.dumps(result, indent=2, sort_keys=True))
    if args.fail_gate and not result["gate_pass"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
