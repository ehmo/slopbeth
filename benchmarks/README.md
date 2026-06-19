# Benchmarks

The benchmark pack tests whether a rewrite keeps meaning while removing slop. It is not an AI-detector contest.

## Files

- `adversarial-pack-v1.jsonl`: 60 cases with gold notes.
- `independent-judge-rows-v1.jsonl`: three judge rows for every case.
- `benchmark-v2.jsonl`: 88 output-bearing cases with required facts and expected edit depth.
- `independent-judge-rows-v2.jsonl`: three judge rows for every v2 case.
- `span-annotations-v1.jsonl`: exact bad spans in inputs and preserved spans in outputs.
- `false-positive-tracker-v1.jsonl`: plain English examples that should not be inflated.
- `competitor-output-runs-v1.jsonl`: scored shared-case outputs for Slopbeth and public-rule baselines.
- `competitor-matrix-v2.md`: rule, packaging, and evidence matrix against public baselines.
- `public-detector-panel-v1.md`: detector-panel evidence and limits.

## Categories

- marketing fluff
- fake clarity
- support replies
- technical incident notes
- policy copy
- founder essays
- human-control text
- paired-voice and mixed-language text
- detector-bait text

## Pass standard

A strong rewrite:

- preserves source facts and uncertainty
- removes generic uplift and formulaic structure
- refuses unsupported concrete claims
- keeps technical and policy obligations intact
- does not turn voice into clipped consultant prose
- stays dense enough that summary loses real ideas

Detector output can be logged. It cannot overrule these checks.

`node bin/slopbeth.js benchmark` runs the v2 corpus through schema, preservation, semantic-drift, signature, cadence, unsummarizability, span-annotation, false-positive, and competitor-output gates.
