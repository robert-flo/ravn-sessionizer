#!/usr/bin/env bash
# make install con DESTDIR + libs compartidas sin divergir de git-setup.
set -euo pipefail
aqui="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fallo() { echo "FALLO: $*" >&2; exit 1; }

make -s -C "$aqui" DESTDIR="$tmp" install
share="$tmp/usr/share/ravn/sessionizer"
[[ -L $tmp/usr/bin/ravn-sessionizer ]] || fallo "symlink en /usr/bin"
for f in ravn-sessionizer herdr-plugin.toml sessionizer.conf.example runtime/commands.tsv runtime/scripts/pick runtime/lib/presentation.sh runtime/completion/ravn-sessionizer.bash; do
  [[ -e $share/$f ]] || fallo "falta $f"
done
NO_COLOR=1 RAVN_SESSIONIZER_CONFIG=/dev/null "$share/ravn-sessionizer" help | grep COMMANDS > /dev/null || fallo "help desde la instalación"
(cd "$aqui" && sha256sum -c --quiet tests/shared-libs.sha256) || fallo "runtime/lib compartidas difieren de git-setup"
echo "ok test-install"
