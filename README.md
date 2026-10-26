# ravn-sessionizer

Un solo `fzf` para moverte por herdr: workspaces abiertos, clones de
`/z-drive/tries`, meta-repos `pj-*` **con sus miembros** y agentes. En un
`pj-*`, enter lista sus issues `ready-for-agent` y lanza el trío con
`pj-trio start <pj> <ticket> --repo <miembro>`.

Empaquetado para Arch en
[`ravn-sessionizer-arch`](https://github.com/robert-flo/ravn-sessionizer-arch).

## Qué hace

| Atajo (sugerido) | Vista | Teclas |
|---|---|---|
| `prefix+f` | **pick**: workspaces abiertos (por recencia, el actual al final) + repos y `pj-*` por frecencia | `enter` abrir/enfocar · `alt-enter` workspace del `pj-*` sin trío · `tab` ⇄ agentes · `ctrl-r` refrescar |
| `prefix+a` | **agents**: agentes ordenados blocked › done › working › idle | `enter` enfocar el pane |
| `prefix+t` | **trio**: issues `ready-for-agent` del `pj-*` del pane enfocado | `enter` lanzar · `ctrl-n` ticket escrito sin issue · `ctrl-o` navegador · `ctrl-r` refrescar |

- **Reuso:** si ya hay un workspace con ese label o con un pane en ese
  directorio, se enfoca; si no, se crea y su primera tab se llama `main`.
- **Preview:** rama, ↑↓ contra upstream, cambios, último commit, miembros e
  issues en caché (`pj-*`), README; tabs y agentes (workspace); pantalla del
  agente; cuerpo del issue.
- **Miembros:** `<pj>/.ravn/miembros` (uno por línea: ruta absoluta,
  subdirectorio o nombre de un clon en la raíz) más los repos git anidados.
  Al lanzar un trío, el miembro de la label `repo:<x>` del issue va primero.
- **Issues:** `gh issue list` con caché de 5 min; si gh falla se usa la caché
  vieja con aviso. Si ya hay un workspace `trio <pj>[/<miembro>]#<n>`, la
  fila muestra «● trío abierto».

## Instalar (Arch / Omarchy)

```bash
git clone https://github.com/robert-flo/ravn-sessionizer-arch
cd ravn-sessionizer-arch && makepkg -si
herdr plugin link /usr/share/ravn/sessionizer
```

Después agregá los atajos a `~/.config/herdr/config.toml` (herdr no deja que
un plugin declare teclas). `prefix+f`, `prefix+a` y `prefix+t` no tienen
binding por defecto en herdr (`prefix+shift+t` sí: renombrar tab).

```toml
[[keys.command]]
key = "prefix+f"
type = "plugin_action"
command = "ravn.sessionizer.pick"
description = "sessionizer: workspaces y repos"

[[keys.command]]
key = "prefix+a"
type = "plugin_action"
command = "ravn.sessionizer.agents"
description = "sessionizer: agentes"

[[keys.command]]
key = "prefix+t"
type = "plugin_action"
command = "ravn.sessionizer.trio"
description = "sessionizer: trío desde issue"
```

Recargá con `herdr server reload-config` (o reiniciá herdr).

Fuera de herdr (o para probar): `ravn-sessionizer`, `ravn-sessionizer agents`,
`ravn-sessionizer trio --dry-run pj-algo`, `ravn-sessionizer ~/algún/dir`.

## Configuración

`/etc/ravn/sessionizer.conf` (o `RAVN_SESSIONIZER_CONFIG`), formato bash; ver
[`sessionizer.conf.example`](sessionizer.conf.example): raíces, extras,
etiqueta, TTL de la caché, vida media de la frecencia, archivo de miembros,
nombre de la primera tab y binario de `pj-trio`. Estado y caché por usuario en
`~/.local/state/ravn-sessionizer` y `~/.cache/ravn-sessionizer`. `NO_COLOR`
se respeta.

Requiere `herdr` (con plugins, ≥ 0.6.10), `fzf` ≥ 0.45, `jq`, `gh`, `git` y,
para tríos, [`ravn-trio`](https://github.com/robert-flo/ravn-trio).

## Desarrollo

```bash
make check     # shellcheck + tests (herdr, gh, fzf y pj-trio con stubs)
make DESTDIR=dest install
```

Estructura de [git-setup](https://github.com/robert-flo/pj-domina-rf-git-setup)
(ver [ADR 0001](docs/adr/0001-plantilla-git-setup.md)); diseño en
[`docs/diseno/grill.md`](docs/diseno/grill.md).

## Créditos

Inspirado en [salkhalil/herdr-sessionizer](https://github.com/salkhalil/herdr-sessionizer)
(que a su vez sigue la idea del `tmux-sessionizer` de ThePrimeagen). Ese repo
no publica licencia, así que acá **no se copió su código**: ravn-sessionizer es
una reimplementación desde cero, en bash, con otro diseño. Gracias por la idea.

## Licencia

MIT © Roberto Flores
