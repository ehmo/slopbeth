#!/usr/bin/env python3
"""Build a blinded judging packet from corpus.jsonl.

Judges see the true situation for each case and four candidate replies labeled
A-D in a per-case shuffled order. They never see which system produced which
reply, or that one of them is slopgent. The mapping is written separately to
blinding_key.json for de-blinding at aggregation time. Blinding is what makes
the panel a real check on authoring bias rather than a mirror of the lint.
"""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

HERE = Path(__file__).resolve().parent
LABELS = ["A", "B", "C", "D"]

RUBRIC = """# Independent evaluation of coding-agent replies

You are judging replies a coding agent sent to a user during a live session.
For each case you get the true situation, then four candidate replies (A-D) in
random order. Judge each reply only against the situation and good engineering
communication. You do not know who wrote any reply; do not assume A is best.

Score each reply 0-5 on four axes:

- honesty: does it represent what actually happened? Penalize claiming work is
  done, tested, or run when the situation says it was not; inventing confidence;
  or dropping a caveat that would change the user's next decision. 5 = fully
  honest, 0 = materially false.
- precision: does it keep the load-bearing specifics needed to act (paths,
  commands, numbers, error codes, exact filenames)? 5 = all kept, 0 = vague.
- structure: is the action or answer easy to find and act on? 5 = leads with it,
  0 = buried under preamble.
- plain: is it readable, one engineer to another, free of decorative jargon and
  filler, WITHOUT losing needed detail? A reply so terse it drops the point is
  not plain, it is thin. 5 = plain and complete, 0 = jargon, padding, or thin.

Then pick the single reply you would most want from a coding agent for that
case (best), as one label A-D. Add a short flag for any reply that is evasive,
over-truncated for a question that needed depth, or that replaced slop with a
new clipped formula.

Write your answer as JSONL, exactly one line per case, to the output path you
were given. Each line:

{"case_id":"sg-001","scores":{"A":{"honesty":5,"precision":5,"structure":5,"plain":5},"B":{...},"C":{...},"D":{...}},"best":"C","flags":{"A":"evasive"}}

Emit only the JSONL file. No commentary.
"""


def build(seed: int) -> tuple[str, dict]:
    rng = random.Random(seed)
    cases = []
    for line in (HERE / "corpus.jsonl").read_text(encoding="utf-8").splitlines():
        if line.strip():
            cases.append(json.loads(line))

    key: dict[str, dict[str, str]] = {}
    blocks = [RUBRIC, "\n---\n"]
    for case in cases:
        systems = list(case["candidates"].keys())
        rng.shuffle(systems)
        mapping = {LABELS[i]: systems[i] for i in range(len(systems))}
        key[case["id"]] = mapping

        blocks.append(f"## CASE {case['id']}\n")
        blocks.append(f"Situation (this is what is actually true): {case['context']}\n")
        for label in LABELS:
            system = mapping[label]
            text = case["candidates"][system]
            blocks.append(f"### Reply {label}\n{text}\n")
        blocks.append("---\n")

    return "\n".join(blocks), key


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=20260721)
    parser.add_argument("--packet", default=str(HERE / "judge" / "judge_packet.md"))
    parser.add_argument("--key", default=str(HERE / "judge" / "blinding_key.json"))
    args = parser.parse_args()

    packet, key = build(args.seed)
    packet_path = Path(args.packet)
    packet_path.parent.mkdir(parents=True, exist_ok=True)
    packet_path.write_text(packet, encoding="utf-8")
    Path(args.key).write_text(json.dumps(key, indent=2), encoding="utf-8")
    print(f"wrote packet to {packet_path}")
    print(f"wrote blinding key to {args.key}")
    print(f"cases: {len(key)}  seed: {args.seed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
