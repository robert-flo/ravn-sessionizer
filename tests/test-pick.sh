#!/usr/bin/env bash
# pick: enter en un pj-* va a issues; alt-enter abre su workspace; esc no hace nada.
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

fzf_script $'alt-enter||pj-demo$'
"$bin" pick
grep -q "^herdr workspace create --cwd $root/pj-demo --label pj-demo --focus$" "$STUB_LOG" || fallo "alt-enter abre el workspace del pj"
grep -q 'pj-trio' "$STUB_LOG" && fallo "alt-enter no lanza trío"
grep -q -- '--expect' "$STUB_DIR/fzf-args-1" || fallo "fzf con --expect"

: > "$STUB_LOG"
fzf_script $'||^pj\t[^\t]*pj-demo\t' $'||^issue' $'||^dir'
"$bin" pick
grep -q "^pj-trio start $root/pj-demo 7 --repo $root/pj-demo/m1$" "$STUB_LOG" || fallo "enter en pj → issue → trío"

: > "$STUB_LOG"
fzf_script $'||CANCEL'
"$bin" pick
grep -v '^herdr api snapshot$' "$STUB_LOG" && fallo "esc no actúa"

: > "$STUB_LOG"
fzf_script $'||^ws'
RAVN_SESSIONIZER_MODE=agents "$bin"
grep -q 'agentes › ' "$STUB_DIR/fzf-args-1" || fallo "modo agents desde el pane del plugin"
echo "ok test-pick"
