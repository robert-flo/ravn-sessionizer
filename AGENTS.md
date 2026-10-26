# AGENTS.md

Repo de código del dúo `ravn-sessionizer` / `ravn-sessionizer-arch`.
El empaquetado (PKGBUILD) vive en `ravn-sessionizer-arch`, no acá.

- `make lint` (shellcheck) y `make test` tienen que pasar antes de cada PR.
  Los tests no necesitan herdr, gh ni fzf reales: usan `tests/stubs/`.
- Layout instalado: todo en `/usr/share/ravn/sessionizer` (launcher,
  `herdr-plugin.toml`, `sessionizer.conf.example`, `runtime/`) y el symlink
  `/usr/bin/ravn-sessionizer`. Config del sistema en `/etc/ravn/sessionizer.conf`.
  En `$HOME` solo estado/caché XDG (historial de frecencia, caché de issues).
- Diseño de `robert-flo/pj-domina-rf-git-setup` (ADR 0001): launcher +
  `runtime/commands.tsv` + un módulo por comando en `runtime/scripts/`.
  `runtime/lib/{presentation,command_catalog,command_interface,dispatch,lifecycle}.sh`
  se copian byte a byte de git-setup (los vigila `tests/shared-libs.sha256`);
  no editarlos acá. Lo propio vive en `runtime/lib/ses_*.sh`.
- herdr se usa solo por su CLI (`$HERDR_BIN_PATH`), que es la API de plugins.
- Commits: identidad `Roberto Flores <25asab015@ujmd.edu.sv>`, sin force push.
- Docs y mensajes en español (voseo).
