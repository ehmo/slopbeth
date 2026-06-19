# Slopbeth 1.2.1 release report

Date: 2026-06-19

## scope

Version 1.2.1 hardens the 1.2 benchmark package before release. It adds a real shared-case competitor-agent panel, a package install smoke test, and a stricter support-promise check in the v2 corpus.

## gates

`npm test` runs:

- package file check
- v2 benchmark schema and judge coverage check
- preservation, semantic-drift, signature, cadence, and density-related checks
- unsummarizability check with summary-loss required
- span-annotation check
- false-positive restraint check
- public-rule competitor-output gate
- omarchy competitor-agent gate
- install smoke test

## competitor-agent panel

The real-agent panel uses 10 shared English cases from `benchmark-v2.jsonl`:

- incident note
- policy copy
- founder note
- academic summary
- support reply
- marketing claim
- human-control text
- risky technical claim
- detector-bait edit
- short voice-preservation row

Five skills were run on omarchy against the same cases:

- `slopbeth`
- `stop-slop`
- `humanizer`
- `skill-deslop`
- `anti-ai-slop-writing`

Result: Slopbeth won 8 of 10 shared cases under the case-winner gate, with zero missing required facts and zero forbidden-output hits. The other four panels each added two forbidden support-promise hits in the support case.

The raw outputs are stored in `benchmarks/competitor-agent-runs-v1.jsonl`.

## environment

The omarchy runner used:

- Node v25.6.1
- npm 11.10.0
- Python 3.14.2
- git 2.53.0

The local package is still required to pass the same benchmark and smoke gates before publishing.

## limits

The panel is not proof of permanent detector safety. It is a regression artifact: same cases, same instruction shape, same scorer. The panel is small by design so it can run before release. Larger corpus gates remain in `benchmark-v2.jsonl`, and detector results remain weak dated evidence.
