#!/usr/bin/env bash
# configure-admin-ux.sh — seed project checklist and generate admin-ux.local.mdc
# from $STANDARDS_HOME/catalogs/admin-ux-options.md (central source, not copied).
# Does NOT touch managed standards/ trees.

ADMIN_UX_SELECT=".cursor/admin-ux.select.md"
ADMIN_UX_LOCAL_MDC="rules/admin-ux.local.mdc"

# catalog_path — resolve catalogs/admin-ux-options.md under STANDARDS_ROOT
catalog_path() {
  resolve_source
  local p="$STANDARDS_ROOT/catalogs/admin-ux-options.md"
  [ -f "$p" ] || die "catalog missing: $p (set STANDARDS_HOME or --source)"
  printf '%s\n' "$p"
}

# parse_catalog <catalog> <outdir>
# Writes:
#   outdir/ids          — ordered id list
#   outdir/<id>.kind    — flag | choice
#   outdir/<id>.title
#   outdir/<id>.choices — comma list (choice only)
#   outdir/<id>.rule            — flag body
#   outdir/<id>.rule.<choice>   — choice body
parse_catalog() {
  local catalog="$1" outdir="$2"
  mkdir -p "$outdir"
  : > "$outdir/ids"

  local line in_option=0 in_rule=0
  local cur_id="" cur_kind="" cur_title="" cur_choices="" rule_choice="" rule_buf=""
  local key val

  _flush_rule() {
    [ -n "$cur_id" ] || return 0
    if [ "$in_rule" = "1" ]; then
      if [ -n "$rule_choice" ]; then
        printf '%s' "$rule_buf" > "$outdir/${cur_id}.rule.${rule_choice}"
      else
        printf '%s' "$rule_buf" > "$outdir/${cur_id}.rule"
      fi
    fi
    in_rule=0
    rule_choice=""
    rule_buf=""
  }

  _flush_option_meta() {
    [ -n "$cur_id" ] || return 0
    printf '%s\n' "$cur_id" >> "$outdir/ids"
    printf '%s\n' "$cur_kind" > "$outdir/${cur_id}.kind"
    printf '%s\n' "$cur_title" > "$outdir/${cur_id}.title"
    if [ "$cur_kind" = "choice" ]; then
      printf '%s\n' "$cur_choices" > "$outdir/${cur_id}.choices"
    fi
  }

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '```option')
        _flush_rule
        in_option=1
        cur_id=""; cur_kind=""; cur_title=""; cur_choices=""
        continue
        ;;
      '```rule'|'```rule:'*)
        _flush_rule
        in_rule=1
        rule_buf=""
        if [ "$line" = '```rule' ]; then
          rule_choice=""
        else
          rule_choice="${line#\`\`\`rule:}"
        fi
        continue
        ;;
      '```')
        if [ "$in_option" = "1" ]; then
          in_option=0
          [ -n "$cur_id" ] || die "catalog option missing id"
          [ -n "$cur_kind" ] || die "catalog option $cur_id missing kind"
          [ -n "$cur_title" ] || die "catalog option $cur_id missing title"
          if [ "$cur_kind" = "choice" ]; then
            [ -n "$cur_choices" ] || die "catalog option $cur_id missing choices"
          fi
          _flush_option_meta
        elif [ "$in_rule" = "1" ]; then
          _flush_rule
        fi
        continue
        ;;
    esac

    if [ "$in_option" = "1" ]; then
      key="${line%%:*}"
      val="${line#*: }"
      [ "$val" = "$line" ] && val="${line#*:}"
      case "$key" in
        id) cur_id="$val" ;;
        kind) cur_kind="$val" ;;
        title) cur_title="$val" ;;
        choices) cur_choices="$val" ;;
      esac
      continue
    fi

    if [ "$in_rule" = "1" ]; then
      rule_buf+="$line"$'\n'
    fi
  done < "$catalog"

  _flush_rule
  [ -s "$outdir/ids" ] || die "catalog parsed zero options: $catalog"
}

