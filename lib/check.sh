#!/usr/bin/env bash
# check.sh — compare the installed lock version against the latest available
# version. Exit codes: 0 up-to-date, 1 upgrade available, 3 error/unknown.

# latest_remote_version <url> — greatest semver tag via `git ls-remote --tags`.
# Every stage is guarded so "no tags"/"offline" yields an empty string, never a
# pipefail that would abort the caller under `set -e`.
latest_remote_version() {
  local url="$1"
  { git ls-remote --tags --refs "$url" 2>/dev/null || true; } \
    | awk -F/ '{print $NF}' \
    | { grep -E '^v?[0-9]+(\.[0-9]+){0,2}' || true; } \
    | sed 's/^v//' \
    | semver_max
}

# latest_local_version — offline fallback using STANDARDS_HOME's tags.
latest_local_version() {
  local d="${STANDARDS_HOME:-}"
  [ -n "$d" ] && [ -d "$d" ] || return 0
  { git -C "$d" tag 2>/dev/null || true; } | sed 's/^v//' | semver_max
}

cmd_check() {
  local target="${1:-.}"
  target="$(abspath "$target")" || die "invalid target: ${1:-.}"
  local lf; lf="$(lock_path "$target")"
  [ -f "$lf" ] || die "no lock file at $lf (run 'cursor-std install' first)"

  local current source_url latest="" origin="remote"
  current="$(lock_get version "$lf")"
  source_url="${OPT_SOURCE:-}"
  [ -n "$source_url" ] || source_url="$(lock_get source "$lf")"
  [ -n "$source_url" ] || source_url="${STANDARDS_REPO:-}"

  if [ -n "$source_url" ]; then
    latest="$(latest_remote_version "$source_url")"
  fi
  if [ -z "$latest" ]; then
    latest="$(latest_local_version)"; origin="local (STANDARDS_HOME)"
  fi

  if [ -z "$latest" ]; then
    warn "could not determine latest version (offline? no tags?)"
    log  "  installed: $current"
    return 3
  fi

  log "  installed: $current"
  log "  latest:    $latest  [$origin]"

  local c; c="$(semver_cmp "$current" "$latest")"
  if [ "$c" = "-1" ]; then
    warn "upgrade available: $current -> $latest  (run: cursor-std update \"$target\")"
    return 1
  fi
  ok "up to date ($current)"
  return 0
}
