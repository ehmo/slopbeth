<p align="center">
  <img src="assets/slopkit.png" alt="Slopkit" width="720">
</p>

<p align="center">
  <a href="https://github.com/ehmo/slopkit/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/ehmo/slopkit/ci.yml?branch=main&style=flat-square&label=CI" alt="CI status"></a>
  <img src="https://img.shields.io/badge/version-1.4.1-0B3D2E?style=flat-square" alt="version 1.4.1">
  <img src="https://img.shields.io/badge/skills-slopbeth%20%2B%20slopgent-0B3D2E?style=flat-square" alt="two skills: slopbeth and slopgent">
  <img src="https://img.shields.io/badge/license-MIT-111827?style=flat-square" alt="MIT license">
  <img src="https://img.shields.io/badge/node-%E2%89%A518-111827?style=flat-square" alt="node 18 or newer">
  <img src="https://img.shields.io/badge/PowerShell-7-2b579a?style=flat-square" alt="PowerShell 7 twin">
</p>

# Slopkit

Two anti-slop skills for coding agents, installed by the same means.

- **[slopbeth](skills/slopbeth/README.md)** cleans the writing you ship. It rewrites and reviews an artifact, cutting AI tells without changing what the draft can honestly claim.
- **[slopgent](skills/slopgent/README.md)** cleans the conversation. It shapes the agent's own replies so they stay honest about what actually ran, action-first, and plain.

They are separate skills. Install both (the default), or remove either one and keep the other. The split is deliberate: point slopgent at a document and you get the clipped formula prose slopbeth exists to remove; ask slopbeth to narrate a build and it has nothing to preserve.

| | slopbeth | slopgent |
| --- | --- | --- |
| Governs | the text you hand over to edit or publish | the agent's own status reports, explanations, and "done" claims |
| Optimizes for | sourced, dense, unsummarizable prose in your voice | honesty first, then structure, then plain language |
| Runtime | Node + Python, with a PowerShell 7 twin | Python (Node for the memory helper) |
| Full docs | [skills/slopbeth/README.md](skills/slopbeth/README.md) | [skills/slopgent/README.md](skills/slopgent/README.md) |

> [!TIP]
> Not sure which you need? **slopbeth** edits a document you hand over. **slopgent** shapes what the agent tells *you* while it works. Most people want both. The default install adds them as siblings, and deleting either directory leaves the other working.

## why

An agent produces two kinds of text, and both drift toward slop in their own way.

- **The artifacts it writes for you** (the README, the postmortem, the release note) fill with unsupported claims, brand-lesson closers, and sentences that read clean but say nothing. slopbeth cuts that without dropping a single sourced fact.
- **The things it says to you** ("Fixed the auth bug," "everything should work now") overstate what actually ran and bury the one command you need. slopgent keeps the agent honest about what it verified and leads with the action.

Neither is a "be concise" directive. Concise-only rules cut the filler and the load-bearing caveat with equal enthusiasm. Both skills cut the filler and keep the caveat.

## install

Install both skills into supported agent skill directories:

```bash
npx github:ehmo/slopkit install
```

That installs slopbeth and slopgent for whichever of Codex, Claude Code, Hermes, OpenClaw, OpenCode, and Pi already exist under your home. Agents you do not use are skipped. Add `--all` (or the `installnpx` alias) to install into every supported agent whether or not its directory exists yet:

```bash
npx github:ehmo/slopkit install --all
npx github:ehmo/slopkit installnpx
```

Both skills land as sibling subdirectories, `skills/slopbeth` and `skills/slopgent`, under each agent's `skills/` directory.

### as Claude Code and Codex plugins

```bash
npx github:ehmo/slopkit install-plugin          # both skills, both agents
npx github:ehmo/slopkit install-plugin claude   # Claude only
npx github:ehmo/slopkit install-plugin codex    # Codex only
```

The Claude plugins install as skills-directory plugins. The Codex plugins install under `~/.codex/plugins/<skill>` and register in `~/.agents/plugins/marketplace.json`, one marketplace entry per skill.

Marketplace install:

```bash
# Claude Code
/plugin marketplace add ehmo/slopkit
/plugin install slopbeth@slopkit
/plugin install slopgent@slopkit

# Codex CLI
codex plugin marketplace add ehmo/slopkit
# then open /plugins and install Slopbeth + Slopgent from the Slopkit marketplace
```

### other paths

Install into a specific directory (both skills land under it):

```bash
npx github:ehmo/slopkit install /path/to/skills
```

Via the external Skills CLI, request all agents explicitly (without `--all` it may install only for the detected current agent):

```bash
npx skills@latest add ehmo/slopkit --all --copy
```

From a clone:

```bash
git clone git@github.com:ehmo/slopkit.git
cd slopkit
node bin/slopkit.js install
```

