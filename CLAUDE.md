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
| `project.md` | **Ideas futuras sin implementar.** Aros, parkour, enemigo mediano. |
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
11. **Todos los saltos pasan por `PlayerController.consumir_salto()`** y piden
    `fsm.cambiar(..., true)`: casi siempre se salta estando ya en `Jump`, y sin
    reentrada la FSM se traga la pulsacion en silencio.
12. **La velocidad horizontal se limita en un solo sitio** (`_limitar_velocidad()`,
    justo antes de `move_and_slide`). Nunca en un estado.
13. **Los grupos corren ANTES que las hojas y les roban el input.** Si una hoja
    tiene su version propia de una accion compartida, tiene que reclamarla con
    `maneja_ataques()` o `maneja_salto()`, **y el guardia tiene que existir en
    TODOS los grupos**, no solo en el de suelo. Es el fallo que mas veces ha
    aparecido en este proyecto —cadena de combos, ataques de surf, salto alto,
    DiveAttack— y siempre es silencioso: se ejecuta la accion generica y la
    especifica no llega a existir nunca.
    **Corolario:** ese guardia hace `return` en mitad de `shared_update`, asi que
    todo lo que quede DEBAJO deja de existir para las hojas que lo declaran. Por
    eso las preguntas de TERRENO —perder el suelo, pendiente, techo, agarre— van
    siempre ANTES que las de accion. Ahi vivio el "floating fall": salirse de una
    plataforma surfeando no cambiaba de estado nunca. Un guardia de INPUT no puede
    cancelar una transicion de TERRENO.
14. **La postura la resuelve el controlador, no las transiciones.** Un estado
    PIDE altura con `pedir_postura()` cada frame; nadie la restaura al salir. La
    altura de la capsula solo la cambian dos cosas: que alguien la pida, o que no
    quepas de pie. **Detectar una pared, una pendiente o una superficie escalable
    NO es motivo para agacharse** — ese acoplamiento fue el bug del cambio brusco
    de altura junto a las rampas.
15. **Un solo numero clasifica las superficies** (`PlayerTuning.clasificar`):
    `<45° camina · 45–110° escala · >110° nada`.
    El wall-run pide ADEMAS `wallrun_angulo_min` (70°), pero eso no es una
    segunda clasificacion: es un requisito extra del verbo. Correr en horizontal
    por una ladera de 50° no es una mecanica, es un error. De ahi salen el sensor de suelo,
    el de pared, la escalada y el `floor_max_angle` del cuerpo. Dos criterios
    distintos para la misma rampa es como se llega a que sea "demasiado empinada
    para andar" y "demasiado tumbada para escalar" a la vez.
16. **La orientacion del visual la escribe UN solo sitio** (`PlayerController`).
    El nado y la escalada escriben pitch y roll; la logica de tierra solo escribe
    yaw. Todo estado que incline el cuerpo tiene que llamar a `enderezar()` al
    salir, o el personaje se queda torcido para siempre. Y se hace en la
    TRANSICION, nunca como guardia por frame: un reset cada frame se pelearia con
    el dash, el agachado y el planeo.
17. **Prioridad en las paredes:** agarre > angulo. Mantener agarre SIEMPRE escala;
    sin agarre, el angulo entre tu avance y la normal decide wall-jump (de frente)
    o wall-run (rozando). Nunca por `pared.lado`: eso es del sensor, no del jugador.

## Autoloads
`EventBus`, `GameState`, `HitstopManager`, `DebugOverlay`. Nada más.

## Estructura
Ver `docs/03_ARQUITECTURA_MECANICAS.md §0`. Resumen: `src/` (código por sistema),
`content/` (assets y datos), `tools/` (Gym, ColossusTestRoom), `docs/`.

## Controles

| Accion | Teclado / raton | Mando |
|---|---|---|
| Mover / camara | WASD / raton | Stick izq. / stick der. |
| Saltar | Espacio | A |
| **Planear** | **Ctrl** o **Mouse 4** (mantener) | LB (mantener) |
| Dash / sprint / esquiva | Shift | B |
| Agacharse / slide | C | D-pad abajo |
| Salto fuerte | C (quieto) + Espacio | |
| Side jump | Correr, girar en seco y saltar (planta y luego sale) | |
| Slide kick | C con velocidad + click izq. (con espera) | |
| Long jump | Shift + C + Espacio | |
| Patada baja (derriba) | C + click | |
| **Clavado (Dive)** | **Click izq. en el aire** (siempre) | RB |
| **Clavado pesado (rebota en cabezas)** | **Click der. en el aire** | RT |
| Picado vertical (ground pound) | C + click der. en el aire | |
| Escalar | Insistir contra el muro · Shift impulsa | |
| Nadar / bucear | C bucea · mantener Espacio sube · Shift acelera | |
| Ataque acuatico | Click izq. / der. en el agua (impulso) | |
| Landing slide | Aterrizar con velocidad manteniendo C | |
| Agarrar / escalar | F (tambien desde el suelo) | Y |
| Ataque ligero / pesado | Click izq. / Click der. | RB / RT |
| Ataque de dash (estocada) | Click izq. durante dash | RB |
| Estocada de surf | **Shift** + click izq. | LB + RB |
| Frenazo de surf | **Shift** + click der. | LB + RT |
| Parry | Q | LT |
| Fijar objetivo | Click medio | R3 |
| Apuntar | R | L3 |
| Debug | F3 panel · F5 tuning · F6 paleta · F4 respawn arena | |

