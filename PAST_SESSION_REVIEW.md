# PAST_SESSION_REVIEW — `coderabbit-threads` fit-check

Retrospective: does the new skill match how Torben actually handles CodeRabbit feedback
across recent deepdock-mono sessions?

Scope reviewed: ~12 top-level Claude Code sessions from the deepdock-mono project (2026-05-01 → 2026-05-12).
The most recent session (`8a3e8472`, May 12) is itself the design session for this skill, so it doubles as both
"what the user said they want" and "ground-truth of past pain points".

## Evidence log

Paraphrased, with provenance — no verbatim transcripts to limit unrelated context leakage.

1. **`a3a6862f` (May 5)** — user said "please launch another agent to read coderabbit pr comments and under each skipped comment one by one." Then "another sonnet agent getting you the newest coderabbit comments you not saw." Then "there are still a few open coderabbit comments can you check them and comment fixed under each if they are fixed." → This is *exactly* the per-thread loop the skill provides; today the user has to manually dispatch a subagent for each round.

2. **`a3a6862f` (May 5)** — user has a memorised standard prompt: *"Apply CodeRabbit findings to PR #119 (DD-27) with the standard 'verify each, fix only still-valid, skip rest with reason' prompt."* → maps to the skill's triage labels (`still-applies`, `out-of-scope`, etc.) and the autonomous reply for `likely-fixed`/`out-of-scope`.

3. **`82d12eb9` (May 8)** — user ran `run coderabbit with base staging` followed by `run coderabbit again` across multiple review rounds (4+ rounds on one PR), triaging 60+ findings. Past notes mention "skipped findings: dark `--destructive` value, Tauri Client link, function-keyword exception restoration, pre-existing section-marker comments, `<img>` onError fallback." → confirms multi-round usage at industrial volume.

4. **`dfabd62d` (May 10)** — user prompts include `"ready for coderabbit feedback?"` after a push, treating "wait for CodeRabbit" as a discrete step in their PR lifecycle. → the skill's Step 1 (verify push state) and Step 3 (bail if `in_progress`) align with this exactly.

5. **`8a3e8472` (May 12, design session)** — user dictated the skill's principles inline:
   - *"claude often replies in one comment in pr but it shall be to each issue"* → per-thread, not bulk PR comment.
   - *"work with feedback pushback and dont be too persuasive"* → reply-template steering.
   - *"raise to user if something out of scope and if issues in linear or equal should be open"* → `out-of-scope` triage + Linear tracking.
   - *"resolve when coderabbit agrees ... schedule a background task for 30sec check"* → Step 7 polling.
   - *"use question ui"* → `AskUserQuestion` primitive throughout.

6. **`8a3e8472` (May 12)** — late in the session: *"if a comment is closed after coderabbit responds its not a pushback since coderabbit or the user decided to close ... should be reflected in tool calls and definitely in skill md."* → the resolved-precedence rule was explicitly user-driven. Already in `reference.md` and SKILL.md Step 4.

