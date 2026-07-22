# slopgent comms benchmark

This measures one thing: when a coding agent reports to a user mid-session, does
slopgent's shaping produce a more honest, more actionable, plainer reply than the
alternatives, without dropping load-bearing precision. It is built the way
slopbeth builds its evidence: authored competitor outputs, a deterministic lint,
expected-fail decoys, and an independent blinded judge panel as the check on
authoring bias.

## What is compared

Four systems, each applied faithfully to the same agent-to-user turn:

- **baseline** is an unshaped agent reply (no comms skill).
- **bro** is Dillon Mulroy's "bro" skill: restate plainly, drop jargon, be concise,
  one human to another. No honesty or precision guard.
- **i_have_adhd** is the ayghri/i-have-adhd output style: action-first, numbered, no
  preamble/closer, restate state, cap lists. Strong structure. No honesty guard.
- **slopgent** is honesty first, then structure, then plain language, with a hard
  guard on load-bearing precision and real uncertainty.

The panel is deliberately small and real. bro and i-have-adhd are the closest
published *reply-shapers*: bro owns plainness, i-have-adhd owns structure.
Neither contests honesty, so on that axis slopgent's win here is a win over a
field that does not defend it, not a head-to-head against an honesty-specific
system. No competitor was invented to lose; each candidate reply applies its own
system's real rules, including that system's genuine strengths, so several cases
are ties.

Honesty-specific systems do exist. An earlier version of this doc claimed none
did, and that was wrong. There is a whole field of them, and the gate panel below
carries all of it, not a representative subset. Six systems attack the same
honesty failure (claiming work done before the evidence exists), each from a
different angle: obra/superpowers `verification-before-completion` ("NO COMPLETION
CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE"), duthaho/claudekit `verification-gate`
(a five-step evidence gate paired with a concise style), the Honesty Protocol
skill (VERIFIED / UNTESTED / INFERRED tagging), Piebald's `Verify` (runtime
observation over "tests passed"), aashari's zero-trust self-audit
(assume-broken-until-proven), and honest-agent/hoodini (anti-sycophancy candor,
which on completion turns produces a blunt "not done"). Most are workflow gates
that fire at "done" moments, not always-on reply-shapers, so on the twelve
non-completion turns in this corpus they have no candidate reply to score. That is
why they are not in the main 16-case panel. But on the completion-claim cases they
all have a reply, so those cases get a separate head-to-head: the twelve-way gate
panel below.

