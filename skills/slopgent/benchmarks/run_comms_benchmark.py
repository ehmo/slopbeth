#!/usr/bin/env python3
"""Run the slopgent comms benchmark over corpus.jsonl and compare systems.

Scores every candidate reply with comms_lint, aggregates per system, prints a
comparison matrix and a per-category breakdown, writes results.json, and applies
a release gate on slopgent's thesis: it must lead the field overall and carry
zero honesty or precision failures across the corpus.

  python3 run_comms_benchmark.py               # text report
  python3 run_comms_benchmark.py --format json
  python3 run_comms_benchmark.py --fail-gate    # exit 1 if the gate fails
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path
from statistics import mean

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "scripts"))
import comms_lint  # noqa: E402

PRIMARY = "slopgent"
MARGIN = 8.0  # points slopgent must lead the runner-up by to claim it is better


def load_corpus(path: Path) -> list[dict]:
    cases = []
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        try:
            cases.append(json.loads(line))
        except json.JSONDecodeError as exc:
            raise ValueError(f"{path}:{n}: invalid JSON: {exc}") from exc
    return cases


def score_corpus(cases: list[dict]) -> dict:
    systems = sorted({s for c in cases for s in c["candidates"]})
    per_system_scores: dict[str, list[float]] = defaultdict(list)
    per_system_sub: dict[str, dict[str, list[float]]] = defaultdict(lambda: defaultdict(list))
    per_system_flags: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    per_case: list[dict] = []
    per_category: dict[str, dict[str, list[float]]] = defaultdict(lambda: defaultdict(list))

    for case in cases:
        row = {"id": case["id"], "category": case["category"], "systems": {}}
        for system, text in case["candidates"].items():
            result = comms_lint.lint(text, case["facts"])
            per_system_scores[system].append(result["comms_score"])
            for k, v in result["sub_scores"].items():
                per_system_sub[system][k].append(v)
            per_category[case["category"]][system].append(result["comms_score"])
            per_system_flags[system]["false_completion"] += len(result["false_completion_hits"])
            per_system_flags[system]["dropped_caveats"] += len(result["missing_caveats"])
            per_system_flags[system]["dropped_anchors"] += len(result["missing_anchors"])
            per_system_flags[system]["invented_confidence"] += len(result["invented_confidence_hits"])
            per_system_flags[system]["preamble_closer"] += len(result["preamble_closer_hits"])
            per_system_flags[system]["decorative_jargon"] += len(result["decorative_jargon_hits"])
            row["systems"][system] = result
        per_case.append(row)

    summary = {}
    for system in systems:
        summary[system] = {
            "mean_comms_score": round(mean(per_system_scores[system]), 1),
            "sub_means": {k: round(mean(v), 1) for k, v in per_system_sub[system].items()},
            "flag_totals": dict(per_system_flags[system]),
        }

    # Head-to-head: cases where PRIMARY strictly beats each competitor.
    head_to_head = {}
    for system in systems:
        if system == PRIMARY:
            continue
        wins = ties = losses = 0
        for case in per_case:
            p = case["systems"][PRIMARY]["comms_score"]
            o = case["systems"][system]["comms_score"]
            if p > o:
                wins += 1
            elif p == o:
                ties += 1
            else:
                losses += 1
        head_to_head[system] = {"wins": wins, "ties": ties, "losses": losses}

    category_means = {
        cat: {sys_: round(mean(scores), 1) for sys_, scores in bysys.items()}
        for cat, bysys in per_category.items()
    }

    return {
        "systems": systems,
        "case_count": len(cases),
        "summary": summary,
        "head_to_head": head_to_head,
        "category_means": category_means,
        "per_case": per_case,
    }


def evaluate_gate(results: dict) -> dict:
    summary = results["summary"]
    checks = []

    primary_mean = summary[PRIMARY]["mean_comms_score"]
    others = {s: v["mean_comms_score"] for s, v in summary.items() if s != PRIMARY}
    runner_up = max(others.values()) if others else 0.0
    runner_up_name = max(others, key=others.get) if others else "n/a"

    checks.append({
        "name": "slopgent_leads_field",
        "ok": all(primary_mean > v for v in others.values()),
        "detail": f"{PRIMARY} {primary_mean} vs best competitor {runner_up_name} {runner_up}",
    })
    checks.append({
        "name": "slopgent_margin",
        "ok": (primary_mean - runner_up) >= MARGIN,
        "detail": f"lead {round(primary_mean - runner_up, 1)} (need >= {MARGIN})",
    })
    flags = summary[PRIMARY]["flag_totals"]
    checks.append({
        "name": "slopgent_zero_false_completion",
        "ok": flags.get("false_completion", 0) == 0,
        "detail": f"false_completion={flags.get('false_completion', 0)}",
    })
    checks.append({
        "name": "slopgent_zero_dropped_caveats",
        "ok": flags.get("dropped_caveats", 0) == 0,
        "detail": f"dropped_caveats={flags.get('dropped_caveats', 0)}",
    })
    checks.append({
        "name": "slopgent_zero_dropped_anchors",
        "ok": flags.get("dropped_anchors", 0) == 0,
        "detail": f"dropped_anchors={flags.get('dropped_anchors', 0)}",
    })
    checks.append({
        "name": "slopgent_leads_honesty_and_precision",
        "ok": all(
            summary[PRIMARY]["sub_means"][dim] >= max(summary[s]["sub_means"][dim] for s in summary)
            for dim in ("honesty", "precision")
        ),
        "detail": "honesty and precision sub-means are field-leading",
    })

    return {"passed": all(c["ok"] for c in checks), "checks": checks}


def render_text(results: dict, gate: dict) -> str:
    lines = []
    lines.append(f"slopgent comms benchmark  ({results['case_count']} cases)")
    lines.append("")
    header = f"{'system':<14}{'overall':>8}{'honesty':>9}{'precis':>8}{'struct':>8}{'plain':>7}"
    lines.append(header)
    lines.append("-" * len(header))
    for system in sorted(results["summary"], key=lambda s: -results["summary"][s]["mean_comms_score"]):
        s = results["summary"][system]
        sub = s["sub_means"]
        star = "  <-" if system == PRIMARY else ""
        lines.append(
            f"{system:<14}{s['mean_comms_score']:>8}{sub['honesty']:>9}{sub['precision']:>8}"
            f"{sub['structure']:>8}{sub['plain']:>7}{star}"
        )
    lines.append("")
    lines.append("head-to-head (slopgent vs each):")
    for system, hh in results["head_to_head"].items():
        lines.append(f"  vs {system:<12} wins {hh['wins']}  ties {hh['ties']}  losses {hh['losses']}")
    lines.append("")
    lines.append("flag totals (lower is better):")
    flag_keys = ["false_completion", "dropped_caveats", "dropped_anchors", "invented_confidence", "preamble_closer", "decorative_jargon"]
    lines.append(f"  {'system':<14}" + "".join(f"{k[:9]:>11}" for k in flag_keys))
    for system in results["systems"]:
        ft = results["summary"][system]["flag_totals"]
        lines.append(f"  {system:<14}" + "".join(f"{ft.get(k, 0):>11}" for k in flag_keys))
    lines.append("")
    lines.append(f"gate: {'PASS' if gate['passed'] else 'FAIL'}")
    for c in gate["checks"]:
        lines.append(f"  [{'ok' if c['ok'] else 'XX'}] {c['name']}: {c['detail']}")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", default=str(HERE / "corpus.jsonl"))
    parser.add_argument("--format", choices=["json", "text"], default="text")
    parser.add_argument("--out", default=str(HERE / "results" / "results.json"))
    parser.add_argument("--fail-gate", action="store_true")
    args = parser.parse_args()

    cases = load_corpus(Path(args.corpus))
    results = score_corpus(cases)
    gate = evaluate_gate(results)

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps({"results": results, "gate": gate}, indent=2), encoding="utf-8")

    if args.format == "json":
        print(json.dumps({"summary": results["summary"], "head_to_head": results["head_to_head"], "gate": gate}, indent=2))
    else:
        print(render_text(results, gate))

    if args.fail_gate and not gate["passed"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
