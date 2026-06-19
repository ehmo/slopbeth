# Competitor matrix v2

Date: 2026-06-19

This matrix compares public anti-slop writing tools and adjacent anti-slop skill repos. It scores benchmark and rule coverage, not author identity and not detector immunity.

## Method

Each row gets checked for:

- installable package shape
- versioned skill instructions
- source-lock and fact-preservation rules
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
| 1 | Slopbeth 1.3.1 | writing | 99 | 88-case v2 output corpus, 264 judge rows, span annotations, false-positive tracker, cadence gate, competitor-output panel, 25-case real competitor-agent panel, score snapshots, installer verification | English-first; detector panel remains weak evidence |
| 2 | ch040602/anti-ai-slop | multi-artifact review | 91 | broad purpose taxonomy, finding format, authorship-claim caution | no output-bearing prose corpus found |
| 3 | B1lli/remove-ai-flavor-writing-skill | Chinese writing | 90 | before/after fixtures, runnable audit, rhythm reports | language-specific; not an English benchmark |
| 4 | blader/humanizer | writing | 84 | broad pattern catalog and false-positive guidance | limited public benchmark evidence |
| 5 | Laith0003/ux-skill | UI/design | 82 | deterministic checks and rule corpus | not a prose-writing benchmark |
| 6 | d-wwei/great-writer | writing modes | 78 | mode-specific writing lanes | limited fixture evidence |
| 7 | willmather95/human-copy | writing | 74 | explicit eval checklist | checklist-only; no full release corpus found |
| 8 | stephenturner/skill-deslop | scientific prose | 72 | compact scientific-writing focus and references | no runnable benchmark found |
| 9 | sirambrosio/humanink | writing | 70 | issue-backed false-positive tracker and modal-stacking pattern | pattern scoring can overflag human text |
| 10 | hardikpandya/stop-slop | writing | 68 | compact phrase and structure catalogs, active issue/PR stream | weaker benchmark and source-lock evidence |
| 11 | jalaalrd/anti-ai-slop-writing | writing | 65 | compact cross-agent skill and banned-word list | detector claims need stronger caveats |
| 12 | sermuns/is-it-slop | detector CLI | 58 | runnable CLI, CI, issue/PR improvement trail | repo-metadata detector, not writing-quality eval |
| 13 | Chinese/Czech anti-slop variants | multilingual writing | 55 | language-specific punctuation and rhythm rules | separate language benchmarks needed |
| 14 | anti-slop UI/design repos | UI/design | 45 | deterministic checks and design anti-slop rules | adjacent domain, not prose eval |

## Adopted into v2 and 1.3.0

- Fixture-pair discipline: v2 uses output-bearing rows with candidate rewrites.
- False-positive pressure: human-control rows require restraint.
- Rhythm and shape checks: signature scoring catches repeated starts, bland-clean sentences, and formula residue.
- Purpose-first scoring: categories change the expected edit depth and risk.
- Detector hygiene: detector-bait rows test whether the system rejects edits that would improve detector optics while harming truth.
- Issue/PR ideas: false-positive tracking, modal stacking, over-even rhythm, interactive marking, and plugin packaging became benchmark dimensions.
- Span review: exact bad-span and preserved-span rows now cover long and risky English samples.
- Cadence scoring: the release gate now checks monotony, repeated starts, and over-polished transitions.
- Competitor outputs: the panel scores shared-case outputs, not only repo packaging.
- Competitor-agent outputs: 1.3.0 expands real shared-case runs from omarchy to 25 cases and gates Slopbeth at 23 of 25 case wins.
- Score snapshots: 1.3.0 writes a compact benchmark summary for release notes and pull requests.
- Installer verification: 1.3.0 verifies the package installer copies the files needed for use and benchmark maintenance.
- Multilingual lanes are deferred; the current release is English-only.

## Not adopted

- Claims of guaranteed human authorship.
- Optimizing text to satisfy a public detector.
- Copying competitor wording or examples.
- One rigid pass sequence for every genre.