### PowerShell edition (no Node or Python required for slopbeth)

Slopkit ships a PowerShell 7 runner alongside the Node one, so you can install and run slopbeth's gates with only `pwsh` on PATH:

```powershell
git clone git@github.com:ehmo/slopkit.git
cd slopkit
pwsh -File bin/slopkit.ps1 install        # existing agent dirs (add -All for every agent)
pwsh -File bin/slopkit.ps1 benchmark      # every release gate
```

slopbeth's gates have one-to-one PowerShell twins; the [slopbeth README](skills/slopbeth/README.md#powershell-edition) lists the pairs. slopgent's gates are Python-only; `pwsh -File bin/slopkit.ps1 benchmark` runs them through `python3` when it is present and skips them with a note when it is not.

## benchmarks

Two designed corpora, each scored by a small blinded panel. Bars run from 0 to full scale, with no truncated axes.

### slopbeth vs. eight anti-slop skills: rubric score / 100

| Rank | Skill | Score | |
| ---: | --- | ---: | :--- |
| 1 | **slopbeth** | **99** | `█████████▉` |
| 2 | blader/humanizer | 84 | `████████▍` |
| 3 | d-wwei/great-writer | 78 | `███████▊` |
| 4 | willmather95/human-copy | 74 | `███████▍` |
| 5 | stephenturner/skill-deslop | 72 | `███████▎` |
| 6 | sirambrosio/humanink | 70 | `███████` |
| 7 | hardikpandya/stop-slop | 68 | `██████▊` |
| 8 | jalaalrd/anti-ai-slop-writing | 65 | `██████▌` |

One run of one rubric against public repos as they stood on the run date, not a standing leaderboard. slopbeth leads because it ships rules *and* evidence: an 88-case output corpus, 264 judge rows, and span, false-positive, cadence, and competitor-agent panels.

### slopgent vs. two reply-shapers + baseline: blinded judges / 5

| System | Judges | | Honesty | Best-picks |
| --- | ---: | :--- | ---: | ---: |
| **slopgent** | **4.96** | `█████████▉` | **5.00** | **40 / 48** |
| i-have-adhd | 3.85 | `███████▊` | 3.31 | 4 / 48 |
| bro | 2.64 | `█████▎` | 2.75 | 4 / 48 |
| baseline | 1.11 | `██▎` | 1.42 | 0 / 48 |

Three judges scored replies relabeled and shuffled, blind to which system wrote which. slopgent took 40 of 48 best-picks; the widest margin is honesty, the axis none of the reply-shapers defend.

> [!NOTE]
> Against the *full* field of dedicated honesty systems, honesty is a **six-way tie at 5.00**: slopgent ties the specialists, it does not out-honest them. Its remaining overall lead is **0.28**, inside panel noise and short of the pre-registered ≥ 0.30 gate. The edge that survives is delivery: judges flagged every competitor's `Claim:/Evidence:` scaffolding as mechanical.

> [!WARNING]
> Neither skill promises detector immunity. Detectors disagree with each other, and chasing them makes the writing worse. Both benchmarks are constructed cases scored by small panels: measured signal that these rules beat the alternatives, not proof of a general edge.

Full methodology: slopbeth in [BENCHMARKS.md](skills/slopbeth/BENCHMARKS.md), slopgent in [benchmarks/README.md](skills/slopgent/benchmarks/README.md).

## documentation

- **slopbeth**: [skills/slopbeth/README.md](skills/slopbeth/README.md) (standard, example, evidence) and [BENCHMARKS.md](skills/slopbeth/BENCHMARKS.md) (full evaluation)
- **slopgent**: [skills/slopgent/README.md](skills/slopgent/README.md) (the three fixes, the panel, how to turn it on)

## contribute

Read [skills/slopbeth/CONTRIBUTING.md](skills/slopbeth/CONTRIBUTING.md) before opening an issue or pull request. The most useful contributions are small public examples: a bad rewrite or an inflated agent reply, the source, the exact fact or caveat that changed, and the expected behavior.

## discord

Join the Discord to share examples, report bad rewrites, and talk about removing slop without flattening the writer:

https://discord.gg/zmYmbN99

## examples

The product is the transformation. Below, each skill does its real job. The **before** is the writing it exists to kill; the **after** is what survives. Notice the after is usually *more* specific, rarely merely shorter.

### slopbeth: the writing you ship

It cuts every hollow phrase and keeps every true one. It doesn't trim for the sake of trimming; it trades vague uplift for facts.

**A launch post**

**Before** (the AI draft):

> I'm absolutely thrilled and beyond humbled to announce that after months of relentless dedication, countless late nights, and more coffee than I care to admit, we've officially launched our app! 🚀 This has been an incredible journey of growth and pushing boundaries, and none of it would have been possible without our phenomenal team, whose passion inspires me every single day. At the end of the day, this isn't just about building a product — it's about building a movement. Here's to chasing dreams and never settling for anything less than extraordinary. The future is bright, and we're just getting started! 🙌 #grateful #startup #innovation

