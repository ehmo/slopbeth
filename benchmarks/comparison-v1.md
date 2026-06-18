# Comparison benchmark v1

Date: 2026-06-18

This is a rule-coverage benchmark. It compares Slopbeth against two public anti-slop baselines on the 60-case adversarial pack. It does not claim that any model output will always win in open-ended prose.

## Method

Each tool was scored against the same case requirements:

- source-locking
- fact and qualifier preservation
- support-copy promise boundaries
- technical and policy obligation boundaries
- density and summary-loss pressure
- over-editing restraint
- detector-claim hygiene
- benchmark artifacts and judge rows
- installability and versioning

## Scores

| Tool | Score | Result |
| --- | ---: | --- |
| Slopbeth 1.0.0 | 94 / 100 | passes release rule coverage |
| humanizer baseline | 76 / 100 | strong AI-writing pattern list, weaker benchmark and source-lock gates |
| stop-slop baseline | 71 / 100 | strong prose-taste rules, weaker support/policy/technical guardrails |

## Why Slopbeth scores higher

Slopbeth scores higher because it treats anti-slop work as preservation first:

- it blocks unsupported claims
- it keeps uncertainty and obligations visible
- it rejects bland-clean rewrites, not only banned phrases
- it includes detector disagreement and benchmark limits
- it ships cases with judge rows

## Limits

This benchmark measures the skill and its evaluation harness. It cannot prove universal writing quality or detector immunity.
