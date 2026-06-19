# Benchmarks

Slopbeth treats benchmarks as evidence, not decoration.

The benchmark suite asks one question: did the rewrite become more specific, more truthful, and less generic without losing the writer's meaning?

## current snapshot

- 60 prompt-only adversarial cases
- 88 output-bearing release cases
- 264 independent judge rows
- 8 span-annotation rows for long and risky samples
- 12 false-positive rows for text that should be left alone or edited lightly
- 25 real competitor-agent cases from omarchy
- 125 real competitor-agent outputs across five skills

Current real-agent result:

| Panel | Cases | Competitors | Slopbeth wins | Win rate |
| --- | ---: | ---: | ---: | ---: |
| public-rule outputs | 5 | 5 | 4 | 0.80 |
| real agent outputs | 25 | 5 | 23 | 0.92 |

The current score snapshot is in `benchmarks/score-snapshot.md`.

## what gets measured

The suite checks:

- fact preservation
- missing required facts
- forbidden claim residue
- semantic drift
- generic AI-writing signatures
- over-polished cadence
- false-positive restraint
- summary-loss pressure
- exact bad-span and preserved-span annotations
- real competitor outputs on shared cases

## why detectors are not the target

Detector output is weak evidence. It can be logged, but it cannot decide whether prose is good. A detector can punish human control text and reward text that is less true. Slopbeth uses detector-facing rows only to reject detector tricks that harm meaning or voice.

## real competitor-agent panel

The real panel runs the same 25 English cases through five public writing skills:

- Slopbeth
- stop-slop
- humanizer
- skill-deslop
- anti-ai-slop-writing

The panel covers:

- incident notes
- policy copy
- founder notes
- academic summaries
- support replies
- marketing proof gaps
- fake clarity
- short human-control rows
- voice-preservation rows
- detector-bait rows
- risky technical claims

Raw outputs are stored in `benchmarks/competitor-agent-runs-v1.jsonl`.

## commands

Run the full package gate:

```bash
npm test
```

Run only the benchmark gate:

```bash
node bin/slopbeth.js benchmark
```

Generate a score snapshot:

```bash
python3 scripts/score_snapshot.py
```

Score the real competitor-agent panel:

```bash
python3 scripts/competitor_output_score.py \
  --corpus benchmarks/benchmark-v2.jsonl \
  --panel benchmarks/competitor-agent-runs-v1.jsonl \
  --min-competitors 5 \
  --min-cases 25 \
  --min-slopbeth-case-win-rate 0.7 \
  --fail-gate \
  --format json
```

## release rule

A release should not pass by sounding nice. It must preserve facts, avoid unsupported claims, retain voice, keep already-good text intact, and show its benchmark evidence.
