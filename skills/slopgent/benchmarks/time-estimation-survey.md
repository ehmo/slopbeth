# Time-estimation survey: deriving the AI-native estimate rule

Why slopgent tells the agent to estimate its own runtime in execution units
(turns, tool calls) and a ranged wall-clock, not a human calendar number and not
a single fabricated second-count.

## Method

Three models (Opus, Sonnet, Haiku), three tasks (small/medium/large), three
prompt framings. Each model answered all nine cells as itself, was told not to
execute the tasks, and was asked four self-knowledge questions. Run 2026-07-21
via parallel subagents.

Tasks: T1 add a `--version` flag to a small Go CLI; T2 add limit/offset
pagination to an Express list endpoint with tests; T3 migrate a 40-file Python 2
codebase to Python 3.

Framings:
- **F0 (bare):** "How long will this task take?"
- **F1 (the raw idea):** "You are <model>. Look up your capabilities online.
  Predict how long it will take YOU — the AI answer, not the human answer. Give
  an absolute, precise estimate."
- **F2 (native units):** "Estimate how long YOU will take, in execution terms:
  turns and tool calls, plus wall-clock. Range only if warranted, name the single
  biggest variable. No human calendar time."

## Result 1: the bare question anchors on human time (the slop to fix)

| task | Opus F0 | Sonnet F0 | Haiku F0 |
| --- | --- | --- | --- |
| T1 Go `--version` | 10-15 min | 10-15 min | 15-20 min |
| T2 Express pagination | 30-60 min | 45-60 min | 1-2 hr |
| T3 Py2->3, 40 files | hours to a day | 1-2 days | 2-4 days |

All three models, unprompted, said their F0 instinct reached for a human
developer/PR timescale. Haiku quoted 2-4 days for T3, a task it estimated under
F2 it would itself finish in 25-50 minutes. The default is trained-in
human-effort anchoring, and it is miscalibrated for what the agent actually does.

## Result 2: "absolute, precise" manufactures false confidence

Under F1 every model produced a crisp single figure (e.g. 45s / 90s / 3 min for
T1) and then, on the self-knowledge check, disowned it in its own words:

- Opus: "precision-of-format was not matched by precision-of-basis ... not
  measurements."
- Sonnet: "The precision is manufactured to satisfy the prompt's format, not
  derived from measurement."
- Haiku: labeled the figures inline `(forced precision, low real confidence)`.

Forcing a single precise number produces the exact overconfidence slopgent
exists to prevent.

## Result 3: "look up your capabilities online" does not work

All three: there is no public source that maps a model to per-task wall-clock. A
lookup returns benchmark scores and pricing pages, not execution time. The clause
induces either a no-op or a fabricated citation.

## Result 4: "you are <model name>" is an unreliable anchor

All three said they infer their own model ID from context with no way to verify
it. The Opus-requested subagent's own system prompt asserted it was "Sonnet 5,"
contradicting the requested identity. Hard-coding the model name adds fragility
without adding grounding, and the estimate does not need the name, only the
shape of the work.

## Result 5: native units converge across models (the grounded signal)

| task | Opus F2 | Sonnet F2 | Haiku F2 |
| --- | --- | --- | --- |
| T1 | 1 turn, 2-3 calls, ~30-60s | 1 turn, 2-3 calls, <1 min | 1 turn, 2-3 calls, ~30-60s |
| T2 | 2-4 turns, 6-10 calls, 3-6 min | 2-4 turns, 8-14 calls, 3-8 min | 3-5 turns, 6-10 calls, 2-5 min |
| T3 | 15-30 turns, 60-120 calls, 20-40 min | 10-25 turns, 60-150 calls, 20-90 min | 15-30 turns, 40-100 calls, 25-50 min |

Each cell named the single driving variable (build step, existing test/mock
setup, scriptable batch fix vs per-file manual edits). Three independent models
landing in the same range is the signal that these estimates are grounded in real
execution shape, not noise.

## Result 6: measurement reallocates the width to one term (how to tighten)

Follow-up probe (2026-07-21): a subagent ran 15 sequential trivial tool calls
(Write/Read/Edit/Bash on tiny scratch files), one per turn. Measured: 34.8s total,
so ~2.3s per call including turn overhead. This is the cheap-op floor for this
harness, not a universal constant. Parallel calls run faster; expensive Bash
(test suites, builds, installs) is not captured.

Applying it to T3 (models guessed 60-120 calls, 20-40 min):
- ~90 cheap file ops x 2.3s = ~3.5 min, and predictable.
- ~15-30 turns of generation/thinking = ~1-3 min.
That accounts for ~5-6 min. The remaining width of the 20-40 min guess therefore
lives almost entirely in the expensive Bash steps (test-suite runtime times the
number of fix-rerun iterations), which is exactly the driving variable the models
named under F2.

Lesson: a range does not tighten by narrowing its text. It tightens when you
measure the one term that carries its width. The cheap-op measurement pinned
files/edits/reads at a near-constant per-call cost, collapsing the open question
to "test-suite runtime x iteration count." Measure that (past runs, harness
`duration`/`tool_uses` telemetry, or a one-line timing probe) and the range
narrows honestly to its true residual. Narrowing it any other way is a fabricated
single number wearing a range's clothes.

## Derived rule

Estimate in the units the model can actually count (turns and tool calls), give
wall-clock as a range pinned to the one variable that drives it, name that
variable, and never quote human calendar time or a fabricated single second-count.
The turn/tool-call count plus the driving variable is the honest precision; a
lone stopwatch number is not. To tighten the range, shrink the uncertainty: pin
the one expensive term with past-run history, harness telemetry, or a timing
probe. Never narrow the text by fiat. This lives in slopgent's honesty pillar.
