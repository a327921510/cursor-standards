#!/usr/bin/env bash
# verify.sh — recompute checksums of the managed subtrees and compare them to
# the manifest recorded in the lock file. Detects hand edits, missing files
# and extra files. Exit codes: 0 clean, 4 drift detected.

cmd_verify() {
  local target="${1:-.}"
  target="$(abspath "$target")" || die "invalid target: ${1:-.}"
  local lf; lf="$(lock_path "$target")"
  [ -f "$lf" ] || die "no lock file at $lf (run 'cursor-std install' first)"

  local cursor_dir="$target/.cursor"
  local drift=0

  # Extract manifest entries: "<path>": "sha256:<hash>"
  local expected_paths="" line path hash actual
  while IFS= read -r line; do
    path="$(printf '%s' "$line" | sed -n 's/^[[:space:]]*"\(.*\)"[[:space:]]*:[[:space:]]*"sha256:\([0-9a-f]*\)".*/\1/p')"
    hash="$(printf '%s' "$line" | sed -n 's/^[[:space:]]*"\(.*\)"[[:space:]]*:[[:space:]]*"sha256:\([0-9a-f]*\)".*/\2/p')"
    [ -n "$path" ] || continue
    expected_paths="$expected_paths$path"$'\n'
    if [ ! -f "$cursor_dir/$path" ]; then
      err "missing: $path"; drift=1; continue
    fi
    actual="$(sha256_file "$cursor_dir/$path")"
    if [ "$actual" != "$hash" ]; then
      err "modified: $path"; drift=1
    fi
  done < <(grep -E '"sha256:[0-9a-f]+"' "$lf")

  # Detect extra files not present in the manifest.
  local sub f rel
  for sub in "$RULES_SUBDIR" "$SKILLS_SUBDIR"; do
    [ -d "$cursor_dir/$sub" ] || continue
    while IFS= read -r f; do
      rel="${f#"$cursor_dir"/}"
      if ! printf '%s' "$expected_paths" | grep -qxF "$rel"; then
        err "unexpected: $rel"; drift=1
      fi
    done < <(find "$cursor_dir/$sub" -type f | LC_ALL=C sort)
  done

  if [ "$drift" -ne 0 ]; then
    warn "integrity drift detected — run 'cursor-std update \"$target\"' to restore"
    return 4
  fi
  ok "integrity OK ($(lock_get version "$lf"))"
  return 0
}
