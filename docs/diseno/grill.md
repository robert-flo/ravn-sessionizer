# Grill de diseño — sessionizer de herdr (fo-herdr-sessionizer → ravn-sessionizer)

> Estilo *grill-with-docs*: un árbol de decisiones. Cada pregunta trae **respuesta recomendada** y **por qué**. Marcá ✅/✏️ en cada nodo; lo que quede ✏️ es lo que tenemos que hablar.
> Este sessionizer lo vas a ver todo el día, todos los días: cada decisión se mide en milisegundos y en teclas.

## 0. Lo que estudié

### Upstream (`salkhalil/herdr-sessionizer` v0.5.0)

- `herdr-plugin.toml`: 2 *actions* (`pick`, `agents`) → `bin/open-picker` → abre el *pane* `picker` (`placement = "overlay"`) que corre `bin/sessionizer`.
- `bin/sessionizer` (431 líneas, un solo archivo): lista workspaces abiertos (orden por *switch history*, el enfocado último → `enter` alterna como `switch-client -l`) + directorios de **zoxide** (solo raíces git) + `extra_dirs`. `tab` alterna a la *vista de agentes* (`herdr agent list`, orden `blocked > done > working > idle`), preview con `herdr agent read --format ansi`. Crear = `workspace create --cwd --label --focus` + tabs de un *template* (`pane run` con `sleep 0.2`). Reusa workspace si el cwd del primer pane coincide con el dir.
- Config: `config.json` en `herdr plugin config-dir sessionizer` (fallback `~/.config/herdr-sessionizer`); historial en `state/history`.
- **Límites**: monolito bash; depende de zoxide (no conoce `/z-drive/tries`); sin caché; sin noción de proyecto `pj-*`, issues ni trío; match de reuso solo por cwd del primer pane (falla si el workspace lo creó pj-trio con label `trio …`); `sleep 0.2` frágil; colores ad hoc; sin tests; `die` con `sleep 4`.

### herdr (docs oficiales, plugin v1)

