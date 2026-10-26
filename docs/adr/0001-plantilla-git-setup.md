# 0001 · Plantilla: git-setup, no shared_dir

- Estado: aceptada (2026-10-26)
- Contexto: Roberto pidió crear ravn-sessionizer y su repo `-arch` desde
  "nuestra plantilla", eligiendo entre `pj-domina-rf-git-setup(-arch)` y
  `pj-domina-rf-shared_dir(-aur)`.

## Opciones

| | git-setup | shared_dir |
|---|---|---|
| Qué es | CLI de usuario: launcher + `runtime/commands.tsv` + módulos por comando | helper de root con unidad systemd y un `helper/common.sh` plano |
| UI | `presentation.sh` (íconos, colores, `print_*`), ayuda y completion desde el catálogo | mensajes sueltos, sin catálogo |
| Ya lo usa | ravn-trio (libs idénticas byte a byte) | — |
| Empaquetado | `-arch`: Makefile + `make/*.mk`, PKGBUILD, validación en contenedor Arch | `-aur`: PKGBUILD + install hook + `ci.yml` |

## Decisión

**git-setup.** El sessionizer es un CLI interactivo de usuario con varios
subcomandos (pick, agents, trio, open, …): exactamente la forma de git-setup.
Además deja a ravn-sessionizer igual que ravn-trio, así que las libs
compartidas se copian byte a byte y una mejora en git-setup llega a los dos.
shared_dir resuelve otro problema (un directorio compartido administrado por
root y systemd) y forzarlo acá agregaría piezas sin uso.

Del `-aur` de shared_dir solo tomamos la idea del `ci.yml` para el repo
`-arch` (git-setup-arch valida en contenedor pero no tiene workflow de CI).

## Consecuencias

- `runtime/lib/{presentation,command_catalog,command_interface,dispatch,lifecycle}.sh`
  no se editan acá; `tests/shared-libs.sha256` falla si divergen.
- Instalación a `/usr/share/ravn/sessionizer` con `make DESTDIR=… install`
  (modelo ravn-trio), no a `/opt` como git-setup-arch.
