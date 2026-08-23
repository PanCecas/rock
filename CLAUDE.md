# ROCK — Contexto del proyecto

Juego 3D en **Godot 4.7** (Forward+, Jolt Physics, D3D12). Español para docs y comentarios.

## Qué es
Un clon de *Shadow of the Colossus* con la movilidad de un plataformero 3D moderno
(*Tears of the Kingdom*) y combate cuerpo a cuerpo estilizado. Verbos del jugador:
correr, saltar, doble salto, dash, planear, deslizarse, wall-run, agarrarse de bordes,
escalar, parry, esquiva, espada, **lanza equipable y lanzable**, lazo/gancho, arco.
El contenido real son los **colosos**: bosses gigantes que funcionan como niveles de
plataformas en movimiento.

## Documentación — leer antes de tocar nada
| Doc | Contiene |
|---|---|
| `docs/00_VISION.md` | Pilares. Toda decisión se justifica contra ellos. |
| `docs/01_DIRECCION_ARTE.md` | **Paleta con hex exactos, regla 60/30/10, shaders, post.** |
| `docs/02_PIPELINE_PERSONAJES_ANIM.md` | Rig, ~205 clips por tiers, concept art, export. |
| `docs/03_ARQUITECTURA_MECANICAS.md` | **Arquitectura completa. La referencia técnica.** |
| `docs/04_ROADMAP.md` | Fases, hitos, orden de construcción. |

## Reglas duras del código
1. **Ningún número mágico en `.gd`.** Todo valor que se toque para "que se sienta bien" vive en
   `PlayerTuning.tres`, `AttackData.tres` o `Palette.tres`.
2. **La FSM manda.** Prohibido `if state == "x"` fuera de la máquina de estados. Cada estado es
   un `Node` con `enter/exit/physics_update/handle_input` y declara sus transiciones.
3. **`SurfaceContext` siempre.** El jugador nunca asume `Vector3.UP` ni un mundo quieto. El
   suelo estático es solo el caso `frame == null`. Nunca se reparenta el jugador a un coloso.
4. **Input solo por `InputBuffer`.** Nada de `Input.is_action_just_pressed()` en los estados.
5. **Hitstop congela `AnimationTree`, nunca `Engine.time_scale`.**
6. **Composición sobre herencia.** Nodos-componente, no jerarquías de clases.
7. **El feel se prueba con cápsulas grises** antes de que exista una sola animación.
8. **Croma (medido en Okhsl, no HSV):** neutros ≤ 0.40 · vegetación ≤ 0.66 ·
   acentos ≥ 0.65. Y los tonos 200–265° (azul) y 335–25° (rojo) están **reservados**:
   ningún material de entorno entra ahí por encima de croma 0.35. Lo valida
   `Palette.validar()`.
9. Colores solo desde `Palette.tres`. Nunca un hex escrito a mano en un shader o material.
10. **Exports a nodos siempre como `NodePath` + `get_node_or_null()`**, nunca
    `@export var x: Node3D`. Los exports tipados a Node no se resuelven al
    instanciar la escena y dejan la referencia en null sin avisar.

## Autoloads
`EventBus`, `GameState`, `HitstopManager`, `DebugOverlay`. Nada más.

## Estructura
Ver `docs/03_ARQUITECTURA_MECANICAS.md §0`. Resumen: `src/` (código por sistema),
`content/` (assets y datos), `tools/` (Gym, ColossusTestRoom), `docs/`.

## Controles y teclas compartidas
Dos teclas llevan dos acciones cada una, a propósito (es el esquema de TotK):

| Tecla | Acciones | Cómo se desambigua |
|---|---|---|
| Espacio / A | `jump` + `glide` | **Pulsar = saltar. Mantener en el aire = planear** (desde el apice). Una pulsacion nueva siempre salta; el planeo solo mira si la tecla sigue abajo. |
| Shift / B | `dash` + `sprint` + `dodge` | **Toque = evasion corta. Mantener = evasion y luego sprint continuo** (`dash_tap_max`). |

Lo resuelve `InputActions.EXCLUSIVAS` + `InputBuffer.consume()`: consumir una accion
invalida a su hermana **si vino de la misma pulsacion** (ventana de 30 ms). `sprint`
queda fuera de esa lista a proposito, o mantener Shift tras un dash dejaria de correr.

Colgado de un canto: **empujar arriba sube**, **saltar salta desde el canto** (y te
deja el doble salto disponible para encadenar en el vacio).

Junto a una pared, **saltar rebota** en vez de gastar el salto aereo: el wall-jump
tiene prioridad sobre el doble salto en `GroupAirborne`, y sigue disponible durante
`pared_coyote` segundos despues de perder el contacto.

## Herramientas
| Script | Para qué |
|---|---|
| `tools/Gym.gd` | Genera la sala de pruebas por código. Editar parámetros, no cubos. |
| `tools/smoke_test.gd` | Comprobación de humo. `godot --headless --path . --script tools/smoke_test.gd` |
| `tools/medir_paleta.gd` | Imprime croma y luminancia de cada color. Mide antes de inventar umbrales. |
| `tools/captura.gd` | Guarda capturas del Gym y del circuito sin abrir el editor. |
| `tools/Circuito.gd` | La carrera de obstaculos del Hito 1, con cronometro. |
| `tools/TestFase1.tscn` | Test funcional de la FSM. `godot --headless --path . tools/TestFase1.tscn` |

Tras crear o renombrar una clase con `class_name`, corre
`godot --headless --path . --import` o el proyecto no la encontrará.

## Estado actual
**Fases 0 y 1 cerradas.** El jugador tiene los verbos completos de traversal:

- `SurfaceContext` + `LocomotionMotor`: toda la matematica en el plano del marco de
  referencia, nunca en XZ del mundo. Listo para colosos sin tocar una linea.
- FSM jerarquica con 3 grupos y 13 estados. Los grupos resuelven las transiciones
  compartidas; las hojas solo su propio comportamiento.
- Correr, esprintar, saltar, doble salto, dash (suelo/aire), planear, deslizarse,
  wall-run, wall-slide, wall-jump, agarrar cantos, shimmy, subir, escalar.
- Stamina unica, camara con modos, DebugOverlay completo, circuito cronometrado.

Siguiente paso: **Fase 2** — combate. `AttackData` como Resource, `HitstopManager`
conectado, ventanas de cancelacion y parry. El hitstop ya existe como autoload con
su API; en la Fase 2 se le enchufan los consumidores.
