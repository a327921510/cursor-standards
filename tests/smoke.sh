#!/usr/bin/env bash
# smoke.sh — end-to-end checks for cursor-std using a throwaway project.
# Covers: install, lock/manifest, idempotency, clean sync (deletion propagates),
# preservation of local.mdc, verify (clean + tamper), pin by tag.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$REPO_ROOT/bin/cursor-std"
PASS=0; FAIL=0
tpass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
tfail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
check() { if eval "$2"; then tpass "$1"; else tfail "$1"; fi; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/cursor-std-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
PROJ="$WORK/proj"; mkdir -p "$PROJ"
export STANDARDS_HOME="$REPO_ROOT"

echo "== install =="
"$CLI" install "$PROJ" >/dev/null 2>&1
check "lock file created"            "[ -f '$PROJ/.cursor/.standards-lock.json' ]"
check "std-general.mdc installed"    "[ -f '$PROJ/.cursor/rules/standards/std-general.mdc' ]"
check "std-req-workflow.mdc installed" "[ -f '$PROJ/.cursor/rules/standards/std-req-workflow.mdc' ]"
check "skill installed"              "[ -f '$PROJ/.cursor/skills/standards/commit-helper/SKILL.md' ]"
check "req-workflow skill installed" "[ -f '$PROJ/.cursor/skills/standards/req-workflow/WORKFLOW.md' ]"
check "implement-req skill installed" "[ -f '$PROJ/.cursor/skills/standards/implement-req/SKILL.md' ]"
check "manifest present in lock"     "grep -q 'sha256:' '$PROJ/.cursor/.standards-lock.json'"
check "version recorded"             "grep -q '\"version\"' '$PROJ/.cursor/.standards-lock.json'"

echo "== verify (clean) =="
"$CLI" verify "$PROJ" >/dev/null 2>&1
check "verify passes when untouched" "$CLI verify '$PROJ' >/dev/null 2>&1"

echo "== local.mdc preserved + idempotency =="
printf -- '---\nalwaysApply: true\n---\nlocal\n' > "$PROJ/.cursor/rules/local.mdc"
"$CLI" install "$PROJ" >/dev/null 2>&1
check "local.mdc preserved on reinstall" "[ -f '$PROJ/.cursor/rules/local.mdc' ]"

echo "== clean sync: upstream deletion propagates =="
# Simulate an installed orphan file then reinstall; it should be removed.
touch "$PROJ/.cursor/rules/standards/orphan.mdc"
"$CLI" install "$PROJ" >/dev/null 2>&1
check "orphan removed by clean sync" "[ ! -f '$PROJ/.cursor/rules/standards/orphan.mdc' ]"

echo "== verify (tamper) =="
echo "hand edit" >> "$PROJ/.cursor/rules/standards/std-general.mdc"
if "$CLI" verify "$PROJ" >/dev/null 2>&1; then tfail "verify should detect tampering"; else tpass "verify detects tampering"; fi
"$CLI" install "$PROJ" >/dev/null 2>&1   # restore

echo "== remove =="
printf -- '---\nalwaysApply: true\n---\nlocal\n' > "$PROJ/.cursor/rules/local.mdc"
"$CLI" remove "$PROJ" >/dev/null 2>&1
check "standards rules removed"      "[ ! -d '$PROJ/.cursor/rules/standards' ]"
check "standards skills removed"     "[ ! -d '$PROJ/.cursor/skills/standards' ]"
check "lock removed"                 "[ ! -f '$PROJ/.cursor/.standards-lock.json' ]"
check "local.mdc preserved on remove" "[ -f '$PROJ/.cursor/rules/local.mdc' ]"
"$CLI" install "$PROJ" >/dev/null 2>&1   # restore for later sections

echo "== configure-req =="
DOCS="$WORK/docs"; APP="$WORK/app"; BOSS="$WORK/boss"
mkdir -p "$DOCS" "$APP" "$BOSS"
"$CLI" configure-req "$PROJ" \
  --doc-root "$DOCS" \
  --repo "app=$APP" \
  --repo "boss=$BOSS" \
  --seed-docs >/dev/null 2>&1
check "req-workflow.local.mdc written"   "[ -f '$PROJ/.cursor/rules/req-workflow.local.mdc' ]"
check "seeded REQ-index"                 "[ -f '$DOCS/backlog/REQ-index.md' ]"
check "seeded changelog"                 "[ -f '$DOCS/changelog.md' ]"
# reinstall must not wipe local REQ config
"$CLI" install "$PROJ" >/dev/null 2>&1
check "configure-req survives reinstall" "[ -f '$PROJ/.cursor/rules/req-workflow.local.mdc' ]"
# without --force should fail
if "$CLI" configure-req "$PROJ" --doc-root "$DOCS" --repo "app=$APP" >/dev/null 2>&1; then
  tfail "configure-req should refuse overwrite without --force"
else
  tpass "configure-req refuses overwrite without --force"
fi
"$CLI" configure-req "$PROJ" --doc-root "$DOCS" --repo "app=$APP" --force >/dev/null 2>&1
check "configure-req --force works"      "[ -f '$PROJ/.cursor/rules/req-workflow.local.mdc' ]"
# remove keeps local REQ config
"$CLI" remove "$PROJ" >/dev/null 2>&1
check "req-workflow.local.mdc kept on remove" "[ -f '$PROJ/.cursor/rules/req-workflow.local.mdc' ]"
"$CLI" install "$PROJ" >/dev/null 2>&1

echo "== pin by tag (if any tag exists) =="
if git -C "$REPO_ROOT" describe --tags --abbrev=0 >/dev/null 2>&1; then
  TAG="$(git -C "$REPO_ROOT" describe --tags --abbrev=0)"
  if "$CLI" install "$PROJ" --version "$TAG" >/dev/null 2>&1; then tpass "pin --version $TAG"; else tfail "pin --version $TAG"; fi
else
  echo "  SKIP (no tags in source repo)"
fi

echo
echo "== semver unit checks =="
# shellcheck source=/dev/null
CURSOR_STD_SELF_ROOT="$REPO_ROOT" . "$REPO_ROOT/lib/common.sh"
check "1.2.0 > 1.1.9"   "[ \"\$(semver_cmp 1.2.0 1.1.9)\" = '1' ]"
check "1.0.0 == v1.0.0" "[ \"\$(semver_cmp 1.0.0 v1.0.0)\" = '0' ]"
check "2.0.0 > 1.9.9"   "[ \"\$(semver_cmp 2.0.0 1.9.9)\" = '1' ]"
check "max picks 1.10.0" "[ \"\$(printf '1.2.0\n1.10.0\n1.9.0\n' | semver_max)\" = '1.10.0' ]"

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
