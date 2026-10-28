#!/usr/bin/env bash
# Clonado: el default es fijo (`try exec --path {root} clone {url} | bash`).
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

fallo() { echo "FALLO: $*" >&2; exit 1; }
resuelve() { bash -c 'source "$1" && ses_clone_cmd_default' _ "$1"; }

out="$(resuelve "$aqui/runtime/lib/ses_sources.sh")"
[[ $out == "try exec --path {root} clone {url} | bash" ]] || fallo "default esperado try exec --path {root} clone {url} | bash; salió: $out"

echo "ok test-clone"
