# coderabbit-threads

[![Claude Code skill](https://img.shields.io/badge/Claude_Code-skill-D97757?logo=anthropic&logoColor=white)](https://docs.claude.com/en/docs/claude-code)
[![Works with CodeRabbit](https://img.shields.io/badge/CodeRabbit-companion-FF6B35)](https://coderabbit.ai)
[![Version](https://img.shields.io/github/v/tag/tkoehlerlg/coderabbit-threads?label=version&color=blue)](https://github.com/tkoehlerlg/coderabbit-threads/releases)

**A Claude Code skill that walks every open [CodeRabbit](https://coderabbit.ai) review thread on a PR and replies to each one conversationally.** Your agent triages each thread, fixes what it can and commits, pushes back when CodeRabbit is wrong, asks you only on judgment calls, and resolves only once CodeRabbit agrees. So you stop being the copy-paster between agent and bot.

This is the multi-round conversational counterpart to the official [`coderabbit:autofix`](https://github.com/coderabbitai/skills) skill, which applies proposed diffs and posts one summary comment. Reach for `coderabbit-threads` when you want to acknowledge, push back, or explicitly defer suggestions thread by thread.

---

## What a run looks like

Your agent goes through every open CodeRabbit thread, replies per-thread, and tracks CodeRabbit's reaction. It runs autonomously when the call is clear and pauses for you when it isn't.

```text
PR #142 · ready · last CodeRabbit activity 9m ago

4 open CodeRabbit threads on PR #142 …

  ✅  likely-fixed   1   already addressed in a follow-up commit …   auto-reply "Fixed in <sha>"
  📌  out-of-scope   1   touches another package …                   auto-reply "Out-of-scope"
  ⚠️   still-applies  1   concern still valid in the cited code …     fix-then-reply (auto) / asking you (together) …
  💬  bot-pushback   1   CodeRabbit replied to your last reply …     asking you …

| # | Triage        | Severity | Location                       | One-liner                       |
|---|---------------|----------|--------------------------------|---------------------------------|
| 1 | bot-pushback  | 🟠 HIGH  | apps/api/src/auth.ts:11        | Async call missing await        |
| 2 | still-applies | 🔴 CRIT  | apps/api/src/scheduled.ts:80   | One failure stops the batch     |
| 3 | likely-fixed  | 🟡 LOW   | apps/app/src/ui.tsx:88         | Use semantic button             |
| 4 | out-of-scope  | 🟡 LOW   | packages/db/src/migrate.ts:14  | Drop legacy column              |

How should I handle these?
  🤝 Together — pause on every judgment call
  🤖 Auto     — handle on my own, only ping for the hard cases
  ❌ Cancel
> auto

May I auto-resolve threads when CodeRabbit agrees?
  ✅ Yes, auto-close   🙋 Ask me each time   ❌ Never auto-close
> yes

— Thread 1/4 · bot-pushback · apps/api/src/auth.ts:11 ——————————
CodeRabbit replied after your last reply:
  > The await is still missing on line 12. Was the fix landed?

(needs your call — bot-pushback always pings, even in auto)
Reply: [fixed-in <sha>] [won't-fix <reason>] [out-of-scope] [skip]
> fixed-in 4af1c9d
Posted: "Fixed in 4af1c9d by adding await on subscribeAll."

— Thread 2/4 · still-applies · apps/api/src/scheduled.ts:80 ———
CodeRabbit says:  One failure in the batch aborts the rest — use Promise.allSettled.
Fix is in autonomous reach (one-file, mechanical, one plausible diff) — applying.
  ✏️  edited apps/api/src/scheduled.ts (Promise.all → Promise.allSettled)
  📦  committed 8c2a17e — bugfix(api): use allSettled in scheduled batch (CodeRabbit thread)
Posted: "Fixed in 8c2a17e by switching the batch from Promise.all to Promise.allSettled."

— Thread 3/4 · likely-fixed · apps/app/src/ui.tsx:88 ——————————
Posted (auto): "Fixed in 4af1c9d by switching <Button> to semantic markup."

— Thread 4/4 · out-of-scope · packages/db/src/migrate.ts:14 ——
Posted (auto): "Out-of-scope of this PR — should be tracked separately."

Polling for CodeRabbit reactions (every 60s, up to 5 min):
  ✅ PRT_a — CodeRabbit agreed, auto-resolved
  ✅ PRT_b — CodeRabbit agreed, auto-resolved
  ⏳ PRT_c — no reaction yet
  🔁 PRT_d — CodeRabbit pushed back, will surface on next run

Handled 4 threads. Posted 4 replies (3 autonomous, 1 user-chosen).
1 commit pushed during the run (8c2a17e — still-applies fix).
2 closed on CodeRabbit agreement; 2 still open.
```

---

## Installation

### Via Claude Code plugin marketplace

```text
/plugin marketplace add tkoehlerlg/coderabbit-threads
/plugin install coderabbit-threads@coderabbit-threads
/reload-plugins
```

The repo ships a single-plugin `.claude-plugin/marketplace.json` so the `/plugin marketplace add` slash command points at this repo directly. After install, Claude Code will discover the skill the next time you ask it to handle a PR's CodeRabbit threads.

The `coderabbit-threads@coderabbit-threads` ID isn't a typo. Claude Code plugin IDs are `<plugin-name>@<marketplace-name>`, and this is a single-plugin marketplace where both names happen to be the same.

### Manual install

Clone into your `~/.claude/skills/` directory:

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/tkoehlerlg/coderabbit-threads.git ~/.claude/skills/coderabbit-threads-repo
ln -s ~/.claude/skills/coderabbit-threads-repo/skills/coderabbit-threads \
       ~/.claude/skills/coderabbit-threads
chmod +x ~/.claude/skills/coderabbit-threads/bin/cr
```

Verify Claude Code can see it:

```bash
ls ~/.claude/skills/coderabbit-threads/SKILL.md
~/.claude/skills/coderabbit-threads/bin/cr --help 2>&1 | head
```

Then in a Claude Code session:

```text
/skills
```

`coderabbit-threads` should appear in the list. Invoke it by asking, for example:

> Go through the open CodeRabbit threads on this PR.

Or use the bundled slash command:

```text
/coderabbit-threads                                       # current-branch PR
/coderabbit-threads 142                                   # explicit PR number on this repo
/coderabbit-threads https://github.com/owner/repo/pull/14 # explicit URL
```

If the current branch has no PR, the command lists recent open PRs and asks which one to review. It never silently guesses.

### Other agent runtimes

The `cr` CLI is plain bash + `gh` + `jq`, so it runs anywhere. The skill *runbook* (SKILL.md) is platform-aware but degrades to portable shell-only behavior when host primitives aren't available.

| Runtime | Status | How to install |
|---------|--------|----------------|
| **Claude Code** | Verified | Plugin marketplace (above). `AskUserQuestion`, `ScheduleWakeup`, the `/coderabbit-threads` slash command, and sticky approvals all work natively. |
| **Copilot CLI** | Expected to work (not yet verified) | Manual install, then ask "go through CodeRabbit threads on this PR". Activation goes through the standard `skill` tool + trigger phrases. The skill detects missing `ScheduleWakeup` and falls back to "re-run in ~2 min" polling. |
| **Codex CLI** | Expected to work (not yet verified) | Same as Copilot CLI: manual install + trigger phrase. Uses Codex's `Skill` tool equivalents. |
| **Gemini CLI** | Expected to work (not yet verified) | Manual install + `activate_skill`. Tool name mapping uses superpowers-style `GEMINI.md` if one exists in your repo. |
| **Other / bare `cr` use** | Always works | Most of the value lives in `cr` itself. `cr threads`, `cr context`, `cr proposed-fix`, `cr reply`, `cr resolve` are all callable from any shell once `gh` is authenticated. The SKILL.md runbook is the choreography on top, and you can also follow it by hand. |

What's Claude-Code-only:

- `AskUserQuestion` interactive prompts → fallback: numbered list with stdin prompt.
- `ScheduleWakeup` 60s polling → fallback: print "re-run in ~2 min to check CodeRabbit's reactions" and exit.
- `/coderabbit-threads` slash command → fallback: ask "go through CodeRabbit threads".

The triage logic, the `MODE` (together/auto) gate, the `RESOLVE_POLICY` gate, sticky approvals, fix-then-reply, `cr proposed-fix`, and `--since <ref>` all work the same on every runtime.

### Requirements

- [`gh`](https://cli.github.com/) (GitHub CLI), authenticated: `gh auth status` must succeed
- [`jq`](https://jqlang.github.io/jq/) on `PATH`
- `bash` 3.2+ (the macOS system bash works fine; the script avoids bash-4-only features)
- An open PR on the current branch with at least one CodeRabbit review thread

No tokens, no extra config. `cr` uses whatever `gh auth login` configured.

---

## How it works

The skill follows an 8-step workflow. The full runbook is in [`skills/coderabbit-threads/SKILL.md`](skills/coderabbit-threads/SKILL.md); condensed:

| # | Step              | Purpose                                                              |
|---|-------------------|----------------------------------------------------------------------|
| 0 | Load conventions  | Read repo `AGENTS.md` / `CLAUDE.md` for commit / issue-tracker style |
| 1 | Verify push state | Warn on uncommitted or unpushed work CodeRabbit hasn't reviewed         |
| 2 | Resolve PR        | Find the current branch's PR, or offer to create one                 |
| 3 | Check CodeRabbit status  | Bail if PR is merged, closed, draft, or CodeRabbit is still working  |
| 4 | Triage threads    | Label each open thread: `bot-pushback`, `still-applies`, `likely-fixed`, `unclear`, `out-of-scope` |
| 5 | Confirm + policy  | Show compact table; ask **together vs auto**; ask self-close policy (auto / ask / never) |
| 6 | Per-thread loop   | Autonomous for `likely-fixed` / `out-of-scope` (both modes); **fix-then-reply** for `still-applies` in auto mode (or `fix-now` in together mode); high-confidence `contested` posts `Won't fix` autonomously; ask user for `unclear` / `bot-pushback` always |
| 7 | Poll for reaction | Check whether CodeRabbit agreed with each reply; apply self-close policy on agreement |
| 8 | Summary           | Terminal-only summary. **No PR-level comment is ever posted.**        |

All GitHub API interaction goes through the bundled `cr` CLI. The skill never constructs raw GraphQL inline.

---

## Why it exists

**TL;DR.**

- A 20-thread CodeRabbit review eats an hour of human time even when most of the threads are mechanical or already addressed.
- The skill walks each thread, replies factually (`Fixed in <sha>`, `Won't fix: <reason>`, `Out-of-scope`), and waits for CodeRabbit to react before resolving.
- In **auto** mode it actually fixes `still-applies` threads in code, commits, and replies. No placeholder "Will fix" promises.
- It **pushes back** when CodeRabbit is technically wrong (`contested`) instead of folding.
- It **asks you only** on the genuine judgment calls (`unclear`, `bot-pushback`, low-confidence `contested`).
- It detects when CodeRabbit has been paused on a PR and lets you resume, run a one-time review, or skip straight to existing threads.

**The friction point this fixes.** Most coding agents don't push back on CodeRabbit themselves. They apply whatever it suggests or punt the decision back to you, which turns *you* into the copy-paster between bot and code: evaluating each claim, dictating each reply, then pasting it back. You're a developer, not a relay. `coderabbit-threads` evaluates CodeRabbit's claims the way you would, fixes what's worth fixing, and pushes back when the bot is wrong, so you only weigh in on the genuine judgment calls.

CodeRabbit reads a PR, posts a review with N threads (sometimes 20+), and then waits. The typical human flow is:

1. Scan all threads, decide which are worth acting on.
2. Fix the worthwhile ones in code.
3. Reply on each thread explaining what happened (`Fixed in <sha>`, `Won't fix because <reason>`, `Out of scope`).
4. Wait for CodeRabbit to react and resolve threads it agrees with.

Steps 3 and 4 are where this skill lives. It is intentionally narrow:

- **Per-thread replies, not a bulk PR comment.** Resolving a thread means reacting to *that* thread. A PR-level summary comment doesn't move state.
- **Wait for CodeRabbit before resolving.** Auto-resolving on reply means CodeRabbit can't push back inline.
- **Reply factually, not persuasively.** Short statements (`Fixed in <sha>`, `Won't fix: <reason>`) end the conversation. Multi-paragraph defenses invite multi-paragraph pushback.
- **Don't give in too quickly.** When the agent reads a thread, it evaluates CodeRabbit's *claim*, not just whether the code changed. If CodeRabbit looks technically wrong (claims a missing `await` on a sync call, flags a race condition on a single-writer path), the thread gets labelled `contested`. The agent then surfaces both sides briefly and asks you to decide, with a pre-filled `Won't fix: <one-line reason>` template ready to send.
- **Two modes: together or auto.** Every run starts with one question. Do you want to handle threads *together*, pausing on every judgment call? Or have the agent run on its own and ping you only when it truly needs guidance? In auto mode the agent **fixes `still-applies` threads in code**. It reads the cited file plus CodeRabbit's proposed-fix diff, applies the change, commits, and posts `Fixed in <sha>`. On `contested` threads where the disagreement is solid, it posts a confident `Won't fix: <one-line technical reason>`. It still pings you on `unclear`, `bot-pushback`, low-confidence `contested`, and any `still-applies` thread that doesn't fit single-file mechanical reach. Those are the cases where the call genuinely isn't the agent's to make.
- **One consent gate for auto-close.** After the mode choice, the skill asks once whether it may auto-resolve threads CodeRabbit agrees with. Closing is the one irreversible action from your perspective, so it gets its own gate.
- **Sticky approvals.** Every time you say `yes` to a prompt (close this thread, use this reply template), the skill follows up with "use this for the rest of the run?". One `yes` then becomes the default for every remaining thread, so a 20-thread PR doesn't turn into 20 identical prompts.

Distinct from `coderabbit:autofix`. That skill applies code changes from CodeRabbit's suggested diffs and posts one summary comment. The two compose: run `autofix` to apply, then `coderabbit-threads` to converse.

---

## The `cr` CLI

`cr` is a bash CLI shipped at `skills/coderabbit-threads/bin/cr`. It wraps `gh api` (REST + GraphQL) with pagination, filtering, and normalized JSON output. The skill itself never builds GraphQL; only `cr` does.

| Subcommand                                         | Purpose                                                       |
|----------------------------------------------------|---------------------------------------------------------------|
| `cr threads <pr-url> [--filter <f>] [--since <ref>]` | List CodeRabbit threads on a PR (paginated, normalized JSON). `--since <ref>` drops threads older than a commit SHA / ISO timestamp / duration (`24h`, `7d`, `1w`). |
| `cr context <pr-url> <thread-id> [--full]`         | Emit a markdown block of one thread's context and how to reply |
| `cr proposed-fix <pr-url> <thread-id>`             | Extract just CodeRabbit's `<details><summary>Proposed fix</summary>` diff (no surrounding markdown). Used by the fix-then-reply path. |
| `cr reply   <pr-url> <thread-id> <body>`           | Post a markdown reply on a thread                             |
| `cr resolve <pr-url> <thread-id>`                  | Mark a thread resolved (idempotent)                           |
| `cr status  <pr-url> [--plain]`                    | PR state + CodeRabbit activity summary (incl. `mode`, `paused_reason`, `pr_author`, `human_open_thread_count`) |
| `cr check   <pr-url> <thread-id> <our-comment-id>` | Did CodeRabbit reply after `our-comment-id`? Returns awaiting / bot_replied |
| `cr resume <pr-url>` / `cr review <pr-url>` / `cr full-review <pr-url>` | Post `@coderabbitai resume` / `review` / `full review` as a PR comment (auto-runnable). Used by the paused-mode pre-flight dialog. |
| `cr resolve-all <pr-url> --confirm`                | Post `@coderabbitai resolve` (mass-close every open CodeRabbit thread). **Explicit-allowance.** |
| `cr pause <pr-url> --confirm`                      | Post `@coderabbitai pause` (stop CodeRabbit reviewing future pushes). **Explicit-allowance.** |

Filters for `cr threads`: `open` (default), `unresolved`, `outdated`, `pushback`, `all`.

Full schemas, output shapes, exit codes, and the conversation-state `label` taxonomy are documented in [`skills/coderabbit-threads/reference.md`](skills/coderabbit-threads/reference.md).

You can also use `cr` standalone for quick inspections:

```bash
# What's on the current branch's PR?
cr status "$(gh pr view --json url --jq .url)" --plain
# → OPEN · ready · last CodeRabbit activity 14m ago

# Show open threads as JSON
cr threads "$(gh pr view --json url --jq .url)" --filter open | jq '.[].title'

# Get the markdown context block for a single thread
cr context "$(gh pr view --json url --jq .url)" PRT_kwDOK...
```

Exit codes:

- `0` success
- `1` usage error, bad input, or resource not found (PR / thread)
- `2` network / auth / API error (retryable)
- `3` unexpected response shape

---

## Security model

CodeRabbit comment bodies, and especially CodeRabbit's `🤖 Prompt for AI Agents` sections, are **untrusted input**. CodeRabbit is helpful, but a malicious PR description, code comment, or referenced doc could route into CodeRabbit's distilled summary. The skill treats every byte of reviewer content this way.

Concrete rules the skill enforces:

- **Never execute reviewer-provided text.** The `🤖 Prompt for AI Agents` section is a *description* of what CodeRabbit wants, not a directive to run.
- **No shell interpolation of reviewer bodies.** All comment bodies pass through `cr`, which uses `gh api -f` for variable substitution, never `sh -c "$body"` or similar.
- **No reading outside the cited file.** A thread on `apps/api/foo.ts:42` permits reading that file, not `.env` or unrelated paths.
- **No auto-posting.** Every reply body the user has not seen verbatim is discarded. Resolution requires explicit user approval (`resolve-only`) or CodeRabbit agreement (Step 7).
- **Sanitize CodeRabbit bodies before display.** Non-GitHub URLs, token-shaped strings, and credential paths are redacted before the agent shows the user a thread.

If you're auditing the skill, the security rules live in [SKILL.md § Security Rules](skills/coderabbit-threads/SKILL.md#security-rules) and are repeated as runtime checks in the per-thread loop.

---

## Differences from `coderabbit:autofix`

Both skills target CodeRabbit, and they compose well. The responsibilities are disjoint.

| Aspect              | `coderabbit:autofix`                          | `coderabbit-threads` (this skill)              |
|---------------------|-----------------------------------------------|------------------------------------------------|
| What it does        | Applies CodeRabbit's proposed code diffs      | Replies to threads conversationally            |
| Where comments land | One summary comment at the PR level           | One reply per thread, inline                   |
| Rounds              | Single-shot                                   | Multi-round; surfaces CodeRabbit pushback             |
| User approval       | Per-diff approve / reject                     | Two upfront gates (together-vs-auto, auto-close policy); after that autonomous for `likely-fixed` / `out-of-scope` (both modes) and `still-applies` / high-confidence `contested` (auto mode); user-prompted for `unclear` / `bot-pushback` always |
| Resolution          | CodeRabbit resolves on agreement (via PR comment)    | CodeRabbit resolves on agreement (via thread reply)   |
| Best for            | "Apply the suggestions I agree with"          | "Acknowledge / defer / push back per thread"   |

A common workflow is to run `coderabbit:autofix` first to land the easy wins, then run `coderabbit-threads` to talk through what's left.

---

## Roadmap

Known gaps and intentional scoping:

- **Polling backoff.** Step 7 polls at a fixed 60s interval up to 5 min. Adaptive backoff (start fast, slow down) is a future improvement.
- **No auto-created issues.** When the user marks a thread `out-of-scope`, the reply notes it but no Linear/Jira/GitHub issue is created. Users do that themselves; the skill stays narrow.
- **Other agent runtimes, verification pending.** The skill is structured to work on Copilot CLI, Codex CLI, and Gemini CLI (see [Other agent runtimes](#other-agent-runtimes)), but Claude Code is the only runtime currently end-to-end verified. PRs adding verified-on-X badges welcome.

---

## Contributing

Issues and PRs welcome at <https://github.com/tkoehlerlg/coderabbit-threads>.

If you're proposing a change to the per-thread loop or to `cr`'s output shape, please run through a real PR end-to-end first. Synthetic mocks of CodeRabbit's GraphQL response miss enough quirks to be misleading.

The skill itself is described, in its entirety, in:

- [`skills/coderabbit-threads/SKILL.md`](skills/coderabbit-threads/SKILL.md) — the runbook Claude Code reads
- [`skills/coderabbit-threads/reference.md`](skills/coderabbit-threads/reference.md) — `cr` CLI subcommand schemas
- [`skills/coderabbit-threads/bin/cr`](skills/coderabbit-threads/bin/cr) — the CLI itself

---

## License

[MIT with Commons Clause](LICENSE) © 2026 Torben Köhler.

In short:

- **Commercial use is OK**, including inside paid products, internal tooling, consulting engagements, and forks shipped for free under the same terms.
- **You may not resell the skill itself** as a primary product. No charging for access to this skill (or a thin wrapper around it) where the customer's payment value derives, entirely or substantially, from this skill's functionality.
- **Attribution required.** The copyright notice and license (including the Commons Clause condition) must be preserved in all copies and substantial portions.
- **No warranty, no liability.** Provided "AS IS".

The full text and exact terms are in [LICENSE](LICENSE). This README summary is informational, not binding; consult a lawyer if your use case sits near the line.
