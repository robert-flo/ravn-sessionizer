#!/usr/bin/env bash

# Shared repository, runtime and install paths for ravn-sessionizer.
helper_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SES_RUNTIME_DIR="${SES_RUNTIME_DIR:-$(cd "$helper_dir/.." && pwd)}"
# Raíz del checkout o de la instalación: ahí viven el launcher, el manifest
# del plugin y sessionizer.conf.example.
SES_ROOT="${SES_ROOT:-$(cd "$SES_RUNTIME_DIR/.." && pwd)}"
# Defaults del sistema (ver Makefile: SHAREDIR). El código nunca vive en $HOME.
SES_SHARE_DIR="${SES_SHARE_DIR:-/usr/share/ravn/sessionizer}"
SES_BIN="$SES_ROOT/ravn-sessionizer"

export SES_RUNTIME_DIR
export SES_ROOT
export SES_SHARE_DIR
export SES_BIN
