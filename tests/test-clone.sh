#!/usr/bin/env bash
# Clonado: comando por defecto (tries si está en el PATH, si no try).
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

fallo() { echo "FALLO: $*" >&2; exit 1; }
resuelve() { bash -c 'source "$1" && ses_clone_cmd_default' _ "$1"; }

# Con el stub de tries en el PATH, el default es tries.
out="$(resuelve "$aqui/runtime/lib/ses_sources.sh")"
[[ $out == "tries exec --path {root} clone {url} | bash" ]] || fallo "con tries en el PATH el default es tries: $out"

# Sin tries, el default cae al try clásico.
solo="$tmp/solo-try"
mkdir -p "$solo" && : > "$solo/try" && chmod +x "$solo/try"
out="$(PATH="$solo:/usr/bin:/bin" resuelve "$aqui/runtime/lib/ses_sources.sh")"
[[ $out == "try exec --path {root} clone {url} | bash" ]] || fallo "sin tries cae a try: $out"

echo "ok test-clone"