- "**El CLI entero es la API del plugin**"; usar `$HERDR_BIN_PATH`. Manifest: `[[actions]]`, `[[panes]]` (`overlay`), `[[events]]`, `[[startup]]`, `[[link_handlers]]`, `[[build]]`.
- Atajos en `~/.config/herdr/config.toml`: `[[keys.command]]` con `type = "plugin_action" | "popup" | "pane" | "shell"`. Reciben `HERDR_ACTIVE_WORKSPACE_ID`, `HERDR_ACTIVE_PANE_CWD`, etc.
- `plugin install` (solo GitHub) / `plugin link <dir>` (local). Config/estado por plugin en dirs que herdr maneja (`plugin config-dir <id>`) → cae en `~/.config` / `$HOME` (workstation#63).
- Ojo: el ejemplo oficial de `prefix+t` es una *popup* de shell scratch; hay que confirmar que no pisa un default.

### ravn-trio (`pj-trio`)

- `pj-trio [--dry-run] [--no-kickoff] [--print-kickoff] <proyecto> <ticket> [--repo <miembro>]`; idempotente: crea/reusa workspace `trio <proyecto>[/<miembro>]#<ticket>` con tabs `pm`/`wk`/`rv` (agentes `pm-<proyecto>-<ticket>`…, kinds `agy`). cwd = meta-repo; miembro vía `--add-dir`. Kickoff una vez por ticket (`.trio/<ticket>/status.json`).
- Diseño git-setup: launcher raíz + `runtime/{commands.tsv, lib/, scripts/, helper/, completion/}`; libs compartidas idénticas (`presentation.sh`, `command_catalog.sh`, `command_interface.sh`, `dispatch.sh`, `lifecycle.sh`) + libs de dominio (`trio_*.sh`). `make check` = shellcheck + tests; `make DESTDIR= install` → `/usr/share/ravn/<x>/` + symlink en `/usr/bin`.

### git-setup (ADR 0001)

- Payload privado en `runtime/`, módulos de comando ejecutables, launcher delgado; paquete Arch en repo aparte (`-arch`). Lenguaje visual: `presentation.sh` (colores semánticos, `ICON_*`, `RAVN_ICON[...]`, Nerd Fonts, degradación sin color con `NO_COLOR`/pipe).

### Cómo mapea lo nuestro

| Querés | Upstream | Cambio |
|---|---|---|
| Buscar en `/z-drive/tries` + `/z/pj-omarchy` | zoxide + `extra_dirs` | fuente `roots` propia con caché; zoxide solo como señal de frecuencia |
| `pj-*` → issues `ready-for-agent` | — | vista nueva "issues" (gh) |
| Lanzar trío | template de tabs | delegar 100 % a `pj-trio` (no duplicar lógica) |
| `prefix+t` | — | nueva action `trio` + keybind |
| Modular | monolito | `runtime/` estilo git-setup |

---

## 1. Identidad del proyecto

### 1.1 ¿Fork o dúo `ravn-sessionizer` desde ya?
**Recomendado:** arrancar en el fork `fo-herdr-sessionizer` solo como *banco de pruebas* (v0: roots + pj-flow encima del upstream, rápido de usar ya), y saltar a `ravn-sessionizer` + `ravn-sessionizer-arch` **en cuanto** toquemos estructura (antes de la segunda feature grande).
**Por qué:** el monolito upstream no admite la arquitectura git-setup sin reescribirlo; mantener un fork divergente es deuda. El fork sirve para validar UX con datos reales una semana.

### 1.2 ¿Qué dispara el salto?
**Recomendado:** el primer de estos: (a) la vista de issues funciona y la usás a diario, (b) necesitamos un segundo módulo de comando, (c) queremos instalarlo vía pacman.
**Por qué:** criterio objetivo, evita "lo hacemos después" eterno.

### 1.3 ¿Seguimos upstream?
**Recomendado:** no hacer rebase continuo; en `ravn-sessionizer` acreditar el upstream (LICENSE/README) y portar ideas (vista de agentes, toggle `enter`) a mano.
**Por qué:** el código diverge al 90 %; seguir merges cuesta más que portar.

### 1.4 Nombre del binario y del plugin id
**Recomendado:** binario `ravn-sessionizer` (alias corto `rs`?), plugin id `ravn.sessionizer`, acciones `pick`, `agents`, `trio`.
**Por qué:** ids con punto evitan colisión con el upstream si ambos están instalados (`ravn.sessionizer.pick`). ✏️ ¿alias corto sí/no?

## 2. Fuentes de búsqueda y caché

### 2.1 ¿Qué raíces?
**Recomendado:** lista en config: `roots = ["/z-drive/tries"]`, `extra = ["/z/pj-omarchy"]`; profundidad 1 (cada hijo directo de `tries` es un repo); filas solo si contienen `.git`.
**Por qué:** tu convención es "una sola raíz de clones"; profundidad 1 = listar instantáneo. ✏️ ¿Hay repos anidados (miembros dentro de `pj-*`)? Si sí, profundidad 2 solo bajo `pj-*`.

### 2.2 ¿Caché?
**Recomendado:** listar con `find -maxdepth 1` en cada apertura (es <10 ms para cientos de dirs) y **cachear solo lo caro**: issues de gh (TTL 5 min en `$XDG_CACHE_HOME/ravn-sessionizer/issues/<repo>.json`) y metadatos git (rama/dirty) calculados *lazy* en el preview.
**Por qué:** caché de directorios = invalidación innecesaria; lo lento es la red.

### 2.3 ¿Zoxide?
**Recomendado:** opcional, solo como peso de frecuencia (`zoxide query -ls`), nunca como fuente.
**Por qué:** que un clon nuevo aparezca aunque nunca hayas hecho `cd`.

### 2.4 ¿Live search?
**Recomendado:** fzf normal (filtro en memoria) sobre la lista completa; `ctrl-r` recarga. No `--disabled` + reload por tecla.
**Por qué:** lista chica → el filtro local es el más rápido posible.

## 3. UX del picker

### 3.1 Orden / frecencia
**Recomendado:** 1) workspaces abiertos por recencia (actual último, se conserva el toggle `enter`), 2) repos por frecencia propia (historial del sessionizer, decaimiento exponencial, vida media 7 días), 3) resto alfabético. `pj-*` sin prioridad extra.
**Por qué:** lo que usás todo el día flota; el toggle es la feature más valiosa del upstream.

