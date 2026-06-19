# Changelog

## 1.2.1 - 2026-06-19

- Added real shared-case competitor-agent outputs from omarchy.
- Added a case-win competitor-agent release gate.
- Added install smoke testing and wired it into `npm test`.
- Tightened the support-promise forbidden-output checks.
- Added a 1.2.1 release report with environment, gates, results, and limits.

## 1.2.0 - 2026-06-19

- Added span-level annotation checks for long and risky English benchmark rows.
- Added a false-positive tracker for text that should be left alone or edited lightly.
- Added cadence/read-aloud scoring for monotony, over-polished transitions, and repeated starts.
- Added a shared-case competitor-output panel and score gate.

## 1.1.0 - 2026-06-18

- Added the v2 output-bearing benchmark corpus with 88 cases and 264 judge rows.
- Wired `slopbeth benchmark` to schema, preservation, semantic-drift, signature, and unsummarizability gates.
- Added the v2 competitor matrix across public anti-slop repos and adjacent tools.
- Added the literature basis for slop measurement, detector limits, voice preservation, and writing-craft gates.
- Cleaned package metadata and excluded Python bytecode from packaged files.

## 1.0.0 - 2026-06-18

- First public Slopbeth package.
- Added versioned `SKILL.md`.
- Added `npx slopbeth install`, `doctor`, and `benchmark` commands.
- Added a 60-case adversarial benchmark pack with independent judge rows.
- Added detector-panel documentation that treats public detector output as weak, dated evidence.
- Added a comparison benchmark against two public anti-slop baselines.
