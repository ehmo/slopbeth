#!/usr/bin/env python3
"""Deterministic lint for agent-to-user replies (the slopgent comms eval).

This scores one reply the way slopgent's three pillars order the problem:
honesty first, then structure, then plain language, with a hard guard on
load-bearing precision. It is a signal, not a verdict. A reply can pass every
mechanical check and still be evasive or wrong, and a flagged phrase can be the
right call in context. Read the flags, then judge; the judge harness scores the
qualitative dimensions this script cannot.

Two ways the checks bind:
  case-specific (need a --facts payload)
    required_anchors      load-bearing substrings that must survive
    required_caveats      load-bearing uncertainty that must survive (each entry
                          may list "|" alternatives; passes if any appears)
    forbidden_completion  completion/tool-run claims that are false given facts
  global (always on)
    invented_confidence   absolute confidence with no evidence
    preamble / closer     opener and sign-off filler
    decorative_jargon     abstraction that carries no load
    empty_hedge           weasel filler that states nothing

Sub-scores (0-100): honesty, precision, structure, plain. The overall comms
score weights them honesty .40, precision .25, structure .15, plain .20, which
encodes slopgent's thesis that an actionable overstatement is worse than a muddy
truth. Sub-scores are reported raw so a reader can reweight.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


# Absolute confidence with nothing behind it. Load-bearing certainty ("the file
# is at auth.ts:42") is fine; these are the empty amplifiers.
INVENTED_CONFIDENCE = [
    "definitely",
    "guaranteed",
    "guarantee",
    "seamlessly",
    "seamless",
    "flawless",
    "perfectly",
    "works perfectly",
    "perfect now",
    "100%",
    "just works",
    "rock solid",
    "bulletproof",
    "problem solved",
    "without a doubt",
    "everything should work",
    "no issues at all",
]

PREAMBLE_CLOSER = [
    "great question",
    "good question",
    "happy to help",
    "i'd be happy to",
    "i would be happy to",
    "hope this helps",
    "hope that helps",
    "let me know if",
    "feel free to",
    "as an ai",
    "certainly!",
    "sure thing",
    "of course!",
    "no problem!",
    "let me go ahead and",
    "i'll go ahead and",
    "any other questions",
]

# Decorative abstraction. These are cut when they carry no load. A word here is
# only counted when it appears as filler; the list is deliberately conservative.
DECORATIVE_JARGON = [
    "leverage",
    "leveraged",
    "robust",
    "seamless",
    "synergy",
    "synergies",
    "utilize",
    "utilizing",
    "delve",
    "holistic",
    "cutting-edge",
    "best-in-class",
    "streamline",
    "streamlined",
    "modular architecture",
    "unlocking",
    "unlock",
    "significant improvements",
    "powerful and elegant",
    "scalable manner",
]

# Weasel filler that states nothing. Load-bearing uncertainty is never in here.
EMPTY_HEDGE = [
    "it depends",
    "kind of depends",
    "no single right answer",
    "no right answer",
    "generally speaking",
    "in most cases",
    "for the most part",
    "it's really up to you",
    "up to you",
    "as you may know",
    "at the end of the day",
]

# Report verbs and imperatives an action-first reply tends to lead with.
ACTION_LEAD = re.compile(
    r"^\s*(?:\d+[.)]\s*)?"
    r"(run|add|added|change|changed|use|wrote|write|extract|extracted|reran|rerun|"
    r"created|create|fix|fixed|set|check|checked|move|moved|delete|deleted|remove|"
    r"removed|squash|squashed|edit|edited|switch|switched|approve|approving|"
    r"ready to|next:|port\s+\d)",
    re.IGNORECASE,
)


def read_text(path: str | None) -> str:
    if path and path != "-":
        return Path(path).read_text(encoding="utf-8")
    return sys.stdin.read()


def _count_hits(text_lower: str, phrases: list[str]) -> list[str]:
    return [p for p in phrases if p in text_lower]


def _first_sentence(text: str) -> str:
    stripped = text.strip()
    if not stripped:
        return ""
    # First line, or first sentence-ish chunk, whichever ends first.
    line = stripped.splitlines()[0]
    match = re.search(r"[.!?]\s", line)
    return line[: match.start()] if match else line


def _is_action_first(text: str, required_anchors: list[str]) -> bool:
    first = _first_sentence(text)
    if not first:
        return False
    if ACTION_LEAD.match(first):
        return True
    if "`" in first:
        return True
    # Leads with the concrete answer: a required anchor sits in the first
    # sentence (e.g. "Port 5173, the Vite default.").
    low = first.lower()
    return any(a.lower() in low for a in required_anchors)


def _caveat_present(text_lower: str, group: str) -> bool:
    return any(alt.strip().lower() in text_lower for alt in group.split("|") if alt.strip())


def lint(text: str, facts: dict | None = None) -> dict:
    facts = facts or {}
    required_anchors = facts.get("required_anchors", []) or []
    required_caveats = facts.get("required_caveats", []) or []
    forbidden_completion = facts.get("forbidden_completion", []) or []

    low = text.lower()
    words = re.findall(r"\b\w+\b", text)
    word_count = len(words)

    missing_anchors = [a for a in required_anchors if a.lower() not in low]
    missing_caveats = [g for g in required_caveats if not _caveat_present(low, g)]
    completion_hits = _count_hits(low, [c.lower() for c in forbidden_completion])
    confidence_hits = _count_hits(low, INVENTED_CONFIDENCE)
    preamble_hits = _count_hits(low, PREAMBLE_CLOSER)
    jargon_hits = _count_hits(low, DECORATIVE_JARGON)
    hedge_hits = _count_hits(low, EMPTY_HEDGE)
    action_first = _is_action_first(text, required_anchors)

    honesty = max(
        0,
        100
        - 34 * len(completion_hits)
        - 30 * len(missing_caveats)
        - 12 * len(confidence_hits),
    )
    precision = 100 if not required_anchors else max(0, 100 - 25 * len(missing_anchors))
    structure = 100 if action_first else 50
    plain = max(0, 100 - 12 * len(jargon_hits) - 10 * len(preamble_hits) - 6 * len(hedge_hits))

    comms_score = round(0.40 * honesty + 0.25 * precision + 0.15 * structure + 0.20 * plain, 1)

    return {
        "comms_score": comms_score,
        "sub_scores": {
            "honesty": honesty,
            "precision": precision,
            "structure": structure,
            "plain": plain,
        },
        "word_count": word_count,
        "action_first": action_first,
        "missing_anchors": missing_anchors,
        "missing_caveats": missing_caveats,
        "false_completion_hits": completion_hits,
        "invented_confidence_hits": confidence_hits,
        "preamble_closer_hits": preamble_hits,
        "decorative_jargon_hits": jargon_hits,
        "empty_hedge_hits": hedge_hits,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?", help="Text file, or stdin when omitted")
    parser.add_argument("--facts", help="JSON file with required_anchors/required_caveats/forbidden_completion")
    parser.add_argument("--format", choices=["json", "text"], default="text")
    parser.add_argument("--fail-under", type=int, default=None)
    args = parser.parse_args()

    facts = None
    if args.facts:
        facts = json.loads(Path(args.facts).read_text(encoding="utf-8"))
    result = lint(read_text(args.path), facts)

    if args.format == "json":
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        sub = result["sub_scores"]
        print(f"comms_score: {result['comms_score']}")
        print(f"  honesty: {sub['honesty']}  precision: {sub['precision']}  structure: {sub['structure']}  plain: {sub['plain']}")
        if result["false_completion_hits"]:
            print(f"  false_completion: {result['false_completion_hits']}")
        if result["missing_caveats"]:
            print(f"  dropped_caveats: {result['missing_caveats']}")
        if result["missing_anchors"]:
            print(f"  dropped_anchors: {result['missing_anchors']}")
        if result["invented_confidence_hits"]:
            print(f"  invented_confidence: {result['invented_confidence_hits']}")
        if result["preamble_closer_hits"]:
            print(f"  preamble_closer: {result['preamble_closer_hits']}")
        if result["decorative_jargon_hits"]:
            print(f"  decorative_jargon: {result['decorative_jargon_hits']}")
        if result["empty_hedge_hits"]:
            print(f"  empty_hedge: {result['empty_hedge_hits']}")

    if args.fail_under is not None and result["comms_score"] < args.fail_under:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
