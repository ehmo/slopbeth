#!/usr/bin/env python3
"""Aggregate the blinded judge panel and de-blind it against the key.

Each judge wrote JSONL over the same packet, scoring replies A-D per case with
no idea which system produced which reply. This reads those files plus
blinding_key.json, maps every label back to its system, and reports per-system
mean judge scores, how often each system was the blinded `best` pick, and
inter-judge spread. The panel is the independent check on the deterministic
lint: the lint is a formula I wrote, the judges are not.

  python3 judge_aggregate.py                    # text report over judge_*.jsonl
  python3 judge_aggregate.py --format json
  python3 judge_aggregate.py --fail-gate        # exit 1 if slopgent does not lead

The gate mirrors the deterministic one but on human-style judgment: slopgent
must lead overall and on honesty, and win the plurality of blinded best-picks.
"""

from __future__ import annotations

import argparse
import glob
import json
import sys
from collections import defaultdict
from pathlib import Path
from statistics import mean, pstdev

HERE = Path(__file__).resolve().parent
AXES = ["honesty", "precision", "structure", "plain"]
PRIMARY = "slopgent"
MARGIN = 0.3  # points (0-5 scale) slopgent must lead the runner-up overall


def load_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        raise FileNotFoundError(f"judge file not found: {path}")
    rows = []
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError as exc:
            raise ValueError(f"{path}:{n}: invalid JSON: {exc}") from exc
    return rows


