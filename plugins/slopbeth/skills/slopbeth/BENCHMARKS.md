# v2 benchmark evidence

Slopbeth uses one public release benchmark: the v2 output corpus.

The question is simple: did the rewrite become more specific, more truthful, and less generic without losing the writer's meaning?

## current corpus

- 88 output-bearing English cases
- 264 independent judge rows
- 8 span-annotation rows for long and risky samples
- 12 false-positive rows for text that should be left alone or edited lightly
- 25 real competitor-agent cases from a remote test host
- 125 real competitor-agent outputs across five skills
- 12 Orwell before/after rows for the six-rule writing system (see below)

## current result

Read this as a parity check, not a ranking. The composite score is computed with Slopbeth's own lint instruments, so scoring rival tools with it is circular: it measures how closely their output matches rules Slopbeth wrote. The gate asks whether Slopbeth stays within 2.0 points of the best peer.

| Panel | Cases | Competitors | Gate | Slopbeth avg | Best peer avg | Deficit | Outright wins | Tied at top |
| --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| public-rule proxy | 5 | 5 | pass | 112.30 | 112.30 | 0.00 | 4 | 0 |
| real agent outputs | 25 | 5 | pass | 112.10 | 112.55 | 0.45 | 0 | 23 |

On the real-agent panel the five tools land inside 0.45 points of each other and 23 of 25 cases are exact five-way ties. Slopbeth wins no case outright and sits last on the mean by 0.45. Good deslop output converges; that convergence, not a ranking, is the finding.

Slopbeth's contribution on that panel is a clean floor rather than a lead: 0 missing required facts, 0 forbidden-output hits, 0 hard signatures.

The public-rule panel is 20 in-house rows written to other projects' published rules, plus 5 shipped Slopbeth outputs. It illustrates what those rulesets ask for. It is not those tools' own output and its 40-70 point spread is not a competitor result.

Earlier releases of this file reported a 0.92 win rate on the real-agent panel. That number counted ties as wins because the scorer awarded each tie to the first-listed tool, and Slopbeth was listed first in every case. It has been withdrawn.

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

## Orwell writing-system suite

A second, smaller before/after corpus checks generation quality against Orwell's six rules from "Politics and the English Language" (1946). It is a supplement to the v2 release corpus, not a replacement.

- `benchmarks/orwell-writing-system-v1.jsonl`: 12 before/after rows across marketing, essay, technical, policy, support, memo, and adversarial copy
- `scripts/orwell_lint.py` scores the five mechanical rules: dead metaphor, long word, deletable words, passive voice, jargon/foreign
- `scripts/orwell_benchmark.py` requires targeted rows to cut total violations without dropping declared facts, and requires control rows to stay near-unedited

Rule six ("break any of these rules sooner than say anything outright barbarous") is deliberately not scored. A licensed passive in policy or incident register, a precise long word, and a live metaphor are all correct, so per-rule counts are review signals, not a defect ledger. The corpus encodes this with control rows that must survive with near-zero edits.

The measurable finding: existing deslop rewrites already drive long words, deletable phrases, and jargon toward zero but barely reduce passive voice, so rule four (active over passive) is the gap that belongs at generation time. `orwell_lint.py` exposes `passive_ratio` as a first-class metric for that reason.

Run the Orwell gate on its own:

```bash
python3 scripts/orwell_benchmark.py \
  --corpus benchmarks/orwell-writing-system-v1.jsonl \
  --fail-gate \
  --format json
```

It also runs as part of `node bin/slopbeth.js benchmark`.

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
  --max-average-deficit 2.0 \
  --fail-gate \
  --format json
```

## release rule

A release should not pass by sounding nice. It must preserve facts, avoid unsupported claims, retain voice, keep already-good text intact, and show v2 evidence.
