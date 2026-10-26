#!/usr/bin/env bash
# open: reusa el workspace existente o crea uno y renombra la primera tab.
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

"$bin" open "$root/alpha"
grep -q '^herdr workspace focus w1$' "$STUB_LOG" || fallo "reusa el workspace abierto (por cwd/label)"
grep -q 'workspace create' "$STUB_LOG" && fallo "no crea duplicado"

: > "$STUB_LOG"
"$bin" "$root/beta"
grep -q "^herdr workspace create --cwd $root/beta --label beta --focus$" "$STUB_LOG" || fallo "crea workspace"
grep -q '^herdr tab rename w9:1 main$' "$STUB_LOG" || fallo "renombra la primera tab"
grep -q "	$root/beta$" "$tmp/state/history" || fallo "registra historial"
echo "ok test-open"
