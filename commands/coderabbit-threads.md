---
description: Walk through open CodeRabbit review threads on a PR. Auto-detects the current-branch PR, or asks if ambiguous.
argument-hint: "[pr-number-or-url]"
allowed-tools: "Bash(gh:*), Bash(cr:*), Bash(git:*)"
---

# CodeRabbit Threads — Review

Use the `coderabbit-threads` skill against the right PR. Pick the PR from the user's
argument when given; otherwise auto-detect from the current branch; otherwise ask.

## Context

- Current directory: !`pwd`
- Is a git repo: !`git rev-parse --is-inside-work-tree 2>/dev/null || echo "(not a git repo)"`
- Current branch: !`git branch --show-current 2>/dev/null || echo "(detached / not a repo)"`
- PR for current branch: !`gh pr view --json url,number,title --jq '"#\(.number) — \(.title) — \(.url)"' 2>/dev/null || echo "(no PR for this branch)"`
- Recent open PRs in this repo: !`gh pr list --state open --limit 5 --json number,title,headRefName,url --jq '.[] | "#\(.number) (\(.headRefName)): \(.title)"' 2>/dev/null || true`

## Instructions

**Argument supplied by the user:** $ARGUMENTS

### Step 1 — Resolve the PR URL

Decide which PR to walk through, in this order:

1. **If `$ARGUMENTS` is a full GitHub PR URL** (`https://github.com/<owner>/<repo>/pull/<n>`), use it directly.

2. **If `$ARGUMENTS` is a number** (e.g. `142`), treat it as a PR number on the current repo. Construct the URL using the current git remote:
   ```bash
   owner_repo=$(gh repo view --json owner,name --jq '.owner.login + "/" + .name')
   pr_url="https://github.com/${owner_repo}/pull/${ARGUMENTS}"
   ```

3. **If `$ARGUMENTS` is empty AND the Context block above shows a PR for the current branch**, use that PR's URL. Tell the user one line:
   > Walking PR #N — `<title>`

4. **If `$ARGUMENTS` is empty AND there is no PR for the current branch**:
   - Show the user the recent open PRs from the Context block.
   - Ask which one to walk through (numbered list; "Other" for a URL paste).
   - **Do not silently pick one.** Even if there's only one open PR, confirm.

5. **If the directory is not a git repo and no URL was given**, ask the user for a PR URL outright.

### Step 2 — Invoke the `coderabbit-threads` skill

Once the PR URL is resolved, **invoke the `coderabbit-threads` skill** with that PR. The skill handles everything from there: status pre-flight, fetch + triage, the walk-through loop, autonomous replies for the obvious cases, ask-once self-close policy, and polling for the bot's reaction.

Do not duplicate the skill's workflow inline. Your job in this command is only to land on the right PR.

### Edge cases

- **Closed/merged/draft PR:** the skill itself bails in its Step 3 pre-flight. Don't pre-check here — let the skill report.
- **CodeRabbit in progress:** same — the skill detects `cr status --plain` shows `bot reviewing` and bails with a retry hint.
- **No open threads on the PR:** the skill exits with "No open CodeRabbit threads." Surface that to the user.

### Quick reference for the user

- `/coderabbit-threads` — use the PR for the current branch
- `/coderabbit-threads 142` — explicit PR number on this repo
- `/coderabbit-threads https://github.com/owner/repo/pull/142` — explicit URL (works in any working directory)
