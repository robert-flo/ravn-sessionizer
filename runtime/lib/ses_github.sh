#!/usr/bin/env bash

# Proyectos, miembros e issues de GitHub vía gh, con caché TTL.
# Todo sale de GitHub (no hace falta tener el pj-* clonado): los proyectos
# son los repos pj-* de $SES_GITHUB_OWNER con proyecto.yml, y sus miembros
# las entradas `repo:` de ese archivo.
# shellcheck disable=SC2154 # SES_* globals come from ses_config.sh.

_ses_fresh() {
  local file="$1" ttl="$2" mtime
  [[ -s $file ]] || return 1
  mtime="$(stat -c %Y "$file" 2> /dev/null || echo 0)"
  (($(date +%s) - mtime < ttl))
}

_ses_slug_file() { printf '%s\n' "${1//\//__}"; }

# Miembros declarados en un proyecto.yml (stdin): dueño/nombre por línea.
ses_parse_proyecto_yml() {
  awk '
    /^[^[:space:]#][^:]*:/ { inrepos = ($0 ~ /^repos:/); next }
    inrepos && /^[[:space:]-]*repo:[[:space:]]*/ {
      v = $0; sub(/^[[:space:]-]*repo:[[:space:]]*/, "", v); sub(/[[:space:]]+#.*$/, "", v)
      gsub(/["'\'']/, "", v); gsub(/[[:space:]]/, "", v)
      if (v != "") print v
    }'
}

# JSON [{pj:"dueño/pj-x", repos:["dueño/pj-x","dueño/miembro",...]}].
# Retorno: 0 fresco, 3 caché vieja (gh falló), 1 sin datos.
ses_projects_json() {
  local force="${1:-0}" file tmp raw line name text ex skip
  file="$SES_CACHE_DIR/projects.json"
  if [[ $force != 1 ]] && _ses_fresh "$file" "$SES_PROJECTS_TTL"; then
    cat "$file"
    return 0
  fi
  mkdir -p "$SES_CACHE_DIR"
  tmp="$(mktemp "$file.XXXXXX")"
  # shellcheck disable=SC2016 # $endCursor/$owner son variables de GraphQL.
  if raw="$(gh api graphql --paginate -F owner="$SES_GITHUB_OWNER" -f query='
      query($owner: String!, $endCursor: String) {
        repositoryOwner(login: $owner) {
          repositories(first: 100, after: $endCursor, ownerAffiliations: OWNER) {
            pageInfo { hasNextPage endCursor }
            nodes { name isArchived object(expression: "HEAD:proyecto.yml") { ... on Blob { text } } }
          }
        }
      }' --jq '.data.repositoryOwner.repositories.nodes[]
        | select(.isArchived | not) | select(.name | test("^pj-"; "i"))
        | select(.object.text != null) | [.name, .object.text] | @json' 2> /dev/null)"; then
    {
      while IFS= read -r line; do
        [[ -n $line ]] || continue
        name="$(jq -r '.[0]' <<< "$line")"
        skip=0
        for ex in "${SES_PJ_EXCLUDE[@]}"; do [[ ${name,,} == "${ex,,}" ]] && skip=1; done
        ((skip)) && continue
        text="$(jq -r '.[1]' <<< "$line")"
        { echo "$SES_GITHUB_OWNER/$name"; ses_parse_proyecto_yml <<< "$text"; } \
          | jq -R . | jq -s --arg pj "$SES_GITHUB_OWNER/$name" '{pj: $pj, repos: (unique - [$pj] | [$pj] + .)}'
      done <<< "$raw"
    } | jq -s 'sort_by(.pj)' > "$tmp" && mv "$tmp" "$file" && { cat "$file"; return 0; }
  fi
  rm -f "$tmp"
  if [[ -s $file ]]; then
    cat "$file"
    return 3
  fi
  return 1
}

# Issues abiertos (todos, no solo la etiqueta) de un repo dueño/nombre.
ses_repo_issues_json() {
  local repo="$1" force="${2:-0}" file tmp
  file="$SES_CACHE_DIR/issues/$(_ses_slug_file "$repo").json"
  if [[ $force != 1 ]] && _ses_fresh "$file" "$SES_ISSUE_TTL"; then
    cat "$file"
    return 0
  fi
  mkdir -p "$(dirname "$file")"
  tmp="$(mktemp "$file.XXXXXX")"
  if gh issue list -R "$repo" --state open --limit 200 \
    --json number,title,labels,updatedAt,url > "$tmp" 2> /dev/null && jq -e 'type == "array"' "$tmp" > /dev/null 2>&1; then
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

# Todos los issues de todos los miembros de todos los proyectos, en un solo
# JSON con .pj y .repo; primero los de $SES_ISSUE_LABEL, luego por fecha.
# Retorno: 0 todo fresco, 3 algo salió de caché vieja o faltó.
ses_all_issues_json() {
  local force="${1:-0}" projects rc=0 prc=0 repo work f
  projects="$(ses_projects_json "$force")" || prc=$?
  ((prc == 1)) && { echo '[]'; return 3; }
  ((prc == 3)) && rc=3
  work="$(mktemp -d)"
  while IFS= read -r repo; do
    (
      r=0
      ses_repo_issues_json "$repo" "$force" > "$work/$(_ses_slug_file "$repo").json" || r=$?
      echo "$r" > "$work/$(_ses_slug_file "$repo").rc"
    ) &
  done < <(jq -r '[.[].repos[]] | unique[]' <<< "$projects")
  wait
  for f in "$work"/*.rc; do
    [[ -e $f ]] || continue
    [[ $(cat "$f") == 0 ]] || rc=3
  done
  local pair_pj pair_repo
  {
    while IFS=$'\t' read -r pair_pj pair_repo; do
      f="$work/$(_ses_slug_file "$pair_repo").json"
      [[ -s $f ]] || continue
      jq --arg pj "$pair_pj" --arg repo "$pair_repo" '.[] + {pj: $pj, repo: $repo}' "$f" 2> /dev/null || true
    done < <(jq -r '.[] as $p | $p.repos[] | [$p.pj, .] | @tsv' <<< "$projects")
  } | jq -s --arg label "$SES_ISSUE_LABEL" '
      unique_by([.repo, .number])
      | sort_by([(if any(.labels[]?; .name == $label) then 0 else 1 end), .pj, .repo, -(.number)])'
  rm -rf "$work"
  return "$rc"
}

# Solo caché (para previews: nunca tocar la red ahí). Arg: dir local.
ses_issues_cached_count() {
  local slug file
  slug="$(ses_remote_slug "$1")" || return 1
  file="$SES_CACHE_DIR/issues/$(_ses_slug_file "$slug").json"
  [[ -s $file ]] && jq 'length' "$file" 2> /dev/null
}

# Detalle de un issue: dueño/repo y número.
ses_issue_view() {
  local repo="$1" number="$2" file
  file="$SES_CACHE_DIR/issue/$(_ses_slug_file "$repo")-$number.json"
  if ! _ses_fresh "$file" "$SES_ISSUE_TTL"; then
    mkdir -p "$(dirname "$file")"
    if gh issue view "$number" -R "$repo" --json number,title,body,labels,author,url > "$file.tmp" 2> /dev/null; then
      mv "$file.tmp" "$file"
    else
      rm -f "$file.tmp"
    fi
  fi
  [[ -s $file ]] && cat "$file"
}

# Lee un JSON de gh con caché TTL. Args: archivo ttl force comando...
# Retorno: 0 fresco, 3 caché vieja (gh falló), 1 sin datos.
_ses_cached_gh() {
  local file="$1" ttl="$2" force="$3" tmp
  shift 3
  if [[ $force != 1 ]] && _ses_fresh "$file" "$ttl"; then
    cat "$file"
    return 0
  fi
  mkdir -p "$(dirname "$file")"
  tmp="$(mktemp "$file.XXXXXX")"
  if "$@" > "$tmp" 2> /dev/null && jq -e 'type == "array"' "$tmp" > /dev/null 2>&1; then
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

# Todos los repos de $SES_GITHUB_OWNER (vista repos / alias rs).
ses_owner_repos_json() {
  _ses_cached_gh "$SES_CACHE_DIR/owner-repos.json" "$SES_PROJECTS_TTL" "${1:-0}" \
    gh repo list "$SES_GITHUB_OWNER" --limit 1000 \
    --json nameWithOwner,name,description,isPrivate,isFork,isArchived,pushedAt,url
}

# Todos los issues abiertos de los repos de $SES_GITHUB_OWNER (vista issues /
# alias ri), con .repo = dueño/nombre.
ses_owner_issues_json() {
  local file="$SES_CACHE_DIR/owner-issues.json" rc=0 json
  json="$(_ses_cached_gh "$file" "$SES_ISSUE_TTL" "${1:-0}" \
    gh search issues --owner "$SES_GITHUB_OWNER" --state open --limit 1000 \
    --json repository,number,title,labels,createdAt,updatedAt,url)" || rc=$?
  ((rc == 1)) && { echo '[]'; return 1; }
  jq 'map(. + {repo: .repository.nameWithOwner})' <<< "$json"
  return "$rc"
}