### 3.2 Formato de fila (lenguaje visual git-setup)
**Recomendado:** `<icono> <nombre>  <badges grises>` con colores de `presentation.sh`:
- `ICON_GIT` repo normal (blanco), ícono de proyecto para `pj-*` (MAGENTA), workspace abierto `●` VERDE, agente blocked `ICON_WARN` ROJO, dirty `±` AMARILLO.
- Respeta `NO_COLOR` (los `[OK]`/`[WARN]` de presentation.sh).
**Por qué:** un solo vocabulario visual en toda la flota ravn.

### 3.3 Teclas
**Recomendado:**
- `enter` abrir/enfocar · `tab` vistas (repos ⇄ agentes) · `ctrl-r` refrescar
- en `pj-*`: `enter` entra a la vista issues; `alt-enter` abre el meta-repo como workspace normal
- en vista issues: `enter` → elegir miembro → pj-trio · `ctrl-n` ticket sin issue · `ctrl-o` abrir issue en navegador · `esc` volver
- `ctrl-x` cerrar workspace (con confirmación)
- Header de fzf con la leyenda, siempre visible.
**Por qué:** `enter` hace lo esperado en cada nivel; los modificadores son escapes. ✏️ ¿`enter` en `pj-*` entra a issues (recomendado) o abre el workspace?

### 3.4 Preview
**Recomendado:** repo: rama, ahead/behind, dirty, último commit, README (primeras líneas, `bat` si existe). Workspace abierto: tabs + estado de agentes. `pj-*`: conteo de issues `ready-for-agent` + tríos activos. Issue: título, labels, cuerpo (`gh issue view`, desde caché). Agente: pantalla viva (upstream).
**Por qué:** decidir sin abrir nada.

### 3.5 ¿Overlay pane o popup?
**Recomendado:** mantener `[[panes]] placement = "overlay"` vía `plugin_action`.
**Por qué:** es la vía soportada para plugins; la popup no recibe `HERDR_PANE_ID` y no la maneja el manifest.

## 4. Flujo `pj-*`

### 4.1 ¿Cómo se detecta un meta-repo?
**Recomendado:** nombre `pj-*` (más `/z/pj-omarchy`) y remoto GitHub resoluble (`gh repo view` desde caché).
**Por qué:** convención fuerte ya establecida.

### 4.2 Picker de issues
**Recomendado:** `gh issue list -R <repo> --label ready-for-agent --state open --json number,title,labels,assignees,updatedAt`; fila `#<n> <título>` + badge si ya hay trío abierto para ese ticket (workspace `trio <proyecto>…#<n>` existente → VERDE "abierto").
**Por qué:** ver qué ya está en vuelo evita lanzar duplicados (aunque pj-trio sea idempotente).

### 4.3 Elegir miembro
**Recomendado:** después del issue: lista de miembros = (a) los declarados por el meta-repo si hay archivo (✏️ ¿existe un manifiesto de miembros en los `pj-*`? p. ej. `members.txt`/sección de `AGENTS.md`), si no (b) heurística: labels `repo:<x>` del issue → preselección; (c) opción "sin miembro" siempre primera.
**Por qué:** `--repo` es opcional en pj-trio; no forzar un paso extra cuando el ticket es solo del meta-repo.

