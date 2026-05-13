# Installation

`coderabbit-threads` is built as a Claude Code plugin. Claude Code is the only fully verified runtime, but the skill is structured to work on most agent hosts that load `SKILL.md` files. This document covers every supported install path.

## Requirements

- [`gh`](https://cli.github.com/) (GitHub CLI), authenticated: `gh auth status` must succeed
- [`jq`](https://jqlang.github.io/jq/) on `PATH`
- `bash` 3.2+ (macOS system bash is fine; the script avoids bash-4-only features)
- An open PR on the current branch with at least one CodeRabbit review thread

No tokens, no extra config. `cr` uses whatever `gh auth login` configured.

## Claude Code — plugin marketplace (recommended)

```text
/plugin marketplace add tkoehlerlg/coderabbit-threads
/plugin install coderabbit-threads@coderabbit-threads
/reload-plugins
```

The repo ships a single-plugin `.claude-plugin/marketplace.json` so `/plugin marketplace add` points at this repo directly. After install, Claude Code discovers the skill on next invocation, and the plugin loader puts `bin/cr` on `$PATH` automatically.

The `coderabbit-threads@coderabbit-threads` ID isn't a typo. Claude Code plugin IDs are `<plugin-name>@<marketplace-name>`, and this is a single-plugin marketplace where both names happen to be the same.

Verify the install:

```text
/skills
```

`coderabbit-threads` should appear in the list. Invoke it via natural language ("Go through the open CodeRabbit threads on this PR.") or the bundled slash command:

```text
/coderabbit-threads                                       # current-branch PR
/coderabbit-threads 142                                   # explicit PR number on this repo
/coderabbit-threads https://github.com/owner/repo/pull/14 # explicit URL
```

If the current branch has no PR, the command lists recent open PRs and asks which one to review. It never silently guesses.

## Claude Code — manual install (git clone)

For development on the skill itself, or to pin to a fork:

```bash
# 1. Clone the repo wherever you like
git clone https://github.com/tkoehlerlg/coderabbit-threads.git ~/code/coderabbit-threads

# 2. Symlink the skill dir into ~/.claude/skills/ so Claude Code discovers SKILL.md
mkdir -p ~/.claude/skills
ln -s ~/code/coderabbit-threads/skills/coderabbit-threads \
      ~/.claude/skills/coderabbit-threads

# 3. Make `cr` callable. Either symlink into a PATH directory:
mkdir -p ~/.local/bin
ln -s ~/code/coderabbit-threads/bin/cr ~/.local/bin/cr

# …or set CR_BIN in your shell rc (the skill honors it):
export CR_BIN=~/code/coderabbit-threads/bin/cr
```

Since v0.4.0 the binary lives at `<plugin-root>/bin/cr` — outside the skill directory. The plugin marketplace install auto-PATHs it; manual installs need either a symlink into a PATH dir or `CR_BIN`.

Verify:

```bash
ls ~/.claude/skills/coderabbit-threads/SKILL.md
cr --help 2>&1 | head        # if you symlinked into ~/.local/bin
"$CR_BIN" --help 2>&1 | head  # if you set CR_BIN
```

## Other agent runtimes

The `cr` CLI is plain bash + `gh` + `jq`, so it runs anywhere. The skill *runbook* (`SKILL.md`) is platform-aware but degrades to portable shell-only behavior when host primitives aren't available.

Targets below are grouped by integration shape. Tier 1 hosts ship a native Agent Skills system that loads `SKILL.md` directly. Tier 2 hosts need a thin wrapper file that references the runbook. Tier 3 is phrase-driven only. Only Claude Code is end-to-end verified; everything else is a documented install path, and PRs adding verified-on-X badges are welcome.

For every Tier 1 host other than Claude Code, `bin/cr` is **not** auto-added to `$PATH`. Either symlink `cr` into a PATH directory at install time, or set `CR_BIN=<plugin-root>/bin/cr` in your shell rc. The skill already honors `CR_BIN`.

### Tier 1 — native Agent Skills (drop-in)

| Runtime | Install path | Activation | Notes |
|---|---|---|---|
| **Claude Code** | Plugin marketplace, or `~/.claude/skills/coderabbit-threads/` | `/coderabbit-threads`, or natural language | All four primitives (`AskUserQuestion`, `ScheduleWakeup`, sticky approvals, slash command) work natively. Only fully verified runtime. |
| **Cursor 2.4+** | `~/.cursor/skills/coderabbit-threads/`, or repo `.cursor/skills/coderabbit-threads/` | `/coderabbit-threads`, or natural language | Same `SKILL.md` shape. No in-IDE `ScheduleWakeup`; Step 7 falls back to "re-run in ~2 min", with an optional Cursor Automation cron as a power-user upgrade. Use Auto-Run mode **Sandbox** or **Ask Every Time**. |
| **Copilot CLI** | `~/.claude/skills/coderabbit-threads/` (Copilot reads `.claude/skills/` natively), or `~/.copilot/skills/coderabbit-threads/` | `/coderabbit-threads`, or natural language | Pre-approve shell calls with `copilot --allow-tool='shell(cr),shell(gh),shell(jq)'` to avoid per-command prompts. |
| **Copilot Chat (VS Code agent mode)** | repo `.claude/skills/coderabbit-threads/`, or `~/.claude/skills/coderabbit-threads/` | `/coderabbit-threads`, or natural language | Same skill system as Copilot CLI; runs in the local workspace so `gh auth status` carries over. |
| **Codex CLI** | `~/.codex/skills/coderabbit-threads/`, or repo `.agents/skills/coderabbit-threads/` | `$coderabbit-threads`, `/skills` picker, or natural language | Recommended posture is `--sandbox workspace-write --ask-for-approval on-request`. |
| **Gemini CLI** | `~/.gemini/skills/coderabbit-threads/`, or `gemini extensions install …` | `/skills`, `activate_skill`, or an optional `.gemini/commands/coderabbit-threads.toml` slash binding | Add `cr` / `gh` / `git` to `tools.allowed` in `~/.gemini/settings.json` to skip per-call prompts. |

### Tier 2 — workflow / rule-file adapter (clean fit, thin wrapper)

These runtimes have their own runbook format. **Drop-in wrappers ship at [`adapters/`](adapters/)** — one per host, mirrored under the path the host expects. Each wrapper is a thin pointer that instructs the host agent to read the vendored `SKILL.md` at runtime (or, for Continue.dev, transcludes it via Handlebars). See [`adapters/README.md`](adapters/README.md) for the one-time vendoring step (`SKILL.md` and `reference.md` go into `<your-repo>/.coderabbit-threads/`).

| Runtime | Copy adapter | To repo path | Activation | Notes |
|---|---|---|---|---|
| **Windsurf** | [`adapters/windsurf/.windsurf/workflows/coderabbit-threads.md`](adapters/windsurf/.windsurf/workflows/coderabbit-threads.md) | `.windsurf/workflows/coderabbit-threads.md` | `/coderabbit-threads` | Frontmatter `auto_execution_mode: 3`. Wrapper instructs Cascade to `read_file .coderabbit-threads/SKILL.md` at runtime (no static `@`-include for workflows). Add `cr` to `cascadeCommandsAllowList`. |
| **Cline** (rule) | [`adapters/cline/.clinerules/10-coderabbit-threads.md`](adapters/cline/.clinerules/10-coderabbit-threads.md) | `.clinerules/10-coderabbit-threads.md` | (always-loaded) | Numeric `10-` prefix orders it after lower-numbered rules in Cline's alphanumeric concat. |
| **Cline** (workflow) | [`adapters/cline/.clinerules/workflows/coderabbit-threads.md`](adapters/cline/.clinerules/workflows/coderabbit-threads.md) | `.clinerules/workflows/coderabbit-threads.md` | `/coderabbit-threads.md` | Per-permission auto-approve (Edit / Execute) maps onto the skill's `MODE=auto` gate. No 60s scheduler. |
| **Kilo Code** (mode) | [`adapters/kilo-code/.roomodes`](adapters/kilo-code/.roomodes) | `.roomodes` | Mode switch | Roo Code's successor — Roo archives 2026-05-15. No user-defined slash commands; pick the mode from the selector, or trigger by phrase. |
| **Kilo Code** (rule) | [`adapters/kilo-code/.roo/rules-coderabbit-threads/01-runbook.md`](adapters/kilo-code/.roo/rules-coderabbit-threads/01-runbook.md) | `.roo/rules-coderabbit-threads/01-runbook.md` | (auto with mode) | Flat-concatenated into the mode body when the mode is active. |
| **Continue.dev** | [`adapters/continue/coderabbit-threads.prompt`](adapters/continue/coderabbit-threads.prompt) | `.continue/prompts/coderabbit-threads.prompt` (or `~/.continue/prompts/`) | `/coderabbit-threads` | The only Tier-2 host with native static includes — wrapper uses Handlebars `{{{ .coderabbit-threads/SKILL.md }}}` to transclude the runbook directly. Set `run_terminal_command` to `Automatic` for sticky-style approval. |
| **Zed Agent Panel** | [`adapters/zed/.rules`](adapters/zed/.rules) | `.rules` (repo root) | `@coderabbit-threads` plus trigger phrase | Zed has no rule-file include syntax, so the wrapper *instructs* the agent to `read_file` the vendored runbook. Use the **Write** profile (terminal tool enabled). `agent.tool_permissions` rule `always_allow ^cr ` gives sticky approval for `cr` calls. |

### Tier 3 — phrase-driven (degraded UX)

| Runtime | Host file | Activation | Notes |
|---|---|---|---|
| **Aider** | `read: SKILL.md` in `.aider.conf.yml`; shell-out via `/run cr …` | Phrase only ("walk the CodeRabbit threads on this PR") | No slash registry, no structured prompts, no scheduler. Aider's single-conversation edit-centric model fights the per-thread loop, but the path works. |

### Not currently supported

- **Copilot coding agent (cloud).** Firewalled sandbox, `copilot/*`-branch-only commits, no interactive Q/A, no path for replying on a human's PR threads. The cloud surface is the wrong tool for this job; `coderabbit:autofix` covers that lane.
- **Roo Code.** RooCodeInc/Roo-Code archives 2026-05-15. Migrate to Kilo Code (above), which inherits the same custom-modes + `.roo/rules-{slug}/` model.

### Bare `cr` use — always works

Most of the value lives in `cr` itself. `cr threads`, `cr context`, `cr proposed-fix`, `cr reply`, `cr resolve` are all callable from any shell once `gh` is authenticated. The `SKILL.md` runbook is the choreography on top, and you can also follow it by hand.

### Primitive-fallback summary

What's missing on hosts outside Claude Code, and how the skill compensates:

- `AskUserQuestion` → numbered list with stdin / chat prompt.
- `ScheduleWakeup` 60s polling → print "re-run in ~2 min to check CodeRabbit's reactions" and exit.
- `/coderabbit-threads` slash command → native on most Tier 1 / Tier 2 hosts; otherwise a natural-language trigger.

The triage logic, the `MODE` (together/auto) gate, the `RESOLVE_POLICY` gate, sticky approvals, fix-then-reply, `cr proposed-fix`, and `--since <ref>` all work the same on every runtime.
