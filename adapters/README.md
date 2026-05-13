# Adapters — Tier-2 host wrappers

Thin wrapper files for hosts that don't natively load `SKILL.md`. Each wrapper sits in the host's expected location and points at the canonical runbook.

## Recommended — one-liner installer

```bash
curl -fsSL https://raw.githubusercontent.com/tkoehlerlg/coderabbit-threads/main/scripts/install-adapter.sh \
  | bash -s -- --host=<windsurf|cline|kilo|continue|zed>
```

Run from your project root. The installer fetches the canonical `SKILL.md` and `reference.md` into `<your-repo>/.coderabbit-threads/`, then drops the matching adapter file(s) at the host's expected path. Pass `--target=<path>` for a different root, `--ref=v0.4.1` to pin a version, `--force` to overwrite existing files. Run with `--help` for the full reference.

After install, make `cr` callable: either symlink `bin/cr` from the plugin into a `$PATH` directory, or set `CR_BIN=<path-to>/coderabbit-threads/bin/cr` in your shell rc. If you have the plugin installed via Claude Code, `cr` is already on `$PATH`.

## Manual install (if you'd rather not run a script)

1. **Vendor the runbook.** From your project root:

   ```bash
   mkdir -p .coderabbit-threads
   curl -sL https://raw.githubusercontent.com/tkoehlerlg/coderabbit-threads/main/skills/coderabbit-threads/SKILL.md \
     > .coderabbit-threads/SKILL.md
   curl -sL https://raw.githubusercontent.com/tkoehlerlg/coderabbit-threads/main/skills/coderabbit-threads/reference.md \
     > .coderabbit-threads/reference.md
   ```

2. **Copy the matching wrapper.** Each subdirectory under `adapters/` mirrors the path the host expects:

   | Host | Copy from → To repo path |
   |---|---|
   | Windsurf | `adapters/windsurf/.windsurf/workflows/coderabbit-threads.md` → `.windsurf/workflows/coderabbit-threads.md` |
   | Cline | `adapters/cline/.clinerules/10-coderabbit-threads.md` → `.clinerules/10-coderabbit-threads.md` plus `adapters/cline/.clinerules/workflows/coderabbit-threads.md` → `.clinerules/workflows/coderabbit-threads.md` |
   | Kilo Code | `adapters/kilo-code/.roomodes` → `.roomodes` plus `adapters/kilo-code/.roo/rules-coderabbit-threads/01-runbook.md` → `.roo/rules-coderabbit-threads/01-runbook.md` |
   | Continue.dev | `adapters/continue/coderabbit-threads.prompt` → `.continue/prompts/coderabbit-threads.prompt` (or `~/.continue/prompts/`) |
   | Zed | `adapters/zed/.rules` → `.rules` (repo root) |

3. **Make `cr` callable** (same as installer step above).

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
