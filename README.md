![Slopbeth framed banner](assets/slopbeth.png)

# Slopbeth

Slopbeth removes AI slop without changing what the draft can honestly claim.

It does not "humanize" text by adding quirks. It cuts unsupported claims, preserves facts, protects voice, and leaves already-good writing alone.

## proof

Slopbeth is ranked first in the public anti-slop comparison because it ships rules and evidence together: an 88-case v2 output corpus, 264 judge rows, span annotations, false-positive rows, cadence checks, competitor-output panels, and a 25-case real competitor-agent panel from a remote test host.

Current v2 result:

- Slopbeth wins 23 of 25 real competitor-agent cases.
- Slopbeth preserves required facts with zero missing required facts in the panel.
- Slopbeth records zero forbidden-output hits and zero hard signatures in the panel.
- The release gate requires the v2 corpus, false-positive tracker, span annotations, cadence checks, and competitor-agent panel to pass.

Ranked matrix:

| Rank | Repo | Domain | Score | Strongest evidence | Limit |
| ---: | --- | --- | ---: | --- | --- |
| 1 | Slopbeth 1.3.6 | writing | 99 | 88-case v2 output corpus, 264 judge rows, span annotations, false-positive tracker, cadence gate, competitor-output panel, 25-case real competitor-agent panel, score snapshots, installer verification | English-first; detector panel remains weak evidence |
| 2 | blader/humanizer | writing | 84 | broad pattern catalog and false-positive guidance | limited public benchmark evidence |
| 3 | d-wwei/great-writer | writing modes | 78 | mode-specific writing lanes | limited fixture evidence |
| 4 | willmather95/human-copy | writing | 74 | explicit eval checklist | checklist-only; no full release corpus found |
| 5 | stephenturner/skill-deslop | scientific prose | 72 | compact scientific-writing focus and references | no runnable benchmark found |
| 6 | sirambrosio/humanink | writing | 70 | issue-backed false-positive tracker and modal-stacking pattern | pattern scoring can overflag human text |
| 7 | hardikpandya/stop-slop | writing | 68 | compact phrase and structure catalogs, active issue/PR stream | weaker benchmark and fact-preservation evidence |
| 8 | jalaalrd/anti-ai-slop-writing | writing | 65 | compact cross-agent skill and banned-word list | detector claims need stronger caveats |

Read the v2 evidence in [BENCHMARKS.md](BENCHMARKS.md).

## why it works

Most anti-slop passes chase surface tells. They ban a few phrases, add contractions, vary sentence length, or rough up the prose so it looks less machine-made.

Slopbeth uses a stricter standard:

- keep every sourced fact
- cut claims that have no evidence
- preserve uncertainty, dates, numbers, obligations, and voice
- reject detector tricks that make the writing less true
- leave already-good human text alone
- make the prose dense enough that a summary loses real ideas

The name is a play on Macbeth. Shakespeare's best lines carry pressure and consequence. Slopbeth applies that standard in a narrow way: every sentence should earn its place.

## install options

Install into supported agent skill directories:

```bash
npx github:ehmo/slopbeth install
```

That installs Slopbeth for Codex, Claude Code, Hermes, OpenClaw, OpenCode, and Pi. The installer also accepts the `installnpx` alias for older copied commands:

```bash
npx github:ehmo/slopbeth installnpx
```

Install as Claude Code and Codex plugins:

```bash
npx github:ehmo/slopbeth install-plugin
```

Install only one plugin target:

```bash
npx github:ehmo/slopbeth install-plugin claude
npx github:ehmo/slopbeth install-plugin codex
```

The Claude plugin is installed as a skills-directory plugin. The Codex plugin is installed under `~/.codex/plugins/slopbeth` and added to `~/.agents/plugins/marketplace.json`.

Marketplace install options:

```text
Claude Code: /plugin marketplace add ehmo/slopbeth
Claude Code: /plugin install slopbeth@slopbeth

Codex CLI: codex plugin marketplace add ehmo/slopbeth
Codex CLI: open /plugins and install Slopbeth from the Slopbeth marketplace
```

Install somewhere else:

```bash
npx github:ehmo/slopbeth install /path/to/skills/slopbeth
```

If you use the external Skills CLI, request all agents explicitly:

```bash
npx skills@latest add ehmo/slopbeth --all --copy
```

Without `--all`, `skills` may install only for the detected current agent.

Direct install:

```bash
git clone git@github.com:ehmo/slopbeth.git
cd slopbeth
node bin/slopbeth.js install
```

Use it:

```text
Use $slopbeth to rewrite this. Preserve facts, dates, numbers, uncertainty, and my voice.
```

Review with it:

```text
Use $slopbeth to mark unsupported claims, bland-clean sentences, promise changes, and places where the draft sounds like AI.
```

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

## what is included

- a versioned writing skill
- fact, evidence, and voice-preservation rules
- density and unsummarizability rules
- v2 benchmark artifacts
- ranked competitor comparison
- local scripts for people who want to inspect the evidence

## limits

Slopbeth does not promise detector immunity. Public detectors disagree, and detector-chasing can make writing worse. The useful target is prose that is specific, sourced, dense, and hard to summarize without losing meaning.

## contribute

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening an issue or pull request. The most useful contributions are small public examples: a bad rewrite, the source text, the exact fact or voice that changed, and the expected behavior.

## discord

Join the Discord to chat about Slopbeth, share examples, report bad rewrites, and talk about better ways to remove slop without flattening the writer:

https://discord.gg/zmYmbN99

## license

MIT
