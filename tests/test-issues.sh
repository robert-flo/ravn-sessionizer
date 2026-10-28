#!/usr/bin/env bash
# issues (ri): todos los issues abiertos de GitHub; ctrl-t alcance (repo
# actual ⇄ todos), ctrl-s orden; enter lanza el trío como `trio`.
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cat > "$STUB_DIR/search-issues.json" << 'JSON'
[{"repository":{"nameWithOwner":"robert-flo/m1"},"number":7,"title":"Arreglar login","labels":[{"name":"ready-for-agent"}],"createdAt":"2026-03-01T00:00:00Z","updatedAt":"","url":"u"},
 {"repository":{"nameWithOwner":"robert-flo/suelto"},"number":2,"title":"Viejo suelto","labels":[],"createdAt":"2026-01-01T00:00:00Z","updatedAt":"","url":"u"},
 {"repository":{"nameWithOwner":"robert-flo/m1"},"number":5,"title":"Medio","labels":[],"createdAt":"2026-02-01T00:00:00Z","updatedAt":"","url":"u"}]
JSON

fzf_script $'||m1 #7'
(cd "$root/pj-demo/m1" && "$bin" issues)
in1="$STUB_DIR/fzf-in-1" args1="$STUB_DIR/fzf-args-1"
grep -q '^gh search issues --owner robert-flo --state open' "$STUB_LOG" || fallo "gh search issues del dueño"
[[ $(wc -l < "$in1") == 3 ]] || fallo "todos los issues"
head -n1 "$in1" | grep -q 'm1 #7' || fallo "más nuevos primero por defecto"
grep -q 'ctrl-t alcance: todos los repos · ctrl-s orden: más nuevos primero' "$args1" || fallo "header con las teclas"
grep -q '^ctrl-t:reload(.*issues --rows --toggle-scope)+transform-header(.*issues --header)$' "$args1" || fallo "bind ctrl-t"
grep -q '^ctrl-s:reload(.*issues --rows --toggle-sort)+transform-header(.*issues --header)$' "$args1" || fallo "bind ctrl-s"
grep -q "^pj-trio start $root/pj-demo 7 --repo $root/pj-demo/m1$" "$STUB_LOG" || fallo "lanza el trío en el pj del miembro: $(cat "$STUB_LOG")"

# Los binds: alternar alcance (repo actual) y orden, con el header al día.
st="$tmp/st"; printf 'all new\n' > "$st"
export SES_ISSUES_STATE="$st" SES_ISSUES_CURRENT=robert-flo/m1
rows="$("$bin" issues --rows --toggle-scope)"
grep -q suelto <<< "$rows" && fallo "solo el repo actual"
[[ $(wc -l <<< "$rows") == 2 ]] || fallo "dos de m1"
"$bin" issues --header | grep -q 'alcance: solo robert-flo/m1' || fallo "header repo actual"
rows="$("$bin" issues --rows --toggle-sort)"
head -n1 <<< "$rows" | grep -q 'm1 #5' || fallo "más viejos primero"
"$bin" issues --header | grep -q 'orden: más viejos primero' || fallo "header orden"
rows="$("$bin" issues --rows --toggle-scope)"
head -n1 <<< "$rows" | grep -q 'suelto #2' || fallo "todos, viejos primero"
unset SES_ISSUES_STATE SES_ISSUES_CURRENT

# Repo fuera de todo pj-*: él mismo es el proyecto; si no está clonado, se clona.
: > "$STUB_LOG"
fzf_script $'||suelto #2'
"$bin" issues
grep -q "^try exec --path $root clone https://github.com/robert-flo/suelto.git$" "$STUB_LOG" || fallo "clona el repo suelto"
grep -q "^pj-trio start $root/2026-01-01-robert-flo-suelto 2$" "$STUB_LOG" || fallo "trío con el repo como proyecto: $(cat "$STUB_LOG")"
echo "ok test-issues"