**After** (slopbeth):

> We launched Reel today. Drop in a folder of raw phone clips and it cuts a 60-second highlight in about two minutes, no timeline and no keyframes. I built it because editing my daughter's birthday footage ate a whole weekend last year. Four of us shipped it in five months. It's free during the beta, and the first 500 sign-ups keep that price for good. Link's in the replies. Tell me what breaks.

**A thread opener**

**Before** (the AI draft):

> Let's talk about productivity. 🧵 In today's fast-paced world, we're all chasing more — more output, more hustle, more success. But here's what nobody tells you: real productivity isn't about doing more, it's about doing what matters. It's not a hack, it's a mindset. When you align your habits with your goals, magic happens. Thread below on how I completely transformed my life 👇

**After** (slopbeth):

> I logged every work hour for a month. 60% of my "productive" time went to two things: a standup that should have been a message, and re-reading Slack. I killed both. Same output, and I got my Fridays back. Spreadsheet and the exact changes below 👇

**A mission statement**

**Before** (the AI draft):

> At Brightpath, we believe in the power of community to change lives. Our mission is to empower individuals and unlock their full potential through innovative, holistic, and sustainable solutions. We are passionate about creating meaningful impact and fostering a culture of inclusion, collaboration, and growth. Together, we can build a brighter tomorrow — one where everyone has the opportunity to thrive. Join us on this transformative journey.

**After** (slopbeth):

> Brightpath runs a free after-school program for kids in three Oakland neighborhoods where the public library closed in 2019. Last year, 240 kids came through. Of the eighth-graders we tutored, 90% passed the state math test, up from 61% the year before they joined us. We run on about 400 monthly donors giving $15 or more. If you want more of that, that's the whole ask.

### slopgent: what the agent tells you

Same job, pointed at your agent's own replies. It strips the padding and the false confidence and keeps the paths, the numbers, and the one caveat that changes your next move.

**A "done" claim** (technical)

**Before** (the inflated reply):

> Great question! I've taken a thorough look at your authentication flow. After carefully analyzing the codebase and weighing several approaches, I identified the root cause and implemented a comprehensive, robust fix. I updated the token verification to follow current best practices, so your auth is now secure, performant, and maintainable. I also took the liberty of tidying up some adjacent code for readability. Everything should be working smoothly now — your app is in great shape! Let me know if there's anything else I can help with. 😊

**After** (slopgent):

> Changed one thing: `verifyToken` in `auth.ts:42` now uses `jwt.verify`'s promise API instead of the deprecated callback.
>
> Two things I did **not** do: run the tests, and fix `refreshToken` in the same file, which has the identical bug and still needs patching.
>
> Next: `npm test -- auth.spec.ts`. If it fails on `exp`, the clock-skew tolerance is the likely cause. Send me the error and I'll fix it.

**A "looks good, right?" check** (technical)

**Before** (the agreeable reply):

> Yes, absolutely! The migration completed successfully and everything looks great. Your database schema is fully up to date and all your data has been migrated over cleanly. You're all set to move forward — nice work getting this done! Let me know if you'd like help with anything else. 🎉

**After** (slopgent):

> No. I can't confirm that, and one thing looks off. The script exited 0, but the `add_index` step logged `SKIPPED: index already exists` on `orders.customer_id`, which means an earlier partial run left a half-applied state. Before you trust it, run `SELECT COUNT(*) FROM orders WHERE customer_id IS NULL;`. If that's above 0, the backfill didn't finish. I haven't run it; I don't have DB access. Paste the count and I'll tell you if you're clear.

**A recommendation** (non-technical)

**Before** (the inflated reply):

> That's a fantastic question, and I'd be delighted to help you find the perfect destination! Where to travel is such an exciting and personal decision, with so many wonderful factors to weigh. Based on everything you've shared, I truly believe Portugal would be an incredible choice — stunning coastlines, rich history, world-class food, and a warm, welcoming culture. You'll make memories that last a lifetime! Ultimately, the best destination is the one that speaks to your heart. Wherever you land, I'm confident you'll have an amazing adventure. Safe travels! ✈️

**After** (slopgent):

> I can't pick for you. You haven't given me your budget or your dates, and those two decide it. Here's the real difference between your three:
>
> - **Portugal**: cheapest in your window. October is shoulder season; Lisbon runs about €90 a night.
> - **Japan**: priciest right now. The yen has recovered, so West Coast flights are around $1,400 and up.
> - **Costa Rica**: the only weather risk. September to November is the Pacific rainy season.
>
> If budget decides it, Portugal. Give me your dates and I'll pull live flight prices for all three.

## license

MIT
