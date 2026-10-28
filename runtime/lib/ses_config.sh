#!/usr/bin/env bash

# Configuración de ravn-sessionizer: formato shell KEY=valor, como trio.conf.
# Precedencia: $RAVN_SESSIONIZER_CONFIG → /etc/ravn/sessionizer.conf →
# sessionizer.conf.example junto al launcher. Nada de config en $HOME.
# shellcheck disable=SC2034,SC2153 # Globals (SES_ROOT comes from set_variable.sh) are read by the sourcing command modules.

ses_config_file() {
  local candidate
  for candidate in "${RAVN_SESSIONIZER_CONFIG:-}" /etc/ravn/sessionizer.conf "$SES_ROOT/sessionizer.conf.example"; do
    if [[ -n $candidate && -r $candidate ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

ses_load_config() {
  # Defaults (los mismos que documenta sessionizer.conf.example).
  SES_ROOTS=(/z-drive/tries)
  SES_EXTRA=(/z/pj-omarchy)
  SES_ISSUE_LABEL="ready-for-agent"
  SES_ISSUE_TTL=300
  SES_HALF_LIFE_DAYS=7
  SES_MEMBERS_FILE=".ravn/miembros"
  SES_FIRST_TAB="main"
  SES_TRIO_BIN="pj-trio"
  SES_GITHUB_OWNER="robert-flo"
  SES_PJ_EXCLUDE=(pj-template)
  SES_PROJECTS_TTL=3600
  SES_CLONE_ROOT=""
  # Vacío = auto: `tries` (try-clone) si está en el PATH, si no `try`.
  SES_CLONE_CMD=""

  local file=""
  if file="$(ses_config_file)"; then
    # shellcheck disable=SC1090 # Ruta elegida en tiempo de ejecución.
    source "$file"
  fi
  SES_CONFIG_FILE="$file"

  # Estado y caché sí son por usuario (XDG); herdr ya guarda su registro de
  # plugins en $HOME (workstation#63), así que no empeoramos nada.
  SES_STATE_DIR="${RAVN_SESSIONIZER_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ravn-sessionizer}"
  SES_CACHE_DIR="${RAVN_SESSIONIZER_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/ravn-sessionizer}"
  SES_HISTORY_FILE="$SES_STATE_DIR/history"
  HERDR="${HERDR_BIN_PATH:-herdr}"
}

# En un pane de plugin el stderr desaparece al cerrarse: esperamos una tecla.
ses_fail() {
  print_error "$*" >&2
  if [[ -n ${HERDR_PLUGIN_ENTRYPOINT_ID:-} && -t 0 ]]; then
    read -rsn1 -p "  presioná una tecla para cerrar…" || true
  fi
  exit 1
}

ses_require() {
  local tool
  for tool in "$@"; do
    command -v "$tool" > /dev/null 2>&1 || ses_fail "falta '$tool' en el PATH (pacman -S $tool)."
  done
}
