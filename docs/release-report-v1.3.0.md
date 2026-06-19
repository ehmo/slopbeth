# Slopbeth 1.3.0 release report

Date: 2026-06-19

## scope

Version 1.3.0 expands the release evidence and improves public adoption material. It replaces the 10-case real competitor-agent panel with a 25-case panel, adds Ubicloud CI, adds PR-visible score snapshots, and rewrites the README as a marketing document.

## real-agent panel

The panel contains 25 shared English cases and 125 outputs across five skills:

- `slopbeth`
- `stop-slop`
- `humanizer`
- `skill-deslop`
- `anti-ai-slop-writing`

Result:

- Slopbeth won 23 of 25 cases.
- Slopbeth win rate: 0.92.
- Missing required facts: 0.
- Forbidden-output hits: 0.
- Hard signatures: 0.

The raw panel is `benchmarks/competitor-agent-runs-v1.jsonl`.

## ci

The Ubicloud workflow runs:

- package gate
- pack dry run
- attribution scan
- secret-pattern scan
- score snapshot generation

The score snapshot is written to the pull request summary and uploaded as an artifact.

## limits

This release still does not claim detector immunity. The real-agent panel is stronger than the previous 10-case panel, but it remains a release regression artifact, not a universal proof of writing quality.
