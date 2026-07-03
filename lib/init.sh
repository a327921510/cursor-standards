#!/usr/bin/env bash
# init.sh — first-time onboarding: install + (non-destructively) wire the
# sessionStart hook that reminds developers when standards are outdated.

cmd_init() {
  local target="${1:-.}"
  target="$(abspath "$target")" || die "invalid target: ${1:-.}"
  [ -d "$target" ] || die "target directory does not exist: $target"

  # 1. Install rules/skills + lock.
  cmd_install "$target"

  resolve_source
  local tpl="$STANDARDS_ROOT/templates"
  local cursor_dir="$target/.cursor"
  mkdir -p "$cursor_dir/hooks"

  # 2. Copy the check hook script.
  if [ -f "$tpl/hooks/check-standards.sh" ]; then
    cp "$tpl/hooks/check-standards.sh" "$cursor_dir/hooks/check-standards.sh"
    chmod +x "$cursor_dir/hooks/check-standards.sh" 2>/dev/null || true
    ok "wrote .cursor/hooks/check-standards.sh"
  else
    warn "template hook not found: $tpl/hooks/check-standards.sh"
  fi

  # 3. Wire hooks.json — NEVER clobber an existing one.
  local hj="$cursor_dir/hooks.json"
  if [ ! -f "$hj" ]; then
    if [ -f "$tpl/hooks.json" ]; then
      cp "$tpl/hooks.json" "$hj"
      ok "wrote .cursor/hooks.json"
    fi
  else
    # Existing hooks.json: write a reference file + instruct manual merge
    # rather than risk destroying the user's configuration.
    cp "$tpl/hooks.json" "$cursor_dir/hooks.standards.json" 2>/dev/null || true
    warn "existing .cursor/hooks.json left untouched."
    log  "  To enable the reminder, merge the sessionStart entry from"
    log  "  .cursor/hooks.standards.json into your .cursor/hooks.json:"
    log  '      "sessionStart": [ { "command": "bash .cursor/hooks/check-standards.sh" } ]'
  fi

  ok "init complete. Enable hooks in Cursor Settings > Hooks (beta) if not already on."
}
