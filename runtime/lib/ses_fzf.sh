#!/usr/bin/env bash

# Filas y fzf con el lenguaje visual de git-setup.
#
# presentation.sh decide los colores según `-t 1` al cargarse, pero las filas
# se generan dentro de pipes de fzf (nunca son tty). Por eso acá repetimos la
# MISMA paleta ANSI de presentation.sh, gobernada solo por NO_COLOR, y usamos
# sus íconos semánticos (ICON_GIT, ICON_PACKAGE, …) tal cual.
# shellcheck disable=SC2034,SC2154 # Palette is read by command modules; ICON_* come from presentation.sh.

if [[ -z ${NO_COLOR:-} ]]; then
  S_RED=$'\033[0;31m' S_GREEN=$'\033[0;32m' S_YELLOW=$'\033[0;33m' S_BLUE=$'\033[0;34m'
  S_MAGENTA=$'\033[0;35m' S_CYAN=$'\033[0;36m' S_WHITE=$'\033[1;37m' S_GRAY=$'\033[0;90m' S_NC=$'\033[0m'
else
  S_RED="" S_GREEN="" S_YELLOW="" S_BLUE="" S_MAGENTA="" S_CYAN="" S_WHITE="" S_GRAY="" S_NC=""
fi

readonly SES_ICON_OPEN="●"
readonly SES_ICON_MEMBER="󰘬"
readonly SES_ICON_AGENT="󰚩"
readonly SES_ICON_ISSUE=""
readonly SES_ICON_NEW=""

# Fila fzf: kind<TAB>target<TAB>texto visible.
ses_row() {
  printf '%s\t%s\t%s\n' "$1" "$2" "$3"
}

ses_status_color() {
  case "$1" in
    blocked) printf '%s' "$S_RED" ;;
    done) printf '%s' "$S_GREEN" ;;
    working) printf '%s' "$S_YELLOW" ;;
    *) printf '%s' "$S_GRAY" ;;
  esac
}

ses_require_fzf() {
  command -v fzf > /dev/null 2>&1 || ses_fail "falta fzf (pacman -S fzf)."
  local version major minor
  version="$(fzf --version | cut -d' ' -f1)"
  major="${version%%.*}" minor="${version#*.}" minor="${minor%%.*}"
  if [[ $major == 0 ]] && ((minor < 45)); then
    ses_fail "fzf >= 0.45 requerido (encontré $version)."
  fi
}

# Opciones comunes: mismas en todas las vistas para que la memoria muscular
# no cambie. El texto visible es el campo 3 en adelante.
ses_fzf() {
  fzf --ansi --delimiter $'\t' --with-nth 3.. --no-multi --reverse \
    --border rounded --info inline-right --pointer '▌' --marker '•' \
    --color 'border:8,header:8,prompt:5,pointer:5,hl:6,hl+:6,info:8,label:5' \
    --preview-window 'right,55%,border-left,<90(down,45%,border-top)' \
    "$@"
}
