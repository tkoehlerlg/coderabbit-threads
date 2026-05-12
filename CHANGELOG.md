# Changelog

All notable changes to `coderabbit-threads` are tracked here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] — 2026-05-12

Post-release polish from a retrospective review of the user's past
CodeRabbit interactions. No CLI or workflow changes; documentation only.

### Fixed

- **Template contradiction.** `Acknowledged — will fix in this PR` and `Acknowledged — leaving as-is` previously appeared with the same prefix but opposite intents. Split into five distinct templates (`Fixed in <sha>`, `Will fix in this PR`, `Won't fix`, `Acknowledged — leaving as-is`, `Out-of-scope`) in both SKILL.md and the README.
- **README "What a run looks like" snippet** previously implied the agent already knows the fix SHA for `still-applies` threads. Updated to show the actual v0.1 flow (commit the fix yourself, re-run; the next pass labels it `likely-fixed` and posts `Fixed in <sha>` autonomously) and link to the v0.2 plan.

### Documented

- **v0.2 roadmap items** in the README:
  - Fix-then-reply for `still-applies` (delegate to `coderabbit:autofix` or apply the bot's diff, then commit + reply in one motion).
  - `cr threads --since <ref>` for skipping threads already handled in earlier review rounds.

## [0.1.0] — 2026-05-12

Initial release.

### Added

- `SKILL.md` — 8-step Claude Code workflow runbook for walking a PR's open CodeRabbit review threads.
- `bin/cr` — bash CLI wrapping GitHub GraphQL with normalized JSON output, full pagination, and the subcommands:
  - `cr threads <pr-url> [--filter open|all|unresolved|outdated|pushback]`
  - `cr context <pr-url> <thread-id> [--full]`
  - `cr reply   <pr-url> <thread-id> <body>`
  - `cr resolve <pr-url> <thread-id>`
  - `cr status  <pr-url> [--plain]`
  - `cr check   <pr-url> <thread-id> <our-comment-id>`
- `reference.md` — `cr` subcommand schemas, exit codes, computed label taxonomy.
- `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` — install via `/plugin marketplace add tkoehlerlg/coderabbit-threads`.
- `README.md` with workflow snippet, install paths, security model, and `autofix` comparison.

### Design choices in this release

- **Autonomous replies for the obvious cases** (`likely-fixed`, `out-of-scope`); the agent prompts only for `still-applies`, `unclear`, and `bot-pushback`. Installers expect the skill to handle threads, not play 20-questions.
- **Ask-once self-close policy.** The skill prompts once: auto-close on bot agreement, ask per thread, or never. Sticky-approvals reuse a `yes` for the rest of the run so big PRs don't become repetitive.
- **`resolved` label takes precedence over conversation-state labels.** A closed thread is historical record, not pushback — even when the bot's last comment came after the human's.
- **PR-state pre-flight bails.** `state == CLOSED|MERGED` or `is_draft == true` exits before fetching threads.
- **Cross-platform `date` parsing.** Works on macOS (BSD) and Linux (GNU).
- **License: MIT + Commons Clause v1.0.** Commercial use permitted; reselling the skill itself as a primary product is not.
