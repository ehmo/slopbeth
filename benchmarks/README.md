# Benchmarks

The benchmark pack tests whether a rewrite keeps meaning while removing slop. It is not an AI-detector contest.

## Files

- `adversarial-pack-v1.jsonl`: 60 cases with gold notes.
- `independent-judge-rows-v1.jsonl`: three judge rows for every case.
- `comparison-v1.md`: rule-coverage comparison against two public baselines.
- `public-detector-panel-v1.md`: detector-panel evidence and limits.

## Categories

- marketing fluff
- fake clarity
- support replies
- technical incident notes
- policy copy
- founder essays

## Pass standard

A strong rewrite:

- preserves source facts and uncertainty
- removes generic uplift and formulaic structure
- refuses unsupported concrete claims
- keeps technical and policy obligations intact
- does not turn voice into clipped consultant prose
- stays dense enough that summary loses real ideas

Detector output can be logged. It cannot overrule these checks.
