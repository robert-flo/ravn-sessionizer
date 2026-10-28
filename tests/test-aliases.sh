#!/usr/bin/env bash
# rs = vista repos, ri = vista issues. Los alias de bash los instala el paquete
# -arch (`alias rs='ravn-sessionizer repos'`); un symlink con ese nombre elige
# la misma vista por argv0, con la misma invocación de fzf que el subcomando.
# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo '[]' > "$STUB_DIR/repos.json"
echo '[]' > "$STUB_DIR/search-issues.json"
aliasbin="$tmp/aliasbin"
mkdir -p "$aliasbin"
ln -s "$bin" "$aliasbin/rs"
ln -s "$bin" "$aliasbin/ri"
export PATH="$aliasbin:$PATH"

mismo_fzf() { # mismo_fzf <cmd-alias> <subcomando> <prompt>
  fzf_script $'||CANCEL'
  RAVN_SESSIONIZER_MODE=trio "$1" || true
  cp "$STUB_DIR/fzf-args-1" "$tmp/a-args"
  fzf_script $'||CANCEL'
  "$bin" "$2" || true
  grep -q "$3" "$STUB_DIR/fzf-args-1" || fallo "$2 no abre «$3»"
  # El estado temporal de issues cambia de nombre: se compara sin él.
  diff -u <(grep -v ravn-sessionizer "$tmp/a-args") <(grep -v ravn-sessionizer "$STUB_DIR/fzf-args-1") \
    || fallo "$1 y ravn-sessionizer $2 no invocan fzf igual"
}
mismo_fzf rs repos 'rs › pj › '
mismo_fzf ri issues 'ri › pj › '

# El subcomando también acepta el nombre corto.
fzf_script $'||CANCEL'
"$bin" rs || true
grep -q 'rs › pj › ' "$STUB_DIR/fzf-args-1" || fallo "ravn-sessionizer rs = repos"

echo "ok test-aliases"
