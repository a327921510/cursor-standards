#!/usr/bin/env bash
# remove.sh — uninstall standards from a project: delete the managed subtrees
# and the lock file, returning the project to an un-onboarded state.
# Never touches local.mdc, hooks, or any sibling files.

cmd_remove() {
  local target="${1:-.}"
  target="$(abspath "$target")" || die "invalid target: ${1:-.}"
  local cursor_dir="$target/.cursor"
  local lf; lf="$(lock_path "$target")"

  if [ ! -d "$cursor_dir/$RULES_SUBDIR" ] && [ ! -d "$cursor_dir/$SKILLS_SUBDIR" ] && [ ! -f "$lf" ]; then
    warn "nothing to remove at $target (no standards installed)"
    return 0
  fi

  info "Removing cursor-standards from $target"
  rm -rf "$cursor_dir/$RULES_SUBDIR"  && log "  removed .cursor/$RULES_SUBDIR"
  rm -rf "$cursor_dir/$SKILLS_SUBDIR" && log "  removed .cursor/$SKILLS_SUBDIR"
  if [ -f "$lf" ]; then rm -f "$lf" && log "  removed .cursor/$LOCK_NAME"; fi

  # Prune now-empty managed parents (rules/ skills/) without disturbing siblings
  # such as local.mdc. rmdir only succeeds when the directory is empty.
  rmdir "$cursor_dir/rules"  2>/dev/null || true
  rmdir "$cursor_dir/skills" 2>/dev/null || true

  warn "hooks, local.mdc, and req-workflow.local.mdc were left untouched."
  log  "  remove them manually if you no longer want the upgrade reminder / REQ paths."
  ok "Done."
}
