#!/usr/bin/env bash

# Operaciones sobre herdr: snapshot, reuso de workspaces, foco y agentes.
# Todo pasa por el CLI ($HERDR_BIN_PATH): es la API oficial de plugins.
# shellcheck disable=SC2154 # HERDR and SES_* globals come from ses_config.sh.

SES_SNAPSHOT=""

ses_snapshot() {
  if [[ -z $SES_SNAPSHOT ]]; then
    SES_SNAPSHOT="$("$HERDR" api snapshot 2> /dev/null)" || SES_SNAPSHOT='{"result":{"snapshot":{"workspaces":[],"tabs":[],"panes":[]}}}'
  fi
  printf '%s\n' "$SES_SNAPSHOT"
}

# Workspaces abiertos: "id<TAB>label<TAB>cwd<TAB>focused<TAB>agent_status".
# cwd = cwd del primer pane (la clave del historial).
ses_workspaces() {
  ses_snapshot | jq -r '
    .result.snapshot as $s
    | $s.workspaces[]
    | . as $w
    | [ $w.workspace_id, ($w.label // ""),
        ([$s.panes[] | select(.workspace_id == $w.workspace_id)][0].cwd // ""),
        ($w.focused // false | tostring), ($w.agent_status // "unknown") ]
    | @tsv'
}

# Reuso: 1) label exacto, 2) cualquier pane del workspace con cwd == dir.
ses_ws_for() {
  local dir="$1" label="$2"
  ses_snapshot | jq -r --arg dir "$dir" --arg label "$label" '
    .result.snapshot as $s
    | ([$s.workspaces[] | select(.label == $label) | .workspace_id]
       + [$s.panes[] | select(.cwd == $dir) | .workspace_id])
    | first // empty'
}

ses_ws_cwd() {
  ses_snapshot | jq -r --arg ws "$1" '
    .result.snapshot as $s | [$s.panes[] | select(.workspace_id == $ws)][0].cwd // ""'
}

ses_focus_ws() {
  local ws="$1"
  "$HERDR" workspace focus "$ws" > /dev/null
  ses_record_history "$(ses_ws_cwd "$ws")"
}

ses_open_dir() {
  local dir label ws created tab
  dir="$(cd "$1" && pwd)" || ses_fail "no es un directorio: $1"
  label="$(basename "$dir")"
  ws="$(ses_ws_for "$dir" "$label")"
  if [[ -n $ws ]]; then
    "$HERDR" workspace focus "$ws" > /dev/null
  else
    created="$("$HERDR" workspace create --cwd "$dir" --label "$label" --focus)"
    tab="$(jq -r '.result.tab.tab_id // empty' <<< "$created")"
    if [[ -n $tab && -n $SES_FIRST_TAB ]]; then
      "$HERDR" tab rename "$tab" "$SES_FIRST_TAB" > /dev/null || true
    fi
  fi
  ses_record_history "$dir"
}

# Agentes: "pane<TAB>status<TAB>ws_label<TAB>tab_label<TAB>agent<TAB>focused",
# ordenados blocked > done > working > idle, luego posición; el enfocado último.
ses_agents() {
  ses_snapshot | jq -r '
    .result.snapshot as $s
    | def prio: {"blocked":0,"done":1,"working":2,"idle":3}[.] // 4;
    [ $s.panes[]
      | select(.agent != null and (.agent_status // "unknown") != "unknown")
      | . as $p
      | ($s.workspaces[] | select(.workspace_id == $p.workspace_id)) as $w
      | ($s.tabs[] | select(.tab_id == $p.tab_id)) as $t
      | { pane: $p.pane_id, st: $p.agent_status, ws: ($w.label // ""), tab: ($t.label // ""),
          agent: $p.agent, f: ($p.focused // false), wn: ($w.number // 0), tn: ($t.number // 0) } ]
    | sort_by([(if .f then 1 else 0 end), (.st | prio), .wn, .tn])[]
    | [.pane, .st, .ws, .tab, .agent, (.f | tostring)] | @tsv'
}

ses_focus_agent() {
  local pane="$1" ws
  "$HERDR" agent focus "$pane" > /dev/null
  ws="$(ses_snapshot | jq -r --arg p "$pane" '.result.snapshot.panes[] | select(.pane_id == $p) | .workspace_id' | head -n1)"
  [[ -n $ws ]] && ses_record_history "$(ses_ws_cwd "$ws")"
  return 0
}

# ¿Hay un trío abierto para <pj>#<ticket>? (label `trio <pj>[/<miembro>]#<ticket>` de pj-trio)
ses_trio_labels() {
  ses_snapshot | jq -r '.result.snapshot.workspaces[].label // "" | select(startswith("trio "))'
}
