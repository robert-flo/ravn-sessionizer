#!/usr/bin/env bash

# Issues de GitHub vía gh, con caché TTL (la red es lo único lento).
# shellcheck disable=SC2154 # SES_* globals come from ses_config.sh.

_ses_fresh() {
  local file="$1" ttl="$2" mtime
  [[ -s $file ]] || return 1
  mtime="$(stat -c %Y "$file" 2> /dev/null || echo 0)"
  (($(date +%s) - mtime < ttl))
}

# Imprime el JSON de issues abiertos con la etiqueta configurada.
# Retorno: 0 fresco, 3 caché vieja (gh falló), 1 sin datos.
ses_issues_json() {
  local pj="$1" force="${2:-0}" file tmp
  file="$SES_CACHE_DIR/issues/$(basename "$pj").json"
  if [[ $force != 1 ]] && _ses_fresh "$file" "$SES_ISSUE_TTL"; then
    cat "$file"
    return 0
  fi
  mkdir -p "$(dirname "$file")"
  tmp="$(mktemp "$file.XXXXXX")"
  if (cd "$pj" && gh issue list --label "$SES_ISSUE_LABEL" --state open --limit 100 \
    --json number,title,labels,updatedAt,url) > "$tmp" 2> /dev/null && jq -e 'type == "array"' "$tmp" > /dev/null 2>&1; then
    mv "$tmp" "$file"
    cat "$file"
    return 0
  fi
  rm -f "$tmp"
  if [[ -s $file ]]; then
    cat "$file"
    return 3
  fi
  return 1
}

# Solo caché (para previews: nunca tocar la red ahí).
ses_issues_cached_count() {
  local file
  file="$SES_CACHE_DIR/issues/$(basename "$1").json"
  [[ -s $file ]] && jq 'length' "$file" 2> /dev/null
}

ses_issue_view() {
  local pj="$1" number="$2" file
  file="$SES_CACHE_DIR/issue/$(basename "$pj")-$number.json"
  if ! _ses_fresh "$file" "$SES_ISSUE_TTL"; then
    mkdir -p "$(dirname "$file")"
    if (cd "$pj" && gh issue view "$number" --json number,title,body,labels,author,url) > "$file.tmp" 2> /dev/null; then
      mv "$file.tmp" "$file"
    else
      rm -f "$file.tmp"
    fi
  fi
  [[ -s $file ]] && cat "$file"
}
