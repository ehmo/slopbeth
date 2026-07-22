---
name: slopbeth
version: 1.4.1
description: Use when drafting, editing, reviewing, or benchmarking prose to remove AI-writing tells while preserving meaning, voice, and density. Trigger this skill for requests about AI slop, humanizing AI-assisted writing, detector-facing validation, unsummarizable prose, voice preservation, or writing that should not sound generic.
---

# Slopbeth

Remove machine-writing tells without sanding away the author's meaning or voice. The target is not "detector-proof" prose; it is dense, specific writing where every sentence carries load and detector results stay dated and tool-specific.

## Workflow

1. Classify the task: rewrite; critique; benchmark; detector-facing validation; or skill maintenance.
2. Separate the brief from the artifact. Long inputs often mix the material with instructions about it: "the note should keep that texture"; "do not turn this into a lesson"; "the rewrite must not promise that the problem cannot recur". Those sentences address you, not the reader. Do what they ask and leave them out of the output. Reprinting them is the same class of error as inventing content, and preservation and density checks will not catch it, because instruction text is specific, sourced, and dense.
3. Preserve facts first. Lock named entities; numbers; dates; URLs; citations; quotations; technical claims; explicit uncertainty; and the user's requested stance.
4. Set the evidence boundary. When the user supplies only vague copy, switch to evidence-bound mode: do not invent or assert product features; dates; people; metrics; workflows; examples; customer facts; or outcome claims. Unsupported claims such as "faster decisions," "better alignment," "reduced friction," "confidence," or "momentum" must become proof gaps, questions, or explicitly attributed claims.
5. Diagnose clusters, not isolated words. Look for filler; vague significance language; formulaic contrast; promotional inflation; padded lists; generic uplift; actorless claims; summary endings; and ornamental formatting.
6. Rewrite in this order: preserve claims and constraints; cut scaffolding and inflated abstract nouns; apply Orwell's six rules as generation defaults (short word over long, cut deletable words, active over passive, no printed-cliche metaphor or jargon, but break any rule sooner than write something unclear or graceless); make each sentence carry a claim, example, constraint, image, number, consequence, or argumentative move; match the user's register; remove concrete details that are not sourced or clearly labeled; check for meaning loss, bland-clean prose, formula replacement, and over-editing.
7. Validate when files or before/after text are available. Use the scripts in `scripts/` for repeatable checks, then apply judgment for meaning, voice, and sentence-load failures.
8. Output the revised text first for normal rewrite requests. Add a compact note only when it helps explain material changes, preservation risks, or remaining issues.

## Reference routing

Load only the references needed for the task:

- `references/slop-taxonomy.md`: thorough diagnosis; red-team review; marker inventory.
- `references/voice-and-preservation.md`: author samples; technical prose; legal, medical, or financial claims; tone preservation.
- `references/density-and-unsummarizability.md`: dense prose; stronger argumentation; the user's "unsummarizable" standard.
- `references/writing-system.md`: generating prose from a positive system; Orwell's six rules; passive-voice reduction; a portable CLAUDE.md/AGENTS.md writing block.
- `references/evaluation.md`: benchmarks; detector logs; release gates; skill-maintenance work.

## Script routing

Use scripts when the user asks for testing, when local files are available, or when validating a skill change:

```bash
node bin/slopbeth.js benchmark
python3 scripts/deslop_lint.py path/to/text.txt --format json
python3 scripts/orwell_lint.py path/to/text.txt --format json
python3 scripts/preservation_check.py original.txt rewrite.txt --format json
python3 scripts/density_report.py original.txt rewrite.txt --format json
```

Use `orwell_lint.py` on a single draft to see passive voice, long words, deletable phrases, and jargon; treat per-rule counts as review signals, not a defect ledger. Use `signature_score.py`, `cadence_score.py`, `semantic_drift.py`, `unsummarizability_check.py`, `run_benchmark.py`, and `orwell_benchmark.py` only on before/after corpora that include candidate outputs. Use `span_annotation_check.py`, `false_positive_check.py`, and `competitor_output_score.py` when maintaining the bundled benchmarks.

Load `references/evaluation.md` for the full benchmark and detector-evidence rules. In this package, use `scripts/` relative to the installed Slopbeth skill directory.

The scripts report signals. They do not decide whether prose is good enough.

## Hard rules

- Never claim text is permanently undetectable, guaranteed human, or safe against all AI detectors.
- Reject detector tricks that make the writing less true, less specific, or less like the author.
- Keep vague copy evidence-bound. If concreteness requires missing source material, ask for it or label the example as a placeholder.
- Do not launder vague outcomes into polished claims. If the source gives only abstract benefits, name the missing mechanism, owner, metric, changed step, or evidence instead of restating the benefit as true.
- Leave support, recruiting, incident, product, strategy, and education copy without invented owners; dates; failure modes; workflow steps; product surfaces; company names; metrics; or obligations.
- In support copy, do not add process promises such as "we will review," "we will follow up," or "we will resolve" unless the source says that team action is available. Ask for the required next input and preserve promise boundaries.
- In policy and incident copy, do not add quality labels such as "auditable," "secure," "resilient," or "controlled" unless the source states that property directly. Keep the rule or incident boundary concrete.
- Preserve qualifiers that carry scope; uncertainty; causality; risk; or legal/technical meaning.
- Avoid replacing AI slop with a new formula: clipped aphorisms; tidy triads; forced contrast; dramatic fragments; or generic consultant voice.
- Over-editing already strong human text is a failure. A light edit or "leave this alone" can be the correct output.
- Instructions about the writing are not the writing. If the source says what the piece should or should not do, do it; do not print it. "Leave this alone" never means "hand the brief back".
- Mark exact spans when reviewing long or risky text: bad span; label; reason; preserved span; reason. If the exact span cannot be pointed to, treat the critique as too vague.
- Check cadence before finalizing medium or long rewrites. Repeated sentence lengths, polished transition stacks, and repeated openers can be slop even when the words are not banned.
- Avoid em dashes, emojis, title-case hype headings, and decorative bold unless the user's sample clearly uses them and the medium calls for them.
- Keep the skill's internal checklist shape out of final prose. User-facing rewrites should not default to title-case sections; labeled vertical lists; exhaustive caveat blocks; or polished three-part scaffolds.
- For detector-facing work, record structured rows with tool name; URL; date; text hash; raw result or screenshot path; result class; and limitation.
