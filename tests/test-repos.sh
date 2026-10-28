#!/usr/bin/env bash
# repos (rs) jerárquico: pj-* → repo miembro o «todos» (todos los repos de
# GitHub). enter en uno sin clonar lo clona (solo ése) con try-clone y lo abre.
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

git -C "$root/alpha" remote add origin https://github.com/robert-flo/alpha.git
cat > "$STUB_DIR/repos.json" << 'JSON'
[{"nameWithOwner":"robert-flo/alpha","name":"alpha","description":"el clonado","isPrivate":false,"isFork":false,"isArchived":false,"pushedAt":"2026-01-01T00:00:00Z","url":"u"},
 {"nameWithOwner":"robert-flo/nuevo","name":"nuevo","description":"sin clonar","isPrivate":true,"isFork":false,"isArchived":false,"pushedAt":"2026-02-01T00:00:00Z","url":"u"},
 {"nameWithOwner":"robert-flo/m1","name":"m1","description":"","isPrivate":false,"isFork":false,"isArchived":false,"pushedAt":"2026-02-01T00:00:00Z","url":"u"},
 {"nameWithOwner":"robert-flo/otro","name":"otro","description":"","isPrivate":false,"isFork":true,"isArchived":false,"pushedAt":"2026-03-01T00:00:00Z","url":"u"}]
JSON

# Sin pj → nuevo: lo clona con try-clone (uno solo) y lo abre.
fzf_script $'||sin pj' $'||nuevo'
"$bin" repos
in1="$STUB_DIR/fzf-in-1" in2="$STUB_DIR/fzf-in-2"
grep -q $'^group\trobert-flo/pj-demo\t' "$in1" || fallo "grupo pj-demo"
grep -q $'^group\t-\t.*sin pj .* 3 repos' "$in1" || fallo "sin pj con alpha, nuevo, otro: $(cat "$in1")"
grep -q 'paso 1/2' "$STUB_DIR/fzf-args-1" || fallo "header nivel 1"
[[ $(wc -l < "$in2") == 4 ]] || fallo "todos + 3 repos: $(cat "$in2")"
grep -q $'^repo\trobert-flo/alpha\t● alpha.*clonado' "$in2" || fallo "clonado marcado"
grep -q m1 "$in2" && fallo "m1 es de pj-demo"
grep -q '^gh repo list robert-flo --limit 1000' "$STUB_LOG" || fallo "gh repo list del dueño"
grep -c '^try exec' "$STUB_LOG" | grep -qx 1 || fallo "clona uno solo"
grep -q "^try exec --path $root clone https://github.com/robert-flo/nuevo.git$" "$STUB_LOG" || fallo "clona el elegido con try-clone"
grep -q "workspace create --cwd $root/2026-01-01-robert-flo-nuevo" "$STUB_LOG" || fallo "abre el clon nuevo: $(cat "$STUB_LOG")"

# pj-demo: miembros (lejano sin clonar, aunque no esté en repo list) y preselección.
: > "$STUB_LOG"
fzf_script $'||pj-demo' $'||CANCEL' $'||CANCEL'
(cd "$root/pj-demo/m1" && "$bin" repos)
grep -q '^load:pos(1)$' "$STUB_DIR/fzf-args-1" || fallo "preselecciona pj-demo"
in2="$STUB_DIR/fzf-in-2"
[[ $(wc -l < "$in2") == 4 ]] || fallo "todos + pj-demo, m1, lejano: $(cat "$in2")"
grep -q $'robert-flo/lejano\t  lejano' "$in2" || fallo "miembro fuera de repo list"
grep -q "^load:pos($(grep -n $'\trobert-flo/m1\t' "$in2" | cut -d: -f1))$" "$STUB_DIR/fzf-args-2" || fallo "preselecciona m1"
grep -q '^try\|workspace' "$STUB_LOG" && fallo "esc no abre nada"

# «todos»: todos los repos de GitHub; alpha ya clonado se enfoca sin clonar.
: > "$STUB_LOG"
fzf_script $'||pj-demo' $'||todos' $'||alpha'
"$bin" repos
[[ $(wc -l < "$STUB_DIR/fzf-in-3") == 4 ]] || fallo "todos los repos del dueño"
grep -q '^try' "$STUB_LOG" && fallo "no clona lo ya clonado"
grep -q "workspace focus w1" "$STUB_LOG" || fallo "enfoca el workspace de alpha: $(cat "$STUB_LOG")"

# Las filas por --rows (sin selección) son todas.
[[ $("$bin" repos --rows | wc -l) == 4 ]] || fallo "--rows"
echo "ok test-repos"
