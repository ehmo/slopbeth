# Evaluation

Evaluate writing quality first. Treat detector output as weak dated evidence.

## Authority stack

No public benchmark fully measures "AI slop" as a writing defect. Use layered evidence:

- detector credibility: RAID plus SemEval-2024 Task 8 and M4GT-Bench
- writing quality: WritingBench plus revision corpora such as CoEdIT and IteraTeR
- slop signs: public field guides for AI-writing tells
- release evidence: local adversarial cases with gold notes and independent judges
- literature basis: `docs/literature-basis.md`

The target is not "classified as human." The target is source-locked, dense, non-generic prose with preserved facts.

## Public pack

This package ships:

- `benchmarks/adversarial-pack-v1.jsonl`
- `benchmarks/independent-judge-rows-v1.jsonl`
- `benchmarks/benchmark-v2.jsonl`
- `benchmarks/independent-judge-rows-v2.jsonl`
- `benchmarks/span-annotations-v1.jsonl`
- `benchmarks/false-positive-tracker-v1.jsonl`
- `benchmarks/competitor-output-runs-v1.jsonl`
- `benchmarks/competitor-agent-runs-v1.jsonl`
- `benchmarks/competitor-matrix-v2.md`
- `benchmarks/public-detector-panel-v1.md`
- `docs/release-report-v1.2.1.md`

The v1 adversarial pack has 60 prompt-only cases across:

- marketing fluff
- fake clarity
- support replies
- technical incident notes
- policy copy
- founder essays

The v2 release corpus has 88 output-bearing cases across those lanes plus human controls, paired voice, dense risky prose, and detector-bait edits. The 1.2 gates add exact span annotations, false-positive restraint rows, cadence scoring, and a shared-case competitor-output panel. The 1.2.1 gate adds real competitor-agent outputs and install-smoke coverage.

## Score model

Use 100 points:

- 25 slop removal
- 25 meaning preservation
- 15 voice preservation or appropriate neutrality
- 20 density and summary-loss pressure
- 10 restraint on control or already-good text
- 5 detector-evidence hygiene

Block release when a rewrite:

- adds unsupported facts
- changes obligations in technical, policy, support, or incident copy
- weakens uncertainty or timing
- turns a human voice into a tidy house style
- claims detector safety

## Scripts

Run from the installed Slopbeth directory:

```bash
node bin/slopbeth.js benchmark
python3 scripts/deslop_lint.py README.md --format json
python3 scripts/preservation_check.py original.txt rewrite.txt --format json
python3 scripts/density_report.py original.txt rewrite.txt --format json
```

Use semantic, signature, cadence, unsummarizability, and full benchmark scripts on corpora that include candidate outputs. Use span, false-positive, competitor-output, and install-smoke scripts when maintaining bundled benchmark artifacts. The v1 pack contains prompts and gold notes; the v2 pack contains candidate outputs and is the public release gate.

Scripts report signals. They do not decide whether prose is good enough.

## Detector evidence

For detector-facing notes, record:

- tool name and URL
- date and timezone
- input text hash
- output or screenshot hash when available
- result class
- tool warning or access limit

Allowed wording: "Tool X returned Y on this text at this date."

Forbidden wording: "This proves the text is human" or "this cannot be detected."

Conflicting detector results are expected. Record disagreement instead of averaging it away.
