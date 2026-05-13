# coderabbit-threads

[![Claude Code skill](https://img.shields.io/badge/Claude_Code-skill-D97757?logo=anthropic&logoColor=white)](https://docs.claude.com/en/docs/claude-code)
[![Works with CodeRabbit](https://img.shields.io/badge/CodeRabbit-companion-FF6B35)](https://coderabbit.ai)
[![Version](https://img.shields.io/github/v/tag/tkoehlerlg/coderabbit-threads?label=version&color=blue)](https://github.com/tkoehlerlg/coderabbit-threads/releases)

**A Claude Code skill that walks every open [CodeRabbit](https://coderabbit.ai) review thread on a PR and replies to each one conversationally.** Your agent triages each thread, fixes what it can and commits, pushes back when CodeRabbit is wrong, asks you only on judgment calls, and resolves only once CodeRabbit agrees. So you stop being the copy-paster between CodeRabbit and your agent.

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

```text
/plugin marketplace add tkoehlerlg/coderabbit-threads
/plugin install coderabbit-threads@coderabbit-threads
/reload-plugins
```

Then trigger it via natural language ("Go through the open CodeRabbit threads on this PR.") or `/coderabbit-threads`. Requires [`gh`](https://cli.github.com/) (authenticated) and [`jq`](https://jqlang.github.io/jq/) on `PATH`.

Full install paths — manual clone, Cursor, Copilot CLI / VS Code, Codex CLI, Gemini CLI, Windsurf, Cline, Kilo Code, Continue.dev, Zed Agent Panel, Aider, and the primitive-fallback matrix — are in [`INSTALLATION.md`](INSTALLATION.md).

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

**The friction point.** Most coding agents don't push back on CodeRabbit themselves. They apply whatever it suggests or punt the decision back to you, which turns *you* into the copy-paster between CodeRabbit and your agent: reading each claim, deciding whether to act, dictating each reply, then handing it back. You're a developer, not a relay.

`coderabbit-threads` evaluates each thread's *claim* (not just whether the code changed), fixes what's worth fixing in code, pushes back with a `Won't fix: <reason>` when CodeRabbit is technically wrong, and only asks you on the genuine judgment calls (`unclear`, `bot-pushback`, low-confidence `contested`). It posts per-thread replies (never a single PR-level summary), waits for CodeRabbit to react before resolving, and one upfront consent gate decides whether you want to drive each thread (`together`) or let the agent run autonomously (`auto`). Sticky approvals collapse 20 identical prompts into one.

Distinct from `coderabbit:autofix`, which applies CodeRabbit's suggested diffs and posts one summary comment. The two compose — run `autofix` to apply, then `coderabbit-threads` to converse.

---

## The `cr` CLI

A bash CLI at [`bin/cr`](bin/cr) (plugin root) wraps `gh api` with pagination, filtering, and normalized JSON output. Subcommands: `threads`, `context`, `proposed-fix`, `reply`, `resolve`, `status`, `check`, plus PR-level `resume` / `review` / `full-review` / `resolve-all` / `pause`. The plugin loader puts `bin/` on `$PATH`, so `cr` is callable as a bare command and standalone-usable.

Full subcommand signatures, schemas, filters, exit codes, and the conversation-state `label` taxonomy live in [`skills/coderabbit-threads/reference.md`](skills/coderabbit-threads/reference.md). Run `cr --help` for the quick reference.

---

## Security

Every byte of CodeRabbit content — comment bodies, the `🤖 Prompt for AI Agents` section, proposed-fix diffs — is treated as **untrusted input**. The skill never executes reviewer text, never shell-interpolates it, reads only the cited file, and posts replies only from a fixed template. Full rules in [SKILL.md § Security Rules](skills/coderabbit-threads/SKILL.md#security-rules).

---

## Contributing

Issues and PRs welcome at <https://github.com/tkoehlerlg/coderabbit-threads>. Changes to the per-thread loop or `cr`'s output shape need an end-to-end real-PR run; synthetic CodeRabbit GraphQL mocks miss too many quirks.

Source of truth: [`SKILL.md`](skills/coderabbit-threads/SKILL.md) (runbook), [`reference.md`](skills/coderabbit-threads/reference.md) (`cr` schemas), [`bin/cr`](bin/cr) (the CLI).

---

## License

[MIT with Commons Clause](LICENSE) © 2026 Torben Köhler.

Commercial use is fine; reselling the skill itself as a primary product is not. Full terms in [LICENSE](LICENSE).
