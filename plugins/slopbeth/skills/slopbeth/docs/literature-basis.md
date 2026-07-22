# Literature basis

Date reviewed: 2026-06-18

Slopbeth treats "AI slop" as a writing-quality problem, not an authorship verdict. The literature supports that choice: detector scores are unstable evidence, while density, relevance, factuality, voice, and template pressure are more useful release targets.

## Research used

- Slop taxonomy: https://arxiv.org/html/2509.19163v2
  - Gives the taxonomy used by the benchmark: density, relevance, factuality, repetition, template residue, excess length, diction, tone, coherence, fluency.
  - Warns that automated metrics and model judges still miss expert slop judgments.

- Detector-quality study: https://arxiv.org/html/2504.07532v1
  - Keeps detector scores in the "weak evidence" lane. The paper finds quality correlation mainly when generated text starts out worse than human text.

- Hardness benchmark: https://arxiv.org/html/2507.15286v1
  - Pushes the benchmark toward harder rows and adversarial cases instead of easy detector wins.

- Span-level detector study: https://arxiv.org/html/2504.11952v3
  - Backs partial-authorship and span-level checks. Binary labels are too crude for edited or mixed text.

- PAN 2026 overview: https://arxiv.org/abs/2602.09147
  - Treats reproducible packaging and mixed or obfuscated authorship as serious evaluation settings.

- Style-homogenization study: https://arxiv.org/html/2409.11360v3
  - Adds voice and culture preservation to the gates. Anti-slop editing should not flatten regional, bilingual, or culturally specific prose.

- Expression-homogenization study: https://arxiv.org/html/2508.01491v2
  - Backs the warning against house-style cleanup. A rewrite can become more polished and less individual at the same time.

- Diversity study: https://arxiv.org/pdf/2509.18880
  - Makes lexical and structural variety a signal, while keeping detector conclusions limited.

- Grammar and rhetoric study: https://arxiv.org/html/2410.16107v1
  - Puts structure on the checklist: nominalization, participial clauses, and register mismatch matter beyond banned-word lists.

- Public reader quiz: https://www.nytimes.com/interactive/2026/03/09/business/ai-writing-quiz.html
  - Serves as a public reader-test example. It is not a release benchmark because the scoring method and corpus are not a harness.

## Writing books used

- Williams and Bizup, style guide.
  - Reader expectations, subjects, verbs, cohesion, and stress positions.

- Zinsser, nonfiction guide.
  - Clutter removal, human scale, and plain commitments.

- Lanham, revision guide.
  - The paramedic method: find the action, remove prepositional padding, and make the actor visible.

- Pinker, style guide.
  - Classic style, concrete subjects, and the curse of knowledge.

- Gopen and Swan, scientific writing.
  - Scientific prose depends on reader expectation, old-to-new flow, and stress position.

- Orwell, "Politics and the English Language" (1946).
  - Stale metaphor, pretentious diction, and evasive abstraction are useful failure labels.
  - Slopbeth uses his six rules as a positive generation system, not a banned-word list: prefer the short word, cut deletable words, choose the active voice, drop printed-cliche metaphor and jargon, and break any rule sooner than write something graceless. `scripts/orwell_lint.py` scores the first five and treats the sixth as a human-review escape hatch, which is why a licensed passive or a precise long word is never a defect.

## Benchmark effects

- Detector results stay weak and dated.
- Good human control text must often be left alone.
- Every rewrite is judged for unsupported additions.
- Dense text is more than shorter text. It must carry facts, conditions, consequences, or voice.
- Cultural, bilingual, and non-native English features are preservation risks, not automatic defects.
- Public claims need public artifacts: corpus rows, judge rows, release gates, and limits.
