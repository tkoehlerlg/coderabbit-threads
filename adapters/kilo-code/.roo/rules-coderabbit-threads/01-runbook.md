# Runbook pointer (Kilo Code, mode: coderabbit-threads)

When invoked in this mode, read the runbook at `.coderabbit-threads/SKILL.md` and follow its 8-step workflow end to end. Read `.coderabbit-threads/reference.md` for the `cr` CLI schemas if you need them.

The runbook owns:

- Status pre-flight (bail on merged / closed / draft / in-progress PRs)
- Triage labels (`bot-pushback`, `still-applies`, `likely-fixed`, `unclear`, `contested`, `out-of-scope`)
- The per-thread loop
- The `MODE` consent gate (`together` / `auto` / `summary-only`)
- The `RESOLVE_POLICY` consent gate (`auto` / `ask` / `never`)
- Sticky approvals
- Fix-then-reply autonomy criteria
- Polling for CodeRabbit's reaction

This file is a *pointer*, not the runbook itself. Don't try to inline-reproduce the runbook here — Kilo concatenates `.roo/rules-{slug}/*.md` files into the mode body, and the runbook is too long for that to be productive. Read the canonical file.

## Why `read_file` rather than an `@`-include

Kilo's rules system has no static `@`-include directive — rules are flat-concatenated. So the wrapper instructs the agent (you) to read the runbook at runtime via the `read` tool. This keeps each layer at its right scope.
