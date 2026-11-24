# opencode-reflect-skill

[![CI](https://github.com/MaxiGP0/opencode-reflect-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/MaxiGP0/opencode-reflect-skill/actions/workflows/ci.yml)

[English](README.md) | [Español](README.es.md)

Port no oficial para OpenCode de **[claude-reflect](https://github.com/BayramAnnakov/claude-reflect)**, de Bayram Annakov. Captura correcciones y notas explícitas del tipo "remember:" en una cola local y después aplica las que aprobás a una sección marcada de `AGENTS.md`.

> Este es un port independiente. No está afiliado a Bayram Annakov ni a OpenCode.

## Qué funciona

| Capacidad | Estado |
| --- | --- |
| Captura de `remember: X` | Sí, cuando el agente sigue el skill |
| Captura de correcciones reutilizables ("no, usá X", "X en vez de Y", "en realidad...") | Sí, mediada por el agente |
| `/view-queue` | Sí |
| `/reflect` con revisión y aprobación | Sí |
| `/reflect --dry-run` | Sí |
| Agrupación de duplicados | Semántica por el agente, más coincidencias exactas normalizadas |
| `/skip-reflect` con confirmación | Sí |
| `/reflect-skills` a partir de sesiones recientes | Best effort; escaneo local opcional |
| Captura automática por hook | **No** |
| Dependencia de Python | **Ninguna** |
| Rutas de Claude Code o archivos de hooks | **Ninguno en el contenido instalado** |

### Por qué la captura no es automática

OpenCode V2 expone hooks de plugins, pero publicar uno acá implicaría agregar un paquete de plugin y modificar la configuración de OpenCode del usuario. Este proyecto no podía probar ese camino de punta a punta sin tocar una configuración real, así que no incluye un hook que pueda fallar en silencio.

La captura es **manual o mediada por el agente**: el skill le indica al agente que agregue un ítem a la cola cuando decís "remember: ..." o hacés una corrección reutilizable. Si la sesión termina antes de que el agente escriba el ítem, ese ítem se pierde. Usá `/view-queue` para confirmar qué se capturó.

## Requisitos

- [OpenCode](https://opencode.ai) V2 con soporte de skills y commands.
- **Windows:** PowerShell 5.1 o superior (viene con Windows 10/11).
- **macOS / Linux:** `bash`.
- Sin Python. Node.js 22.5+ es opcional y solo lo usa `/reflect-skills` para escanear sesiones recientes.

## Instalación

Este instalador copia los archivos propios del port desde el repositorio clonado. **No** descarga el plugin original, así que no tiene `-Ref` / `--ref`. Para fijar una versión, hacé checkout de un tag o commit de este repositorio antes de ejecutar el instalador.

### Windows (PowerShell)

```powershell
git clone https://github.com/MaxiGP0/opencode-reflect-skill.git
cd opencode-reflect-skill
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Si usás PowerShell 7, también funciona `pwsh -File .\install.ps1`.

### macOS / Linux

```bash
git clone https://github.com/MaxiGP0/opencode-reflect-skill.git
cd opencode-reflect-skill
bash install.sh
```

### Directorio de configuración personalizado

```powershell
.\install.ps1 -ConfigDir "D:\opencode-config"
```

```bash
bash install.sh --config-dir /ruta/a/opencode-config
```

También funciona `OPENCODE_CONFIG_DIR`. El valor por defecto es `~/.config/opencode` (`%USERPROFILE%\.config\opencode` en Windows).

### Actualizar y forzar

Sin `-Force` / `--force`, el instalador se niega a ejecutarse cuando el skill o alguno de los cuatro comandos ya existe. Volvé a ejecutarlo con force para reemplazar solo esos archivos:

```powershell
.\install.ps1 -Force
```

```bash
bash install.sh --force
```

La cola se conserva al actualizar. Otros comandos y archivos no relacionados nunca se sobrescriben.

## Archivos instalados

```text
<config>/skills/claude-reflect/SKILL.md
<config>/skills/claude-reflect/scripts/recent-sessions.mjs
<config>/skills/claude-reflect/LICENSE
<config>/skills/claude-reflect/NOTICE
<config>/commands/reflect.md
<config>/commands/reflect-skills.md
<config>/commands/skip-reflect.md
<config>/commands/view-queue.md
<config>/reflect-queue.json
```

El instalador crea una cola vacía solo si no existe ninguna. No crea ni edita `AGENTS.md`; `/reflect` crea la sección marcada cuando aplicás el primer aprendizaje.

## Verificar

```powershell
.\verify.ps1
```

```bash
bash verify.sh
```

Para un directorio personalizado:

```powershell
.\verify.ps1 -ConfigDir "D:\opencode-config"
```

```bash
bash verify.sh /ruta/a/opencode-config
```

El verificador comprueba que existan el skill y los cuatro comandos, que `SKILL.md` declare `name: claude-reflect` y una descripción, que estén documentados la ruta de la cola y los marcadores de `AGENTS.md`, y que ningún archivo instalado contenga una ruta de Claude Code o una referencia a un archivo de hooks. Si falla, sale con código distinto de cero y un mensaje concreto.

## Uso

Abrí una sesión nueva de OpenCode después de instalar. El skill se descubre por su descripción; los comandos aparecen como `/reflect`, `/reflect-skills`, `/skip-reflect` y `/view-queue`.

### Capturar

Decí cualquiera de estas frases durante una sesión:

- `remember: usá pnpm, no npm en este repo`
- `recordá: los tests van con Vitest`
- `no, usá pnpm en vez de npm`
- `use X not Y`
- `en realidad, la API devuelve un objeto paginado`

El agente debería agregar un ítem a `<config>/reflect-queue.json` y confirmarlo. Las notas explícitas con "remember:" siempre se capturan; las correcciones se capturan cuando contienen una regla reutilizable.

### Revisar y aplicar

```text
/reflect --dry-run
/reflect
```

`/reflect` carga los ítems pendientes, agrupa duplicados, muestra los bullets y archivos propuestos, y espera aprobación. Solo se escriben los grupos aprobados. Los ítems rechazados quedan pendientes.

Los bullets van dentro de esta sección:

```markdown
<!-- claude-reflect:start -->
## Learned Corrections (claude-reflect)

- Use pnpm instead of npm in this repository. (2026-11-24)
<!-- claude-reflect:end -->
```

Los ítems con alcance de proyecto van al `AGENTS.md` del directorio indicado en `project`. Los ítems globales van a `<config>/AGENTS.md`. El contenido fuera de los marcadores nunca se modifica.

### Inspeccionar y descartar

```text
/view-queue
/skip-reflect
```

`/view-queue` es de solo lectura. `/skip-reflect` muestra lo que se perdería y pide confirmación antes de escribir una cola vacía.

### Proponer comandos reutilizables

```text
/reflect-skills
/reflect-skills --days 30 --dry-run
```

Este comando busca tareas repetidas y propone archivos de comandos nuevos. Puede leer prompts recientes de la base local de OpenCode V2 cuando están disponibles Node.js 22.5+ y `node:sqlite`. Si el escáner no está disponible, usa la conversación actual y te pide contexto exportado. Nunca escribe un comando sin aprobación.

## Esquema de la cola

La cola es un único archivo JSON para toda la instalación de OpenCode. El alcance de proyecto se guarda en cada ítem.

```json
{
  "version": 1,
  "items": [
    {
      "id": "2026-11-24T18-22-05Z-7f3a",
      "text": "Use pnpm instead of npm in this repository.",
      "scope": "project",
      "source": "correction",
      "date": "2026-11-24T18:22:05Z",
      "status": "pending",
      "project": "C:\\Users\\me\\code\\my-app"
    }
  ]
}
```

| Campo | Tipo | Reglas |
| --- | --- | --- |
| `version` | número | Siempre `1` |
| `items` | array | Puede estar vacío |
| `id` | string | Único; timestamp más 4 caracteres hexadecimales |
| `text` | string | Una regla independiente, sin secretos |
| `scope` | string | `project` o `global` |
| `source` | string | `user-remember`, `correction`, `reflect-skills` o `manual` |
| `date` | string | Fecha y hora ISO 8601 UTC de captura |
| `status` | string | `pending` |
| `project` | string | Ruta absoluta; obligatoria cuando `scope` es `project` |

Los ítems aplicados se eliminan. Los rechazados y los que fallaron quedan en `pending`.

## Cómo funciona

1. El skill resuelve la raíz de configuración de OpenCode y la ruta de la cola.
2. Ante un disparador de captura, el agente lee la cola, agrega un ítem estructurado y la vuelve a escribir.
3. `/reflect` agrupa los ítems pendientes, pide aprobación y edita solo la sección marcada del `AGENTS.md` destino.
4. `/reflect` elimina de la cola los ítems aplicados.
5. `/reflect-skills` lee opcionalmente prompts recientes de la base local de OpenCode en modo solo lectura y propone archivos de comandos.

No hay scripts de Python, llamadas de red ni procesos en segundo plano.

## Diferencias con el proyecto original

| claude-reflect original | Este port |
| --- | --- |
| Plugin de Claude Code con hooks | Skill y comandos de OpenCode, sin hooks |
| Detección automática de correcciones | Captura manual / mediada por el agente |
| Scripts de Python | Ninguno obligatorio |
| Cola por proyecto dentro de un directorio de datos de Claude | Una cola en la raíz de configuración de OpenCode, con campo `project` |
| `CLAUDE.md`, `CLAUDE.local.md`, rules, auto memory | Solo `AGENTS.md` de proyecto y global |
| Puntajes de confianza y decaimiento | Sin puntajes ni decaimiento |
| Validación semántica mediante una llamada a un modelo externo | Solo revisión del agente |
| `--scan-history`, `--targets`, `--dedupe`, `--organize` | No portados |
| Revisión interactiva | Sí, con `/reflect` y `/reflect-skills` |
| Dry run | Sí, `/reflect --dry-run` |

El port prioriza un flujo chico e inspeccionable antes que la paridad total de funciones. Si necesitás el conjunto completo del proyecto original, usalo con Claude Code.

## Actualizar y desinstalar

Actualizar:

```powershell
git pull
.\install.ps1 -Force
```

```bash
git pull
bash install.sh --force
```

Desinstalar:

```powershell
Remove-Item -Recurse -Force "$HOME\.config\opencode\skills\claude-reflect"
Remove-Item "$HOME\.config\opencode\commands\reflect.md"
Remove-Item "$HOME\.config\opencode\commands\reflect-skills.md"
Remove-Item "$HOME\.config\opencode\commands\skip-reflect.md"
Remove-Item "$HOME\.config\opencode\commands\view-queue.md"
```

```bash
rm -rf ~/.config/opencode/skills/claude-reflect
rm -f ~/.config/opencode/commands/reflect.md \
      ~/.config/opencode/commands/reflect-skills.md \
      ~/.config/opencode/commands/skip-reflect.md \
      ~/.config/opencode/commands/view-queue.md
```

La cola y las secciones marcadas de `AGENTS.md` quedan en su lugar. Borralas a mano si querés empezar de cero.

## Solución de problemas

**El skill no aparece en OpenCode.** Ejecutá el verificador, confirmá la raíz de configuración y abrí una sesión nueva. OpenCode descubre los skills al iniciar la sesión.

**Los comandos no aparecen.** Confirmá que los cuatro archivos estén en `<config>/commands/` y abrí una sesión nueva. OpenCode recarga los comandos cuando cambian los archivos, pero una sesión nueva es la prueba más simple.

**No se capturó nada.** La captura depende de que el agente siga el skill. Revisá `/view-queue`; si el ítem no está, agregalo de nuevo o escribí el ítem a mano con el esquema de arriba.

**La cola está mal formada.** Hacé una copia, corregí el JSON o reemplazalo por `{"version": 1, "items": []}`. Los comandos no sobrescriben una cola mal formada.

**El instalador se niega a ejecutarse.** Encontró un skill o un comando existente. Volvé a ejecutarlo con `-Force` / `--force`.

**PowerShell bloquea el script.** Usá `powershell -ExecutionPolicy Bypass -File .\install.ps1`.

**`/reflect-skills` no puede leer sesiones.** Instalá Node.js 22.5+ o usá el fallback: pegá o exportá los prompts que querés analizar. El resto del port no necesita Node.js.

**Un bullet está mal.** Editalo directamente dentro de la sección marcada, o borralo. `/reflect` no reescribe bullets existentes salvo para evitar duplicados.

## Licencia y atribución

- **Este port:** MIT, Copyright (c) 2026 Máximo Gomez Pessoa (MaxiGP0). Ver [LICENSE](LICENSE).
- **claude-reflect original:** MIT, Copyright (c) 2025 Bayram Annakov. Ver [NOTICE](NOTICE) y el [repositorio original](https://github.com/BayramAnnakov/claude-reflect).

Adapted from claude-reflect, Copyright (c) 2025 Bayram Annakov, MIT.

Si la idea te resulta útil, dale una estrella al proyecto original: [BayramAnnakov/claude-reflect](https://github.com/BayramAnnakov/claude-reflect).