def load_key(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"blinding key not found: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def deblind(judge_files: list[Path], key: dict) -> dict:
    # per-system axis scores across all judges/cases, plus best-pick tallies.
    system_axis: dict[str, dict[str, list[float]]] = defaultdict(lambda: defaultdict(list))
    system_overall: dict[str, list[float]] = defaultdict(list)
    best_picks: dict[str, int] = defaultdict(int)
    best_by_judge: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    per_case_overall: dict[str, dict[str, list[float]]] = defaultdict(lambda: defaultdict(list))
    flags: dict[str, list[str]] = defaultdict(list)
    judge_names = []
    coverage = {"cases_scored": 0, "judge_case_rows": 0, "missing": []}

    for jf in judge_files:
        judge = jf.stem
        judge_names.append(judge)
        rows = load_jsonl(jf)
        seen_cases = set()
        for row in rows:
            case_id = row.get("case_id")
            if case_id not in key:
                raise ValueError(f"{jf}: case_id {case_id!r} not in blinding key")
            seen_cases.add(case_id)
            coverage["judge_case_rows"] += 1
            mapping = key[case_id]  # {label: system}
            scores = row.get("scores", {})
            for label, system in mapping.items():
                axis_scores = scores.get(label)
                if not axis_scores:
                    coverage["missing"].append(f"{judge}:{case_id}:{label}")
                    continue
                vals = []
                for axis in AXES:
                    v = axis_scores.get(axis)
                    if v is None:
                        coverage["missing"].append(f"{judge}:{case_id}:{label}:{axis}")
                        continue
                    system_axis[system][axis].append(float(v))
                    vals.append(float(v))
                if vals:
                    ov = mean(vals)
                    system_overall[system].append(ov)
                    per_case_overall[case_id][system].append(ov)
            best_label = row.get("best")
            if best_label in mapping:
                best_system = mapping[best_label]
                best_picks[best_system] += 1
                best_by_judge[judge][best_system] += 1
            for label, note in (row.get("flags") or {}).items():
                if label in mapping and note:
                    flags[mapping[label]].append(f"{case_id}: {note}")
        # cases each judge missed entirely
        for case_id in key:
            if case_id not in seen_cases:
                coverage["missing"].append(f"{judge}:{case_id}:ALL")

    coverage["cases_scored"] = len(key)

    systems = sorted(system_overall)
    summary = {}
    for system in systems:
        summary[system] = {
            "overall": round(mean(system_overall[system]), 2) if system_overall[system] else None,
            "overall_sd": round(pstdev(system_overall[system]), 2) if len(system_overall[system]) > 1 else 0.0,
            "axes": {a: round(mean(system_axis[system][a]), 2) if system_axis[system][a] else None for a in AXES},
            "best_picks": best_picks.get(system, 0),
            "n_scores": len(system_overall[system]),
        }

    return {
        "judges": judge_names,
        "systems": systems,
        "summary": summary,
        "best_by_judge": {j: dict(v) for j, v in best_by_judge.items()},
        "per_case_overall": {
            cid: {s: round(mean(v), 2) for s, v in bysys.items()}
            for cid, bysys in per_case_overall.items()
        },
        "flags": dict(flags),
        "coverage": coverage,
    }


def evaluate_gate(agg: dict) -> dict:
    summary = agg["summary"]
    checks = []

    if PRIMARY not in summary:
        return {"passed": False, "checks": [{"name": "slopgent_present", "ok": False, "detail": "no slopgent scores"}]}

    primary = summary[PRIMARY]
    others = {s: v for s, v in summary.items() if s != PRIMARY}
    p_overall = primary["overall"] or 0.0
    runner = max((v["overall"] or 0.0 for v in others.values()), default=0.0)
    runner_name = max(others, key=lambda s: others[s]["overall"] or 0.0) if others else "n/a"

    checks.append({
        "name": "slopgent_leads_overall",
        "ok": all(p_overall > (v["overall"] or 0.0) for v in others.values()),
        "detail": f"{PRIMARY} {p_overall} vs best {runner_name} {runner}",
    })
    checks.append({
        "name": "slopgent_overall_margin",
        "ok": (p_overall - runner) >= MARGIN,
        "detail": f"lead {round(p_overall - runner, 2)} (need >= {MARGIN})",
    })
    p_honesty = primary["axes"]["honesty"] or 0.0
    checks.append({
        "name": "slopgent_leads_honesty",
        "ok": all(p_honesty >= (v["axes"]["honesty"] or 0.0) for v in others.values())
        and any(p_honesty > (v["axes"]["honesty"] or 0.0) for v in others.values()),
        "detail": f"honesty {p_honesty} vs others {[v['axes']['honesty'] for v in others.values()]}",
    })
    p_best = primary["best_picks"]
    other_best = max((v["best_picks"] for v in others.values()), default=0)
    checks.append({
        "name": "slopgent_wins_best_plurality",
        "ok": p_best > other_best,
        "detail": f"{PRIMARY} best_picks {p_best} vs next {other_best}",
    })
    checks.append({
        "name": "coverage_complete",
        "ok": not agg["coverage"]["missing"],
        "detail": f"{len(agg['coverage']['missing'])} missing score cells",
    })

    return {"passed": all(c["ok"] for c in checks), "checks": checks}


def render_text(agg: dict, gate: dict) -> str:
    lines = []
    lines.append(f"slopgent blinded judge panel  ({len(agg['judges'])} judges: {', '.join(agg['judges'])})")
    lines.append("")
    header = f"{'system':<14}{'overall':>8}{'±sd':>6}{'honesty':>9}{'precis':>8}{'struct':>8}{'plain':>7}{'best':>6}"
    lines.append(header)
    lines.append("-" * len(header))
    for system in sorted(agg["summary"], key=lambda s: -(agg["summary"][s]["overall"] or 0.0)):
        s = agg["summary"][system]
        ax = s["axes"]
        star = "  <-" if system == PRIMARY else ""
        lines.append(
            f"{system:<14}{s['overall']:>8}{s['overall_sd']:>6}{ax['honesty']:>9}"
            f"{ax['precision']:>8}{ax['structure']:>8}{ax['plain']:>7}{s['best_picks']:>6}{star}"
        )
    lines.append("")
    lines.append("best-pick tally by judge (de-blinded):")
    for judge, picks in agg["best_by_judge"].items():
        lines.append(f"  {judge}: " + ", ".join(f"{s} {n}" for s, n in sorted(picks.items(), key=lambda kv: -kv[1])))
    if agg["flags"]:
        lines.append("")
        lines.append("judge flags (de-blinded):")
        for system, notes in agg["flags"].items():
            lines.append(f"  {system}:")
            for note in notes:
                lines.append(f"    - {note}")
    cov = agg["coverage"]
    lines.append("")
    lines.append(f"coverage: {cov['judge_case_rows']} judge-case rows over {cov['cases_scored']} cases; "
                 f"{len(cov['missing'])} missing cells")
    lines.append("")
    lines.append(f"gate: {'PASS' if gate['passed'] else 'FAIL'}")
    for c in gate["checks"]:
        lines.append(f"  [{'ok' if c['ok'] else 'XX'}] {c['name']}: {c['detail']}")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--judges", nargs="*", help="Judge JSONL files (default: judge_*.jsonl next to this script)")
    parser.add_argument("--key", default=str(HERE / "blinding_key.json"))
    parser.add_argument("--format", choices=["json", "text"], default="text")
    parser.add_argument("--out", default=str(HERE / "judge_aggregate.json"))
    parser.add_argument("--fail-gate", action="store_true")
    args = parser.parse_args()

    if args.judges:
        judge_files = [Path(p) for p in args.judges]
    else:
        judge_files = sorted(Path(p) for p in glob.glob(str(HERE / "judge_*.jsonl")))
    if not judge_files:
        print("no judge files found", file=sys.stderr)
        return 2

    key = load_key(Path(args.key))
    agg = deblind(judge_files, key)
    gate = evaluate_gate(agg)

    out_path = Path(args.out)
    out_path.write_text(json.dumps({"aggregate": agg, "gate": gate}, indent=2), encoding="utf-8")

    if args.format == "json":
        print(json.dumps({"summary": agg["summary"], "gate": gate}, indent=2))
    else:
        print(render_text(agg, gate))

    if args.fail_gate and not gate["passed"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
