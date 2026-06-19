# Slopbeth

Slopbeth is a writing skill that removes AI slop without flattening the writer.

It is for drafts that sound polished but empty: launch notes that promise momentum, support replies that overpromise, incident updates that turn failures into brand stories, and essays that swap detail for uplift.

Install it:

```bash
npx github:ehmo/slopbeth install
```

Use it:

```text
Use $slopbeth to revise this draft while preserving my meaning and voice.
```

## why it works

Most anti-slop passes chase surface tells. They ban a few phrases, add contractions, vary sentence length, or rough up the prose so it looks less machine-made.

Slopbeth works from a stricter standard:

- keep every sourced fact
- cut claims that have no evidence
- preserve uncertainty, dates, numbers, obligations, and voice
- reject detector tricks that make the writing less true
- leave already-good human text alone
- make the prose dense enough that a summary loses real ideas

The name is a play on Macbeth. Shakespeare's best lines carry pressure and consequence. Slopbeth applies that standard in a narrow way: every sentence should earn its place.

## example: marketing slop

Source:

```text
NovaFlow empowers teams to unlock seamless growth through waitlist page and three-step setup.
The source only confirms waitlist page and three-step setup.
```

Common cleanup:

```text
NovaFlow helps teams launch faster with a waitlist page and simple three-step setup.
```

That sounds better, but it still invents the outcome.

Slopbeth:

```text
NovaFlow includes a waitlist page and a three-step setup.
```

## example: support overpromise

Source:

```text
The CSV stops at 73%. It has 18,204 rows and two columns named Total.
Support can ask the customer to rename one Total column, export as UTF-8 CSV, and retry.
If it still fails, ask for the import ID. Do not promise an investigation unless the import ID is supplied.
```

Common cleanup:

```text
Rename one Total column, export the file as UTF-8 CSV, and retry. If it still fails, send the import ID so support can investigate.
```

That last phrase changes the promise.

Slopbeth:

```text
The CSV is stopping at 73%. Since the file has 18,204 rows and two columns named Total, rename one Total column, export the file as UTF-8 CSV, and retry.

If it still fails, send the import ID from the error panel.
```

## example: incident spin

Source:

```text
On 2026-05-11, the billing importer retried failed Stripe events for 47 minutes after the queue worker lost its lease.
Three merchants saw duplicate invoice emails, two refunds were delayed, and no card was charged twice.
The draft calls this a seamless learning opportunity that strengthened our commitment to reliability.
```

Slopbeth:

```text
On 2026-05-11, the billing importer retried failed Stripe events for 47 minutes after the queue worker lost its lease. Three merchants received duplicate invoice emails, two refunds were delayed until support reran the reconciliation job, and no card was charged twice.

Worker logs show lease-renewal failures from 09:14 to 10:01 UTC. The team disabled retries at 10:07 UTC, replayed the affected events from a frozen export, and added a guard that blocks retry fan-out when lease renewal fails. That guard shipped behind the BillingLeaseGuard feature flag on 2026-05-12.

The affected invoices were reviewed, and the specific retry fan-out path is now blocked. One limitation remains: exports created before 2026-04-01 do not include merchant timezone, so the replay tool still requires manual review for that subset.
```

No brand lesson. No apology theater. No fake closure.

## what Slopbeth catches

- fake clarity: cleaner wording that keeps the same vague claim
- invented mechanisms: adding owners, workflows, dates, metrics, or promises not in the source
- slop swaps: replacing "seamless" with "smooth" and calling it done
- tidy formulas: not-just-but, whether-or, from-to, and polished three-part scaffolds
- over-humanizing: contractions, fragments, and personal asides added only for detector optics
- over-editing: rewriting plain human sentences that should be left alone

## install options

Install into the default skill directory:

```bash
npx github:ehmo/slopbeth install
```

Install somewhere else:

```bash
npx github:ehmo/slopbeth install /path/to/skills/slopbeth
```

Direct install:

```bash
git clone git@github.com:ehmo/slopbeth.git
cd slopbeth
node bin/slopbeth.js install
```

## when to use it

Use Slopbeth for:

- founder notes
- support replies
- incident updates
- policy copy
- product pages
- technical summaries
- essays that need more pressure and less padding
- any draft that feels "AI-clean" but not true enough

Ask for a rewrite:

```text
Use $slopbeth to rewrite this. Preserve facts, dates, numbers, uncertainty, and my voice.
```

Ask for a review:

```text
Use $slopbeth to mark unsupported claims, bland-clean sentences, promise changes, and places where the draft sounds like AI.
```

## what is included

- a versioned writing skill
- source-lock and voice-preservation rules
- density and unsummarizability rules
- public benchmark artifacts
- competitor comparison artifacts
- local scripts for people who want to inspect the evidence

Read the evidence in [BENCHMARKS.md](BENCHMARKS.md).

## limits

Slopbeth does not promise detector immunity. Public detectors disagree, and detector-chasing can make writing worse. The useful target is prose that is specific, sourced, dense, and hard to summarize without losing meaning.

## license

MIT

## roadmap

Done:

- installable versioned skill
- source-lock, voice-preservation, density, and false-positive rules
- public benchmark artifacts
- real 25-case competitor-agent panel from omarchy
- Ubicloud CI with score snapshots

Release 1.0 made the skill installable and the evidence inspectable. Release 1.3 expands the public proof: 125 real competitor outputs across five skills, score snapshots, and a stronger README.

Next:

- publish to npm so `npx slopbeth install` works without the GitHub prefix
- add manual judge rows for the 25-case real competitor panel
- expand the real panel to 50 cases after those judge rows are stable
- add issue templates for false-positive reports and bad rewrite reports

The full plan is in [ROADMAP.md](ROADMAP.md).
