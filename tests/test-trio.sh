#!/usr/bin/env bash
# trio: todos los issues de todos los miembros (desde GitHub, sin clonar) →
# pj-trio con --repo del miembro; clona lo que falta; enfoca tríos abiertos.
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

fzf_script $'||m1 #7'
"$bin" trio
in1="$STUB_DIR/fzf-in-1"
head -n1 "$in1" | grep -q 'm1 #7' || fallo "ready-for-agent primero: $(head -n1 "$in1")"
grep -q 'pj-demo #3' "$in1" || fallo "issues del meta-repo"
grep -q 'lejano #9' "$in1" || fallo "issues de un miembro sin clonar"
grep -q 'No debe salir' "$in1" && fallo "pj-template excluido"
grep -q 'gh issue list -R robert-flo/lejano' "$STUB_LOG" || fallo "gh issue list -R por miembro"
grep -q -- '--label' "$STUB_LOG" && fallo "no filtra por etiqueta"
grep -q "^pj-trio start $root/pj-demo 7 --repo $root/pj-demo/m1$" "$STUB_LOG" || fallo "argv con miembro, sin preguntar"
[[ $(cat "$STUB_DIR/fzf.n") == 1 ]] || fallo "un solo fzf (sin picker de miembro)"

# Miembro sin clonar: lo clona con SES_CLONE_CMD y lanza con su ruta.
: > "$STUB_LOG"
fzf_script $'||lejano #9'
"$bin" trio pj-demo
grep -q "^try exec --path $root clone https://github.com/robert-flo/lejano.git$" "$STUB_LOG" || fallo "clona el miembro"
grep -q "^pj-trio start $root/pj-demo 9 --repo $root/2026-01-01-robert-flo-lejano$" "$STUB_LOG" || fallo "lanza con el clon nuevo"
grep -q 'gh issue list' "$STUB_LOG" && fallo "la caché fresca evita gh"

# Issue del meta-repo: sin --repo.
: > "$STUB_LOG"
fzf_script $'||pj-demo #3'
"$bin" trio --dry-run
grep -q "^pj-trio start --dry-run $root/pj-demo 3$" "$STUB_LOG" || fallo "meta-repo sin --repo"

# ctrl-n: ticket escrito, en el repo de la fila elegida.
: > "$STUB_LOG"
fzf_script $'ctrl-n|#X-12|m1 #7'
"$bin" trio
grep -q "^pj-trio start $root/pj-demo X-12 --repo $root/pj-demo/m1$" "$STUB_LOG" || fallo "ctrl-n"

# ctrl-o abre el issue en su repo.
: > "$STUB_LOG"
fzf_script $'ctrl-o||m1 #7' $'||CANCEL'
"$bin" trio
grep -q '^gh issue view 7 -R robert-flo/m1 --web' "$STUB_LOG" || fallo "ctrl-o con -R"

# Trío ya abierto: badge y enter lo enfoca sin relanzar.
sed -i 's/"label":"alpha"/"label":"trio pj-demo\/m1#7"/' "$STUB_SNAPSHOT"
: > "$STUB_LOG"
fzf_script $'||m1 #7'
"$bin" trio
grep -q 'trío abierto' "$STUB_DIR/fzf-in-1" || fallo "badge de trío abierto"
grep -q '^herdr workspace focus w1' "$STUB_LOG" || fallo "enfoca el trío abierto"
grep -q 'pj-trio' "$STUB_LOG" && fallo "no relanza un trío abierto"

# Caché vieja + gh caído: igual lista, con aviso.
touch -d '2 hours ago' "$tmp"/cache/issues/*.json "$tmp/cache/projects.json"
fzf_script $'||CANCEL'
STUB_GH_FAIL=1 "$bin" trio
grep -q 'caché' "$STUB_DIR/fzf-args-1" || fallo "aviso de caché vieja"
grep -q 'm1 #7' "$STUB_DIR/fzf-in-1" || fallo "issues de la caché vieja"

# pj-* con fecha de try clone: se reconoce por el remoto.
mkdir -p "$tmp/r2" && git init -q "$tmp/r2/2026-10-26-robert-flo-pj-ravn"
git -C "$tmp/r2/2026-10-26-robert-flo-pj-ravn" remote add origin https://github.com/robert-flo/pj-ravn.git
grep -q . <<< "$(RAVN_SESSIONIZER_CONFIG=/dev/null bash -c "SES_ROOT='$aqui'; source '$aqui/runtime/lib/ses_sources.sh'; ses_is_pj '$tmp/r2/2026-10-26-robert-flo-pj-ravn' && echo si")" || fallo "ses_is_pj por remoto"

# overlay: abre el pane del plugin con modo y cwd.
: > "$STUB_LOG"
HERDR_PLUGIN_CONTEXT_JSON="{\"focused_pane_cwd\":\"$root/beta\"}" "$bin" overlay trio
grep -q "^herdr plugin pane open --plugin ravn.sessionizer --entrypoint picker --env RAVN_SESSIONIZER_MODE=trio --env RAVN_SESSIONIZER_CWD=$root/beta$" "$STUB_LOG" || fallo "overlay"
echo "ok test-trio"
