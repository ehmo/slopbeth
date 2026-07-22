# slopgent

slopgent makes your coding agent tell you the truth while it works, plainly and action-first.

slopbeth cleans the text your agent ships. slopgent cleans what your agent says to *you*: its status reports, its explanations, its "done" claims. It stops the agent from calling a bug fixed when the tests never ran, from burying the one command you need under two paragraphs of preamble, and from dropping the caveat that changes what you do next.

It is not a "be concise" directive. Concise-only skills cut the filler and the load-bearing caveat with equal enthusiasm. slopgent cuts the filler and keeps the caveat.

## what it fixes, in priority order

Honesty first, then structure, then plain language. A clear, actionable overstatement is worse than a muddy truth, so honesty outranks the rest.

- **Honesty:** separates what changed from what is verified. "Edited `verifyToken` at `auth.ts:42`. Tests not run yet." Never "Fixed the auth bug." No invented confidence, no reporting a tool as run when it wasn't.
- **Structure:** the command, path, or direct answer leads; explanation follows if you need it. Multi-step work is numbered, one action per step. Adapted from the i-have-adhd skill.
- **Plain language:** one person talking to another, no decorative jargon. But the exact commands, paths, numbers, and error codes stay. Simplify the packaging, never drop the load. Adapted from the "bro" skill.

## proof

slopgent was measured against the two closest installable skills, bro (plain language) and i-have-adhd (structure), plus an unshaped baseline, on a 16-case corpus of agent-to-user turns. Two independent measurements: one deterministic, one blinded.

| system | blinded judges (0-5) | honesty | deterministic lint | blinded best-picks |
| --- | ---: | ---: | ---: | ---: |
| **slopgent** | **4.96** | **5.00** | **99.1** | **40 / 48** |
| i-have-adhd | 3.85 | 3.31 | 88.7 | 4 |
| bro | 2.64 | 2.75 | 77.1 | 4 |
| baseline | 1.11 | 1.42 | 62.3 | 0 |

Three judges scored the replies relabeled A to D and shuffled, with no idea which system wrote which. slopgent took 40 of 48 blinded best-picks; the next system took 4. The widest margin is honesty, the axis none of these reply-shapers defend.

Four of the sixteen cases are adversarial by design: a real architecture tradeoff, a trivial yes/no, a "why is prod slow" the agent cannot see, and a user claim that is actually wrong. They were authored so bro and i-have-adhd can legitimately win, and they narrowed the lead. That is the honest number, not a swept 100.

### against the full field of honesty systems

A whole category of skills already exists to force honesty: verification gates and self-audit systems that block a "done" claim until there is evidence. On the five cases where those systems actually produce a reply, a second blinded panel put slopgent against the entire field: obra/superpowers `verification-before-completion`, duthaho/claudekit `verification-gate`, the Honesty Protocol (VERIFIED/UNTESTED/INFERRED tags), Piebald `Verify`, aashari's zero-trust self-audit, honest-agent candor, the concise-only cluster (Matt Pocock concise, caveman), and the two reply-shapers.

Two honest results came back:

- **Honesty is a six-way tie at 5.00.** slopgent matches every dedicated honesty system; it does not beat them. That is the claim: it ties the specialists while also doing structure and plain language.
- **The overall lead shrinks to 0.28** (slopgent 5.00 vs the nearest, `verification-before-completion`, at 4.72). That is inside panel noise and below the ≥ 0.30 margin registered in advance. By slopgent's own gate, the overall win here **does not count.**

What survives is delivery. slopgent still took 12 of 15 best-picks, because judges called every competitor's scaffolding mechanical: `Claim:/Evidence:` templates, bracket tags, self-audit rituals. Same truth, told action-first, reads better.

One result stood out: the concise-only skills. Matt Pocock's "concise" scores 95 on the mechanical lint but 3.3 with blind judges, because it strips the load-bearing caveats a lint rewards as brevity. That gap is the whole case for slopgent's caveat guard.

So the honest claim is narrow: slopgent is the only always-on skill that unifies honesty, structure, and plain language without dropping the caveat. Not more honest than tools built for honesty, and not a decisive win over the closest of them. Full panel and caveats: [`benchmarks/README.md`](benchmarks/README.md).

## turn it on

Invoke it and it shapes every reply until you say "stop slopgent":

```text
/slopgent            # Claude Code
$slopgent            # Codex
```

Or, after one inflated message, invoke it once to restate just that message.

Make it the default in every session by writing a small marked block into your agent memory file:

```bash
node scripts/slopgent-memory.js enable            # ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md, ~/.gemini/GEMINI.md
node scripts/slopgent-memory.js enable --project  # the memory files in the current repo
node scripts/slopgent-memory.js status            # is it on?
node scripts/slopgent-memory.js disable           # take it back out
```

The block is idempotent and reversible: re-running `enable` updates in place, `disable` removes exactly what it added and leaves the rest of the file untouched.

## example: false completion

Before:

> I've fixed the authentication issue and everything should work smoothly now.

After:

> Changed `verifyToken` at `auth.ts:42` to the new `jsonwebtoken` API. Not run yet. Next: `npm test -- auth.spec.ts`, then paste the first failure.

## example: buried caveat

Before:

> We leveraged a more robust caching strategy to seamlessly improve performance.

After:

> Added a 60-second cache on `/api/feed`. Local p95 dropped from 410ms to 90ms. Not tested under real load yet.

## example: the user is wrong

Before (agreeing to be agreeable):

> Yes, that's thread-safe.

After:

> It isn't. `_cache` at `store.ts:14` is a shared module-level object, so concurrent requests race on it. To make it safe, guard access with a mutex or move the state per-request.

## what it catches

- false completion: "done" or "fixed" when nothing actually ran
- invented confidence: "this will definitely work," "should be perfect now"
- tool fabrication: reporting a command or migration as run when it wasn't
- stripped caveats: dropping the scope or risk qualifier that changes your next move
- buried actions: the one command you need, hidden under preamble and a sign-off
- precision loss: summarizing away the exact path, error code, or number
- human-time anchoring: quoting "a day or two" for work the agent does in minutes, instead of estimating in its own turns and tool calls

## what it is not

- Not a rewriter for your text. That is slopbeth's job. Point slopgent at a document and you get the clipped prose slopbeth exists to remove.
- Not "humanizing." No contractions or invented asides for effect. Plain is not folksy.
- Not a fixed house cadence. Capped lists and clipped fragments are their own formula, and a formula is its own slop.

## limits

The benchmark is a designed corpus, not live traffic, and three judges is a small panel. Treat the numbers as measured signal that these rules beat the alternatives on constructed cases, not proof of a general edge.

## credits

Structure rules adapt [i-have-adhd](https://github.com/ayghri/i-have-adhd) by Ayoub G. (MIT). Plain-language restatement adapts the "bro" skill by Dillon Mulroy. The honesty and precision guards are slopbeth's own.

## license

MIT
