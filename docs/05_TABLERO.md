# ROCK — Tablero de estado

Registro vivo de en qué punto está cada cosa. **Esta es la fuente de verdad**: si
una entrada de aquí y un comentario del código se contradicen, gana lo que diga
el código y se corrige el tablero en el mismo commit.

Cinco estados, y la diferencia entre ellos importa:

| Estado | Qué significa exactamente |
|---|---|
| **LISTO** | Hecho **y verificado por un test**. Sin test que lo cubra no es listo, es "creo que funciona". |
| **EN PROCESO** | Hay código escrito ahora mismo. Como mucho dos o tres cosas a la vez. |
| **BUGUEADO** | Funciona mal **y la causa está medida**. Un bug sin causa medida va a EN PROCESO hasta que se mida. |
| **BLOQUEADO** | No se puede empezar hasta que otra cosa termine, y esa cosa está nombrada. |
| **FALTA** | Ni empezado. Sin nada que lo impida salvo el orden. |

---

## LISTO

**Fases 0, 1 y 2 cerradas.**

| | Verificado por |
|---|---|
| Traversal: FSM jerárquica de 5 grupos y 27 estados | `TestFase1` 12/12 |
| `SurfaceContext` + `LocomotionMotor`, escalada 45–110° | `TestFase1` · `TestVisual` |
| Combate: `AttackData`, hitbox por consulta, hitstop, parry, poise, ragdoll | `TestFase2` 129/129 |
| **FSM de enemigos extraída** (P0.1) — `Guardian.gd` de 372 a ~100 líneas | `TestEnemigos` 14/14 |
| Embestidor · Volador · ColosoMediano | `TestEnemigos` 14/14 |
| Los dos clavados diferenciados: ligero rebota, pesado levanta | `TestFase2` |
| Screenshot test, 10 tomas | `TestVisual` 10/10 |
| Mallas de los tres enemigos (collider ≠ visual) | `TestVisual` · toma `corral_enemigos` |
| ProtonScatter compilando en 4.7 | arranque limpio |
| **Portabilidad**: Player, Volador, Guardián y Coloso arrancan en escena desnuda | medido, ver §Notas |
| **Apuntado en 3D** — un enemigo encima ya se puede fijar | `TestEnemigos` |
| **El arrastre del coloso** — 13.82 → **1.73 m/s** en el borde, por debajo de caminar | `TestEnemigos`, invariante |
| **La altura del volador** — medida sobre el suelo, no sobre tu cabeza | `TestEnemigos` |
| **Menu de controles (F1)** — primera UI del proyecto, lee el InputMap en vivo | `TestMenu` 4/4 |

Jefe Kuramoto **documentado** en `project.md §5`. Documentar es el entregable; no
se implementa.

---

## EN PROCESO

- **Parche 3.05.** Remate aéreo y entorno modular. Rama `Ver3.05`.

---

## BUGUEADO

Ordenados por lo que más estorba para jugar.

### 1 · Los verbos de pared se pisan
La adherencia automática mide la **dirección de input deseada**
(`dot(-normal) ≥ 0.65`, o sea ≤ 49.5°); el wall-run mide la **dirección real de
movimiento** (≥ 55°). Dos vectores distintos que con momentum divergen: **las
dos condiciones pueden ser ciertas a la vez** y decide un temporizador de 0.35 s.
Además queda una zona muerta entre 49.5° y 55°, y el wall-slide exige
`get_vertical() < 0.0`, así que subiendo no ocurre nada.

### 2 · `GroupAirborne` no comprueba `maneja_salto()`
Solo lo hace `GroupGrounded`. Es el corolario de la regla dura #13 escrito en
`CLAUDE.md` y aun así incumplido: en el aire, una hoja no puede reclamar el
salto. En su lugar hay `fsm.actual.name != &"WallRun"`, que es el
`if state == "x"` que prohíbe la regla #2.

