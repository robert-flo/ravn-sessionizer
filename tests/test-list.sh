#!/usr/bin/env bash
# Filas del picker: workspaces abiertos, repos, pj-* y miembros; frecencia; NO_COLOR.
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

mkdir -p "$tmp/state"
now=$(date +%s)
printf '%s\t%s\n' "$((now - 60))" "$root/pj-demo" "$((now - 30))" "$root/pj-demo" "$((now - 9000000))" "$root/beta" > "$tmp/state/history"

out="$("$bin" list workspaces)"
first="$(sed -n 1p <<< "$out")"
[[ $first == ws$'\t'w1$'\t'* ]] || fallo "el workspace abierto va primero: $first"
grep -q 'blocked' <<< "$first" || fallo "badge de estado del workspace"
[[ $(grep -c "$root/alpha\$" <<< "$(cut -f2 <<< "$out")") == 0 ]] || fallo "alpha abierto no se repite como directorio"
second="$(sed -n 2p <<< "$out")"
[[ $second == pj$'\t'"$root/pj-demo"$'\t'* ]] || fallo "el pj más frecente va segundo: $second"
grep -q "^dir	$root/pj-demo/m1	" <<< "$out" || fallo "miembro anidado del pj"
grep -q "^dir	$root/beta	" <<< "$out" || fallo "clon de la raíz"
grep -q "^pj	$tmp/extra/pj-omarchy	" <<< "$out" || fallo "directorio extra"
grep -q 'no-git' <<< "$out" && fallo "directorio sin git"
grep -q $'\033' <<< "$out" && fallo "NO_COLOR respeta sin escapes"
[[ $(grep -c "	$root/beta	" <<< "$out") == 1 ]] || fallo "beta (miembro por archivo) no se duplica"

pj_only="$("$bin" list pj | cut -f1 | sort -u)"
[[ $pj_only == pj ]] || fallo "list pj solo devuelve pj-*"

color="$(env -u NO_COLOR "$bin" list workspaces)"
grep -q $'\033\[' <<< "$color" || fallo "con color hay ANSI aunque stdout no sea tty"

agents="$("$bin" list agents)"
[[ $agents == agent$'\t'w1:1:1$'\t'* ]] || fallo "fila de agente"

toggle="$(FZF_PROMPT='workspace › ' "$bin" list --toggle)"
[[ $toggle == *"list agents)+change-prompt(agentes › )" ]] || fallo "tab alterna a agentes: $toggle"
toggle="$(FZF_PROMPT='agentes › ' "$bin" list --toggle)"
[[ $toggle == *"list workspaces)+change-prompt(workspace › )" ]] || fallo "tab vuelve a workspaces"
echo "ok test-list"
