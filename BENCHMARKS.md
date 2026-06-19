# v2 benchmark evidence

Slopbeth uses one public release benchmark: the v2 output corpus.

The question is simple: did the rewrite become more specific, more truthful, and less generic without losing the writer's meaning?

## current corpus

- 88 output-bearing English cases
- 264 independent judge rows
- 8 span-annotation rows for long and risky samples
- 12 false-positive rows for text that should be left alone or edited lightly
- 25 real competitor-agent cases from omarchy
- 125 real competitor-agent outputs across five skills

## current result

| Panel | Cases | Competitors | Slopbeth wins | Win rate |
| --- | ---: | ---: | ---: | ---: |
| public-rule outputs | 5 | 5 | 4 | 0.80 |
| real agent outputs | 25 | 5 | 23 | 0.92 |

In the real-agent panel, Slopbeth has:

- 0 missing required facts
- 0 forbidden-output hits
- 0 hard signatures

The current generated snapshot is `benchmarks/score-snapshot.md`.

## what v2 measures

V2 checks the failure modes that make anti-slop rewrites dangerous:

- unsupported facts added during cleanup
- changed support, policy, incident, or technical obligations
- vague claims kept under cleaner wording
- voice flattened into house style
- already-good human text over-edited
- detector-facing tricks that damage truth or meaning
- over-polished cadence and repeated sentence starts
- summary-loss pressure: a shorter version should lose real ideas

## real competitor-agent panel

The real panel runs the same 25 English cases through five public writing skills:

- Slopbeth
- stop-slop
- humanizer
- skill-deslop
- anti-ai-slop-writing

The panel covers incident notes, policy copy, founder notes, academic summaries, support replies, marketing proof gaps, fake clarity, human-control rows, voice preservation, detector bait, and risky technical claims.

Raw outputs are stored in `benchmarks/competitor-agent-runs-v1.jsonl`.

## commands

Run the full release gate:

```bash
npm test
```

Run only the benchmark gate:

```bash
node bin/slopbeth.js benchmark
```

Generate the score snapshot:

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

A release should not pass by sounding nice. It must preserve facts, avoid unsupported claims, retain voice, keep already-good text intact, and show v2 evidence.