# choice_valid <id_outdir> <id> <choice> — 0 if choice listed
choice_valid() {
  local outdir="$1" id="$2" choice="$3"
  local list
  list=",$(tr -d ' \t\r\n' < "$outdir/${id}.choices"),"
  case "$list" in
    *",$choice,"*) return 0 ;;
    *) return 1 ;;
  esac
}

# seed_select <select_path> <parsed_outdir> — write checklist stub
seed_select() {
  local select_path="$1" parsed="$2"
  local id kind title choices first tmp
  mkdir -p "$(dirname "$select_path")"
  {
    cat <<'EOF'
# Admin UX 项目勾选

> 由 `cursor-std configure-admin-ux --seed` 生成。  
> 勾选后运行：`cursor-std configure-admin-ux` → 生成 `.cursor/rules/admin-ux.local.mdc`。  
> 正文来自中央目录（`STANDARDS_HOME/catalogs/admin-ux-options.md`），**不要**在本文件写 rule 正文。  
> `install` / `update` / `remove` **不会**删除本文件或生成的 local mdc。

## 用法

- 开关项：`- [x] B1`
- 带做法项：`- [x] C2=click-search`（必须 `ID=choice`）
- 取消：改回 `- [ ] …`

## 勾选

EOF
    while IFS= read -r id || [ -n "$id" ]; do
      [ -n "$id" ] || continue
      kind="$(tr -d '\r\n' < "$parsed/${id}.kind")"
      title="$(tr -d '\r\n' < "$parsed/${id}.title")"
      if [ "$kind" = "choice" ]; then
        choices="$(tr -d ' \t\r\n' < "$parsed/${id}.choices")"
        first="${choices%%,*}"
        printf -- '- [ ] %s=%s  # %s（可选：%s）\n' "$id" "$first" "$title" "$choices"
      else
        printf -- '- [ ] %s  # %s\n' "$id" "$title"
      fi
    done < "$parsed/ids"
    printf '\n'
  } > "$select_path"
}

# parse_select <select_path> <parsed_outdir> <enabled_file>
# enabled_file lines: ID or ID=choice for checked items; validates against catalog.
parse_select() {
  local select_path="$1" parsed="$2" enabled_file="$3"
  local line checked rest id choice kind
  : > "$enabled_file"
  local errors=0

  while IFS= read -r line || [ -n "$line" ]; do
    # Prefix "- [x] " / "- [X] " is 6 chars; do not use ${var#…[x]…} (glob class).
    case "$line" in
      '- [x] '*|'- [X] '*)
        rest="${line:6}"
        ;;
      '- [ ] '*)
        continue
        ;;
      *)
        continue
        ;;
    esac

    # strip trailing comment
    rest="${rest%%#*}"
    # trim
    rest="$(printf '%s' "$rest" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -n "$rest" ] || continue

    id="${rest%%=*}"
    if [ "$rest" = "$id" ]; then
      choice=""
    else
      choice="${rest#*=}"
    fi

    if [ ! -f "$parsed/${id}.kind" ]; then
      err "unknown id in select: $id"
      errors=$((errors + 1))
      continue
    fi
    kind="$(tr -d '\r\n' < "$parsed/${id}.kind")"

    if [ "$kind" = "flag" ]; then
      if [ -n "$choice" ]; then
        err "$id is a flag; do not use '=' (got $rest)"
        errors=$((errors + 1))
        continue
      fi
      if [ ! -f "$parsed/${id}.rule" ]; then
        err "catalog missing rule body for $id"
        errors=$((errors + 1))
        continue
      fi
      printf '%s\n' "$id" >> "$enabled_file"
    else
      if [ -z "$choice" ]; then
        err "$id requires a choice: use - [x] $id=<choice>"
        errors=$((errors + 1))
        continue
      fi
      if ! choice_valid "$parsed" "$id" "$choice"; then
        err "invalid choice for $id: '$choice' (allowed: $(tr -d '\r\n' < "$parsed/${id}.choices"))"
        errors=$((errors + 1))
        continue
      fi
      if [ ! -f "$parsed/${id}.rule.${choice}" ]; then
        err "catalog missing rule:$choice for $id"
        errors=$((errors + 1))
        continue
      fi
      printf '%s=%s\n' "$id" "$choice" >> "$enabled_file"
    fi
  done < "$select_path"

  [ "$errors" -eq 0 ] || die "fix select has $errors error(s); fix and re-run"
}

