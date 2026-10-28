#!/usr/bin/env bash
# Alias rs (vista de workspaces) y ri (vista de issues): symlinks del launcher
# que eligen la vista por el nombre del binario. El argv0 manda sobre
# RAVN_SESSIONIZER_MODE, y la invocación de fzf es idéntica a la del
# subcomando equivalente (issue #3): mismos argumentos y misma entrada.
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

aliasbin="$tmp/aliasbin"
mkdir -p "$aliasbin"
ln -s "$bin" "$aliasbin/rs"
ln -s "$bin" "$aliasbin/ri"
export PATH="$aliasbin:$PATH"

alias_fzf_igual() { # alias_fzf_igual <args-guardados> <in-guardado> <etiqueta>
  local diffout
  diffout="$STUB_DIR/fzf-diff"
  if ! diff -u "$1" "$STUB_DIR/fzf-args-1" >"$diffout"; then
    cat "$diffout" >&2
    fallo "$3 (argumentos de fzf)"
  fi
  if ! diff -u "$2" "$STUB_DIR/fzf-in-1" >"$diffout"; then
    cat "$diffout" >&2
    fallo "$3 (entrada de fzf)"
  fi
}

# rs con MODE=trio: el argv0 manda sobre la variable y abre workspaces igual.
fzf_script $'||CANCEL'
RAVN_SESSIONIZER_MODE=trio rs
cp "$STUB_DIR/fzf-args-1" "$tmp/rs-args"
cp "$STUB_DIR/fzf-in-1" "$tmp/rs-in"

# La misma invocación de fzf que ravn-sessionizer pick (issue #3), no solo el
# mismo prompt: los argumentos y la entrada tienen que ser idénticos.
: > "$STUB_LOG"
fzf_script $'||CANCEL'
"$bin" pick
grep -q 'workspace › ' "$STUB_DIR/fzf-args-1" || fallo "pick lanza la vista de workspaces"
alias_fzf_igual "$tmp/rs-args" "$tmp/rs-in" "rs (con RAVN_SESSIONIZER_MODE=trio) y ravn-sessionizer pick no invocan fzf igual"

# ri = vista de issues (trio).
: > "$STUB_LOG"
fzf_script $'||CANCEL'
ri
cp "$STUB_DIR/fzf-args-1" "$tmp/ri-args"
cp "$STUB_DIR/fzf-in-1" "$tmp/ri-in"

# La misma invocación de fzf que ravn-sessionizer trio (issue #3).
: > "$STUB_LOG"
fzf_script $'||CANCEL'
"$bin" trio
grep -q 'issues › ' "$STUB_DIR/fzf-args-1" || fallo "trio lanza la vista de issues"
alias_fzf_igual "$tmp/ri-args" "$tmp/ri-in" "ri y ravn-sessionizer trio no invocan fzf igual"

echo "ok test-aliases"
