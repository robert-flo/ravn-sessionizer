#!/usr/bin/env bash
# trio: issue → miembro preseleccionado por label repo:<x> → argv exacto de pj-trio.
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

fzf_script $'||^issue' $'||.'
"$bin" trio pj-demo
grep -q "^pj-trio start $root/pj-demo 7 --repo $root/pj-demo/m1$" "$STUB_LOG" || fallo "argv con miembro preseleccionado"
head -n1 "$STUB_DIR/fzf-in-2" | grep -q "$root/pj-demo/m1" || fallo "repo:m1 va primero"
grep -q "(cwd=$root/pj-demo)" "$STUB_LOG" || fallo "gh corre dentro del pj"

: > "$STUB_LOG"
fzf_script $'ctrl-n|#X-12|^issue' $'||^none'
"$bin" trio --dry-run "$root/pj-demo"
grep -q "^pj-trio start --dry-run $root/pj-demo X-12$" "$STUB_LOG" || fallo "ctrl-n ticket escrito, sin miembro, --dry-run"
grep -q '^gh issue list' "$STUB_LOG" && fallo "la caché fresca evita gh"

: > "$STUB_LOG"
fzf_script $'|bad ticket!|^new' $'||CANCEL'
"$bin" trio pj-demo || true
grep -q 'pj-trio' "$STUB_LOG" && fallo "ticket inválido no lanza"

# Caché vieja + gh caído: igual lista, con aviso en el header.
touch -d '2 hours ago' "$tmp/cache/issues/pj-demo.json"
: > "$STUB_LOG"
fzf_script $'||CANCEL'
STUB_GH_FAIL=1 "$bin" trio pj-demo
grep -q 'caché' "$STUB_DIR/fzf-args-1" || fallo "aviso de caché vieja"
grep -q '^issue	7' "$STUB_DIR/fzf-in-1" || fallo "issues de la caché vieja"

# Contexto: el cwd del pane enfocado (miembro) resuelve el pj.
: > "$STUB_LOG"
fzf_script $'||^issue' $'||^none'
RAVN_SESSIONIZER_CWD="$root/pj-demo/m1" "$bin" trio
grep -q "^pj-trio start $root/pj-demo 7$" "$STUB_LOG" || fallo "pj desde el cwd del pane"

# Trío ya abierto: badge.
sed -i 's/"label":"alpha"/"label":"trio pj-demo\/m1#7"/' "$STUB_SNAPSHOT"
fzf_script $'||CANCEL'
"$bin" trio pj-demo
grep -q 'trío abierto' "$STUB_DIR/fzf-in-1" || fallo "badge de trío abierto"

# overlay: abre el pane del plugin con modo y cwd.
: > "$STUB_LOG"
HERDR_PLUGIN_CONTEXT_JSON="{\"focused_pane_cwd\":\"$root/beta\"}" "$bin" overlay trio
grep -q "^herdr plugin pane open --plugin ravn.sessionizer --entrypoint picker --env RAVN_SESSIONIZER_MODE=trio --env RAVN_SESSIONIZER_CWD=$root/beta$" "$STUB_LOG" || fallo "overlay"
echo "ok test-trio"
