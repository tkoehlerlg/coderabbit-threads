#!/usr/bin/env bash
# install-adapter.sh — drop the right Tier-2 wrapper into your project.
#
# Usage:
#   install-adapter.sh --host=<windsurf|cline|kilo|continue|zed>
#                      [--target=<project-root>]   default: $PWD
#                      [--ref=<git-ref>]           default: main
#                      [--force]                   overwrite existing files
#                      [--help]
#
# Fetches SKILL.md and reference.md from the coderabbit-threads repo and
# vendors them at <target>/.coderabbit-threads/, then copies the matching
# adapter file(s) into the host's expected path under <target>.
#
# One-liner (no clone needed):
#   curl -fsSL https://raw.githubusercontent.com/tkoehlerlg/coderabbit-threads/main/scripts/install-adapter.sh \
#     | bash -s -- --host=windsurf
#
# Requires: curl.

set -euo pipefail

REPO="tkoehlerlg/coderabbit-threads"
RAW="https://raw.githubusercontent.com/${REPO}"

HOST=""
TARGET=""
REF="main"
FORCE=0

usage() {
  cat <<'EOF'
install-adapter.sh — drop the right Tier-2 wrapper into your project.

Usage:
  install-adapter.sh --host=<windsurf|cline|kilo|continue|zed>
                     [--target=<project-root>]   default: $PWD
                     [--ref=<git-ref>]           default: main
                     [--force]                   overwrite existing files
                     [--help]

Fetches SKILL.md and reference.md from the coderabbit-threads repo and
vendors them at <target>/.coderabbit-threads/, then copies the matching
adapter file(s) into the host's expected path under <target>.

One-liner (no clone needed):
  curl -fsSL https://raw.githubusercontent.com/tkoehlerlg/coderabbit-threads/main/scripts/install-adapter.sh \
    | bash -s -- --host=windsurf

Requires: curl.
EOF
  exit "${1:-0}"
}

# Bare invocation (no args) → show help and exit cleanly; standard CLI etiquette.
[ $# -eq 0 ] && usage 0

while [ $# -gt 0 ]; do
  case "$1" in
    --host=*)   HOST="${1#*=}" ;;
    --host)     HOST="${2:-}"; shift ;;
    --target=*) TARGET="${1#*=}" ;;
    --target)   TARGET="${2:-}"; shift ;;
    --ref=*)    REF="${1#*=}" ;;
    --ref)      REF="${2:-}"; shift ;;
    --force)    FORCE=1 ;;
    --help|-h)  usage 0 ;;
    *)          echo "install-adapter.sh: unknown arg: $1" >&2; echo "Try --help for usage." >&2; exit 1 ;;
  esac
  shift
done

[ -z "$HOST" ] && { echo "install-adapter.sh: --host is required (one of: windsurf, cline, kilo, continue, zed)" >&2; echo "Try --help for usage." >&2; exit 1; }
[ -z "$TARGET" ] && TARGET="$PWD"
[ ! -d "$TARGET" ] && { echo "install-adapter.sh: target dir does not exist: $TARGET" >&2; exit 1; }
command -v curl >/dev/null || { echo "install-adapter.sh: curl required but not found" >&2; exit 1; }

# Per-host file list. Each entry is "<src-in-repo>|<dst-relative-to-target>".
case "$HOST" in
  windsurf)
    files=(
      "adapters/windsurf/.windsurf/workflows/coderabbit-threads.md|.windsurf/workflows/coderabbit-threads.md"
    ) ;;
  cline)
    files=(
      "adapters/cline/.clinerules/10-coderabbit-threads.md|.clinerules/10-coderabbit-threads.md"
      "adapters/cline/.clinerules/workflows/coderabbit-threads.md|.clinerules/workflows/coderabbit-threads.md"
    ) ;;
  kilo|kilo-code)
    files=(
      "adapters/kilo-code/.roomodes|.roomodes"
      "adapters/kilo-code/.roo/rules-coderabbit-threads/01-runbook.md|.roo/rules-coderabbit-threads/01-runbook.md"
    ) ;;
  continue|continue.dev)
    files=(
      "adapters/continue/coderabbit-threads.prompt|.continue/prompts/coderabbit-threads.prompt"
    ) ;;
  zed)
    files=(
      "adapters/zed/.rules|.rules"
    ) ;;
  *) echo "install-adapter.sh: unknown --host '$HOST' (expected: windsurf, cline, kilo, continue, zed)" >&2; exit 1 ;;
esac

# Always-vendored runbook files (shared across hosts).
vendor=(
  "skills/coderabbit-threads/SKILL.md|.coderabbit-threads/SKILL.md"
  "skills/coderabbit-threads/reference.md|.coderabbit-threads/reference.md"
)

fetch_to() {
  local src="$1" dst="$2"
  if [ -e "$dst" ] && [ "$FORCE" -eq 0 ]; then
    printf '  • skip (exists): %s   (use --force to overwrite)\n' "$dst"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  if curl -fsSL "${RAW}/${REF}/${src}" -o "$dst"; then
    printf '  ✓ wrote: %s\n' "$dst"
  else
    printf '  ✗ FAILED to fetch %s/%s/%s\n' "$RAW" "$REF" "$src" >&2
    return 1
  fi
}

printf 'Installing coderabbit-threads adapter for host: %s\n' "$HOST"
printf 'Target: %s\n' "$TARGET"
printf 'Ref:    %s\n\n' "$REF"

printf 'Vendoring runbook into <target>/.coderabbit-threads/ …\n'
for entry in "${vendor[@]}"; do
  fetch_to "${entry%%|*}" "${TARGET}/${entry##*|}"
done

printf '\nCopying adapter files …\n'
for entry in "${files[@]}"; do
  fetch_to "${entry%%|*}" "${TARGET}/${entry##*|}"
done

cat <<'EOF'

Done. Next steps:
  1. Make `cr` callable.
     • If you have the plugin installed via Claude Code, `cr` is already on PATH.
     • Otherwise: symlink the binary into a PATH directory, or export CR_BIN.
       The binary lives at <plugin-root>/bin/cr.
  2. Open the project in your host and trigger the skill
     (e.g. `/coderabbit-threads` in Windsurf, Cline; mode switch in Kilo Code;
     `@coderabbit-threads` in Zed; `/coderabbit-threads` in Continue.dev).
EOF