**El planeo esta separado del salto a proposito.** Compartir tecla obligaba a
negociar cada pulsacion entre doble salto y capa, y resultaba incomodo. Ahora
`glide` se mantiene y ya esta.

**La escalera de velocidad va con Shift, y solo con Shift:**

```
sin Shift ->  caminar -> trotar -> correr   (rampa continua por CARRERILLA)
con Shift ->  DASH (esquive corto, unidireccional) -> SURF (fluido, sostenido)
```

El dash es un **esquive**, no un desplazamiento: 0.12 s y casi sin giro. Quien
pilota es el `Surf`, que **no caduca**: se sostiene mientras mantengas Shift y su
unico limite es la stamina. Soltarlo lo corta en el acto.

La locomocion sin Shift no tiene peldanos: acumula **carrerilla** (segundos
manteniendo la direccion) y la velocidad recorre caminar -> trotar -> correr de
forma continua, con suavizado exponencial (`suavizado_velocidad`, constante de
tiempo en segundos, independiente del framerate). El stick solo pone el techo:
empujar a medias camina aunque lleves carrerilla.

**Pivote del dash:** pedir la direccion CONTRARIA en pleno dash frena en seco y
salta (estilo Mario 64). Ese salto esta exento de jump cut: no lo pidio el boton.

Colgado de un canto: **empujar arriba sube**, **saltar salta desde el canto**.
Junto a una pared, **saltar rebota** en vez de gastar el salto aereo, y sigue
disponible durante `pared_coyote` segundos tras perder el contacto.

## Herramientas
| Script | Para qué |
|---|---|
| `tools/Gym.gd` | Sala de pruebas por código. Editar parámetros, no cubos. Incluye las rampas de calibración de escalada (45–90°, con el pie en la misma línea). |
| `tools/smoke_test.gd` | Comprobación de humo. `godot --headless --path . --script tools/smoke_test.gd` |
| `tools/medir_paleta.gd` | Imprime croma y luminancia de cada color. Mide antes de inventar umbrales. |
| `tools/captura.gd` | Guarda capturas del Gym y del circuito sin abrir el editor. |
| `tools/Circuito.gd` | La carrera de obstaculos del Hito 1, con cronometro. |
| `tools/Arena.gd` | Patio de combate del Hito 2. F4 respawnea a los Guardianes. |
| `tools/TestFase2.tscn` | Test funcional de combate, postura, agua y escalada. 118 comprobaciones. |
| `tools/TestFase1.tscn` | Test funcional de la FSM. `godot --headless --path . tools/TestFase1.tscn` |

Tras crear o renombrar una clase con `class_name`, corre
`godot --headless --path . --import` o el proyecto no la encontrará.

## Estado actual
**Fases 0, 1 y 2 cerradas.**

- **Traversal completo:** `SurfaceContext` + `LocomotionMotor`, FSM jerarquica de
  5 grupos y 27 estados, correr/esprintar/saltar/doble salto/dash/planeo/slide/
  wall-run/wall-slide/wall-jump/cantos/shimmy/escalada. Stamina unica.
  La escalada acepta **cualquier superficie de 45 a 110 grados**, desplomes
  incluidos, y el cuerpo se inclina con ella. Por debajo de 45 se anda; por
  encima, o trepas o resbalas.
- **Combate:** `AttackData` como Resource (tiempos en frames a 60 Hz), hitbox por
  consulta de forma, hitstop, ventanas de cancelacion, cadena ligera con finisher,
  pesado con knockback terrestre + stagger, aereos que reponen el dash, picado,
  parry normal y perfecto, poise con GuardBreak, soft-lock y 3 Guardianes.
  **El jugador se mueve mientras ataca** (`AttackData.movilidad`) y al morir los
  enemigos salen despedidos como cadaver fisico (`Ragdoll`).

Ademas: agachado con side hop, escalada BotW con wall lunge, Dive y DiveAttack,
aterrizajes agachado (slide con velocidad, recepcion en cuclillas sin ella) y el
agua completa: nado en superficie, buceo, clavado y combate acuatico. Falta solo
la **IA acuatica**, documentada en `project.md`.

Siguiente paso: **Fase 3** — lanza y lazo. La lanza clavada como `ClimbAnchor` +
`PlatformSurface` es la herramienta de progresion vertical del juego.
