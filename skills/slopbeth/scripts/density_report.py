#!/usr/bin/env python3
"""Report mechanical density signals for one text or a before/after pair."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


CLAIM_MARKERS = re.compile(
    r"\b(?:because|therefore|so|but|however|although|unless|if|when|cost|risk|gain|lose|"
    r"percent|%|\d+|must|should|cannot|can|will|won't|means|requires|causes|prevents)\b",
    re.I,
)
WEAK_WORDS = re.compile(
    r"\b(?:very|really|quite|rather|important|significant|powerful|robust|seamless|dynamic|"
    r"comprehensive|valuable|meaningful|interesting|unique)\b",
    re.I,
)


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def sentences(text: str) -> list[str]:
    return [s.strip() for s in re.split(r"(?<=[.!?])\s+", text.strip()) if s.strip()]


def metrics(text: str) -> dict[str, object]:
    words = re.findall(r"\b[\w']+\b", text)
    sents = sentences(text)
    claim_hits = len(CLAIM_MARKERS.findall(text))
    weak_hits = len(WEAK_WORDS.findall(text))
    removable_candidates = [
        s for s in sents if not CLAIM_MARKERS.search(s) and len(re.findall(r"\b[\w']+\b", s)) > 8
    ]
    return {
        "word_count": len(words),
        "sentence_count": len(sents),
        "avg_sentence_words": round(len(words) / max(1, len(sents)), 2),
        "claim_markers": claim_hits,
        "claim_markers_per_100_words": round(claim_hits * 100 / max(1, len(words)), 2),
        "weak_word_count": weak_hits,
        "removable_sentence_candidates": removable_candidates,
    }


def report(original: str, rewrite: str | None) -> dict[str, object]:
    original_metrics = metrics(original)
    result: dict[str, object] = {"original": original_metrics}
    if rewrite is not None:
        rewrite_metrics = metrics(rewrite)
        result["rewrite"] = rewrite_metrics
        result["compression_ratio"] = round(
            rewrite_metrics["word_count"] / max(1, original_metrics["word_count"]), 3
        )
        result["claim_density_delta"] = round(
            rewrite_metrics["claim_markers_per_100_words"]
            - original_metrics["claim_markers_per_100_words"],
            2,
        )
        result["weak_word_delta"] = rewrite_metrics["weak_word_count"] - original_metrics["weak_word_count"]
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original")
    parser.add_argument("rewrite", nargs="?")
    parser.add_argument("--format", choices=["json", "text"], default="text")
    args = parser.parse_args()
    result = report(read(args.original), read(args.rewrite) if args.rewrite else None)
    if args.format == "json":
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
