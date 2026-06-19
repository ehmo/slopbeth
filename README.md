# Slopbeth

Slopbeth is a writing skill for removing AI slop without flattening the writer.

The name is a play on Macbeth. Shakespeare's best lines carry pressure and consequence. Slopbeth applies that standard in a narrow way: every sentence should earn its place. If a summary can delete half the words without losing much, the draft is still padded.

## Install

Run from GitHub:

```bash
npx github:ehmo/slopbeth install
```

The installer copies the skill into `~/.codex/skills/slopbeth` by default. To install somewhere else:

```bash
npx github:ehmo/slopbeth install /path/to/skills/slopbeth
```

If the package is later published to npm, `npx slopbeth install` will work too.

Direct install:

```bash
git clone git@github.com:ehmo/slopbeth.git
cd slopbeth
node bin/slopbeth.js install
```

## Use

Ask your agent:

```text
Use $slopbeth to revise this draft while preserving my meaning and voice.
```

For a stricter review:

```text
Use $slopbeth to mark every unsupported claim, bland-clean sentence, and detector-chasing edit.
```

## What it does

Slopbeth aims for:

- source-locked rewrites
- preserved facts and uncertainty
- fewer generic claims and filler transitions
- prose that loses real ideas when compressed
- restraint on already-good human text
- detector evidence treated as weak dated evidence

It does not promise detector immunity. That is the wrong target. Public detectors disagree with each other and can flag human control samples. Detector output is a regression signal, not truth.

## Benchmarks

This package includes:

- `benchmarks/adversarial-pack-v1.jsonl`: 60 adversarial cases across six business-writing genres.
- `benchmarks/independent-judge-rows-v1.jsonl`: 180 judge rows, three per case.
- `benchmarks/benchmark-v2.jsonl`: 88 output-bearing cases across eight risk categories.
- `benchmarks/independent-judge-rows-v2.jsonl`: 264 judge rows, three per v2 case.
- `benchmarks/span-annotations-v1.jsonl`: exact bad-span and preserved-span annotations for long and risky rows.
- `benchmarks/false-positive-tracker-v1.jsonl`: examples Slopbeth should leave alone or edit only lightly.
- `benchmarks/competitor-output-runs-v1.jsonl`: shared-case output panel against public-rule baselines.
- `benchmarks/competitor-matrix-v2.md`: a rule, evidence, and package matrix against public anti-slop baselines.
- `benchmarks/public-detector-panel-v1.md`: public detector evidence, framed as weak evidence.
- `docs/literature-basis.md`: research and writing-craft basis for the benchmark gates.

Run:

```bash
npm test
```

or:

```bash
node bin/slopbeth.js benchmark
```

Slopbeth was built by benchmark-driven iteration, not by model training. The shipped package test runs the v2 corpus through schema, preservation, semantic-drift, signature, cadence, unsummarizability, span-annotation, false-positive, and competitor-output gates. Detector immunity is not claimed.

## Package shape

- `SKILL.md`: versioned skill instructions
- `references/`: deeper rules for taxonomy, voice, density, and evaluation
- `scripts/`: repeatable checks used by the benchmark workflow
- `benchmarks/`: public eval packs and comparison notes
- `bin/slopbeth.js`: installer and package checks

## License

MIT
