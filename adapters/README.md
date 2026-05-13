# Adapters — Tier-2 host wrappers

Thin wrapper files for hosts that don't natively load `SKILL.md`. Each wrapper sits in the host's expected location and points at the canonical runbook.

## How they work

1. **Vendor the runbook into your repo.** Copy `skills/coderabbit-threads/SKILL.md` from this plugin into your project as `.coderabbit-threads/SKILL.md`. (Or `git submodule add` the plugin and symlink.) The wrappers reference this path.

   ```bash
   # From your project root:
   mkdir -p .coderabbit-threads
   curl -sL https://raw.githubusercontent.com/tkoehlerlg/coderabbit-threads/main/skills/coderabbit-threads/SKILL.md \
     > .coderabbit-threads/SKILL.md
   curl -sL https://raw.githubusercontent.com/tkoehlerlg/coderabbit-threads/main/skills/coderabbit-threads/reference.md \
     > .coderabbit-threads/reference.md
   ```

2. **Drop the matching wrapper into your project.** Each subdirectory under `adapters/` mirrors the path the host expects:

   | Host | Wrapper path (copy as-is) |
   |---|---|
   | Windsurf | `adapters/windsurf/.windsurf/workflows/coderabbit-threads.md` → `<your-repo>/.windsurf/workflows/coderabbit-threads.md` |
   | Cline | `adapters/cline/.clinerules/10-coderabbit-threads.md` → `<your-repo>/.clinerules/10-coderabbit-threads.md` plus `adapters/cline/.clinerules/workflows/coderabbit-threads.md` → `<your-repo>/.clinerules/workflows/coderabbit-threads.md` |
   | Kilo Code | `adapters/kilo-code/.roomodes` → `<your-repo>/.roomodes` plus `adapters/kilo-code/.roo/rules-coderabbit-threads/01-runbook.md` → `<your-repo>/.roo/rules-coderabbit-threads/01-runbook.md` |
   | Continue.dev | `adapters/continue/coderabbit-threads.prompt` → `<your-repo>/.continue/prompts/coderabbit-threads.prompt` (or `~/.continue/prompts/`) |
   | Zed | `adapters/zed/.rules` — **inline only**, see below |

3. **Make `cr` callable.** Either symlink `bin/cr` from the plugin into a `$PATH` directory, or set `CR_BIN=<path-to>/coderabbit-threads/bin/cr` in your shell rc.

## Why not just `@`-reference the runbook?

We checked. The reference-syntax support varies:

| Host | Static `@`-include support | Strategy |
|---|---|---|
| Windsurf | No (`@` is chat-only; workflows have a 12 KB cap) | Wrapper instructs Cascade to `read_file .coderabbit-threads/SKILL.md` |
| Cline | No (`@` is chat-only; `.clinerules` are concatenated) | Wrapper instructs the agent to read `.coderabbit-threads/SKILL.md` |
| Kilo Code | No (rules are flat-concatenated into the mode body) | Wrapper instructs the agent to read `.coderabbit-threads/SKILL.md` |
| Continue.dev | **Yes** — Handlebars `{{{ ./path }}}` includes | Wrapper does `{{{ .coderabbit-threads/SKILL.md }}}` |
| Zed | No (docs: "you have to dump everything in one huge file") | Wrapper *instructs* the agent to read the vendored runbook, since the agent's tools can. |

The wrappers are written conservatively — every host's wrapper says "load and follow `.coderabbit-threads/SKILL.md`", which works whether the host supports static includes or only runtime tool reads.

## Updating the vendored runbook

When `coderabbit-threads` releases a new version, re-pull `.coderabbit-threads/SKILL.md` from the tag of your choice. The wrappers don't change between versions unless the runbook restructures.
