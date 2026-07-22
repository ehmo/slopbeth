# Slopbeth score snapshot

- Generated: 2026-07-22T05:37:17.495177+00:00
- Version: `1.4.1`
- v2 output-bearing cases: `88`
- v2 judge rows: `264`
- span annotation rows: `8`
- false-positive rows: `12`

## competitor gates

Diagnostic parity gates, not a quality ranking. The composite score is built from
Slopbeth's own instruments, so scoring other tools with it is circular. The gate asks
whether Slopbeth stays within 2.0 points of the best peer, not whether it wins.
Ties are reported as ties: on the real-agent panel almost every case is a five-way tie,
so outright wins is the honest count and a per-case win rate carries no signal.

| Panel | Cases | Competitors | Gate | Slopbeth avg | Best peer avg | Deficit | Outright wins | Tied at top |
| --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| public-rule proxy | 5 | 5 | pass | 112.3 | 112.3 | 0.00 | 4 | 0 |
| real agent outputs | 25 | 5 | pass | 112.1 | 112.55 | 0.45 | 0 | 23 |

The public-rule panel is 20 in-house rows written to other
projects' published rules plus 5 shipped Slopbeth outputs. It illustrates
rulesets; it is not a competitor result, and its wide spread is an artifact of that.
Only the real-agent panel contains outputs those tools produced.

## real agent summary

| Competitor | Cases | Average diagnostic score | Missing facts | Forbidden hits | Hard signatures |
| --- | ---: | ---: | ---: | ---: | ---: |
| anti-ai-slop-writing | 25 | 112.34 | 0 | 0 | 0 |
| humanizer | 25 | 112.3 | 0 | 0 | 0 |
| skill-deslop | 25 | 112.12 | 0 | 0 | 0 |
| slopbeth | 25 | 112.1 | 0 | 0 | 0 |
| stop-slop | 25 | 112.55 | 0 | 0 | 0 |

## real agent top scorers

A tie means the tools scored identically on this diagnostic, so the case has no
winner. Near-identical peer output makes ties the norm here, not the exception.

| Case | Top scorer |
| --- | --- |
| v2-long-incident-001 | tie (2-way): anti-ai-slop-writing, stop-slop |
| v2-long-policy-001 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-long-founder-001 | stop-slop |
| v2-medium-academic-001 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-medium-support-001 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-mkt-001 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-control-001 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-risk-001 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-bait-001 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-short-voice-001 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-mkt-002 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-mkt-003 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-clar-001 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-clar-002 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-clar-003 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-pol-001 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-pol-002 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-essay-001 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-essay-002 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-voice-001 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-voice-002 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-ctrl-001 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-ctrl-002 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-risk-002 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
| v2-bait-002 | tie (5-way): anti-ai-slop-writing, humanizer, skill-deslop, slopbeth, stop-slop |
