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
out="$("$bin" preview issue "robert-flo/pj-demo|robert-flo/m1|7")"
grep -q 'cuerpo' <<< "$out" || fallo "preview de issue"
grep -q 'gh issue view 7 -R robert-flo/m1' "$STUB_LOG" || fallo "preview lee el issue en el miembro"
"$bin" help > /dev/null || fallo "help"
echo "ok test-preview"
