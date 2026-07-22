#!/usr/bin/env python3
"""Compare preservation-sensitive tokens between a source and rewrite."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


PATTERNS = {
    "urls": re.compile(r"https?://[^\s)]+"),
    "emails": re.compile(r"\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b"),
    "numbers": re.compile(r"\b\d+(?:[.,]\d+)*(?:%|[a-zA-Z]+)?\b"),
    "dates": re.compile(
        r"\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2},?\s+\d{2,4}\b|\b\d{4}-\d{2}-\d{2}\b",
        re.I,
    ),
    "quoted_terms": re.compile(r"['\"][^'\"]{2,80}['\"]"),
    "capitalized_terms": re.compile(r"\b(?:[A-Z][A-Za-z0-9&.-]+(?:\s+[A-Z][A-Za-z0-9&.-]+){0,4})\b"),
}

CAPITALIZED_STOPWORDS = {
    "A",
    "An",
    "And",
    "Because",
    "But",
    "For",
    "If",
    "Keep",
    "Or",
    "So",
    "The",
    "This",
    "When",
}


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def extract(text: str) -> dict[str, list[str]]:
    data: dict[str, list[str]] = {}
    for name, pattern in PATTERNS.items():
        values = sorted(set(m.group(0).strip(".,;:") for m in pattern.finditer(text)))
        if name == "capitalized_terms":
            values = [v for v in values if v not in CAPITALIZED_STOPWORDS and v.lower() != "i" and len(v) > 1]
        data[name] = values
    return data


def compare(original: str, rewrite: str) -> dict[str, object]:
    before = extract(original)
    after = extract(rewrite)
    missing = {
        key: [item for item in values if item not in after[key]]
        for key, values in before.items()
    }
    added = {
        key: [item for item in values if item not in before[key]]
        for key, values in after.items()
    }
    critical_missing = (
        len(missing["urls"])
        + len(missing["emails"])
        + len(missing["numbers"])
        + len(missing["dates"])
        + len(missing["quoted_terms"])
    )
    return {
        "missing": {k: v for k, v in missing.items() if v},
        "added": {k: v for k, v in added.items() if v},
        "critical_missing_count": critical_missing,
        "review_required": critical_missing > 0 or bool(missing["capitalized_terms"]),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original")
    parser.add_argument("rewrite")
    parser.add_argument("--format", choices=["json", "text"], default="text")
    args = parser.parse_args()
    result = compare(read(args.original), read(args.rewrite))
    if args.format == "json":
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(f"critical_missing_count: {result['critical_missing_count']}")
        print(f"review_required: {str(result['review_required']).lower()}")
        for key, values in result["missing"].items():
            print(f"missing_{key}: {', '.join(values)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
