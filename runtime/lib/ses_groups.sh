#!/usr/bin/env bash

# Picker jerárquico de repos/issues/ri: proyecto pj-* → repo miembro (o todos) →
# issue/repo. Los grupos salen de ses_projects_json (GitHub, sin clonar el
# pj-*); los repos que no son miembro de ningún pj-* van al grupo «sin pj».
# shellcheck disable=SC2154 # S_* y SES_* vienen de ses_fzf.sh y ses_config.sh.

readonly SES_NO_PJ="-"

# Grupos. Args: projects_json extra_repos_json(array de dueño/nombre)
# issues_json(array con .repo). Salida: [{key, name, repos, count}] con
# count = issues abiertos de sus repos; «sin pj» (key "-") al final si hay.
ses_groups_json() {
  # JSON por --slurpfile (no --argjson): con ~130 repos y cientos de issues el
  # payload supera ARG_MAX y exec falla con «Argument list too long».
  jq -n --slurpfile p <(printf '%s' "$1") --slurpfile extra <(printf '%s' "$2") \
    --slurpfile is <(printf '%s' "$3") --arg none "$SES_NO_PJ" '
    $p[0] as $p | $extra[0] as $extra | $is[0] as $is
    | ($is | map(.repo | ascii_downcase) | group_by(.) | map({(.[0]): length}) | add // {}) as $cnt
    | ([$p[].repos[] | ascii_downcase] | unique) as $members
    | def total($rs): [$rs[] | $cnt[ascii_downcase] // 0] | add // 0;
      ($p | map({key: .pj, name: (.pj | split("/")[1]), repos: .repos, count: total(.repos)}))
      + ([$extra[], ($is[].repo)] | map(select(. != null))
         | unique_by(ascii_downcase) | map(select((ascii_downcase | IN($members[])) | not))
         | if length > 0 then [{key: $none, name: "sin pj", repos: ., count: total(.)}] else [] end)'
}

# Filas fzf de los grupos (nivel 1).
ses_group_rows() {
  jq -r --arg w "$S_WHITE" --arg g "$S_GRAY" --arg c "$S_CYAN" --arg y "$S_YELLOW" --arg n "$S_NC" \
    --arg none "$SES_NO_PJ" '.[]
    | ["group", .key,
       (if .key == $none then $y + "○ " else $c + "◆ " end) + $n + $w + .name + $n
       + "  " + (if .count > 0 then $c else $g end) + "\(.count) issues" + $n
       + "  " + $g + "\(.repos | length) repos"
       + (if .key == $none then " · sin trío" else "" end) + $n] | @tsv' <<< "$1"
}

# Repos de un grupo (array JSON). Args: groups_json key.
ses_group_repos() {
  jq -c --arg k "$2" '[.[] | select(.key == $k) | .repos[]]' <<< "$1"
}

# Índice (1-based) del grupo que contiene al repo actual: el pj que ES el repo
# gana; si no, el primero que lo tiene como miembro. Vacío si ninguno.
ses_group_index_of() {
  [[ -n $2 ]] || return 0
  jq -r --arg r "${2,,}" '
    to_entries
    | (map(select((.value.key | ascii_downcase) == $r)) + map(select(any(.value.repos[]; ascii_downcase == $r))))
    | .[0].key // empty | if . == "" then empty else . + 1 end' <<< "$1"
}

# pj-* del trío de un repo: preferido (si es miembro) → el pj que es el repo
# → el primero que lo declara. Vacío = no tiene trío.
ses_pj_of() {
  local projects="$1" repo="$2" prefer="${3:-}"
  jq -r --arg r "${repo,,}" --arg p "${prefer,,}" '
    [.[] | select(any(.repos[]; ascii_downcase == $r))]
    | (map(select((.pj | ascii_downcase) == $p)) + map(select((.pj | ascii_downcase) == $r)) + .)
    | .[0].pj // empty' <<< "$projects" 2> /dev/null || true
}

# Espera una tecla si hay terminal (para que se lea un mensaje antes de volver
# al picker); sin tty sigue de largo.
ses_pause() {
  if [[ -t 2 ]] && { : < /dev/tty; } 2> /dev/null; then
    read -rsn1 -p "${S_GRAY}tecla para volver…${S_NC}" < /dev/tty || true
    printf '\n' >&2
  fi
}
