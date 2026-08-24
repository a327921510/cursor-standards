#!/usr/bin/env bash
# install.sh — sync rules/skills into <target>/.cursor using copy + clean sync,
# then write .standards-lock.json with an integrity manifest.

# materialize_ref <src> <ref> — export a git ref into a fresh temp dir without
# mutating the user's working tree. Prints the temp dir path.
materialize_ref() {
  local src="$1" ref="$2" tmp
  git -C "$src" rev-parse --git-dir >/dev/null 2>&1 || die "source is not a git repo; cannot pin --version/--commit"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/cursor-std.XXXXXX")"
  if ! git -C "$src" archive "$ref" 2>/dev/null | tar -x -C "$tmp" 2>/dev/null; then
    rm -rf "$tmp"
    die "cannot resolve ref '$ref' in source $src"
  fi
  printf '%s\n' "$tmp"
}

# resolve_version_ref <src> <requested> — map a version string to a local git
# ref. Accepts "1.2.0" or "v1.2.0". Prints the resolvable ref; exit 1 if none.
resolve_version_ref() {
  local src="$1" req="$2" cand
  for cand in "$req" "v${req#v}" "${req#v}"; do
    if git -C "$src" rev-parse --verify "${cand}^{commit}" >/dev/null 2>&1; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  return 1
}

# build_manifest_json <cursor_dir> — emit the "manifest" object body (entries
# only, no braces) mapping paths (relative to .cursor/) to sha256 digests.
build_manifest_json() {
  local base="$1" sub f rel first=1
  for sub in "$RULES_SUBDIR" "$SKILLS_SUBDIR"; do
    [ -d "$base/$sub" ] || continue
    while IFS= read -r f; do
      rel="${f#"$base"/}"
      [ "$first" -eq 1 ] && first=0 || printf ',\n'
      printf '    "%s": "sha256:%s"' "$rel" "$(sha256_file "$f")"
    done < <(find "$base/$sub" -type f | LC_ALL=C sort)
  done
  [ "$first" -eq 0 ] && printf '\n'
  return 0
}

cmd_install() {
  local target="${1:-.}"
  target="$(abspath "$target")" || die "invalid target: ${1:-.}"
  [ -d "$target" ] || die "target directory does not exist: $target"

  resolve_source

  # Decide content source: pinned ref (via git archive) or the working tree.
  local content_src="$STANDARDS_ROOT" ref="" pinned_tmp="" version commit dirty

  # Pinning needs remote tags/commits in the local source clone.
  if { [ -n "${OPT_VERSION:-}" ] || [ -n "${OPT_COMMIT:-}" ]; } \
     && git -C "$STANDARDS_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    info "Fetching tags from source remote (for --version/--commit pin)"
    if ! git -C "$STANDARDS_ROOT" fetch --tags --quiet 2>/dev/null; then
      warn "git fetch failed (offline?); resolving pin from local refs only"
    fi
  fi

  if [ -n "${OPT_VERSION:-}" ]; then
    ref="$(resolve_version_ref "$STANDARDS_ROOT" "$OPT_VERSION")" \
      || die "cannot resolve --version '$OPT_VERSION' in $STANDARDS_ROOT (need tag like v${OPT_VERSION#v}; run: git -C \"\$STANDARDS_HOME\" fetch --tags)"
  fi
  if [ -n "${OPT_COMMIT:-}" ]; then ref="$OPT_COMMIT"; fi

  if [ -n "$ref" ]; then
    pinned_tmp="$(materialize_ref "$STANDARDS_ROOT" "$ref")"
    content_src="$pinned_tmp"
    commit="$(git -C "$STANDARDS_ROOT" rev-parse "${ref}^{commit}" 2>/dev/null || echo unknown)"
    if [ -f "$content_src/VERSION" ]; then
      version="$(tr -d ' \t\r\n' < "$content_src/VERSION")"; version="${version#v}"
    elif [ -n "${OPT_VERSION:-}" ]; then
      version="${OPT_VERSION#v}"
    else
      version="0.0.0"
    fi
    dirty=false
  else
    version="$(source_version "$STANDARDS_ROOT")"
    commit="$(source_commit "$STANDARDS_ROOT")"
    dirty="$(source_dirty "$STANDARDS_ROOT")"
  fi

  local mode="${OPT_MODE:-copy}"
  [ "$mode" = "copy" ] || die "install mode '$mode' not supported yet (only 'copy')"

  local source_url
  source_url="$(git_remote_url "$STANDARDS_ROOT")"
  [ -n "$source_url" ] || source_url="$STANDARDS_ROOT"

  local cursor_dir="$target/.cursor"
  info "Installing cursor-standards $version -> $target"
  [ "$dirty" = "true" ] && warn "source checkout has uncommitted changes; lock will be marked dirty:true"

  # Clean sync managed subtrees only. local.mdc and any sibling files untouched.
  sync_tree "$content_src/rules"   "$cursor_dir/$RULES_SUBDIR"
  sync_tree "$content_src/skills"  "$cursor_dir/$SKILLS_SUBDIR"

  # Guard rail: drop a README into managed dirs to discourage hand edits.
  _managed_notice "$cursor_dir/$RULES_SUBDIR"
  _managed_notice "$cursor_dir/$SKILLS_SUBDIR"

  # Write lock + manifest.
  local lf; lf="$(lock_path "$target")"
  mkdir -p "$cursor_dir"
  {
    printf '{\n'
    printf '  "source": "%s",\n' "$source_url"
    printf '  "version": "%s",\n' "$version"
    printf '  "commit": "%s",\n' "$commit"
    printf '  "installedAt": "%s",\n' "$(now_iso)"
    printf '  "installMode": "%s",\n' "$mode"
    printf '  "cliVersion": "%s",\n' "$CLI_VERSION"
    printf '  "dirty": %s,\n' "$dirty"
    printf '  "manifest": {\n'
    build_manifest_json "$cursor_dir"
    printf '  }\n'
    printf '}\n'
  } > "$lf"

  [ -n "$pinned_tmp" ] && rm -rf "$pinned_tmp"

  ok "Done. Wrote $(_relpath "$target" "$lf")"
  log "  rules  -> .cursor/$RULES_SUBDIR"
  log "  skills -> .cursor/$SKILLS_SUBDIR"
}

_managed_notice() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  cat > "$dir/README.md" <<'EOF'
<!-- Managed by cursor-std. DO NOT EDIT BY HAND. -->
This directory is generated by `cursor-std install/update`.
Local changes here are overwritten on the next sync and reported by `cursor-std verify`.
Put project-specific rules in `.cursor/rules/local.mdc` instead.
EOF
}

_relpath() { # <base> <path>
  local base="$1" path="$2"
  printf '%s\n' "${path#"$base"/}"
}
