#!/usr/bin/env bash
# sessions: Estables vs Efímeras vs /z-home-repos/HR-* con separador ———,
# ctrl-s para filtrar activas y flujo attached vs detached.
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
unset HERDR_ENV HERDR_SOCKET_PATH

hr_root="$tmp/z-home-repos"
mkdir -p "$hr_root/HR-CLAVIS" "$hr_root/HR-NUEVO" "$hr_root/pj-ignorado" "$hr_root/otro-dir"
export SES_HOME_REPOS_DIR="$hr_root"
export STUB_SESSIONS_JSON="$tmp/sessions.json"

cat > "$STUB_SESSIONS_JSON" << 'JSON'
{"sessions":[
  {"default":false,"name":"HR-CLAVIS","running":true,"session_dir":"/tmp/s/HR-CLAVIS","socket_path":"/tmp/s/HR-CLAVIS/herdr.sock"},
  {"default":false,"name":"scratchpad","running":false,"session_dir":"/tmp/s/scratchpad","socket_path":"/tmp/s/scratchpad/herdr.sock"},
  {"default":false,"name":"#126 - selector fzf","running":true,"session_dir":"/tmp/s/126","socket_path":"/tmp/s/126/herdr.sock"},
  {"default":false,"name":"#99 - viejo","running":false,"session_dir":"/tmp/s/99","socket_path":"/tmp/s/99/herdr.sock"}
]}
JSON

# 1. Listado completo: Estables -> ——— -> Efímeras -> ——— -> /z-home-repos/HR-* únicamente.
out="$("$bin" sessions --list)"
expected_lines=(
  "session	HR-CLAVIS"
  "session	scratchpad"
  "sep	"
  "session	#126 - selector fzf"
  "session	#99 - viejo"
  "sep	"
  "dir	$hr_root/HR-NUEVO"
)
line_no=1
for prefix in "${expected_lines[@]}"; do
  actual="$(sed -n "${line_no}p" <<< "$out")"
  [[ $actual == "$prefix"* ]] || fallo "línea $line_no esperada '$prefix*', obtuve: '$actual'"
  ((line_no++))
done
[[ $(wc -l <<< "$out") == 7 ]] || fallo "esperaba exactamente 7 filas, obtuve:\n$out"
grep -q 'pj-ignorado\|otro-dir' <<< "$out" && fallo "no debe listar directorios fuera de HR-*"
grep -q '———' <<< "$out" || fallo "debe incluir separador ———"

# 2. ctrl-s (--toggle / --list --active): filtra solo sesiones activas (running) sin directorios.
active_out="$("$bin" sessions --list --active)"
[[ $(wc -l <<< "$active_out") == 3 ]] || fallo "activas debe tener 3 filas (HR-CLAVIS, ———, #126), obtuve:\n$active_out"
grep -q '^session	HR-CLAVIS	' <<< "$active_out" || fallo "falta HR-CLAVIS en activas"
grep -q '^sep	' <<< "$active_out" || fallo "falta separador en activas"
grep -q '^session	#126 - selector fzf	' <<< "$active_out" || fallo "falta #126 en activas"
grep -q 'scratchpad\|#99\|HR-NUEVO' <<< "$active_out" && fallo "stopped o dirs no deben salir en activas"

toggle_to_active="$(FZF_PROMPT='sesiones › ' "$bin" sessions --toggle)"
[[ $toggle_to_active == *"sessions --list --active)+change-prompt(activas › )" ]] || fallo "ctrl-s a activas: $toggle_to_active"
toggle_to_all="$(FZF_PROMPT='activas › ' "$bin" sessions --toggle)"
[[ $toggle_to_all == *"sessions --list)+change-prompt(sesiones › )" ]] || fallo "ctrl-s vuelve a todas: $toggle_to_all"

# 3. Flujo detached: attach a sesión existente y creación en cwd para HR-* nuevo.
: > "$STUB_LOG"
fzf_script $'||^session\tHR-CLAVIS\t'
"$bin" sessions
grep -q '^herdr session attach HR-CLAVIS$' "$STUB_LOG" || fallo "detached: attach a sesión"
grep -q -- '--bind' "$STUB_DIR/fzf-args-1" || fallo "fzf debe recibir binds"
grep -q 'ctrl-s:transform:' "$STUB_DIR/fzf-args-1" || fallo "fzf debe tener bind ctrl-s"

: > "$STUB_LOG"
fzf_script $'||^dir\t.*HR-NUEVO\t'
"$bin" sessions
grep -q '^herdr --session HR-NUEVO$' "$STUB_LOG" || fallo "detached: crea nueva sesión con --session"
grep -q "^pwd=$hr_root/HR-NUEVO$" "$STUB_LOG" || fallo "detached: entra al directorio HR-NUEVO"

# 4. Flujo attached (HERDR_ENV=1): attach/switch a sesión y creación sin TUI anidada + attach para HR-*.
: > "$STUB_LOG"
fzf_script $'||^session\t#126 - selector fzf\t'
HERDR_ENV=1 HERDR_SOCKET_PATH="/tmp/herdr.sock" "$bin" sessions
grep -q '^herdr session attach #126 - selector fzf$' "$STUB_LOG" || fallo "attached: attach/switch a sesión"

: > "$STUB_LOG"
fzf_script $'||^dir\t.*HR-NUEVO\t'
HERDR_ENV=1 HERDR_SOCKET_PATH="/tmp/herdr.sock" "$bin" sessions
grep -q "^herdr --session HR-NUEVO workspace create --cwd $hr_root/HR-NUEVO --label HR-NUEVO --focus$" "$STUB_LOG" \
  || fallo "attached: crea workspace en la sesión nueva"
grep -q '^herdr session attach HR-NUEVO$' "$STUB_LOG" || fallo "attached: adjunta tras crear"

# 5. Separador y ESC no hacen nada.
: > "$STUB_LOG"
fzf_script $'||^sep\t'
"$bin" sessions
grep -v '^herdr session list --json$' "$STUB_LOG" && fallo "separador no debe ejecutar nada"

: > "$STUB_LOG"
fzf_script $'||CANCEL'
"$bin" sessions
grep -v '^herdr session list --json$' "$STUB_LOG" && fallo "esc no debe ejecutar nada"

# 6. Preview de sesión y separador.
"$bin" preview session HR-CLAVIS | grep -q 'running' || fallo "preview de sesión"
"$bin" preview sep ""

echo "ok test-sessions"
