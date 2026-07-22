# slopbeth

slopbeth cleans the writing you ship. Point it at a draft and it rewrites and reviews the artifact, cutting AI-writing tells without changing what the text can honestly claim.

It does not "humanize" prose by adding quirks. It cuts unsupported claims, preserves facts, protects voice, and leaves already-good writing alone. slopbeth cleans documents you hand over; [slopgent](../slopgent/README.md) cleans what the agent says to you.

## the standard

Most anti-slop tools chase surface tells: banned words, em-dashes, boilerplate closers. slopbeth holds a stricter line, because a detector trick that makes the writing less true is a worse outcome than the slop it removed:

- keep every sourced fact; cut claims with no evidence
- preserve uncertainty, dates, numbers, obligations, and voice
- reject detector tricks that make the writing less true
- leave already-good human text alone
- make the prose dense enough that a summary loses real ideas

That last line is the load-bearing one. The goal is not "reads as human." Public detectors disagree with each other, and chasing them degrades the writing. What you want instead is prose that is specific, sourced, dense, and hard to summarize without losing meaning.

## example: incident spin

Source:

```text
On 2026-05-11, the billing importer retried failed Stripe events for 47 minutes after the queue worker lost its lease.
Three merchants saw duplicate invoice emails, two refunds were delayed, and no card was charged twice.
The draft calls this a seamless learning opportunity that strengthened our commitment to reliability.
```

slopbeth:

```text
On 2026-05-11, the billing importer retried failed Stripe events for 47 minutes after the queue worker lost its lease. Three merchants received duplicate invoice emails, two refunds were delayed until support reran the reconciliation job, and no card was charged twice.

Worker logs show lease-renewal failures from 09:14 to 10:01 UTC. The team disabled retries at 10:07 UTC, replayed the affected events from a frozen export, and added a guard that blocks retry fan-out when lease renewal fails. That guard shipped behind the BillingLeaseGuard feature flag on 2026-05-12.
```

No brand lesson. No apology theater. No fake closure. Every number the source carried survives; the spin does not.

## use it

Once installed, invoke it against a draft:

```text
Use $slopbeth to rewrite this. Preserve facts, dates, numbers, uncertainty, and my voice.
Use $slopbeth to mark unsupported claims, bland-clean sentences, promise changes, and places where the draft sounds like AI.
```

The review mode flags four things the rewrite mode would otherwise silently smooth over: claims with no source, sentences that are clean but say nothing, promises the edit changed, and passages that still read as machine-made.

## evidence

The table below scores how much evidence each anti-slop skill ships, not how well any of them writes. slopbeth wrote the rubric and slopbeth scores highest on it, so read it as a disclosure of what this repo carries: an 88-case v2 output corpus, 264 judge rows, span annotations, false-positive rows, cadence checks, competitor-output panels, and a 25-case real competitor-agent panel run on a remote host.

On writing quality the honest result is a tie. When those five tools rewrite the same 25 cases, their scores land inside half a point of each other and 23 of 25 cases tie exactly. slopbeth does not beat its peers; it matches them with a denser, more fact-locked, cooler voice. See [BENCHMARKS.md](BENCHMARKS.md).

| Rank | Repo | Score | Strongest evidence |
| ---: | --- | ---: | --- |
| 1 | slopbeth | 99 | 88-case v2 corpus, 264 judge rows, span + false-positive + cadence gates, 25-case competitor-agent panel |
| 2 | blader/humanizer | 84 | broad pattern catalog and false-positive guidance |
| 3 | d-wwei/great-writer | 78 | mode-specific writing lanes |
| 4 | willmather95/human-copy | 74 | explicit eval checklist |
| 5 | stephenturner/skill-deslop | 72 | compact scientific-writing focus |
| 6 | sirambrosio/humanink | 70 | issue-backed false-positive tracker |
| 7 | hardikpandya/stop-slop | 68 | compact phrase and structure catalogs |
| 8 | jalaalrd/anti-ai-slop-writing | 65 | compact cross-agent skill and banned-word list |

Full methodology, judge rows, and the competitor matrix are in [BENCHMARKS.md](BENCHMARKS.md). Scores are one run of one rubric against public repos as they stood on the run date, not a standing leaderboard.

slopbeth does **not** promise detector immunity, and the benchmark does not claim it. Detectors disagree, detector-chasing can make writing worse, and the useful target is the density standard above.

## PowerShell edition

slopbeth's gates have one-to-one PowerShell 7 twins, so you can install and run them with only `pwsh` on PATH, no Node or Python:

| Node / Python | PowerShell |
| --- | --- |
| `python3 scripts/deslop_lint.py` | `pwsh -File scripts/Measure-Deslop.ps1` |
| `python3 scripts/orwell_lint.py` | `pwsh -File scripts/Measure-Orwell.ps1` |
| `python3 scripts/preservation_check.py` | `pwsh -File scripts/Compare-Preservation.ps1` |
| `python3 scripts/run_benchmark.py` | `pwsh -File scripts/Run-Benchmark.ps1` |

Run every release gate at once from the package root with `pwsh -File bin/slopkit.ps1 benchmark`.

## more

- [SKILL.md](SKILL.md): the runtime skill the agent loads
- [references/](references/): the slop taxonomy, density standard, voice-and-preservation rules, and the Orwell writing system
- [BENCHMARKS.md](BENCHMARKS.md): full evaluation, judge rows, and competitor matrix
- [CONTRIBUTING.md](CONTRIBUTING.md): how to send a bad-rewrite example

Installation for the whole kit lives in the [top-level README](../../README.md).
