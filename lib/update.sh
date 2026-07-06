#!/usr/bin/env bash
# update.sh — refresh the source checkout (if git) then re-run install.

cmd_update() {
  local target="${1:-.}"
  target="$(abspath "$target")" || die "invalid target: ${1:-.}"
  local lf; lf="$(lock_path "$target")"
  [ -f "$lf" ] || die "no lock file at $lf (run 'cursor-std install' first)"

  resolve_source

  # Pull latest tags/commits into the source checkout when it is a git repo
  # and no explicit pin was requested.
  if [ -z "${OPT_VERSION:-}" ] && [ -z "${OPT_COMMIT:-}" ] \
     && git -C "$STANDARDS_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    info "Fetching latest from source ($STANDARDS_ROOT)"
    if ! git -C "$STANDARDS_ROOT" fetch --tags --quiet 2>/dev/null; then
      warn "git fetch failed (offline?); reinstalling from current checkout state"
    fi
  fi

  # Preserve the previous version for the summary.
  local prev; prev="$(lock_get version "$lf")"

  cmd_install "$target"

  local now; now="$(lock_get version "$lf")"
  if [ "$prev" != "$now" ]; then
    ok "Updated: $prev -> $now"
  else
    ok "Already at $now (reinstalled)"
  fi
}
