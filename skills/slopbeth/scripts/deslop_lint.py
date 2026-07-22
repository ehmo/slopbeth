#!/usr/bin/env python3
"""Deterministic slop-marker lint for prose."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


FILLER_PHRASES = [
    "it is important to note",
    "in today's fast-paced",
    "in the ever-evolving",
    "in conclusion",
    "ultimately",
    "at its core",
    "delve into",
    "dive into",
    "let's explore",
    "here's why",
    "this guide will",
    "plays a crucial role",
    "a crucial role",
    "more than just",
    "not just",
    "game changer",
    "game-changing",
    "unlock",
    "elevate",
    "empower",
    "supercharge",
    "seamless",
    "robust",
    "dynamic",
    "comprehensive",
    "transformative",
    "landscape",
    "ecosystem",
    "journey",
    "tapestry",
    "realm",
]

ABSTRACT_WORDS = [
    "important",
    "significant",
    "impactful",
    "innovative",
    "powerful",
    "valuable",
    "meaningful",
    "essential",
    "critical",
    "key",
    "vital",
    "enhance",
    "optimize",
    "streamline",
    "underscore",
    "highlight",
    "showcase",
]

STRUCTURE_PATTERNS = {
    "not_just_but": re.compile(r"\bnot\s+(?:just|only)\b.{0,90}\bbut\b", re.I | re.S),
    "whether_or": re.compile(r"\bwhether\b.{0,90}\bor\b", re.I | re.S),
    "from_to": re.compile(r"\bfrom\b.{1,60}\bto\b", re.I | re.S),
    "at_core": re.compile(r"\bat (?:its|the) core\b", re.I),
    "generic_here": re.compile(r"\bhere'?s (?:why|how|what)\b", re.I),
    "passiveish": re.compile(r"\b(?:is|are|was|were|be|been|being)\s+\w+(?:ed|en)\b", re.I),
}

GENERIC_CLOSERS = [
    "the future",
    "the possibilities are endless",
    "stands as a testament",
    "paving the way",
    "sets the stage",
]


def read_text(path: str | None) -> str:
    if not path or path == "-":
        return sys.stdin.read()
    return Path(path).read_text(encoding="utf-8")


def count_phrase_hits(text: str, phrases: list[str]) -> dict[str, int]:
    lower = text.lower()
    return {phrase: lower.count(phrase) for phrase in phrases if lower.count(phrase)}


def split_sentences(text: str) -> list[str]:
    return [s.strip() for s in re.split(r"(?<=[.!?])\s+", text.strip()) if s.strip()]


def title_case_heading_count(text: str) -> int:
    count = 0
    for line in text.splitlines():
        stripped = line.strip("#* ")
        if not stripped or len(stripped.split()) < 2:
            continue
        words = [w for w in re.findall(r"[A-Za-z]+", stripped) if len(w) > 2]
        if words and sum(w[:1].isupper() for w in words) / len(words) >= 0.75:
            count += 1
    return count


def repeated_sentence_starts(sentences: list[str]) -> dict[str, int]:
    starts: dict[str, int] = {}
    for sentence in sentences:
        words = re.findall(r"[A-Za-z']+", sentence.lower())[:3]
        if len(words) >= 2:
            key = " ".join(words[:2])
            starts[key] = starts.get(key, 0) + 1
    return {k: v for k, v in starts.items() if v > 1}


def lint(text: str) -> dict[str, object]:
    sentences = split_sentences(text)
    phrase_hits = count_phrase_hits(text, FILLER_PHRASES)
    closer_hits = count_phrase_hits(text, GENERIC_CLOSERS)
    abstract_hits = count_phrase_hits(text, ABSTRACT_WORDS)
    structure_hits = {
        name: len(pattern.findall(text)) for name, pattern in STRUCTURE_PATTERNS.items()
    }
    emphasis_count = len(re.findall(r"\*\*[^*\n]{1,80}\*\*", text))
    emoji_count = len(re.findall(r"[\U0001f300-\U0001faff]", text))
    dash_count = text.count("—") + text.count("–")
    triad_count = len(re.findall(r"\b\w+\s*,\s*\w+\s*,\s*(?:and|or)\s+\w+\b", text))
    suspect_total = (
        sum(phrase_hits.values())
        + sum(closer_hits.values())
        + sum(abstract_hits.values())
        + sum(structure_hits.values())
        + emphasis_count
        + emoji_count
        + dash_count
        + triad_count
        + title_case_heading_count(text)
    )
    words = re.findall(r"\b[\w']+\b", text)
    score = max(0, 100 - suspect_total * 4 - max(0, structure_hits["passiveish"] - 2) * 2)
    return {
        "word_count": len(words),
        "sentence_count": len(sentences),
        "slop_score": score,
        "suspect_total": suspect_total,
        "phrase_hits": phrase_hits,
        "abstract_hits": abstract_hits,
        "generic_closer_hits": closer_hits,
        "structure_hits": structure_hits,
        "formatting": {
            "emphasis_count": emphasis_count,
            "emoji_count": emoji_count,
            "dash_count": dash_count,
            "title_case_heading_count": title_case_heading_count(text),
        },
        "triad_count": triad_count,
        "repeated_sentence_starts": repeated_sentence_starts(sentences),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?", help="Text file, or stdin when omitted")
    parser.add_argument("--format", choices=["json", "text"], default="text")
    parser.add_argument("--fail-under", type=int, default=None)
    args = parser.parse_args()

    result = lint(read_text(args.path))
    if args.format == "json":
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(f"slop_score: {result['slop_score']}")
        print(f"suspect_total: {result['suspect_total']}")
        print(f"word_count: {result['word_count']}")
        print(f"sentence_count: {result['sentence_count']}")
    if args.fail_under is not None and int(result["slop_score"]) < args.fail_under:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
