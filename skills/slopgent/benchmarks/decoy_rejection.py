#!/usr/bin/env python3
"""Prove comms_lint rejects clean-looking-but-bad slopgent decoys.

A scorer that only rewards surface brevity would pass a reply that is terse,
structured, and jargon-free but still lies about what ran or drops a
load-bearing caveat. This harness feeds the lint a set of such decoys and
asserts each is rejected with the specific reason it should be — not merely a
low aggregate score. It also runs honest pass-controls that must clear a high
bar, so the suite proves the lint can both reject bad output and accept good.

Every fail row lists must_flag categories; the row passes the suite only if the
lint raises at least one required flag AND the honesty-or-precision sub-score it
targets is actually depressed. Every pass row must clear min_score with zero
honesty or precision failures. A suite that cannot fail every decoy, or that
fails a control, exits non-zero.

  python3 decoy_rejection.py                 # text report
  python3 decoy_rejection.py --format json
  python3 decoy_rejection.py --fail-gate     # exit 1 if any row is mishandled
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "scripts"))
import comms_lint  # noqa: E402

# must_flag name -> (lint result key, the sub-score that should be depressed)
FLAG_MAP = {
    "false_completion": ("false_completion_hits", "honesty"),
    "dropped_caveats": ("missing_caveats", "honesty"),
    "dropped_anchors": ("missing_anchors", "precision"),
    "invented_confidence": ("invented_confidence_hits", "honesty"),
    "preamble_closer": ("preamble_closer_hits", "plain"),
    "decorative_jargon": ("decorative_jargon_hits", "plain"),
    "empty_hedge": ("empty_hedge_hits", "plain"),
}


def load_rows(path: Path) -> list[dict]:
    rows = []
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError as exc:
            raise ValueError(f"{path}:{n}: invalid JSON: {exc}") from exc
    return rows


def evaluate(rows: list[dict]) -> dict:
    results = []
    for row in rows:
        result = comms_lint.lint(row["text"], row.get("facts", {}))
        kind = row["kind"]
        if kind == "fail":
            required = row.get("must_flag", [])
            raised = []
            for flag in required:
                key, sub = FLAG_MAP[flag]
                hit = bool(result.get(key))
                depressed = result["sub_scores"][sub] < 100
                if hit and depressed:
                    raised.append(flag)
            ok = bool(required) and all(f in raised for f in required)
            results.append({
                "id": row["id"], "kind": kind, "ok": ok,
                "required": required, "raised": raised,
                "comms_score": result["comms_score"],
                "detail": "rejected with required reason(s)" if ok
                          else f"MISSED: needed {required}, raised {raised}",
            })
        elif kind == "pass":
            min_score = row.get("min_score", 90)
            honesty_ok = not result["false_completion_hits"] and not result["missing_caveats"] \
                and not result["invented_confidence_hits"]
            precision_ok = not result["missing_anchors"]
            ok = result["comms_score"] >= min_score and honesty_ok and precision_ok
            results.append({
                "id": row["id"], "kind": kind, "ok": ok,
                "comms_score": result["comms_score"], "min_score": min_score,
                "detail": "accepted above bar, clean honesty+precision" if ok
                          else f"CONTROL FAILED: score {result['comms_score']} / need {min_score}, "
                               f"honesty_ok={honesty_ok} precision_ok={precision_ok}",
            })
        else:
            results.append({"id": row["id"], "kind": kind, "ok": False, "detail": f"unknown kind {kind!r}"})

    fails = [r for r in results if r["kind"] == "fail"]
    passes = [r for r in results if r["kind"] == "pass"]
    gate = {
        "all_decoys_rejected": all(r["ok"] for r in fails),
        "all_controls_accepted": all(r["ok"] for r in passes),
        "fail_row_count": len(fails),
        "pass_row_count": len(passes),
    }
    gate["passed"] = gate["all_decoys_rejected"] and gate["all_controls_accepted"] \
        and gate["fail_row_count"] >= 4 and gate["pass_row_count"] >= 2
    return {"results": results, "gate": gate}


def render_text(report: dict) -> str:
    lines = ["slopgent decoy rejection", ""]
    for r in report["results"]:
        mark = "ok" if r["ok"] else "XX"
        lines.append(f"  [{mark}] {r['id']} ({r['kind']}): {r['detail']}")
    g = report["gate"]
    lines.append("")
    lines.append(f"fail rows: {g['fail_row_count']} (need >= 4)  pass rows: {g['pass_row_count']} (need >= 2)")
    lines.append(f"all decoys rejected: {g['all_decoys_rejected']}   all controls accepted: {g['all_controls_accepted']}")
    lines.append(f"gate: {'PASS' if g['passed'] else 'FAIL'}")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--decoys", default=str(HERE / "decoys.jsonl"))
    parser.add_argument("--format", choices=["json", "text"], default="text")
    parser.add_argument("--fail-gate", action="store_true")
    args = parser.parse_args()

    rows = load_rows(Path(args.decoys))
    report = evaluate(rows)

    if args.format == "json":
        print(json.dumps(report, indent=2))
    else:
        print(render_text(report))

    if args.fail_gate and not report["gate"]["passed"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
