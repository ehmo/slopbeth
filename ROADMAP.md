# Roadmap

Slopbeth is built around one standard: remove slop without removing meaning.

## done

- Versioned skill package
- GitHub install through `npx github:ehmo/slopbeth install`
- Source-lock rules for unsupported claims
- Voice-preservation rules
- Density and unsummarizability rules
- Public benchmark packs
- Span-level annotations
- False-positive tracker
- Cadence scoring
- Real competitor-agent panel on omarchy
- Ubicloud CI workflow
- PR-visible score snapshot

## release 1.0

The first public release shipped the installable skill and the first benchmark artifacts:

- `SKILL.md`
- installer and package checks
- 60 adversarial prompt cases
- 180 judge rows
- detector evidence policy
- public comparison notes

The goal was simple: make the skill installable and make the evidence inspectable.

## release 1.1

This release moved the benchmark from prompts to output-bearing cases:

- 88 release cases
- 264 judge rows
- semantic-drift checks
- signature checks
- unsummarizability checks
- expanded literature basis

The goal was to test actual rewrites, not just intentions.

## release 1.2

This release added stricter review surfaces:

- exact bad-span and preserved-span annotations
- false-positive restraint rows
- cadence and read-aloud scoring
- shared-case competitor-output panel

The goal was to catch polished but wrong edits.

## release 1.3

This release focuses on public trust and adoption:

- real 25-case competitor-agent panel from omarchy
- 125 competitor outputs across five skills
- score snapshot artifact
- Ubicloud CI
- install smoke coverage
- expanded public README
- pulled-out benchmark documentation
- branch-protection guidance

The goal is to make Slopbeth easy to install and hard to regress.

## next

- Publish to npm so `npx slopbeth install` works without the GitHub prefix.
- Add manual judge rows for the 25-case real competitor-agent panel.
- Expand the real competitor-agent panel to 50 cases once the judge rows are stable.
- Add issue templates for false-positive reports and bad rewrite reports.
- Add a small gallery of before/after examples from public benchmark rows.
- Track benchmark deltas across releases.
- Add optional adapters for common agent skill directories.

## not planned

- Claims of detector immunity
- Detector-specific rewriting tricks
- Multilingual lanes before the English benchmark is stable
- Copying competitor wording or examples