### 4.4 Ticket sin issue
**Recomendado:** `ctrl-n` pide un id libre (fzf `--print-query`), validado `^[0-9A-Za-z._-]+$`, y llama pj-trio igual.
**Por qué:** pj-trio acepta tickets arbitrarios (ej. `999`).

### 4.5 ¿Quién lanza?
**Recomendado:** el sessionizer **solo** arma argv y hace `exec pj-trio start <proyecto> <ticket> [--repo <miembro>]`; nada de crear tabs él mismo. `--dry-run` disponible para tests.
**Por qué:** una sola fuente de verdad del trío; si pj-trio cambia, el sessionizer no se rompe.

## 5. Reuso de sesiones

### 5.1 ¿Cuándo reusar un workspace?
**Recomendado:** match por, en orden: (1) label exacto (para tríos), (2) cwd de *cualquier* pane del workspace == dir (no solo el primero), (3) si no, crear.
**Por qué:** el upstream falla con workspaces cuyo primer pane cambió de cwd.

### 5.2 ¿Template para workspaces nuevos?
**Recomendado:** default 1 tab `main` (shell); overrides por glob en config (como upstream). Esperar el shell con `herdr wait output`/estado en vez de `sleep 0.2`.
**Por qué:** robustez.

## 6. `prefix+t`

### 6.1 ¿Qué hace?
**Recomendado:** action `ravn.sessionizer.trio`: si el pane activo está dentro de un `pj-*` (usa `HERDR_ACTIVE_PANE_CWD`), salta directo a la vista de issues de ese proyecto; si no, abre el picker filtrado a `pj-*`.
**Por qué:** cero teclas extra en el caso común.

### 6.2 ¿"Hardcoded"?
**Recomendado:** el binding vive en `~/.config/herdr/config.toml` (lo instala/propone el paquete o la workstation, no el plugin — herdr no deja que el manifest registre teclas). Verificar que `prefix+t` no colisiona con un default de herdr (la doc lo usa como *ejemplo* de scratch popup).
**Por qué:** el manifest no declara keybindings; hay que documentarlo como paso de instalación. ✏️ ¿lo escribe la workstation (chezmoi/omarchy) o el paquete vía `post_install` sugerido?

## 7. Config y el problema de `~/.config` (workstation#63)

### 7.1 ¿Dónde vive la config?
**Recomendado:** precedencia: `$RAVN_SESSIONIZER_CONFIG` → `$HERDR_PLUGIN_CONFIG_DIR/config` → `/etc/ravn/sessionizer.conf` → defaults en `/usr/share/ravn/sessionizer/sessionizer.conf.example`. Formato **shell `KEY=valor`** (como `trio.conf`), no JSON.
**Por qué:** igual que pj-trio (consistencia, sin jq para config); `/etc` es el lugar sano si `$HOME` es problemático. ✏️ depende de cómo se resuelva #63.

### 7.2 ¿Y el plugin mismo?
**Recomendado:** `herdr plugin link /usr/share/ravn/sessionizer` (lo apunta el paquete); herdr guarda el registro en `$HOME` igual, no es evitable. Estado (historial) en `$XDG_STATE_HOME/ravn-sessionizer`, caché en `$XDG_CACHE_HOME`.
**Por qué:** el código queda en `/`, solo el registro y el estado tocan `$HOME`.

## 8. Empaquetado

### 8.1 Ruta
**Recomendado:** `ravn-sessionizer-arch` con PKGBUILD → `make DESTDIR="$pkgdir" install` → `/usr/share/ravn/sessionizer/` + `/usr/bin/ravn-sessionizer`. Única ruta a `/` es pacman.
**Por qué:** mismo modelo que trio/git-setup (ADR 0001).

### 8.2 Dependencias
`depends=(bash herdr fzf jq git github-cli ravn-trio)`, `optdepends=(zoxide bat)`.

## 9. Tests

