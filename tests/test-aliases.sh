#!/usr/bin/env bash
# Alias rs (vista de workspaces) y ri (vista de issues): symlinks del launcher
# que eligen la vista por el nombre del binario.
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

aliasbin="$tmp/aliasbin"
mkdir -p "$aliasbin"
ln -s "$bin" "$aliasbin/rs"
ln -s "$bin" "$aliasbin/ri"
export PATH="$aliasbin:$PATH"

# rs = vista de workspaces (pick).
fzf_script $'||CANCEL'
rs
grep -q 'workspace › ' "$STUB_DIR/fzf-args-1" || fallo "rs lanza la vista de workspaces"

# ri = vista de issues (trio).
: > "$STUB_LOG"
fzf_script $'||CANCEL'
ri
grep -q 'issues › ' "$STUB_DIR/fzf-args-1" || fallo "ri lanza la vista de issues"
echo "ok test-aliases"
