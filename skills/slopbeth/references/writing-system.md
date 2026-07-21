# Writing system

Deslop mostly removes tells after the fact. This reference gives the other half: a positive system to write from, so prose does not arrive in the generic AI voice that later needs stripping. Banning words one at a time ("no em dashes," "stop saying delve") treats symptoms. A writing system treats the cause.

The base is Orwell's six rules from "Politics and the English Language" (1946). They are old, blunt, and load-bearing. Use them at generation time and as a rewrite pass, not only as a lint after the draft is done.

## The six rules

1. Never use a metaphor, simile, or figure of speech you are used to seeing in print. Dead metaphors ("move the needle," "low-hanging fruit," "paving the way," "navigate the landscape") carry no image; they signal that no one pictured anything. Cut them or replace them with a live, specific image the sentence actually earns.
2. Never use a long word where a short one will do. `utilize` is `use`, `facilitate` is `help`, `methodology` is `method`, `approximately` is `about`. The long word rarely adds precision; it adds distance.
3. If it is possible to cut a word out, cut it out. `in order to` is `to`, `due to the fact that` is `because`, `has the ability to` is `can`. Windups like "it is important to note that" delete cleanly with no loss.
4. Never use the passive where you can use the active. Name the actor. "Access must be suspended" hides who suspends it. Passive is the single Orwell rule that survives most AI rewrites, so check it hardest.
5. Never use a foreign phrase, a scientific word, or a jargon word if you can think of an everyday equivalent. `synergy`, `operationalize`, `leverage`, `vis-a-vis` almost always have a plain word that is also more honest.
6. Break any of these rules sooner than say anything outright barbarous.

## Rule six is the reason this does not become new slop

The first five rules, followed mechanically, produce their own tell: clipped, uniform, aggressively plain prose that reads as another template. Rule six is the escape valve, and it maps directly onto the deslop hard rule against replacing one formula with another.

- Keep a long or Latinate word when it is the precise term (`latency`, `plaintiff`, `idempotent`), not decoration.
- Keep passive voice when the actor is unknown, irrelevant, or when the register demands it. Policy, legal, and incident copy use agentless obligation ("logs must be retained for seven years") on purpose; forcing an actor there is the barbarous option. The passive signal is a review queue for those cases, not an order to rewrite them.
- Keep a metaphor when it is live and specific to this subject, not a printed reflex.
- Keep rhythm. A cut that leaves the sentence hard to parse on first read fails rule six.

If applying a rule would make the sentence less true, less specific, or harder to read, break the rule and note why.

## How this sits with the rest of the skill

The five active rules overlap the taxonomy but are sharper as generation defaults:

- Rule 1 covers part of "abstract significance language" and generic closers.
- Rules 2 and 3 are the concrete, checkable core of "filler and windups."
- Rule 4 is the actionable form of "false agency and actorless claims," and it is the rule the current outputs miss most.
- Rule 5 overlaps promotional and jargon inflation.

Density and preservation still rule. Orwell tightens sentences; it does not decide what a sentence should carry. A passage can pass all six rules and still be bland-clean scaffolding that fails the sentence-load and topic-swap tests in `density-and-unsummarizability.md`. Apply the writing system first, then check that every surviving sentence still carries a claim, number, example, constraint, or consequence. Preservation of facts, qualifiers, and voice outranks all six rules.

## Portable block

The thread that motivated this reference recommends pasting the rules into a global `CLAUDE.md` or `AGENTS.md` so every session inherits them. That is a reasonable use, with one caveat: paste rule six with the other five. The five-rule version travels the internet as a "humanizer" and produces the uniform plain voice it was meant to prevent.

```
Writing rules (Orwell, 1946), applied to any prose you generate:
1. No printed-cliche metaphors; use a live image or none.
2. No long word where a short one works (use, not utilize).
3. Cut every word that can be cut (to, not in order to).
4. Active over passive; name the actor unless it is unknown or the register needs agentless.
5. No jargon or foreign phrase with a plain equivalent.
6. Break any rule sooner than write something unclear, untrue, or graceless.
Facts, numbers, qualifiers, and the author's voice outrank all six.
```

## Deterministic check

`scripts/orwell_lint.py` counts the five mechanical rules and reports a passive ratio, per-rule hits, and plain-word suggestions. It does not implement rule six, so treat its output as a signal.

```bash
python3 skills/deslop/scripts/orwell_lint.py path/to/text.txt --format json
python3 skills/deslop/scripts/orwell_lint.py path/to/text.txt --max-passive-ratio 0.3
```

Calibration finding on the current release corpus: deslop rewrites already cut long words, deletable phrases, and jargon to near zero, but passive-voice count barely moves between input and output. That gap is why rule 4 gets its own passive-ratio field and why it is worth checking at generation time rather than trusting the general rewrite to catch it.
