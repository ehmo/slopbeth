#!/usr/bin/env python3
"""Deterministic Orwell writing-system lint for prose.

Measures the five mechanically checkable rules from Orwell's "Politics and the
English Language" (1946). Rule six ("break any of these rules sooner than say
anything outright barbarous") is deliberately not mechanized: the score is a
signal, not a verdict. A low passive ratio or a rewritten cliche can still be
wrong, and a rule violation can be the right call. Read the flagged spans, then
decide.

Rules covered:
  1. dead metaphors and printed-cliche figures of speech
  2. long word where a short one will do
  3. words that can be cut
  4. passive where the active works
  5. foreign phrase, scientific word, or jargon with an everyday equivalent
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


# Rule 1: figures of speech "you are used to seeing in print" (Orwell's phrase).
# Curated dead metaphors and business/AI cliches, not live imagery.
DEAD_METAPHORS = [
    "at the end of the day",
    "moving forward",
    "going forward",
    "low-hanging fruit",
    "low hanging fruit",
    "think outside the box",
    "hit the ground running",
    "move the needle",
    "boil the ocean",
    "circle back",
    "deep dive",
    "deep-dive",
    "north star",
    "paradigm shift",
    "best-in-class",
    "best in class",
    "table stakes",
    "in the weeds",
    "tip of the iceberg",
    "level the playing field",
    "elephant in the room",
    "double-edged sword",
    "when push comes to shove",
    "needle in a haystack",
    "the perfect storm",
    "a game of cat and mouse",
    "navigate the landscape",
    "navigating the landscape",
    "in the realm of",
    "a beacon of",
    "stands as a testament",
    "paving the way",
    "sets the stage",
    "a double click",
    "double-click on",
    "raise the bar",
    "push the envelope",
    "the road ahead",
    "a stone's throw",
    "bring to the table",
]

# Rule 2: long word -> short word. Everyday equivalent exists.
LONG_WORDS = {
    "utilize": "use",
    "utilise": "use",
    "utilized": "used",
    "utilised": "used",
    "utilization": "use",
    "utilisation": "use",
    "leverage": "use",
    "leveraged": "used",
    "leveraging": "using",
    "facilitate": "help",
    "facilitates": "helps",
    "facilitated": "helped",
    "demonstrated": "showed",
    "demonstrates": "shows",
    "endeavor": "try",
    "endeavour": "try",
    "commence": "start",
    "commencing": "starting",
    "terminate": "end",
    "demonstrate": "show",
    "ascertain": "find out",
    "methodology": "method",
    "functionality": "features",
    "individual": "person",
    "approximately": "about",
    "additional": "more",
    "numerous": "many",
    "sufficient": "enough",
    "initiate": "start",
    "subsequently": "then",
    "accordingly": "so",
    "consequently": "so",
    "furthermore": "also",
    "moreover": "also",
    "nevertheless": "but",
    "notwithstanding": "despite",
    "henceforth": "from now on",
    "aforementioned": "this",
    "remuneration": "pay",
    "cognizant": "aware",
    "expedite": "speed up",
    "elucidate": "explain",
    "encompass": "cover",
    "necessitate": "need",
    "predominantly": "mostly",
    "utilizes": "uses",
    "aggregate": "total",
    "optimal": "best",
    "myriad": "many",
    "plethora": "plenty",
}

# Rule 3: deletable words and windy phrases. Cut or shorten.
DELETABLE_PHRASES = {
    "in order to": "to",
    "due to the fact that": "because",
    "in the event that": "if",
    "at this point in time": "now",
    "at the present time": "now",
    "in spite of the fact that": "although",
    "for the purpose of": "to",
    "with regard to": "about",
    "with respect to": "about",
    "in terms of": "(cut)",
    "it should be noted that": "(cut)",
    "it is important to note that": "(cut)",
    "the fact that": "that",
    "a large number of": "many",
    "in a timely manner": "on time",
    "on a daily basis": "daily",
    "has the ability to": "can",
    "have the ability to": "can",
    "is able to": "can",
    "are able to": "can",
    "the majority of": "most",
    "a variety of": "various",
    "each and every": "every",
    "first and foremost": "first",
    "in the near future": "soon",
    "in conjunction with": "with",
    "in the process of": "(cut)",
    "a wide range of": "many",
    "at all times": "always",
    "in the context of": "in",
    "serves as a": "is a",
    "plays a role in": "affects",
    "when it comes to": "(cut)",
}

# Rule 5: foreign phrase, scientific/jargon word with an everyday equivalent.
JARGON_TERMS = {
    "synergy": "fit",
    "synergies": "fit",
    "operationalize": "put to work",
    "incentivize": "reward",
    "ideate": "think",
    "actionable": "usable",
    "bandwidth": "time",
    "vis-a-vis": "about",
    "vis-à-vis": "about",
    "per se": "itself",
    "inter alia": "among other things",
    "ipso facto": "by that fact",
    "de facto": "in practice",
    "modus operandi": "method",
    "a priori": "in advance",
    "ceteris paribus": "all else equal",
    "raison d'etre": "purpose",
    "raison d'être": "purpose",
    "zeitgeist": "mood",
    "status quo": "current state",
    "paradigm": "model",
    "holistic": "whole",
    "granular": "detailed",
    "scalable": "able to grow",
    "frictionless": "smooth",
    "turnkey": "ready to use",
    "low-hanging": "easy",
}

# Auxiliary "be" forms for passive detection.
BE_FORMS = {"is", "are", "was", "were", "be", "been", "being", "get", "gets", "got", "getting"}

# Irregular past participles that do not end in -ed/-en.
IRREGULAR_PARTICIPLES = {
    "built", "sent", "made", "done", "kept", "held", "told", "found", "left",
    "lost", "put", "set", "cut", "run", "led", "read", "paid", "meant", "dealt",
    "sold", "brought", "bought", "caught", "taught", "thought", "sought", "given",
    "taken", "shown", "known", "grown", "drawn", "thrown", "written", "driven",
    "chosen", "spoken", "broken", "frozen", "stolen", "hidden", "beaten", "seen",
    "won", "spent",
}

# Past participles that are usually adjectival (skip to cut false positives).
ADJECTIVAL_PARTICIPLES = {
    "interested", "excited", "concerned", "involved", "related", "based",
    "located", "aimed", "designed", "intended", "supposed", "used", "known",
    "committed", "dedicated", "limited", "detailed", "advanced", "experienced",
    "qualified", "skilled", "gifted", "tired", "pleased", "satisfied",
}

WORD_RE = re.compile(r"[A-Za-z][A-Za-z'\-]*")


def read_text(path: str | None) -> str:
    if not path or path == "-":
        return sys.stdin.read()
    return Path(path).read_text(encoding="utf-8")


def split_sentences(text: str) -> list[str]:
    return [s.strip() for s in re.split(r"(?<=[.!?])\s+", text.strip()) if s.strip()]


def phrase_hits(text_lower: str, table: dict[str, str] | list[str]) -> dict[str, int]:
    keys = table if isinstance(table, list) else list(table.keys())
    hits: dict[str, int] = {}
    for key in keys:
        count = text_lower.count(key)
        if count:
            hits[key] = count
    return hits


def looks_participle(word: str) -> bool:
    lower = word.lower()
    if lower in ADJECTIVAL_PARTICIPLES:
        return False
    if lower in IRREGULAR_PARTICIPLES:
        return True
    if len(lower) > 4 and (lower.endswith("ed") or lower.endswith("en")):
        return True
    return False


def passive_sentences(sentences: list[str]) -> list[str]:
    """Flag sentences with a be-form followed within two tokens by a participle.

    Deliberately conservative: skips adjectival participles and "by" is not
    required, so it over-includes rather than misses. Read the spans.
    """
    flagged = []
    for sentence in sentences:
        tokens = WORD_RE.findall(sentence)
        lowered = [t.lower() for t in tokens]
        for index, token in enumerate(lowered):
            if token not in BE_FORMS:
                continue
            window = tokens[index + 1 : index + 3]
            for candidate in window:
                if candidate.lower() in BE_FORMS:
                    continue
                if looks_participle(candidate):
                    flagged.append(sentence.strip())
                    break
            else:
                continue
            break
    return flagged


def lint(text: str) -> dict[str, object]:
    lower = text.lower()
    sentences = split_sentences(text)
    words = WORD_RE.findall(text)
    word_count = len(words)

    metaphor_hits = phrase_hits(lower, DEAD_METAPHORS)
    long_word_hits = {
        word: len(re.findall(rf"\b{re.escape(word)}\b", lower)) for word in LONG_WORDS
    }
    long_word_hits = {w: c for w, c in long_word_hits.items() if c}
    deletable_hits = phrase_hits(lower, DELETABLE_PHRASES)
    jargon_hits = {
        term: len(re.findall(rf"\b{re.escape(term)}\b", lower))
        for term in JARGON_TERMS
    }
    jargon_hits = {t: c for t, c in jargon_hits.items() if c}

    passive = passive_sentences(sentences)

    rule1 = sum(metaphor_hits.values())
    rule2 = sum(long_word_hits.values())
    rule3 = sum(deletable_hits.values())
    rule4 = len(passive)
    rule5 = sum(jargon_hits.values())

    sentence_count = max(1, len(sentences))
    per_100 = 100.0 / max(1, word_count)
    passive_ratio = round(rule4 / sentence_count, 3)

    # Weighted penalty. Passive and cliche weigh a little heavier than a single
    # long word because they reshape whole sentences.
    penalty = rule1 * 5 + rule2 * 2 + rule3 * 4 + rule4 * 4 + rule5 * 3
    score = max(0, 100 - penalty)

    return {
        "word_count": word_count,
        "sentence_count": len(sentences),
        "orwell_score": score,
        "penalty": penalty,
        "passive_ratio": passive_ratio,
        "rule_counts": {
            "rule1_dead_metaphor": rule1,
            "rule2_long_word": rule2,
            "rule3_deletable_words": rule3,
            "rule4_passive_voice": rule4,
            "rule5_jargon_foreign": rule5,
        },
        "per_100_words": {
            "dead_metaphor": round(rule1 * per_100, 2),
            "long_word": round(rule2 * per_100, 2),
            "deletable_words": round(rule3 * per_100, 2),
            "jargon_foreign": round(rule5 * per_100, 2),
        },
        "dead_metaphor_hits": metaphor_hits,
        "long_word_hits": long_word_hits,
        "deletable_hits": deletable_hits,
        "jargon_hits": jargon_hits,
        "passive_sentences": passive[:20],
        "suggestions": {
            **{w: f"-> {LONG_WORDS[w]}" for w in long_word_hits},
            **{p: f"-> {DELETABLE_PHRASES[p]}" for p in deletable_hits},
            **{t: f"-> {JARGON_TERMS[t]}" for t in jargon_hits},
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?", help="Text file, or stdin when omitted")
    parser.add_argument("--format", choices=["json", "text"], default="text")
    parser.add_argument("--fail-under", type=int, default=None)
    parser.add_argument(
        "--max-passive-ratio",
        type=float,
        default=None,
        help="Fail when passive_ratio exceeds this value (signal only; rule six still applies)",
    )
    args = parser.parse_args()

    result = lint(read_text(args.path))
    if args.format == "json":
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        counts = result["rule_counts"]
        print(f"orwell_score: {result['orwell_score']}")
        print(f"passive_ratio: {result['passive_ratio']}")
        print(f"rule1_dead_metaphor: {counts['rule1_dead_metaphor']}")
        print(f"rule2_long_word: {counts['rule2_long_word']}")
        print(f"rule3_deletable_words: {counts['rule3_deletable_words']}")
        print(f"rule4_passive_voice: {counts['rule4_passive_voice']}")
        print(f"rule5_jargon_foreign: {counts['rule5_jargon_foreign']}")

    failed = False
    if args.fail_under is not None and int(result["orwell_score"]) < args.fail_under:
        failed = True
    if args.max_passive_ratio is not None and float(result["passive_ratio"]) > args.max_passive_ratio:
        failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
