#!/usr/bin/env bash
# Entorno aislado para las pruebas: raíces temporales, stubs primero en PATH.
# shellcheck disable=SC2034 # Variables consumed by the sourcing tests.
set -euo pipefail

aqui="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export STUB_DIR="$tmp/stub" STUB_LOG="$tmp/stub/log" STUB_SNAPSHOT="$tmp/snapshot.json"
export STUB_FZF_SCRIPT="$tmp/fzf-script" STUB_GH_ISSUES="$tmp/issues.json"
mkdir -p "$STUB_DIR"
: > "$STUB_LOG"
export PATH="$aqui/tests/stubs:$PATH"
export RAVN_SESSIONIZER_CONFIG="$tmp/sessionizer.conf"
export RAVN_SESSIONIZER_STATE_DIR="$tmp/state" RAVN_SESSIONIZER_CACHE_DIR="$tmp/cache"
export NO_COLOR=1
unset HERDR_BIN_PATH HERDR_PLUGIN_ID HERDR_PLUGIN_ENTRYPOINT_ID HERDR_PLUGIN_CONTEXT_JSON HERDR_ACTIVE_PANE_CWD RAVN_SESSIONIZER_MODE RAVN_SESSIONIZER_CWD

root="$tmp/tries"
mkrepo() { mkdir -p "$1" && git init -q "$1"; }
mkrepo "$root/alpha"
mkrepo "$root/beta"
mkrepo "$root/pj-demo"
mkrepo "$root/pj-demo/m1"
mkdir -p "$root/pj-demo/.ravn" && echo "beta  # clon de la raíz" > "$root/pj-demo/.ravn/miembros"
mkdir -p "$root/no-git"
mkrepo "$tmp/extra/pj-omarchy"

cat > "$RAVN_SESSIONIZER_CONFIG" << CONF
SES_ROOTS=("$root")
SES_EXTRA=("$tmp/extra/pj-omarchy")
SES_TRIO_BIN=pj-trio
CONF

# Snapshot: un workspace abierto sobre alpha.
cat > "$STUB_SNAPSHOT" << JSON
{"result":{"snapshot":{
  "workspaces":[{"workspace_id":"w1","label":"alpha","focused":false,"agent_status":"blocked","number":1}],
  "tabs":[{"tab_id":"w1:1","workspace_id":"w1","label":"main","number":1}],
  "panes":[{"pane_id":"w1:1:1","workspace_id":"w1","tab_id":"w1:1","cwd":"$root/alpha","agent":"claude","agent_status":"blocked","focused":false}]
}}}
JSON
echo '[{"number":7,"title":"Arreglar login","labels":[{"name":"ready-for-agent"},{"name":"repo:m1"}],"updatedAt":"","url":"u"}]' > "$STUB_GH_ISSUES"

bin="$aqui/ravn-sessionizer"
fallo() { echo "FALLO: $*" >&2; exit 1; }
fzf_script() { printf '%s\n' "$@" > "$STUB_FZF_SCRIPT"; rm -f "$STUB_DIR/fzf.n"; }
