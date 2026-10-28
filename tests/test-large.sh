#!/usr/bin/env bash
# Regresión ARG_MAX: con muchos repos/issues (JSON > 2 MB) ri y rs no deben
# pasar el JSON como argumento de jq («Argument list too long»).
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

pad="$(printf 'x%.0s' {1..2000})"
jq -nc --arg pad "$pad" '[range(0; 1500) | {repository: {nameWithOwner: "robert-flo/r\(. % 150)"},
  number: ., title: "Issue \(.) \($pad)", labels: [], createdAt: "2026-03-01T00:00:00Z", updatedAt: "", url: "u"}]' \
  > "$STUB_DIR/search-issues.json"
jq -nc --arg pad "$pad" '[range(0; 150) | {nameWithOwner: "robert-flo/r\(.)", name: "r\(.)", description: $pad,
  isPrivate: false, isFork: false, isArchived: false, pushedAt: "2026-01-01T00:00:00Z", url: "u"}]' \
  > "$STUB_DIR/repos.json"
(($(wc -c < "$STUB_DIR/search-issues.json") > 2000000)) || fallo "fixture > 2 MB"

fzf_script $'||sin pj' $'||todos' $'||CANCEL' $'||CANCEL' $'||CANCEL'
out="$("$bin" issues 2>&1)" || true
grep -q 'Argument list too long' <<< "$out" && fallo "ri: ARG_MAX: $out"
grep -q $'^group\t-\t.*sin pj  1500 issues  150 repos' "$STUB_DIR/fzf-in-1" || fallo "ri grupos: $out $(head -c 500 "$STUB_DIR/fzf-in-1")"
[[ $(wc -l < "$STUB_DIR/fzf-in-2") == 151 ]] || fallo "ri: todos + 150 repos"

fzf_script $'||sin pj' $'||CANCEL' $'||CANCEL'
out="$("$bin" repos 2>&1)" || true
grep -q 'Argument list too long' <<< "$out" && fallo "rs: ARG_MAX: $out"
grep -q $'^group\t-\t.*sin pj' "$STUB_DIR/fzf-in-1" || fallo "rs grupos: $out"
echo "ok large"
