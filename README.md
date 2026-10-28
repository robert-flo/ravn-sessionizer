# ravn-sessionizer

Un solo `fzf` para moverte por herdr: workspaces abiertos, clones de
`/z-drive/tries`, meta-repos `pj-*` **con sus miembros** y agentes. En un
`trio` lista los issues abiertos de todos los miembros de todos los
proyectos `pj-*` (leídos de GitHub, sin clonar nada) y enter lanza el trío con
`pj-trio start <pj> <ticket> --repo <miembro>`.

Empaquetado para Arch en
[`ravn-sessionizer-arch`](https://github.com/robert-flo/ravn-sessionizer-arch).

## Qué hace

| Atajo (sugerido) | Vista | Teclas |
|---|---|---|
| `prefix+f` | **pick**: workspaces abiertos (por recencia, el actual al final) + repos y `pj-*` por frecencia | `enter` abrir/enfocar · `alt-enter` workspace del `pj-*` sin trío · `tab` ⇄ agentes · `ctrl-r` refrescar |
| `prefix+a` | **agents**: agentes ordenados blocked › done › working › idle | `enter` enfocar el pane |
| `prefix+t` | **trio**: todos los issues abiertos de todos los proyectos, `ready-for-agent` primero; filas `<repo> #9 título` | `enter` lanzar o enfocar el trío · `ctrl-n` ticket escrito (en el repo de la fila) · `ctrl-o` navegador · `ctrl-r` refrescar |

- **Reuso:** si ya hay un workspace con ese label o con un pane en ese
  directorio, se enfoca; si no, se crea y su primera tab se llama `main`.
- **Preview:** rama, ↑↓ contra upstream, cambios, último commit, miembros e
  issues en caché (`pj-*`), README; tabs y agentes (workspace); pantalla del
  agente; cuerpo del issue.
- **Miembros:** `<pj>/.ravn/miembros` (uno por línea: ruta absoluta,
  subdirectorio o nombre de un clon en la raíz) más los repos git anidados.
- **Proyectos (trio):** repos `pj-*` de `SES_GITHUB_OWNER` con `proyecto.yml`
  (una consulta GraphQL, caché 1 h, `SES_PJ_EXCLUDE=(pj-template)`); sus
  miembros son las entradas `repo:`. Los clones de `try clone` (con fecha en
  el nombre) se reconocen por su remoto origin. Al lanzar, un clon que ya
  existe se actualiza con `git pull --rebase --autostash` (si el pull falla
  sigue con lo que hay) y lo que no existe se clona con `SES_CLONE_CMD`;
  vacío, el default es `try exec --path {root} clone {url} | bash`.
- **Issues:** `gh issue list -R <dueño>/<repo>` por repo, en paralelo, con
  caché de 5 min por repo; si gh falla se usa la caché vieja con aviso.
- **Lanzar:** si ya hay un workspace `trio <pj>[/<miembro>]#<n>` se enfoca
  (la fila muestra «● trío abierto»). Si no, se busca el pj y el miembro por
  remoto en las raíces; lo que falte se clona con `SES_CLONE_CMD` (default
  `try exec --path {root} clone {url} | bash`), corre `pj-trio start` y se
  enfoca el workspace nuevo. Sin preguntas.

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

### `rs` y `ri` (alias de bash del paquete -arch)

`ravn-sessionizer-arch` instala `/usr/share/ravn/bash/rc.d/ravn-sessionizer.bash`
(que el `rc` de `ravn-omarchy-overlay` carga en cada bash interactiva) con:

| Alias | Comando | Qué hace | Teclas |
|---|---|---|---|
| `rs` | `ravn-sessionizer repos` | **todos** los repos de `SES_GITHUB_OWNER` (gh), `●` = ya clonado en `SES_ROOTS`/`SES_EXTRA` | `enter` abrir; si no está clonado, clona **ese** repo con try-clone y lo abre · `ctrl-o` navegador · `ctrl-r` refrescar |
| `ri` | `ravn-sessionizer issues` | **todos** los issues abiertos de los repos del dueño (`gh search issues`) | `enter` lanzar/enfocar el trío (como `trio`) · `ctrl-t` repo actual ⇄ todos · `ctrl-s` nuevos ⇄ viejos primero · `ctrl-o` navegador · `ctrl-r` refrescar |

En `ri`, el proyecto del trío es el `pj-*` que declara al repo como miembro;
si ningún `pj-*` lo declara, el repo mismo hace de proyecto. Nunca se clona en
lote: solo el repo (y su pj) del elemento elegido.

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