**Recomendado:** `tests/run.sh` como ravn-trio; `herdr` y `gh` **falsos** en `PATH` (stubs que devuelven JSON fijo y registran argv); tests de: listado de roots, orden de frecencia, armado del argv de pj-trio (con/ sin miembro, ticket libre), reuso por label/cwd, `NO_COLOR`. fzf con `--filter` para pruebas no interactivas. `make check` = shellcheck + tests en CI.
**Por qué:** lo que más se rompe es la integración; los stubs la cubren sin herdr real.

## 10. Modos de falla

| Falla | Comportamiento |
|---|---|
| `gh` sin auth / sin red | vista issues muestra caché vieja con aviso AMARILLO; `ctrl-n` sigue funcionando |
| `pj-trio` no instalado | fila de issues deshabilitada, `print_error` con cómo instalar |
| root inexistente | `print_warn`, se omite |
| herdr < versión mínima | `die` claro al inicio |
| fzf viejo | idem upstream (≥ 0.45) |
| pj-trio falla | el pane overlay no se cierra: muestra stderr y espera tecla (no `sleep 4`) |
| workspace duplicado | reuso por label lo evita |

## 11. Arquitectura propuesta (mapeo a git-setup)

```text
ravn-sessionizer/
├── ravn-sessionizer            # launcher: dispatch por runtime/commands.tsv; sin subcomando → pick
├── herdr-plugin.toml           # actions pick/agents/trio → `ravn-sessionizer <cmd>`; pane overlay
├── sessionizer.conf.example
├── Makefile                    # check/test/lint/install (DESTDIR) — copia de ravn-trio
└── runtime/
    ├── commands.tsv            # pick, agents, trio, list, preview, open, help
    ├── completion/ravn-sessionizer.bash
    ├── helper/set_variable.sh
    ├── lib/
    │   ├── presentation.sh  command_catalog.sh  command_interface.sh  dispatch.sh  lifecycle.sh   # idénticas
    │   ├── ses_config.sh       # precedencia de config, roots
    │   ├── ses_sources.sh      # roots + workspaces + frecencia (historial)
    │   ├── ses_herdr.sh        # snapshot, focus, create, reuso por label/cwd
    │   ├── ses_github.sh       # issues ready-for-agent + caché TTL
    │   └── ses_fzf.sh          # binds, header, render de filas con iconos
    └── scripts/
        ├── pick   agents   trio      # vistas interactivas
        ├── list   preview            # internos que llama fzf (reload/preview)
        ├── open                      # dir|workspace|agent → focus/create
        └── help
```

`commands.tsv` (borrador):

```text
# canonical	aliases	label	description	icon	menu	options
pick	p --pick	Pick	Repos y workspaces (vista por defecto).		1	-h --help
agents	a --agents	Agents	Saltar al agente más urgente.	󰚩	1	-h --help
trio	t --trio	Trio	Issues ready-for-agent de un pj-* → pj-trio.		1	-h --help
list	--list	List	(interno) filas para fzf.		0	-h --help
preview	--preview	Preview	(interno) preview de una fila.		0	-h --help
open	o --open	Open	Enfocar o crear workspace para un dir.		1	-h --help
help	h --help -h	Help and usage	Show this guide.	󰋖	1	-h --help
```

## 12. Preguntas abiertas (resumen)

1. ¿`enter` en un `pj-*` entra a issues o abre el workspace? (recomendado: issues; `alt-enter` workspace)
2. ¿Existe/creamos un manifiesto de miembros por `pj-*`, o heurística por labels `repo:`?
3. Config/keybind con #63 sin resolver: ¿`/etc/ravn` + quién escribe `prefix+t` en `config.toml`?
4. ¿Cuándo exactamente saltamos a `ravn-sessionizer`: ya, o tras una semana de uso del fork?
5. ¿Profundidad de búsqueda: solo hijos de `/z-drive/tries` o también miembros anidados?
