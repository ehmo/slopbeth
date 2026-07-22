# Competitor matrix v2

Date: 2026-06-19

This matrix compares public English anti-slop writing tools and writing skill repos. It excludes UI/design tools, repo-detector tools, general review tools, and non-English rows. It scores benchmark and rule coverage, not author identity and not detector immunity.

## Method

Each row gets checked for:

- installable package shape
- versioned skill instructions
- evidence-bound and fact-preservation rules
- voice and false-positive controls
- domain guardrails for support, policy, incidents, essays, and marketing
- public benchmark artifacts
- runnable checks or fixtures
- detector hygiene
- issue and pull request signals

Scores are 100-point coverage scores. A higher score means the repo exposes stronger rules and evidence. It does not prove that every generated rewrite will win. The output panel uses shared English cases and public-rule baselines because the compared repos do not all provide stable command-line generators.

## Ranked matrix

| Rank | Repo | Domain | Score | Strongest evidence | Limit |
| ---: | --- | --- | ---: | --- | --- |
| 1 | Slopbeth 1.4.0 | writing | 99 | 88-case v2 output corpus, 264 judge rows, span annotations, false-positive tracker, cadence gate, competitor-output panel, 25-case real competitor-agent panel, score snapshots, installer verification | English-first; detector panel remains weak evidence |
| 2 | blader/humanizer | writing | 84 | broad pattern catalog and false-positive guidance | limited public benchmark evidence |
| 3 | d-wwei/great-writer | writing modes | 78 | mode-specific writing lanes | limited fixture evidence |
| 4 | willmather95/human-copy | writing | 74 | explicit eval checklist | checklist-only; no full release corpus found |
| 5 | stephenturner/skill-deslop | scientific prose | 72 | compact scientific-writing focus and references | no runnable benchmark found |
| 6 | sirambrosio/humanink | writing | 70 | issue-backed false-positive tracker and modal-stacking pattern | pattern scoring can overflag human text |
| 7 | hardikpandya/stop-slop | writing | 68 | compact phrase and structure catalogs, active issue/PR stream | weaker benchmark and fact-preservation evidence |
| 8 | jalaalrd/anti-ai-slop-writing | writing | 65 | compact cross-agent skill and banned-word list | detector claims need stronger caveats |

## What Slopbeth includes now

- Fixture-pair discipline: v2 uses output-bearing rows with candidate rewrites.
- False-positive pressure: human-control rows require restraint.
- Rhythm and shape checks: signature scoring catches repeated starts, bland-clean sentences, and formula residue.
- Purpose-first scoring: categories change the expected edit depth and risk.
- Detector hygiene: detector-bait rows test whether the system rejects edits that would improve detector optics while harming truth.
- Issue/PR ideas: false-positive tracking, modal stacking, over-even rhythm, interactive marking, and plugin packaging became benchmark dimensions.
- Span review: exact bad-span and preserved-span rows now cover long and risky English samples.
- Cadence scoring: the release gate now checks monotony, repeated starts, and over-polished transitions.
- Competitor outputs: the panel scores shared-case outputs, not only repo packaging.
- Competitor-agent outputs: the real shared-case panel from a remote test host covers 25 cases and gates Slopbeth at 23 of 25 case wins.
- Score snapshots: CI writes a compact benchmark summary for pull requests.
- Installer verification: the package installer must copy the files needed for use and benchmark maintenance.
- Multilingual lanes are deferred; the current release is English-only.

## Not adopted

- Claims of guaranteed human authorship.
- Optimizing text to satisfy a public detector.
- Copying competitor wording or examples.
- One rigid pass sequence for every genre.