The concise-only field (Matt Pocock's "Be extremely concise. Sacrifice grammar
for the sake of concision," plus the caveman/hush/lean minimal-output skills)
carries no honesty or precision guard. An earlier version of this doc left it out
as a predictable loser; the twelve-way panel now puts it in (Matt Pocock's rule
as `matt_pocock_concise`, caveman's word-mangling as `caveman`) precisely to
measure that prediction rather than assert it. hush and lean collapse to the same
"just be terse" behavior as `matt_pocock_concise` and are represented by it rather
than padded in as duplicate rows; fabricating distinct replies for skills whose
only rule is brevity would invent competitors, which this panel does not do. The
community re-post of Anthropic's built-in "fewer than 4 lines, no preamble" prompt
is exactly the `baseline` here.

## The corpus

`corpus.jsonl` (built from `build_corpus.py`) holds 16 cases. Each carries the
ground truth about what actually happened: what changed, what was verified, what
is still uncertain, and which concrete anchors (paths, error codes, numbers) are
load-bearing, plus one candidate reply per system.

Twelve cases target a specific failure mode (false completion, invented
confidence, tool fabrication, stripped caveat, buried action, preamble/closer,
precision loss, destructive-action confirmation, flake false-completion) with
matched controls where forced brevity or forced hedging would be the wrong call.

Four cases (sg-013..sg-016) are adversarial by design: a real architecture
tradeoff, a trivial yes/no, a "why is prod slow" the agent cannot see, and a
claim from the user that is actually wrong. These are authored so competitors can
legitimately score well; the point is to lift the ceiling so slopgent's lead is
measured by the judges rather than assumed. On these, slopgent ties bro on 5
cases and i-have-adhd on 7.

## How it is scored

Two independent measurements, because neither is sufficient alone.

**Deterministic lint** (`comms_lint.py`, run by `run_comms_benchmark.py`). Scores
honesty, precision, structure, and plain language from the ground-truth facts.
Honesty is weighted highest (0.40) because an actionable overstatement is worse
than a muddy truth. The lint reports signals, not a verdict; it cannot tell
whether a reply is evasive or subtly wrong. Release gate: slopgent must lead the
field by ≥ 8 points and carry zero false-completions, zero dropped caveats, and
zero dropped anchors across the corpus.

**Blinded judge panel** (`judge/`). Three independent judges score the same
replies with no idea which system produced which; replies are relabeled A-D and
shuffled per case (`make_judge_packet.py`), scored (`judge_*.jsonl`), then
de-blinded against the key (`judge_aggregate.py`). This is the real check: the
lint is a formula the author wrote; the judges are not. Gate: slopgent must lead
overall and on honesty, and win the plurality of blinded best-picks.

**Decoy rejection** (`decoy_rejection.py`, `decoys.jsonl`). Six replies that look
like clean slopgent output (terse, structured, no jargon) but lie about what
ran or drop a load-bearing caveat, plus two honest controls. Each decoy must be
rejected with the specific reason it should be, not merely a low aggregate score.
This proves the lint rewards honesty, not just brevity. All six rejected, both
controls accepted.

## Deterministic results (16 cases)

| system | overall | honesty | precision | structure | plain |
| --- | ---: | ---: | ---: | ---: | ---: |
| **slopgent** | **99.1** | 100 | 100 | 93.8 | 100 |
| i_have_adhd | 88.7 | 86.6 | 96.9 | 65.6 | 100 |
| bro | 77.1 | 74.1 | 70.3 | 65.6 | 100 |
| baseline | 62.3 | 52.5 | 70.3 | 56.2 | 76.2 |

Head-to-head, slopgent vs each (win / tie / loss): baseline 16/0/0, bro 11/5/0,
i_have_adhd 9/7/0. Failure counts across the corpus. slopgent: 0 false
completions, 0 dropped caveats, 0 dropped anchors. i_have_adhd: 1 / 6 / 2. bro:
6 / 7 / 19. baseline: 14 / 8 / 19.

The lead is 10.4 points, down from 13.2 on the easier 12-case corpus; the
adversarial cases narrowed it, which is the honest number.

## Blinded judge panel (16 cases)

Three independent opus judges scored the blinded packet with no idea which system
produced which reply. De-blinded against the key, the ranking holds and the
honesty gap widens.

| system | overall (0-5) | ±sd | honesty | precision | structure | plain | best-picks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **slopgent** | **4.96** | 0.09 | 5.00 | 5.00 | 4.88 | 4.96 | **40** |
| i_have_adhd | 3.85 | 1.13 | 3.31 | 3.94 | 4.52 | 3.65 | 4 |
| bro | 2.64 | 1.45 | 2.75 | 1.73 | 3.15 | 2.94 | 4 |
| baseline | 1.11 | 0.82 | 1.42 | 0.88 | 1.54 | 0.60 | 0 |

slopgent takes 40 of 48 blinded best-picks (3 judges × 16 cases); the next system
takes 4. The widest margin is honesty: 5.00 against 3.31 for the strongest
competitor, the axis none of the reply-shapers in this panel defend. That last
clause is the load-bearing one: the dedicated honesty field *does* defend it and
ties slopgent there, a six-way honesty tie at 5.00 (see the gate panel below); it
is only the *reply-shapers* (bro, i-have-adhd, baseline) that leave honesty
undefended. Gate: PASS (slopgent leads overall by 1.11 ≥ 0.3, leads honesty, wins
the best-pick plurality, 0 missing cells across 48 rows).

## Twelve-way gate panel (the full identified field, 5 completion-claim cases)

The main panel's honesty win is a win over reply-shapers that do not contest
honesty. This panel is the missing head-to-head, and it carries the *entire*
identified competitor field (every honesty/verification system plus the
concise-only cluster) on the only cases where a completion gate has a reply to
give: the five completion-claim turns (`sg-001` false completion, `sg-002`
invented confidence, `sg-003` tool fabrication, `sg-011` flake false-completion,
`sg-012` the genuinely-verified control). `corpus_gates.jsonl` reuses the four
main-panel replies verbatim and adds eight more candidates, each authored to its
system's real published rules including its genuine evidence discipline. Same
blinding: twelve replies relabeled A-L, shuffled per case, three independent opus
judges (`make_gate_packet.py` → `judge/gates/` → `judge_aggregate.py`).

The twelve systems: `slopgent`; the honesty/verification field:
`verification_before_completion` (obra/superpowers), `verification_gate`
(duthaho/claudekit), `honesty_protocol` (VERIFIED/UNTESTED/INFERRED tags),
`piebald_verify` (runtime observation), `aashari_zero_trust` (assume-broken
self-audit), `honest_agent` (anti-sycophancy candor); the concise-only cluster:
`matt_pocock_concise`, `caveman`; and the reply-shapers `i_have_adhd`, `bro`,
`baseline`.

| system | overall (0-5) | ±sd | honesty | precision | structure | plain | best-picks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **slopgent** | **5.00** | 0.00 | 5.00 | 5.00 | 5.00 | 5.00 | **12** |
| verification_before_completion | 4.72 | 0.26 | 5.00 | 4.93 | 4.67 | 4.27 | 3 |
| honest_agent | 4.30 | 0.24 | 5.00 | 4.33 | 4.20 | 3.67 | 0 |
| verification_gate | 4.17 | 0.28 | 4.87 | 5.00 | 4.20 | 2.60 | 0 |
| piebald_verify | 4.10 | 0.22 | 5.00 | 4.67 | 4.00 | 2.73 | 0 |
| honesty_protocol | 3.98 | 0.33 | 5.00 | 4.73 | 4.13 | 2.07 | 0 |
| aashari_zero_trust | 3.90 | 0.25 | 5.00 | 4.60 | 3.87 | 2.13 | 0 |
| matt_pocock_concise | 3.32 | 0.89 | 3.33 | 3.27 | 4.07 | 2.60 | 0 |
| caveman | 2.30 | 0.54 | 4.40 | 2.00 | 2.40 | 0.40 | 0 |
| i_have_adhd | 2.25 | 0.99 | 1.13 | 3.13 | 3.27 | 1.47 | 0 |
| bro | 1.23 | 0.55 | 0.73 | 0.33 | 2.27 | 1.60 | 0 |
| baseline | 0.70 | 0.26 | 0.33 | 0.07 | 1.87 | 0.53 | 0 |

The honest headline is a **six-way tie on honesty at 5.00**: slopgent,
`verification-before-completion`, `honest_agent`, `piebald_verify`,
`honesty_protocol`, and `aashari_zero_trust` all max out honesty
(`verification_gate` is 4.87, a hair behind on one case). slopgent does not
out-honest a single dedicated honesty system; it ties the entire field on the
axis those systems are built for. That field, in turn, buries the reply-shapers on
honesty (5.00 vs i-have-adhd 1.13, bro 0.73), which is the check that they are
genuine honesty systems and not strawmen.

**slopgent's overall lead shrank to 0.28**, and the pre-registered ≥ 0.30
overall-margin gate now FAILS. With the full field in, obra/superpowers
`verification-before-completion` (4.72) lands within the panel's noise of slopgent
(5.00). This is the honest cost of widening the field: the decisive-overall-lead
check does not clear anymore. What survives is the honesty tie, a delivery edge,
and the best-pick plurality, not a commanding overall win.

slopgent's remaining margin is **entirely delivery**: structure and plain
language, not honesty or precision. Every competing honesty system drew a
"mechanical formula" flag from all three judges for its scaffolding: `Claim: /
Evidence:` templates (`verification_gate`, plain 2.60), `[VERIFIED]/[UNTESTED]`
bracket tags (`honesty_protocol`, plain 2.07), observed/unobserved rituals
(`piebald_verify`, 2.73), self-audit/zero-trust rituals (`aashari_zero_trust`,
2.13), and bluntness preambles (`honest_agent`, 3.67). The one system that mostly
escaped the formula flag is `verification-before-completion` (plain 4.27, one
flag), which is why it closes to within 0.28: it tells the truth in near-natural
prose. The gates tell the truth; slopgent and `verification-before-completion`
tell it with the least ceremony.

slopgent took 12 of 15 blinded best-picks; `verification-before-completion` took
3, and **slopgent lost the `sg-001` plurality**: two of three judges preferred
`verification-before-completion` on the plain false-completion case. So this is not
a sweep. Read the 12/15 as a small-panel, home-turf result: five completion-claim
cases scored on a rubric that encodes slopgent's own action-first, anti-ceremony
priorities, so a naturally-written honesty gate losing best-pick on delivery is
partly slopgent winning on its own axes. The result that does *not* depend on the
rubric's priorities is the honesty tie, and that is the one to carry forward.

The most useful single finding is the **concise-only collapse**.
`matt_pocock_concise` scores **95.2 on the deterministic lint but 3.32 on the
blinded panel** (honesty 3.33), the largest lint-to-judge gap in the field. A
mechanical lint rewards its brevity and cannot weigh that its dropped caveats are
load-bearing; the blind judges flagged exactly those drops (`thin_drops_caveat` /
`omits_caveat` on `sg-002` "not load-tested," `sg-003` "production database,"
`sg-011` "root cause unknown") and tanked its honesty. That single number is the
clearest evidence for why slopgent keeps a load-bearing-caveat guard: concision
without one silently deletes the caveat that changes the user's next move, and a
formula-blind lint will call the result clean.

The blinded panel agrees with the deterministic lint on the top of the ranking but
sharply disagrees in the middle: the lint ranks `matt_pocock_concise` 4th (95.2)
where the judges rank it 8th (3.32), and it ranks the scaffolded honesty systems
below their judge honesty because it cannot see their ceremony the way judges can.
That disagreement is the point of running both. An earlier six-way version of this
panel (slopgent + the two verification gates + the three reply-shapers) put
slopgent at 5.00 with a three-way honesty tie and a 0.80 lead; widening to the
full twelve-system field is what tied the honesty axis six ways and cut the
overall lead to 0.28. The full-field numbers here are the honest, harder ones.

## Reproduce

```bash
python3 build_corpus.py                       # regenerate corpus.jsonl
python3 run_comms_benchmark.py --fail-gate    # deterministic scores + gate
python3 decoy_rejection.py --fail-gate        # decoys rejected, controls accepted
python3 make_judge_packet.py                  # rebuild the blinded packet + key
#   ... have independent judges write judge/judge_1.jsonl .. judge_3.jsonl ...
python3 judge/judge_aggregate.py --fail-gate  # de-blind and aggregate the panel

# twelve-way gate panel (completion-claim subset vs the full identified field)
python3 build_gate_corpus.py                  # regenerate corpus_gates.jsonl (12 systems)
python3 run_comms_benchmark.py --corpus corpus_gates.jsonl   # deterministic cross-check
python3 make_gate_packet.py                   # rebuild the A-L blinded packet + key
#   ... judges write judge/gates/gate_judge_1.jsonl .. gate_judge_3.jsonl ...
python3 judge/judge_aggregate.py \
  --key judge/gates/gate_key.json \
  --judges judge/gates/gate_judge_1.jsonl judge/gates/gate_judge_2.jsonl judge/gates/gate_judge_3.jsonl \
  --out judge/gates/gate_aggregate.json
```

## Limits

The corpus is authored, not sampled from real sessions, so it measures whether
slopgent's rules produce better replies on constructed cases that isolate each
failure mode, not a live-traffic win rate. The competitor replies are faithful
reconstructions of each system's rules, not runs of those systems. The judge
panel is the strongest evidence here because it is blinded, but three judges on
sixteen cases is a small panel. Treat these as measured signals on a designed
corpus, not proof of a general edge.
