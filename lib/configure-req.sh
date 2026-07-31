#!/usr/bin/env bash
# configure-req.sh — write project-local REQ workflow paths
# (.cursor/rules/req-workflow.local.mdc) and optionally seed doc stubs.
# Does NOT touch managed standards/ trees.

REQ_LOCAL_MDC="rules/req-workflow.local.mdc"

# prompt_line <prompt> <default> — read a line from TTY; empty keeps default.
prompt_line() {
  local prompt="$1" default="${2:-}" ans
  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$prompt" "$default" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi
  IFS= read -r ans || true
  if [ -z "$ans" ]; then
    printf '%s\n' "$default"
  else
    printf '%s\n' "$ans"
  fi
}

# interactive_fill — populate OPT_DOC_ROOT / OPT_REPOS / etc when TTY and missing.
interactive_fill() {
  [ -t 0 ] || return 0
  local line label path

  if [ -z "${OPT_DOC_ROOT:-}" ]; then
    OPT_DOC_ROOT="$(prompt_line "文档根绝对路径 (--doc-root)" "")"
  fi

  if [ "${#OPT_REPOS[@]}" -eq 0 ]; then
    info "添加代码仓（label=绝对路径）。空行结束。"
    while true; do
      line="$(prompt_line "  --repo" "")"
      [ -z "$line" ] && break
      OPT_REPOS+=("$line")
    done
  fi

  if [ -z "${OPT_FEATURE_DOC:-}" ]; then
    OPT_FEATURE_DOC="$(prompt_line "功能真相相对路径" "项目功能需求文档.md")"
  fi
  if [ -z "${OPT_CHANGELOG:-}" ]; then
    OPT_CHANGELOG="$(prompt_line "changelog 相对路径" "changelog.md")"
  fi
}

# validate_repo_spec <spec> — must be label=/abs/or/rel/path
validate_repo_spec() {
  local spec="$1" label path
  case "$spec" in
    *=*) ;;
    *) die "invalid --repo '$spec' (expected label=/path)" ;;
  esac
  label="${spec%%=*}"
  path="${spec#*=}"
  [ -n "$label" ] || die "invalid --repo '$spec': empty label"
  [ -n "$path" ] || die "invalid --repo '$spec': empty path"
  [ -d "$path" ] || die "repo path does not exist: $path (label=$label)"
}

# render_local_mdc <doc_root> <feature_doc> <changelog> <repo_specs...>
# Prints rendered mdc to stdout. Uses bash string replace (safe for path chars).
render_local_mdc() {
  local doc_root="$1" feature_doc="$2" changelog="$3"
  shift 3
  local tpl line spec label path
  resolve_source
  tpl="$STANDARDS_ROOT/templates/req-workflow/req-workflow.local.mdc.tpl"
  [ -f "$tpl" ] || die "template missing: $tpl"

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *'{{REPO_ROWS}}'*)
        for spec in "$@"; do
          label="${spec%%=*}"
          path="${spec#*=}"
          path="$(abspath "$path")" || die "cannot resolve repo path: $path"
          printf '| %s | %s |\n' "$label" "$path"
        done
        ;;
      *)
        line="${line//\{\{DOC_ROOT\}\}/$doc_root}"
        line="${line//\{\{FEATURE_DOC\}\}/$feature_doc}"
        line="${line//\{\{CHANGELOG\}\}/$changelog}"
        printf '%s\n' "$line"
        ;;
    esac
  done < "$tpl"
}

# seed_docs <doc_root> <changelog_rel>
seed_docs() {
  local doc_root="$1" changelog_rel="$2"
  local assets backlog dest
  resolve_source
  assets="$STANDARDS_ROOT/skills/req-workflow/assets"
  [ -d "$assets" ] || die "assets missing: $assets"

  backlog="$doc_root/backlog"
  mkdir -p "$backlog"

  _seed_one() {
    local src="$1" dest="$2"
    if [ -e "$dest" ]; then
      log "  skip (exists): $dest"
      return 0
    fi
    cp "$src" "$dest"
    ok "  seeded $dest"
  }

  _seed_one "$assets/REQ-index.stub.md"   "$backlog/REQ-index.md"
  _seed_one "$assets/_template.md"        "$backlog/_template.md"
  _seed_one "$assets/backlog-README.md"   "$backlog/README.md"
  _seed_one "$assets/changelog.stub.md"   "$doc_root/$changelog_rel"
}

cmd_configure_req() {
  local target="${1:-.}"
  target="$(abspath "$target")" || die "invalid target: ${1:-.}"
  [ -d "$target" ] || die "target directory does not exist: $target"

  # Defaults
  OPT_FEATURE_DOC="${OPT_FEATURE_DOC:-}"
  OPT_CHANGELOG="${OPT_CHANGELOG:-}"
  OPT_DOC_ROOT="${OPT_DOC_ROOT:-}"
  OPT_SEED_DOCS="${OPT_SEED_DOCS:-0}"
  OPT_FORCE="${OPT_FORCE:-0}"

  interactive_fill

  [ -n "${OPT_DOC_ROOT:-}" ] || die "missing --doc-root (or provide interactively on a TTY)"
  [ "${#OPT_REPOS[@]}" -ge 1 ] || die "need at least one --repo label=/path (or provide interactively)"

  OPT_FEATURE_DOC="${OPT_FEATURE_DOC:-项目功能需求文档.md}"
  OPT_CHANGELOG="${OPT_CHANGELOG:-changelog.md}"

  local doc_root
  doc_root="$(abspath "$OPT_DOC_ROOT")" || die "invalid --doc-root: $OPT_DOC_ROOT"
  [ -d "$doc_root" ] || die "doc-root does not exist: $doc_root"

  local spec resolved_repos=()
  for spec in "${OPT_REPOS[@]}"; do
    validate_repo_spec "$spec"
    # Normalize to label=abspath
    local label path
    label="${spec%%=*}"
    path="$(abspath "${spec#*=}")"
    resolved_repos+=("${label}=${path}")
  done

  local cursor_dir="$target/.cursor"
  local out="$cursor_dir/$REQ_LOCAL_MDC"
  mkdir -p "$(dirname "$out")"

  if [ -f "$out" ] && [ "$OPT_FORCE" != "1" ]; then
    die "already exists: $out (pass --force to overwrite)"
  fi

  info "Writing REQ workflow local config -> $out"
  render_local_mdc "$doc_root" "$OPT_FEATURE_DOC" "$OPT_CHANGELOG" "${resolved_repos[@]}" > "$out"
  ok "wrote $REQ_LOCAL_MDC"

  if [ "$OPT_SEED_DOCS" = "1" ]; then
    info "Seeding doc stubs under $doc_root (skip existing)"
    seed_docs "$doc_root" "$OPT_CHANGELOG"
  fi

  ok "configure-req complete."
  log "  Agents will read .cursor/$REQ_LOCAL_MDC for doc/code paths."
  log "  Next: use Cursor prompts like「按工作流登记需求」/「按 REQ-xxx 实现」."
}
