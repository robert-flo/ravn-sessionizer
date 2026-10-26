#!/usr/bin/env bash
# preview: cada tipo de fila produce algo útil sin red.
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

git -C "$root/pj-demo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "primer commit"
out="$("$bin" preview pj "$root/pj-demo")"
grep -q 'primer commit' <<< "$out" || fallo "último commit"
grep -q 'm1' <<< "$out" || fallo "miembros del pj"
grep -q 'sin caché' <<< "$out" || fallo "no toca la red en la preview"
grep -q '^gh' "$STUB_LOG" && fallo "preview llamó gh"
out="$("$bin" preview ws w1)"
grep -q 'claude blocked' <<< "$out" || fallo "preview de workspace"
out="$(SES_PJ="$root/pj-demo" "$bin" preview issue 7)"
grep -q 'cuerpo' <<< "$out" || fallo "preview de issue"
"$bin" help > /dev/null || fallo "help"
echo "ok test-preview"