# render_local_mdc <parsed> <enabled_file> > stdout
render_admin_ux_local_mdc() {
  local parsed="$1" enabled_file="$2"
  local entry id choice title body

  cat <<'EOF'
---
description: 本项目管理后台可选交互（由 configure-admin-ux 根据勾选生成）
globs: **/*.{ts,tsx,js,jsx,vue}
alwaysApply: false
---

# 管理后台可选约定（本项目）

> 由 `cursor-std configure-admin-ux` 生成。勾选源：`.cursor/admin-ux.select.md`。  
> **基线**见 `.cursor/rules/standards/std-admin-ux.mdc`。升级中央目录文案后重新 generate 即可；`install`/`update` 不覆盖本文件。

EOF

  if [ ! -s "$enabled_file" ]; then
    cat <<'EOF'
（当前无勾选项。编辑 `.cursor/admin-ux.select.md` 后重新运行 `cursor-std configure-admin-ux`。）
EOF
    return 0
  fi

  while IFS= read -r entry || [ -n "$entry" ]; do
    [ -n "$entry" ] || continue
    id="${entry%%=*}"
    if [ "$entry" = "$id" ]; then
      choice=""
      body="$(cat "$parsed/${id}.rule")"
    else
      choice="${entry#*=}"
      body="$(cat "$parsed/${id}.rule.${choice}")"
    fi
    title="$(tr -d '\r\n' < "$parsed/${id}.title")"
    printf '## %s · %s\n\n' "$id" "$title"
    if [ -n "$choice" ]; then
      printf -- '- 本项目取值：`%s`\n\n' "$choice"
    fi
    # body already ends with newline from catalog
    printf '%s' "$body"
    printf '\n'
  done < "$enabled_file"
}

cmd_configure_admin_ux() {
  local target="${1:-.}"
  target="$(abspath "$target")" || die "invalid target: ${1:-.}"
  [ -d "$target" ] || die "target directory does not exist: $target"

  OPT_SEED="${OPT_SEED:-0}"
  OPT_FORCE="${OPT_FORCE:-0}"

  local catalog work
  catalog="$(catalog_path)"
  work="$(mktemp -d "${TMPDIR:-/tmp}/admin-ux-parse.XXXXXX")"

  info "Parsing catalog -> $catalog"
  parse_catalog "$catalog" "$work/parsed"

  local select_path="$target/$ADMIN_UX_SELECT"
  local out_mdc="$target/.cursor/$ADMIN_UX_LOCAL_MDC"

  if [ "$OPT_SEED" = "1" ]; then
    if [ -f "$select_path" ] && [ "$OPT_FORCE" != "1" ]; then
      rm -rf "$work"
      die "already exists: $select_path (pass --force to overwrite checklist)"
    fi
    info "Seeding checklist -> $select_path"
    seed_select "$select_path" "$work/parsed"
    ok "wrote $ADMIN_UX_SELECT"
    log "  Edit checkboxes, then run: cursor-std configure-admin-ux $target"
    rm -rf "$work"
    return 0
  fi

  if [ ! -f "$select_path" ]; then
    rm -rf "$work"
    die "missing $select_path — run: cursor-std configure-admin-ux --seed"
  fi

  parse_select "$select_path" "$work/parsed" "$work/enabled"

  mkdir -p "$(dirname "$out_mdc")"
  info "Generating -> $out_mdc"
  render_admin_ux_local_mdc "$work/parsed" "$work/enabled" > "$out_mdc"
  ok "wrote $ADMIN_UX_LOCAL_MDC"

  local n=0
  if [ -s "$work/enabled" ]; then
    n="$(wc -l < "$work/enabled" | tr -d ' ')"
  fi
  log "  enabled entries: $n"
  log "  Agents pick up .cursor/$ADMIN_UX_LOCAL_MDC together with standards/std-admin-ux.mdc."
  rm -rf "$work"
}