7. **`8a3e8472` (May 12)** — user UX-tested `cr` ("please test on as many prs as you want and verify it works nicely") and a subagent reported back with concrete UX gaps: filter semantics, `line: null` rendering as `:?`, no `--plain` mode on `cr status`. → Some of these are already fixed in the bin/cr (the PR #102 follow-up test passes `--plain`); a few remain.

8. **`02a33f1f` / `efb2917a`** — user routinely instructs *"task a subagent with opus to do that in a new branch and use sonnet agents to move quick then review with other opus agent also in background and create pr."* → workflow is heavily subagent-driven. The skill does not currently spawn subagents for the per-thread fix work; it expects the calling agent to handle code changes.

9. **`a3a6862f`** — user later says "and review the code smell findings" after CR responds. → CR-thread review and broader review are *interleaved*; user does not see them as two separate skills.

10. **`82d12eb9` / `01e064a5`** — user prompts are 1–10 word fragments in English (`"1 yes set all to the same non bad version, unify"`, `"please review the tests"`, `"oh thats good (your pick)"`). User does not type in German; CodeRabbit also writes in English. No evidence the skill needs i18n for replies.

## Integration gaps

1. **No commit-and-push step after applying a fix.** *(severity: blocker for the common case)* — When the user marks a thread `still-applies` and answers `Acknowledged — will fix in this PR`, the skill does not actually fix anything. Past sessions show the user expects the agent to *find the file, fix it, commit, push, and then reply `Fixed in <sha>`*. The skill's reply template assumes a SHA already exists (`Fixed in <sha> by <one-line change>`) but the Step 6 table for `still-applies` only offers `Acknowledged — will fix in this PR / Won't fix / Out-of-scope / skip`. The path from "user said fix" → "code change lands" → "reply with the SHA" is missing.

2. **No Linear issue creation for `out-of-scope`.** *(severity: nice-to-have)* — User explicitly said *"raise to user if something out of scope and if issues in linear or equal should be open"*. The current skill's Roadmap section acknowledges this gap (`No auto-created issues`). But in past sessions the user *does* maintain DD-* tickets routinely (project memory shows DD-8, DD-11, DD-12, DD-27, DD-36, DD-37, DD-38, DD-39 all tracked). For deepdock-mono specifically, an opt-in *"create Linear issue DD-? for this?"* prompt would close a real loop. As an escape hatch, surface the suggested `linear_create_issue` call as a *display-only* hint the user can copy.

3. **No interleaving with `coderabbit:autofix`.** *(severity: nice-to-have)* — Past sessions show the user toggling between *applying* fixes (autofix territory) and *replying* (this skill). The README mentions "the two compose well" but does not say *how* — e.g., "if autofix already posted a summary, list those threads as `likely-fixed` and skip them in the walk." A user reading the README cold will not know whether to run them in series or whether re-running this skill after autofix triple-replies.

4. **No multi-round / "run again" affordance.** *(severity: nice-to-have)* — User pattern: `run coderabbit with base staging` → fix → `run coderabbit again` → fix → repeat. Each `again` produces new threads. The skill walks "open threads now" but does not surface "how many new threads since you last ran this skill?" — a useful diff for the user's actual workflow.

5. **Self-close prompt happens after triage, not before the walk-through cancel.** *(severity: aesthetic)* — Step 5 displays the table, asks `Walk through? / Skip / Cancel`, then if walk-through is chosen, asks `RESOLVE_POLICY`. Two consecutive prompts before any actual work feels heavier than the README's snippet suggests. Past sessions show the user wants to see the table and decide *one* thing.

6. **No detection of human-authored review comments.** *(severity: aesthetic)* — Past sessions show colleagues sometimes weigh in on CR threads alongside the bot. The skill's `cr.label` taxonomy is bot-vs-human-on-bot-thread, but a human-only thread or a CR-thread-with-third-party-replies aren't surfaced as a special case. The `--full` context flag exposes them, but triage doesn't differentiate.

## Friction points

- **The walk-through assumes one reply per thread.** Real sessions sometimes go 2–3 rounds on a single thread within one skill run (bot pushes back, user re-replies). The skill's Step 7 polls only after *all* replies are posted; it then exits to "next run". A user who wants to handle pushback *immediately* during the same run cannot.
- **`Acknowledged — will fix in this PR` is a half-promise that needs follow-through.** If the user picks this template, the skill posts and moves on. There is no tracking that the fix actually lands before the run summary prints "Walked N threads." A summary line *"N threads acknowledged-but-not-yet-fixed"* would help.
- **Severity icons in the table use 🔴/🟠/🟡/🟢 mapped to CRIT/HIGH/MEDIUM/LOW/INFO, but CodeRabbit only emits `severity: minor/major/critical` (and sometimes none).** The README's snippet shows `LOW` and `CRIT` side by side; the skill's mapping logic for the in-between values is not specified.
- **`cr context` markdown is great for the agent, but the user never sees it.** In past sessions the user occasionally asks "what did CR actually say on thread X?" — having a `cr context --plain` or letting the agent show a 2-line summary on a `bot-pushback` prompt would help.

## README revision recommendations

Concrete edits. *Do not apply* — recommendations only.

### R1 — "What a run looks like" (lines 11-62) overstates autonomy

The snippet shows 4 threads, posts 4 replies, 2 are auto-generated, 2 ask the user. But the user prompts are shown as one-liners like `> fixed-in 4af1c9d` — implying the agent already knows the SHA. In reality, for `still-applies` threads, the user usually wants the *agent* to find and apply the fix first, then post `Fixed in <sha>`. Replace thread 2's exchange with something like:

> — Thread 2/4 · still-applies · apps/api/src/scheduled.ts:80 ———
> Reply: [fix-now] [acknowledged] [won't-fix <reason>] [out-of-scope] [skip]
> > fix-now
> Applied fix in commit 4af1c9d (added Promise.allSettled per CR suggestion).
> Posted: "Fixed in 4af1c9d by switching to Promise.allSettled."

This would also flag integration gap #1 to readers up-front.

### R2 — Move `run coderabbit again` language into "Why it exists"

Lines 68-83 frame the human flow as a one-shot ("CodeRabbit's bot reads a PR, posts a review with N threads ... waits"). Past sessions show 4+ rounds is normal. Add a sentence under "Why it exists":

> CodeRabbit reviews iteratively — each push triggers a fresh pass with new threads on the *delta*. A typical PR sees 3-5 review rounds before merge, and threads accumulate (some from round 1, some from round 4). This skill is designed to be *re-run after each round*, walking only the unresolved threads.

### R3 — Reword the autofix relationship

Lines 215-228 (the comparison table) treat autofix and this skill as siblings. In practice the user toggles between them within one PR. Add a paragraph above the table:

> The intended workflow is: (1) push code, (2) wait for CodeRabbit, (3) run `coderabbit:autofix` to land the easy diffs CR proposed, (4) run `coderabbit-threads` to converse on what's left. Threads autofix already addressed will appear here as `likely-fixed` and get an autonomous reply; the remainder are the judgment calls.

### R4 — The `still-applies` template list is misleading

Line 246 lists `Acknowledged — leaving as-is per <one-line reason>` as one of the four reply templates. But Step 6 row `still-applies` (line 237) offers `Acknowledged — will fix in this PR`. These are *opposite* meanings (one is "leaving it", the other is "I will fix it"). Disambiguate:

```
Fixed in <sha> by <one-line change>.
Will fix in this PR — applying now.
Won't fix: <one-line reason>.
Out-of-scope of this PR — should be tracked separately.
Acknowledged — leaving as-is per <one-line reason>.
```

Five templates, not four.

### R5 — Drop "Other agent runtimes" from Roadmap line 236

The skill itself is platform-aware (Step 7's "Without ScheduleWakeup" branch). The roadmap item reads as an apology for v1 scope but the skill *already works* on Cursor/Codex via the documented fallbacks. Trim to a single Note in Installation:

> On Cursor / Codex / Copilot CLI, install manually and invoke `cr` directly. `AskUserQuestion` and `ScheduleWakeup` have fallback paths documented in `SKILL.md`.

## Skill-design recommendations

For `SKILL.md` and `cr`. Recommendations only — do not edit.

### S1 — Add a `fix-now` action for `still-applies` and `unclear`

The Step 6 row for `still-applies` should offer `fix-now` as the first option:

> Reply: [**fix-now**] [acknowledged-deferred] [won't-fix <reason>] [out-of-scope] [skip]

`fix-now` triggers:
1. Read the cited file, apply the change the bot suggested *or* let the user pick from CR's proposed diff (if `cr context` has one).
2. Run repo verification gates (`bun format && bun lint && bun typecheck` per the repo's `quality-gates.md`).
3. Commit with the format `bugfix(<scope>): <CR one-liner>` per the repo's commit conventions (loaded in Step 0).
4. Push.
5. Reply `Fixed in <sha> by <one-line change>.`

Without this, the user goes back to dispatching subagents themselves (which past sessions show is the current pattern).

### S2 — Add a `cr threads --since <ref>` filter for re-run scenarios

CodeRabbit re-reviews on every push. A user re-running the skill wants to know which threads are *new since last time*. `cr threads --since HEAD~1` or `--since <last-bot-review-sha>` would return only the newly-created threads. Implementation: filter on `thread.created_at > <ref>`.

### S3 — Add a `cr resolve --bulk-fixed <sha>` for the autofix interleave

If `coderabbit:autofix` posted a fix in commit `<sha>` that closes 7 threads at once, the user wants to acknowledge those 7 threads inline (`Fixed in <sha>`) without a 7-prompt walk. A `cr resolve --bulk-fixed <sha> <thread-id>...` would post the same template-reply across all and mark them autonomously.

### S4 — Surface a "create Linear issue for this?" prompt on `out-of-scope`

Per evidence #5 and integration gap #2. Add a single optional prompt (also sticky-able) after the user picks `out-of-scope`:

> Track this in Linear (DD-)? `yes` (auto-create) / `copy-suggestion` (print `linear_create_issue` call for me to run) / `no`

The MCP `mcp__linear-server__save_issue` tool is already available in deepdock-mono sessions; for portability, the `copy-suggestion` mode just emits a markdown line the user can paste.

### S5 — Differentiate `bot-pushback` from `awaiting-third-party`

In sessions where a teammate replied on a CR thread alongside the bot, the existing `cr.label = bot-pushback` flag still fires (because the *bot* may have replied last, after the teammate). The triage should distinguish:
- `bot-pushback`: bot replied to a human reply
- `human-pushback`: a non-bot human reply weighs in on a CR thread

The skill currently treats all `bot-pushback` as "user judgment call". Adding `human-pushback` would let the skill at minimum *show* the teammate's reply verbatim and let the user decide whether to respond to the human or to CR.

### S6 — Track "acknowledged-but-not-yet-fixed" in the summary

After the run, if any thread received `Acknowledged — will fix in this PR` without a `fix-now`, list them in the terminal summary:

> Acknowledged-but-not-yet-fixed (1):
>   ▢ thread PRT_x — apps/api/src/scheduled.ts:80 — fix before re-running the skill

Helps the user not lose the half-promise across runs.

### S7 — Reduce the prompt count before the walk-through

Lines 175-195 ask two questions back-to-back (`walk?` then `RESOLVE_POLICY`). Combine into one `AskUserQuestion`:

> Open CodeRabbit threads on PR #N (table above). What now?
> - 🚶 Walk through, auto-close on agreement
> - 🚶 Walk through, ask me before closing
> - 🚶 Walk through, never auto-close
> - ⏭️ Skip all  ❌ Cancel

Five options, one prompt. The `auto-close` policy is the default-recommended branch; the other walk modes are still one click away.

---

*Generated 2026-05-12 by Claude Code from a retrospective scan of the user's past sessions.*
