---
description: Walk through open CodeRabbit review threads on a PR. Auto-detects the current-branch PR, or asks if ambiguous.
argument-hint: "[pr-number-or-url]"
allowed-tools: "Bash(gh:*), Bash(cr:*), Bash(git:*)"
---

# CodeRabbit Threads — Review

This is a thin router. Resolve the PR URL, then invoke the `coderabbit-threads` skill with it. Do not restate the skill's workflow.

## Context (resolved silently)

- Argument: $ARGUMENTS
- Current branch PR: !`gh pr view --json url --jq .url 2>/dev/null || echo ""`
- Recent open PRs: !`gh pr list --state open --limit 5 --json number,headRefName,url --jq '.[] | "#\(.number) (\(.headRefName)) \(.url)"' 2>/dev/null || true`
- Repo: !`gh repo view --json owner,name --jq '.owner.login + "/" + .name' 2>/dev/null || echo ""`

## Resolve the URL

In order:

1. `$ARGUMENTS` is a full GitHub PR URL → use it.
2. `$ARGUMENTS` is numeric → `https://github.com/<repo>/pull/<arg>` from the Context block.
3. `$ARGUMENTS` empty AND a current-branch PR exists → use that.
4. `$ARGUMENTS` empty AND no current-branch PR → list the recent open PRs and ask which (or "Other" for a paste). Never silently pick.
5. Not in a git repo and no URL → ask for one.

## Invoke

Once the URL is resolved, **invoke the `coderabbit-threads` skill** with it. Stop here. The skill owns status pre-flight, triage, the walk-through loop, replies, and polling.
