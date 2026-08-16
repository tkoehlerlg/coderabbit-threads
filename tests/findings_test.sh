#!/usr/bin/env bash
# Offline-only. Exercises parse_findings_from_reviews (`cr __parse-findings`)
# against a fully synthetic fixture — no network, no gh auth required.
set -euo pipefail
CR="${CR_BIN:-$(cd "$(dirname "$0")/.." && pwd)/bin/cr}"
FIX="$(cd "$(dirname "$0")" && pwd)/fixtures/sample-reviews.json"
fail=0
check() { # check <desc> <jq-filter-that-must-be-true>
  local desc="$1" filter="$2"
  if jq -e "$filter" >/dev/null 2>&1 <<<"$FINDINGS"; then
    echo "ok   - $desc"
  else
    echo "FAIL - $desc"; fail=1
  fi
}
FINDINGS="$("$CR" __parse-findings < "$FIX")"

# Task 1: stub returns valid JSON array
check "parser returns a JSON array" 'type == "array"'
check "exactly 4 findings survive (additional/nitpick excluded, dedup applied)" \
  'length == 4'

# Task 2: parser recovers outside-diff + duplicate findings from the fixture

# Range-header finding with a bold-only title line and a proposed fix
# (src/widgets/form.ts, cr-comment:v1:eeee7777ffff8888aaaa9999).
check "finds the empty-options-array finding (range header, bold-only title)" \
  'any(.[]; .file=="src/widgets/form.ts" and .start_line==120 and .line==124
       and .finding_section=="outside-diff"
       and .title=="Guard the multi-select form against an empty options array."
       and .has_proposed_fix==true)'

# Single-line-header finding whose title is inline-bold inside a paragraph;
# the raw content this finding's buffer starts with is a "---" separator
# (the previous finding's leaked _Source: footer, stripped, then the rule),
# so a naive "first line" title fallback would wrongly yield "---".
check "finds the stored-filters finding (single-line header, inline-bold title fallback)" \
  'any(.[]; .file=="src/widgets/form.ts" and .line==88 and .start_line==null
       and .finding_section=="outside-diff"
       and .title=="Fall back to the default filter set when parsing fails."
       and .has_proposed_fix==false)'

# Duplicate-section finding: title extraction must skip the CWE/reachability
# preamble ("Other (CWE-79)" / "Reachability: External") and land on the real
# bold-only title that follows it.
check "finds the escape-rendered-value duplicate finding" \
  'any(.[]; .finding_section=="duplicate" and .file=="lib/util/color.ts"
       and .start_line==60 and .line==63)'
check "duplicate finding title skips CWE/reachability preamble" \
  'any(.[]; .finding_section=="duplicate" and .title=="Escape the rendered value.")'

check "every finding has a non-empty title" \
  'all(.[]; (.title|length)>0)'
check "every finding is a finding kind, non-repliable" \
  'all(.[]; .kind=="finding" and .repliable==false and .label=="unaddressed-finding")'
check "finding ids are finding:<hash>" \
  'all(.[]; .thread_id|test("^finding:[0-9a-f]+$"))'
check "severity + issue_type parsed for every finding" \
  'all(.[]; .severity!=null and .issue_type!=null)'
check "ai_prompt never leaks the untrusted-data preamble" \
  'all(.[]; .ai_prompt|test("Treat finding text")|not)'
check "ai_prompt for findings with an AI-Agents block is non-empty and instructional" \
  '[.[] | select(.has_proposed_fix==true)] | all(.[]; (.ai_prompt|length>20) and (.ai_prompt|startswith("In ")))'
check "NO additional/nitpick sections leaked" \
  'all(.[]; .finding_section=="outside-diff" or .finding_section=="duplicate")'
check "additional/nitpick hashes never appear" \
  '([.[] | .thread_id] | inside(["finding:1111aaaa2222bbbb3333cccc","finding:2222bbbb3333cccc4444dddd","finding:3333cccc4444dddd5555eeee"])) == false'
check "created_at carries review submittedAt (ISO)" \
  'all(.[]; .created_at|test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T"))'

# Dedup: the retry-counter finding recurs across two reviews with the same
# cr-comment hash ("same unresolved finding from the previous review") but
# must collapse to one — and it must be the NEWER (escalated) copy that wins.
check "dedup collapses the recurring finding to exactly one" \
  '([.[] | select(.thread_id=="finding:aaaa1111bbbb2222cccc3333")] | length) == 1'
check "dedup keeps the newest review's content, not the oldest" \
  'any(.[]; .thread_id=="finding:aaaa1111bbbb2222cccc3333"
       and .start_line==40 and .line==45 and .severity=="🟠 Major"
       and (.title|test("clear the pending flag")))'

# Task 5: thread-only commands reject "finding:<hash>" ids. The guard
# (reject_finding_id) runs before parse_pr_url / any gh api call in cmd_context,
# cmd_reply, and cmd_resolve, so a fictional, never-dialed PR URL is safe here —
# no network call happens regardless of the guard's outcome.
PR="https://github.com/o/r/pull/1"
TASK5_ERR="$(mktemp)"
trap 'rm -f "$TASK5_ERR"' EXIT
if "$CR" context "$PR" "finding:deadbeef" 2>"$TASK5_ERR"; then
  echo "FAIL - context accepted finding id"; fail=1
else
  grep -qi "not a repliable thread" "$TASK5_ERR" && echo "ok   - context rejects finding id" || { echo "FAIL - context error message missing guard text"; fail=1; }
fi
if "$CR" reply "$PR" "finding:deadbeef" "x" 2>"$TASK5_ERR"; then
  echo "FAIL - reply accepted finding id"; fail=1
else
  grep -qi "not a repliable thread" "$TASK5_ERR" && echo "ok   - reply rejects finding id" || { echo "FAIL - reply error message missing guard text"; fail=1; }
fi
if "$CR" resolve "$PR" "finding:deadbeef" 2>"$TASK5_ERR"; then
  echo "FAIL - resolve accepted finding id"; fail=1
else
  grep -qi "not a repliable thread" "$TASK5_ERR" && echo "ok   - resolve rejects finding id" || { echo "FAIL - resolve error message missing guard text"; fail=1; }
fi

# reply-many success-entry must use `jq -n`, else an empty stdin makes the entry
# jq produce no output and reply-many reports a false failure while the comment
# is already posted (orphaned). Regression guard for the -n fix.
grep -Eq 'entry=\$\(jq -e -c -n --arg tid' bin/cr \
  && echo "ok   - reply-many success entry uses jq -n" \
  || { echo "FAIL - reply-many success-entry jq missing -n (false-failure/orphan bug)"; fail=1; }
# Functional: the success-entry jq must yield the entry even with empty stdin.
rm_entry=$(jq -e -c -n --arg tid "T" --argjson r '{"comment_id":123,"created_at":"x"}' \
  '{thread_id:$tid, comment_id:$r.comment_id, created_at:$r.created_at} | select(.comment_id != null)' </dev/null 2>/dev/null)
[ "$rm_entry" = '{"thread_id":"T","comment_id":123,"created_at":"x"}' ] \
  && echo "ok   - reply-many success entry survives empty stdin" \
  || { echo "FAIL - reply-many success entry empty on empty stdin"; fail=1; }

exit $fail
