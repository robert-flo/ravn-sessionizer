#!/usr/bin/env bash
# repos (rs): todos los repos de GitHub, los clonados marcados; enter en uno
# sin clonar lo clona (solo ése) con try-clone y lo abre.
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

git -C "$root/alpha" remote add origin https://github.com/robert-flo/alpha.git
cat > "$STUB_DIR/repos.json" << 'JSON'
[{"nameWithOwner":"robert-flo/alpha","name":"alpha","description":"el clonado","isPrivate":false,"isFork":false,"isArchived":false,"pushedAt":"2026-01-01T00:00:00Z","url":"u"},
 {"nameWithOwner":"robert-flo/nuevo","name":"nuevo","description":"sin clonar","isPrivate":true,"isFork":false,"isArchived":false,"pushedAt":"2026-02-01T00:00:00Z","url":"u"},
 {"nameWithOwner":"robert-flo/otro","name":"otro","description":"","isPrivate":false,"isFork":true,"isArchived":false,"pushedAt":"2026-03-01T00:00:00Z","url":"u"}]
JSON

fzf_script $'||nuevo'
"$bin" repos
in1="$STUB_DIR/fzf-in-1"
[[ $(wc -l < "$in1") == 3 ]] || fallo "todos los repos de GitHub: $(cat "$in1")"
head -n1 "$in1" | grep -q $'^repo\trobert-flo/alpha\t● alpha.*clonado' || fallo "clonado marcado y primero: $(head -n1 "$in1")"
grep -q $'robert-flo/nuevo\t  nuevo' "$in1" || fallo "sin clonar sin marca"
grep -q '^gh repo list robert-flo --limit 1000' "$STUB_LOG" || fallo "gh repo list del dueño"
grep -c '^try exec' "$STUB_LOG" | grep -qx 1 || fallo "clona uno solo"
grep -q "^try exec --path $root clone https://github.com/robert-flo/nuevo.git$" "$STUB_LOG" || fallo "clona el elegido con try-clone"
grep -q "workspace create --cwd $root/2026-01-01-robert-flo-nuevo" "$STUB_LOG" || fallo "abre el clon nuevo: $(cat "$STUB_LOG")"

# Clonado: no clona, abre el existente.
: > "$STUB_LOG"
fzf_script $'||alpha'
"$bin" repos
grep -q '^try' "$STUB_LOG" && fallo "no clona lo ya clonado"
grep -q "workspace focus w1" "$STUB_LOG" || fallo "enfoca el workspace de alpha: $(cat "$STUB_LOG")"

# Las filas por reload (ctrl-r) son las mismas.
"$bin" repos --rows | grep -q 'robert-flo/nuevo' || fallo "--rows"
echo "ok test-repos"