### 3 · `direccion_frontal()` devuelve +Z
Devuelve `visual.global_basis.z`, no `-z`. Cazado montando el screenshot test:
un jugador colocado sin girar sondea **en dirección contraria** a la pared que
tiene delante.

---

## BLOQUEADO

| Qué | Bloqueado por |
|---|---|
| **Cámara cinematográfica** | `CameraTuning` / `PhantomDirector` / `PhantomRig` están escritos pero sin cablear. Phantom se queda con el `transform` y todo el movimiento deduce la dirección de `player.camara()`: cablearlo tal cual son **18 tests en rojo**. |
| **Inventario BotW** | Sigue siendo la capa de UI que no existe. El menú de controles abrió `src/ui/` y fijó las costumbres —se construye por código, los colores salen de la `Palette`—, pero un inventario paginado con arrastrar y soltar pide navegación y gestión de foco, que es otro orden de magnitud. |

---

## FALTA

**Deuda del roadmap (P0):**
- Escala unificada de screen shake — hoy sale de ~15 sitios con valores a mano.
- Audio mínimo — `content/audio/` está vacío. El multiplicador de juice más barato.
- Sincronizar los números del roadmap con la realidad.

**Contenido:**
- **Remate aéreo 3+1** — pesado en el aire: tres golpes que persiguen
  recalculando cada frame y un cuarto que estampa. **Desbloqueado**: el apuntado
  en 3D ya existe. Ojo con `velocidad_maxima = 22`, que recorta en silencio, y
  con `cd_dive`, que estrangula la cadena.
- Fase 3: lanza y lazo.
- `SquadDirector` — grupos de enemigos.
- IA acuática.
- Fase 4: el coloso.

**Herramientas y entorno:**
- Plantilla de nivel vacía + comprobador de geometría importada.
- Guía de uso de ProtonScatter.

---

## APARCADO A PROPÓSITO

No es que falte: es que **se decidió no hacerlo todavía**, y el motivo está
escrito. Distinguirlo de FALTA importa, porque una idea aparcada que se cuela en
la lista de pendientes acaba construyéndose sin que nadie decida construirla.

| Idea | Dónde | Por qué espera |
|---|---|---|
| **El lobo** — montura viva | `project.md §4` | Va **después** del coloso mediano. Construir la montura antes significaría estrenar el marco móvil a la vez que se diseñan controles nuevos: dos cosas difíciles al mismo tiempo. Y la mitad del trabajo de un lobo no es montarlo, es cómo se comporta cuando **no** lo montas — seguirte, esperarte, perderte de vista. |
| **Jefe Kuramoto** — el sincronizador | `project.md §5` | Es un jefe de *ritmo*, no de escalada. Toda su gracia depende de que pegar y esquivar ya se sientan bien, así que pide el combate base cerrado. |

Regla que aplica a los dos: **no se añaden ganchos "por si acaso"**. Un hueco
vacío en la arquitectura envejece peor que un hueco inexistente.

---

## Notas

**Los PR se acumulan.** #2, #3 y #4 siguen abiertos sin mergear. Cada rama
parte de la anterior, así que cuanto más se tarde, más caro sale.

**GitHub Desktop hace stash del trabajo sin avisar.** Ha pasado dos veces
(`stash@{1}` en la 2.01, `stash@{0}` en la 3.04) y las dos veces el árbol
apareció limpio con el trabajo escondido. Si algo "desapareció",
`git stash list` antes que nada.

**Portabilidad, medida y no supuesta.** `Player.tscn` en una escena con solo
suelo y cámara: aterriza, se desplaza 4.11 m con input y llega a `Move`. Volador,
Guardián y Coloso arrancan igual. Funciona porque todo el acoplamiento va por
autoloads, por `class_name` estáticos y por Resources — nada apunta a
`Main.tscn`— y `camara()` es `get_viewport().get_camera_3d()`.
Las tres condiciones para geometría nueva: **collider en capa 1**, escalable en
**capa 4**, y nada más empinado de **45°** es caminable.
