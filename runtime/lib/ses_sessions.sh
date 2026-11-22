#!/usr/bin/env bash

# Operaciones sobre sesiones persistentes de herdr y directorios HR-*.
# shellcheck disable=SC2154 # HERDR, SES_* y S_* vienen de ses_config.sh y ses_fzf.sh.

ses_herdr_sessions_json() {
  "$HERDR" session list --json 2> /dev/null || printf '{"sessions":[]}\n'
}

ses_is_attached() {
  [[ -n ${HERDR_ENV:-} || -n ${HERDR_SOCKET_PATH:-} ]]
}

ses_session_category() {
  local name="$1"
  if [[ ${name,,} =~ ^hr- ]] || [[ $name == scratchpad || $name == default ]]; then
    printf 'stable\n'
  else
    printf 'ephemeral\n'
  fi
}

# Directorios disponibles para crear nueva sesión: exclusivamente /z-home-repos/HR-*
# (sin zoxide ni find ~).
ses_hr_dirs() {
  local base="${SES_HOME_REPOS_DIR:-/z-home-repos}" d
  [[ -d $base ]] || return 0
  for d in "$base"/HR-*/; do
    d="${d%/}"
    [[ -d $d ]] && printf '%s\n' "$d"
  done | sort
}

ses_session_row() {
  local name="$1" running="$2" category="$3" icon color status_label cat_label
  if [[ $running == true ]]; then
    icon="$SES_ICON_OPEN"
    color="$S_GREEN"
    status_label="running"
  else
    icon="○"
    color="$S_GRAY"
    status_label="stopped"
  fi
  if [[ $category == stable ]]; then
    cat_label="estable"
  else
    cat_label="efímera"
  fi
  ses_row session "$name" \
    "${color}${icon}${S_NC}  ${S_WHITE}${name}${S_NC}  ${S_GRAY}${cat_label} · ${status_label}${S_NC}"
}

ses_session_sep_row() {
  ses_row sep "" "${S_GRAY}———${S_NC}"
}

# Genera las filas para fzf:
#   Estables (HR-*, scratchpad, default)
#   ———
#   Efímeras (specs activos)
#   ———
#   Directorios /z-home-repos/HR-* (solo si active_only == 0)
ses_session_rows() {
  local active_only="${1:-0}" json name running cat
  local stable_rows="" ephemeral_rows="" dir_rows=""
  declare -A existing_sessions=()

  json="$(ses_herdr_sessions_json)"
  while IFS=$'\t' read -r name running; do
    [[ -n $name ]] || continue
    existing_sessions[$name]=1
    if [[ $active_only == 1 && $running != true ]]; then
      continue
    fi
    cat="$(ses_session_category "$name")"
    if [[ $cat == stable ]]; then
      stable_rows+="$(ses_session_row "$name" "$running" "$cat")"$'\n'
    else
      ephemeral_rows+="$(ses_session_row "$name" "$running" "$cat")"$'\n'
    fi
  done < <(jq -r '.sessions[]? | [.name, ((.running // false) | tostring)] | @tsv' <<< "$json" 2> /dev/null || true)

  if [[ $active_only == 0 ]]; then
    local dir base
    while IFS= read -r dir; do
      [[ -n $dir ]] || continue
      base="$(basename "$dir")"
      [[ -n ${existing_sessions[$base]:-} ]] && continue
      dir_rows+="$(ses_row dir "$dir" \
        "${S_MAGENTA}${ICON_PACKAGE}${S_NC}  ${S_WHITE}${base}${S_NC}  ${S_GRAY}${dir}${S_NC}")"$'\n'
    done < <(ses_hr_dirs)
  fi

  local had_prev=0
  if [[ -n $stable_rows ]]; then
    printf '%s' "$stable_rows"
    had_prev=1
  fi
  if [[ -n $ephemeral_rows ]]; then
    ((had_prev)) && ses_session_sep_row
    printf '%s' "$ephemeral_rows"
    had_prev=1
  fi
  if [[ -n $dir_rows ]]; then
    ((had_prev)) && ses_session_sep_row
    printf '%s' "$dir_rows"
  fi
}

# Abre o adjunta una sesión/directorio según estado attached vs detached en herdr.
ses_session_open() {
  local kind="$1" target="$2" name
  case "$kind" in
    sep | "") return 0 ;;
    session)
      if ses_is_attached; then
        "$HERDR" session attach "$target"
      else
        exec "$HERDR" session attach "$target"
      fi
      ;;
    dir)
      [[ -d $target ]] || ses_fail "no es un directorio: $target"
      name="$(basename "$target")"
      if ses_is_attached; then
        "$HERDR" --session "$name" workspace create --cwd "$target" --label "$name" --focus > /dev/null
        "$HERDR" session attach "$name"
      else
        cd "$target" || ses_fail "no pude entrar a: $target"
        exec "$HERDR" --session "$name"
      fi
      ;;
    *) ses_fail "fila de sesión desconocida: $kind" ;;
  esac
}
