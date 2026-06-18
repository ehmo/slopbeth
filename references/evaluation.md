# Evaluation

Evaluate writing quality first. Treat detector output as weak dated evidence.

## Authority stack

No public benchmark fully measures "AI slop" as a writing defect. Use layered evidence:

- detector credibility: RAID plus SemEval-2024 Task 8 and M4GT-Bench
- writing quality: WritingBench plus revision corpora such as CoEdIT and IteraTeR
- slop signs: public field guides for AI-writing tells
- release evidence: local adversarial cases with gold notes and independent judges

The target is not "classified as human." The target is source-locked, dense, non-generic prose with preserved facts.

## Public pack

This package ships:

- `benchmarks/adversarial-pack-v1.jsonl`
- `benchmarks/independent-judge-rows-v1.jsonl`
- `benchmarks/comparison-v1.md`
- `benchmarks/public-detector-panel-v1.md`

The adversarial pack has 60 cases across:

- marketing fluff
- fake clarity
- support replies
- technical incident notes
- policy copy
- founder essays

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

Use semantic, signature, unsummarizability, and full benchmark scripts on corpora that include candidate outputs. The public adversarial pack contains prompts and gold notes; validate it with the package benchmark command.

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
