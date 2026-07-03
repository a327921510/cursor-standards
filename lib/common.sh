#!/usr/bin/env bash
# common.sh — shared helpers for cursor-std.
# Sourced by bin/cursor-std and lib/*.sh. Pure bash + git + coreutils only.

# CLI version (independent of the standards content VERSION file).
CLI_VERSION="0.1.0"

# Subdirectories (relative to <target>/.cursor) that this tool owns.
# Everything else under .cursor/ (e.g. local.mdc) is never touched.
RULES_SUBDIR="rules/standards"
SKILLS_SUBDIR="skills/standards"
LOCK_NAME=".standards-lock.json"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
_is_tty() { [ -t 2 ]; }
if _is_tty; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_RED=$'\033[31m'; C_YEL=$'\033[33m'; C_GRN=$'\033[32m'; C_BLU=$'\033[34m'
else
  C_RESET=""; C_DIM=""; C_RED=""; C_YEL=""; C_GRN=""; C_BLU=""
fi
log()  { printf '%s\n' "$*" >&2; }
info() { printf '%s%s%s\n' "$C_BLU" "$*" "$C_RESET" >&2; }
ok()   { printf '%s%s%s\n' "$C_GRN" "$*" "$C_RESET" >&2; }
warn() { printf '%swarn:%s %s\n' "$C_YEL" "$C_RESET" "$*" >&2; }
err()  { printf '%serror:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()  { err "$*"; exit 1; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

require_cmd() {
  local c
  for c in "$@"; do
    have_cmd "$c" || die "required command not found: $c"
  done
}

# ---------------------------------------------------------------------------
# Portability helpers
# ---------------------------------------------------------------------------

# now_iso — UTC timestamp, e.g. 2026-07-03T09:00:00Z
now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# abspath <path> — resolve to an absolute path without relying on `readlink -f`
# (which is unavailable on stock macOS). Works for existing dirs and files.
abspath() {
  local p="$1"
  if [ -d "$p" ]; then
    (cd "$p" 2>/dev/null && pwd)
  else
    local d b
    d="$(dirname -- "$p")"; b="$(basename -- "$p")"
    d="$(cd "$d" 2>/dev/null && pwd)" || return 1
    printf '%s/%s\n' "$d" "$b"
  fi
}

# sha256_file <file> — print the sha256 hex digest of a file.
sha256_file() {
  if have_cmd sha256sum; then
    sha256sum "$1" | awk '{print $1}'
  elif have_cmd shasum; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    die "need 'sha256sum' or 'shasum' to compute checksums"
  fi
}

# ---------------------------------------------------------------------------
# Semver (pure bash — avoids GNU-only `sort -V`)
# ---------------------------------------------------------------------------

# semver_norm <v> -> "MAJ MIN PATCH" (strips leading v, build metadata, pre-release)
semver_norm() {
  local v="${1#v}"
  v="${v%%+*}"      # drop +build
  v="${v%%-*}"      # drop -prerelease
  local a b c IFS=.
  # shellcheck disable=SC2086
  set -- $v
  a="${1:-0}"; b="${2:-0}"; c="${3:-0}"
  # guard against non-numeric segments
  [[ "$a" =~ ^[0-9]+$ ]] || a=0
  [[ "$b" =~ ^[0-9]+$ ]] || b=0
  [[ "$c" =~ ^[0-9]+$ ]] || c=0
  printf '%s %s %s\n' "$a" "$b" "$c"
}

# semver_cmp <a> <b> -> prints -1 (a<b), 0 (a==b), 1 (a>b)
semver_cmp() {
  local a1 b1 c1 a2 b2 c2
  read -r a1 b1 c1 <<<"$(semver_norm "$1")"
  read -r a2 b2 c2 <<<"$(semver_norm "$2")"
  local x y
  for pair in "$a1:$a2" "$b1:$b2" "$c1:$c2"; do
    x="${pair%%:*}"; y="${pair##*:}"
    if (( 10#$x > 10#$y )); then echo 1; return; fi
    if (( 10#$x < 10#$y )); then echo -1; return; fi
  done
  echo 0
}

# semver_max — read newline-separated versions on stdin, print the greatest.
semver_max() {
  local best="" line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if [ -z "$best" ] || [ "$(semver_cmp "$line" "$best")" = "1" ]; then
      best="$line"
    fi
  done
  printf '%s\n' "$best"
}

# ---------------------------------------------------------------------------
# Source resolution
# ---------------------------------------------------------------------------
# The "source" is the cursor-standards checkout that holds rules/ and skills/.
# Resolution order:
#   1. --source <dir>            (OPT_SOURCE)
#   2. $STANDARDS_HOME           (local clone; enables offline install)
#   3. the repo the CLI lives in (self — bin/.. )
STANDARDS_ROOT=""   # set by resolve_source
resolve_source() {
  local candidate=""
  if [ -n "${OPT_SOURCE:-}" ]; then
    candidate="$OPT_SOURCE"
  elif [ -n "${STANDARDS_HOME:-}" ]; then
    candidate="$STANDARDS_HOME"
  else
    candidate="$CURSOR_STD_SELF_ROOT"
  fi
  [ -d "$candidate" ] || die "standards source not found: $candidate"
  STANDARDS_ROOT="$(abspath "$candidate")"
  [ -d "$STANDARDS_ROOT/rules" ] || warn "source has no rules/ directory: $STANDARDS_ROOT"
}

# sanitize_url <url> — strip embedded credentials (user:pass@ / token@) so we
# never persist secrets into a committed lock file.
sanitize_url() {
  printf '%s\n' "$1" | sed -E 's#(https?://)[^@/]*@#\1#'
}

# git_remote_url <dir> — best-effort, credential-stripped remote URL.
# Always exits 0 (prints nothing when there is no origin) so callers using
# `url="$(git_remote_url ...)"` under `set -e` do not abort.
git_remote_url() {
  local d="$1" u
  u="$(git -C "$d" remote get-url origin 2>/dev/null || true)"
  if [ -n "$u" ]; then sanitize_url "$u"; fi
  return 0
}

# source_version <dir> — version string of the source checkout.
# Prefers `git describe --tags`; falls back to the VERSION file.
source_version() {
  local d="$1" v=""
  if git -C "$d" rev-parse --git-dir >/dev/null 2>&1; then
    v="$(git -C "$d" describe --tags --abbrev=0 2>/dev/null || true)"
  fi
  if [ -z "$v" ] && [ -f "$d/VERSION" ]; then
    v="$(tr -d ' \t\r\n' < "$d/VERSION")"
  fi
  [ -n "$v" ] || v="0.0.0"
  printf '%s\n' "${v#v}"
}

source_commit() {
  local d="$1"
  git -C "$d" rev-parse HEAD 2>/dev/null || echo "unknown"
}

source_dirty() {
  local d="$1"
  if git -C "$d" rev-parse --git-dir >/dev/null 2>&1; then
    if [ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ]; then echo true; else echo false; fi
  else
    echo false
  fi
}

# ---------------------------------------------------------------------------
# Lock file helpers (minimal JSON, no jq dependency)
# ---------------------------------------------------------------------------

# lock_path <target> -> path to the lock file inside <target>/.cursor
lock_path() { printf '%s/.cursor/%s\n' "$1" "$LOCK_NAME"; }

# lock_get <key> <lockfile> — read a flat string value.
lock_get() {
  [ -f "$2" ] || return 0
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$2" | head -n1
}

# ---------------------------------------------------------------------------
# Clean sync — atomically replace a managed subtree without touching siblings.
# ---------------------------------------------------------------------------
# sync_tree <src_dir> <dest_dir>
# Removes dest_dir entirely (propagating upstream deletions) then copies the
# contents of src_dir into it. If src_dir is missing/empty, dest_dir ends empty.
sync_tree() {
  local src="$1" dest="$2"
  rm -rf "$dest"
  mkdir -p "$dest"
  if [ -d "$src" ] && [ -n "$(ls -A "$src" 2>/dev/null)" ]; then
    cp -R "$src/." "$dest/"
  fi
}
