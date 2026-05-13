# /coderabbit-threads

Walk the current PR's open CodeRabbit review threads — triage each, reply per-thread, and wait for CodeRabbit's reaction before resolving.

## Steps

1. Read the runbook at `.coderabbit-threads/SKILL.md` (vendored from the `coderabbit-threads` plugin). Read `.coderabbit-threads/reference.md` for the `cr` CLI schemas if you need them.
2. Resolve the PR URL — from `$ARGUMENTS` (a number, a full URL, or empty), or from `gh pr view --json url --jq .url` for the current branch. Never silently guess.
3. Follow the runbook's 8-step workflow against that PR. The runbook owns status pre-flight, triage, the per-thread loop, the two consent gates (`MODE` and `RESOLVE_POLICY`), sticky approvals, fix-then-reply autonomy, and polling.
4. Use `cr` for all GitHub API interaction. It must be callable as a bare command (symlinked into `$PATH`) or invoked via `CR_BIN`.

## Notes

- The runbook is too large for a Cline workflow to inline; this wrapper exists only to invoke it from a slash command.
- Cline has no built-in 60s scheduler. The runbook's Step 7 falls back to "re-run in ~2 min to check CodeRabbit's reactions" automatically.
