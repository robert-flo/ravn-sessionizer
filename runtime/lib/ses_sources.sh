#!/usr/bin/env bash

# Fuentes del picker: raíces de clones, miembros de pj-*, historial y frecencia.
# shellcheck disable=SC2154 # SES_* globals come from ses_config.sh.

# dueño/nombre del remoto origin (los clones de `try clone` llevan fecha en el
# nombre del directorio, así que el nombre real sale del remoto).
ses_remote_slug() {
  local url
  url="$(git -C "$1" config --get remote.origin.url 2> /dev/null)" || return 1
  url="${url%.git}"
  url="${url%/}"
  [[ $url == *[:/]*/* ]] || return 1
  printf '%s/%s\n' "$(basename "$(dirname "${url//://}")")" "$(basename "$url")"
}

ses_is_pj() {
  local slug
  [[ $(basename "$1") == pj-* ]] && return 0
  slug="$(ses_remote_slug "$1" 2> /dev/null)" || return 1
  [[ ${slug#*/} == pj-* ]]
}

# Directorio local de un repo dueño/nombre: busca por remoto en las raíces
# (hijos y nietos, como deja try-clone los miembros) y en los extra.
ses_find_local() {
  local want="${1,,}" root d slug
  for root in "${SES_ROOTS[@]}" "${SES_EXTRA[@]}"; do
    [[ -d $root ]] || continue
    for d in "$root" "$root"/*/ "$root"/*/*/; do
      d="${d%/}"
      [[ -e $d/.git ]] || continue
      slug="$(ses_remote_slug "$d")" || continue
      [[ ${slug,,} == "$want" ]] && { printf '%s\n' "$d"; return 0; }
    done
  done
  return 1
}

# Clona dueño/nombre con $SES_CLONE_CMD ({url} {repo} {owner} {name} {root})
# y devuelve dónde quedó.
ses_clone() {
  local repo="$1" cmd root="${SES_CLONE_ROOT:-${SES_ROOTS[0]}}"
  cmd="$SES_CLONE_CMD"
  cmd="${cmd//\{url\}/https://github.com/$repo.git}"
  cmd="${cmd//\{repo\}/$repo}"
  cmd="${cmd//\{owner\}/${repo%%/*}}"
  cmd="${cmd//\{name\}/${repo#*/}}"
  cmd="${cmd//\{root\}/$root}"
  mkdir -p "$root"
  print_step "clonando $repo: $cmd" >&2
  (cd "$root" && bash -c "$cmd") >&2 || return 1
  ses_find_local "$repo"
}

ses_ensure_local() {
  ses_find_local "$1" || ses_clone "$1"
}

ses_is_repo() {
  [[ -e $1/.git ]]
}

# Miembros de un pj-*: primero el archivo de miembros (uno por línea: ruta
# absoluta, subdirectorio del pj o nombre de un clon en alguna raíz), luego
# los repos git anidados dentro del pj.
ses_members() {
  local pj="$1" line root d
  {
    if [[ -r $pj/$SES_MEMBERS_FILE ]]; then
      while IFS= read -r line || [[ -n $line ]]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z $line ]] && continue
        if [[ $line == /* ]]; then
          [[ -d $line ]] && printf '%s\n' "$line"
        elif [[ -d $pj/$line ]]; then
          printf '%s\n' "$pj/$line"
        else
          for root in "${SES_ROOTS[@]}"; do
            [[ -d $root/$line ]] && { printf '%s\n' "$root/$line"; break; }
          done
        fi
      done < "$pj/$SES_MEMBERS_FILE"
    fi
    for d in "$pj"/*/; do
      d="${d%/}"
      [[ -d $d ]] && ses_is_repo "$d" && printf '%s\n' "$d"
    done
  } | awk '!seen[$0]++'
}

# Todos los directorios buscables: hijos git de cada raíz, miembros anidados
# en cada pj-* y los extra. Sin caché: es un `ls` de un nivel (milisegundos).
ses_repo_dirs() {
  local root d
  {
    for root in "${SES_ROOTS[@]}"; do
      [[ -d $root ]] || continue
      for d in "$root"/*/; do
        d="${d%/}"
        if [[ ! -d $d ]] || ! ses_is_repo "$d"; then continue; fi
        printf '%s\n' "$d"
        if ses_is_pj "$d"; then ses_members "$d"; fi
      done
    done
    for d in "${SES_EXTRA[@]}"; do
      [[ -d $d ]] && printf '%s\n' "$d"
      if [[ -d $d ]] && ses_is_pj "$d"; then ses_members "$d"; fi
    done
  } | awk '!seen[$0]++'
}

# Nombre corto: relativo a su raíz (pj-x/miembro) o basename para extras.
ses_short_name() {
  local dir="$1" root
  for root in "${SES_ROOTS[@]}"; do
    if [[ $dir == "$root"/* ]]; then
      printf '%s\n' "${dir#"$root"/}"
      return 0
    fi
  done
  for root in "${SES_EXTRA[@]}"; do
    if [[ $dir == "$root"/* ]]; then
      printf '%s/%s\n' "$(basename "$root")" "${dir#"$root"/}"
      return 0
    fi
  done
  basename "$dir"
}

# Si dir vive dentro de un pj-* (o es uno), imprime el pj.
ses_pj_of() {
  local dir="$1"
  while [[ -n $dir && $dir != / ]]; do
    if ses_is_pj "$dir" && ses_is_repo "$dir"; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

ses_record_history() {
  local dir="$1"
  [[ -n $dir ]] || return 0
  mkdir -p "$SES_STATE_DIR"
  printf '%s\t%s\n' "${EPOCHSECONDS:-$(date +%s)}" "$dir" >> "$SES_HISTORY_FILE"
  # Poda barata: el historial nunca pasa de ~2000 líneas.
  if (($(wc -l < "$SES_HISTORY_FILE") > 2000)); then
    tail -n 1000 "$SES_HISTORY_FILE" > "$SES_HISTORY_FILE.tmp" && mv "$SES_HISTORY_FILE.tmp" "$SES_HISTORY_FILE"
  fi
}

# Frecencia: suma de 0.5^(edad / vida media). Imprime "score<TAB>último<TAB>dir".
ses_frecency() {
  [[ -r $SES_HISTORY_FILE ]] || return 0
  awk -F'\t' -v now="${EPOCHSECONDS:-$(date +%s)}" -v hl="$SES_HALF_LIFE_DAYS" '
    { s[$2] += 0.5 ^ ((now - $1) / (hl * 86400)); if ($1 > last[$2]) last[$2] = $1 }
    END { for (d in s) printf "%.6f\t%d\t%s\n", s[d], last[d], d }
  ' "$SES_HISTORY_FILE"
}
