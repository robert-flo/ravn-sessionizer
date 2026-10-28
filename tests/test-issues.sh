#!/usr/bin/env bash
# issues (ri) jerárquico: pj-* (con cuenta de issues) → repo o todos → issue.
# enter en el issue lanza el trío del pj; nada se lanza sin elegir un issue;
# los repos sin pj-* se ven pero avisan que no tienen trío.
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cat > "$STUB_DIR/search-issues.json" << 'JSON'
[{"repository":{"nameWithOwner":"robert-flo/m1"},"number":7,"title":"Arreglar login","labels":[{"name":"ready-for-agent"}],"createdAt":"2026-03-01T00:00:00Z","updatedAt":"","url":"u"},
 {"repository":{"nameWithOwner":"robert-flo/suelto"},"number":2,"title":"Viejo suelto","labels":[],"createdAt":"2026-01-01T00:00:00Z","updatedAt":"","url":"u"},
 {"repository":{"nameWithOwner":"robert-flo/m1"},"number":5,"title":"Medio","labels":[],"createdAt":"2026-02-01T00:00:00Z","updatedAt":"","url":"u"}]
JSON

# Dentro de m1: pj-demo y m1 preseleccionados; los tres pasos y el lanzamiento.
fzf_script $'||pj-demo' $'||  m1  ' $'||m1 #7'
(cd "$root/pj-demo/m1" && "$bin" issues)
in1="$STUB_DIR/fzf-in-1" args1="$STUB_DIR/fzf-args-1"
grep -q '^gh search issues --owner robert-flo --state open' "$STUB_LOG" || fallo "gh search issues del dueño"
[[ $(wc -l < "$in1") == 2 ]] || fallo "pj-demo y sin pj: $(cat "$in1")"
grep -q $'^group\trobert-flo/pj-demo\t.*pj-demo  2 issues  3 repos' "$in1" || fallo "cuenta de issues del pj: $(cat "$in1")"
grep -q $'^group\t-\t.*sin pj  1 issues  1 repos · sin trío' "$in1" || fallo "grupo sin pj"
grep -q 'plantilla' "$in1" && fallo "pj excluido"
grep -q '^load:pos(1)$' "$args1" || fallo "preselecciona el pj del repo actual"
grep -q 'paso 1/3' "$args1" || fallo "header nivel 1"
grep -q 'no se lanza nada hasta que elijas un issue' "$args1" || fallo "header explica que no hay acción automática"
grep -q '^--select-1$\|^-1$\|^--exit-0$\|^-0$' "$STUB_DIR"/fzf-args-* && fallo "fzf nunca elige solo"
in2="$STUB_DIR/fzf-in-2" args2="$STUB_DIR/fzf-args-2"
[[ $(wc -l < "$in2") == 4 ]] || fallo "todos + 3 miembros: $(cat "$in2")"
head -n1 "$in2" | grep -q $'^repo\t\\*\ttodos  2 issues  3 repos' || fallo "fila todos"
grep -q "^load:pos($(grep -n $'\trobert-flo/m1\t' "$in2" | cut -d: -f1))$" "$args2" || fallo "preselecciona m1"
in3="$STUB_DIR/fzf-in-3" args3="$STUB_DIR/fzf-args-3"
[[ $(wc -l < "$in3") == 2 ]] || fallo "solo issues de m1: $(cat "$in3")"
head -n1 "$in3" | grep -q 'm1 #7' || fallo "más nuevos primero por defecto"
grep -q 'ctrl-t alcance: robert-flo/m1 · ctrl-s orden: más nuevos primero' "$args3" || fallo "header nivel 3: $(cat "$args3")"
grep -q '^ctrl-t:reload(.*issues --rows --toggle-scope)+transform-header(.*issues --header)$' "$args3" || fallo "bind ctrl-t"
grep -q '^ctrl-s:reload(.*issues --rows --toggle-sort)+transform-header(.*issues --header)$' "$args3" || fallo "bind ctrl-s"
grep -q "^pj-trio start $root/pj-demo 7 --repo $root/pj-demo/m1$" "$STUB_LOG" || fallo "lanza el trío en el pj del miembro: $(cat "$STUB_LOG")"

# esc en el nivel 1: sale sin lanzar nada (nunca se lanza solo).
: > "$STUB_LOG"
fzf_script $'||CANCEL'
(cd "$root/pj-demo/m1" && "$bin" issues)
grep -q '^pj-trio' "$STUB_LOG" && fallo "lanzó sin elegir"
[[ $(cat "$STUB_DIR/fzf.n") == 1 ]] || fallo "un solo fzf"

# esc vuelve un nivel: 1 → 2 → esc → 1 → esc.
fzf_script $'||pj-demo' $'||CANCEL' $'||CANCEL'
"$bin" issues
[[ $(cat "$STUB_DIR/fzf.n") == 3 ]] || fallo "esc vuelve al nivel 1"
grep -q '^pj-trio' "$STUB_LOG" && fallo "lanzó al volver"
grep -q '^load:pos' "$STUB_DIR/fzf-args-1" && fallo "sin repo actual no preselecciona"

# Sin pj: el issue se ve, pero avisa que no tiene trío y vuelve a la lista.
fzf_script $'||sin pj' $'||todos' $'||suelto #2' $'||CANCEL' $'||CANCEL' $'||CANCEL'
err="$("$bin" issues 2>&1 > /dev/null)"
grep -q 'sin trío' "$STUB_DIR/fzf-in-3" || fallo "fila marcada sin trío"
grep -q 'no es miembro de ningún pj-\*, así que no tiene trío' <<< "$err" || fallo "mensaje sin trío: $err"
grep -q '^pj-trio\|^try' "$STUB_LOG" && fallo "sin pj no lanza ni clona: $(cat "$STUB_LOG")"
[[ $(cat "$STUB_DIR/fzf.n") == 6 ]] || fallo "vuelve al picker tras el aviso"

# Los binds del nivel 3: alcance selección → repo actual → todos, y orden.
st="$tmp/st" sel="$tmp/sel"; printf 'sel new\n' > "$st"; echo '["robert-flo/m1"]' > "$sel"
export SES_ISSUES_STATE="$st" SES_ISSUES_SEL="$sel" SES_ISSUES_SEL_LABEL=m1 SES_ISSUES_CURRENT=robert-flo/suelto
rows="$("$bin" issues --rows)"
[[ $(wc -l <<< "$rows") == 2 ]] || fallo "selección: dos de m1"
rows="$("$bin" issues --rows --toggle-scope)"
[[ $(wc -l <<< "$rows") == 1 ]] || fallo "repo actual: uno"
grep -q suelto <<< "$rows" || fallo "repo actual: suelto"
"$bin" issues --header | grep -q 'alcance: solo robert-flo/suelto' || fallo "header repo actual"
rows="$("$bin" issues --rows --toggle-scope)"
[[ $(wc -l <<< "$rows") == 3 ]] || fallo "todos"
rows="$("$bin" issues --rows --toggle-sort)"
head -n1 <<< "$rows" | grep -q 'suelto #2' || fallo "todos, viejos primero"
"$bin" issues --header | grep -q 'orden: más viejos primero' || fallo "header orden"
rows="$("$bin" issues --rows --toggle-scope)"
head -n1 <<< "$rows" | grep -q 'm1 #5' || fallo "vuelve a la selección"
echo "ok test-issues"
