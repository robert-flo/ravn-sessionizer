#!/usr/bin/env bash

# Carga común de los módulos de comando: presentación + dominio + config.
# shellcheck disable=SC1091 # Libraries live beside this file.

_ses_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_ses_lib_dir/presentation.sh"
source "$_ses_lib_dir/command_interface.sh"
source "$_ses_lib_dir/ses_config.sh"
source "$_ses_lib_dir/ses_sources.sh"
source "$_ses_lib_dir/ses_herdr.sh"
source "$_ses_lib_dir/ses_github.sh"
source "$_ses_lib_dir/ses_fzf.sh"
ses_load_config

# cwd del pane enfocado al invocar: env explícito (overlay) → contexto del
# plugin → custom command de herdr.
ses_context_cwd() {
  local cwd="${RAVN_SESSIONIZER_CWD:-}"
  if [[ -z $cwd && -n ${HERDR_PLUGIN_CONTEXT_JSON:-} ]]; then
    cwd="$(jq -r '.focused_pane_cwd // .workspace_cwd // empty' <<< "$HERDR_PLUGIN_CONTEXT_JSON" 2> /dev/null || true)"
  fi
  [[ -z $cwd ]] && cwd="${HERDR_ACTIVE_PANE_CWD:-}"
  printf '%s\n' "$cwd"
}
