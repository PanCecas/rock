# ROCK — Arquitectura Técnica de Mecánicas (Godot 4.7, Forward+, Jolt)

---

## 0. Estructura de carpetas

```
res://
├── src/
│   ├── core/          GameState, EventBus, SaveSystem, DebugOverlay, Palette
│   ├── input/         InputBuffer, InputActions, ContextualPrompt
│   ├── player/
│   │   ├── PlayerController.gd
│   │   ├── states/    ~30 archivos, uno por estado
│   │   ├── motor/     LocomotionMotor, SurfaceContext, StaminaComponent
│   │   └── sensors/   LedgeSensor, GroundSensor, ClimbSensor, WallSensor
│   ├── combat/        HitBox, HurtBox, AttackData, HitstopManager,
│   │                  DamageResolver, PoiseComponent, TargetingSystem
│   ├── traversal/     GlideComponent, DashComponent, RopeSystem, ClimbSystem
│   ├── weapons/       SpearSystem, SwordSystem, BowSystem, WeaponSocket
│   ├── colossus/      ColossusController, GripSurface, WeakPoint,
│   │                  ColossusPhase, ShakeDirector, MovingFrame
│   ├── camera/        CameraRig, CameraMode_*, CameraShake, FramingDirector
│   ├── art/           shaders/, materials/, palette/, post/
│   └── ui/
├── content/
│   ├── characters/ colossi/ levels/ vfx/ audio/ data/
├── tools/             Gym.tscn, ColossusTestRoom.tscn, AnimBrowser.tscn
└── docs/
```

**Autoloads:** `EventBus`, `GameState`, `HitstopManager`, `DebugOverlay`.
Nada más. Todo lo demás es composición de nodos.

---

## 1. El corazón: `SurfaceContext`

> Esto es lo primero que hay que resolver y lo que hace o rompe todo el proyecto.

En un plataformero normal, "abajo" es `Vector3.DOWN` y el mundo está quieto. Aquí el jugador
puede estar de pie sobre **el hombro de un coloso que camina, gira y se sacude**. Si esto se
parchea después, hay que reescribir el controlador entero.

```gdscript
class_name SurfaceContext extends RefCounted

var frame: Node3D          # el nodo cuyo transform define "el mundo" ahora mismo
var up: Vector3            # dirección "arriba" local
var gravity: Vector3
var _last_frame_xform: Transform3D

# Cada physics_frame:
# 1. Calcular el delta del transform del frame desde el tick anterior
# 2. Aplicar ese delta a la posición y rotación del jugador ANTES de move_and_slide
# 3. Convertir el input de la cámara al espacio del frame
# 4. move_and_slide con up_direction = up
func consume_frame_delta() -> Transform3D
```

Detalles no negociables:
- El jugador **nunca** se hace hijo del coloso en el árbol de escena (rompe la física y la
  cámara). Se reconcilia por delta de transform.
- La cámara vive en espacio-mundo pero su *input* se transforma al espacio del frame para que
  "adelante" siga significando lo mismo mientras el coloso gira.
- El suelo estático es simplemente `frame = null`, `up = Vector3.UP`. El mismo código.

---

## 2. Controlador del jugador

`CharacterBody3D` + **máquina de estados jerárquica**.

```
PlayerStateMachine
├── Grounded
│   ├── Idle · Move · Sprint · Crouch · Slide · Landing
├── Airborne
│   ├── Jump · DoubleJump · Fall · Glide · AirDash · Plunge
├── Attached
│   ├── LedgeHang · LedgeClimb · WallRun · WallSlide
│   ├── Climb · ClimbBrace (sacudida) · ClimbSlip
│   ├── RopeSwing · RopeZip
│   └── SpearHang (colgado de la lanza clavada)
├── Combat
│   ├── AttackGround · AttackAir · Charge · Parry · ParryCounter
│   ├── Dodge · Hitstun · Knockdown · GuardBreak
└── Special
	└── Aim · Throw · Recall · Interact · Cinematic
```

Cada estado es un `Node` con `enter()`, `exit()`, `physics_update(delta)`,
`handle_input(buffer)`, y declara `can_transition_to()`. Los estados de combate declaran
además sus **ventanas de cancelación**.

### 2.1 Los números que hay que exponer y tunear en vivo
Todo en un `PlayerTuning.tres` (`Resource`) editable con el juego corriendo (hot-reload):

| Parámetro | Valor inicial | Nota |
|---|---|---|
| Altura de salto | 2.2 m | Se define en metros, no en fuerza |
| Gravedad de subida | −22 m/s² | |
| Gravedad de caída | −38 m/s² | Asimétrica: subir flotante, caer contundente |
| Coyote time | 0.12 s | |
| Jump buffer | 0.15 s | |
| Jump cut (soltar botón) | ×0.45 a la velocidad Y | |
| Velocidad de carrera | 7.5 m/s | |
| Aceleración suelo / aire | 60 / 25 m/s² | |
| Dash: distancia / duración | 6 m / 0.18 s | |
| Dash i-frames | 0.10 s | |
| Cargas de dash en aire | 1 (2 con upgrade) | |
| Planeo: caída / velocidad | −3 m/s / 12 m/s | |
| Ventana de parry | 0.16 s (0.06 s perfecto) | |
| Hitstop base | 0.08 s (0.16 s en parry) | |

**Regla:** ningún número mágico dentro de un `.gd`. Si se toca para que "se sienta bien",
va en el Resource.

### 2.2 Input buffer y perdón
`InputBuffer` guarda las últimas ~20 acciones con timestamp. Todo estado consulta el buffer,
nunca `Input.is_action_just_pressed()` directamente. Esto es lo que separa un plataformero que
se siente bien de uno que se siente roto.

Perdones activos: coyote time, jump buffer, **ledge assist** (si fallas el borde por <0.4 m se
te concede el agarre), **dash correction** (el dash se alinea al enemigo cercano dentro de 20°).

---

## 3. Combate

### 3.1 `AttackData` como Resource
Cada ataque es un archivo `.tres`. Nadie escribe combate en código.

```gdscript
class_name AttackData extends Resource
@export var anim: StringName
@export var damage: float
@export var poise_damage: float
@export var hitbox_shape: Shape3D
@export var hitbox_bone: StringName
@export var active_frames: Vector2i        # inicio, fin
@export var cancel_windows: Dictionary     # {"dash": Vector2i, "jump":..., "attack":...}
@export var motion_curve: Curve            # empuje hacia adelante durante el ataque
@export var hitstop: float
@export var camera_shake: ShakeProfile
@export var launch: Vector3
@export var vfx: PackedScene
@export var sfx: AudioStream
@export var next_in_chain: AttackData
```

### 3.2 Hitstop — lo que hace que un golpe "pese"
**No usar `Engine.time_scale`.** Congela solo el `AnimationTree` del atacante y del receptor,
más una micro-pausa global de 1–3 frames. El resto del mundo (partículas, cámara) sigue vivo:
así el golpe se siente sin que el juego se sienta con lag.

Escala: golpe ligero 50 ms · golpe pesado 90 ms · parry 160 ms · punto débil del coloso 250 ms.

### 3.3 Ventanas de cancelación — el motor del "flashy"
La sensación estilizada no viene de las animaciones: viene de **poder cancelar**.
- Ataque → dash: siempre, desde el frame de impacto.
- Ataque → salto: solo tras conectar.
- Ataque → parry: en los primeros 6 frames de la recuperación.
- Dash → ataque: siempre (`atk_dash`).
- En el aire, conectar un golpe **restaura una carga de dash**. Ese único detalle es lo que
  convierte el combate en un juego de mantenerte en el aire.

### 3.4 Parry
1. Ventana de 0.16 s desde la pulsación; los primeros 0.06 s son "perfecto".
2. Éxito: hitstop 160 ms + zoom punch de cámara + destello `#F2F0E6` + onda de choque radial
   + el enemigo entra en `GuardBreak`.
3. Perfecto: además ralentiza al enemigo 0.8 s y abre `parry_counter`.
4. Fallo: 0.4 s de recuperación vulnerable. Debe doler.

### 3.5 Objetivo (targeting)
`TargetingSystem` con **soft-lock**, no hard-lock: la cámara sugiere, no encadena. Selección
por cono desde la cámara ponderando distancia y ángulo. Contra un coloso el objetivo es un
`WeakPoint`, no el bicho entero.

---

## 4. La lanza — sistema completo

Máquina de estados propia, independiente del jugador:

```
Holstered  -> (equip)   -> Wielded
Wielded    -> (throw)   -> InFlight
InFlight   -> (impacto) -> Embedded | Grounded
Embedded   -> (recall)  -> Returning -> Wielded
Embedded   -> (interact)-> se usa como asidero / plataforma
Grounded   -> (pickup)  -> Wielded
```

### 4.1 Empuñada (`Wielded`)
Cambia el moveset entero: alcance mayor, ataques más lentos, `spear_sweep` en área,
y **`spear_vault`**: si hay una lanza clavada cerca, te impulsas con ella (pértiga) para ganar
altura. Es una mecánica de plataformas disfrazada de arma.

### 4.2 En vuelo (`InFlight`)
- Proyectil con física propia + ligero *aim assist* (curva de corrección de máx. 8°).
- Carga: mantener pulsado aumenta velocidad y penetración; a carga máxima atraviesa escudos.
- Durante el apuntado en el aire, `time_scale` local baja a 0.35 (coste de stamina).

### 4.3 Clavada (`Embedded`) — **la mecánica clave**
Cuando la lanza se clava en una superficie válida, el nodo `Spear`:
1. Se reparenta al hueso/superficie impactada (hereda el `SurfaceContext` de ese frame).
2. Registra un `ClimbAnchor` → puedes engancharte a ella con el lazo o agarrarte a mano.
3. Registra una `PlatformSurface` de 0.4 m → **puedes quedarte de pie encima**.
4. Si se clavó en un coloso, cuenta como asidero permanente aunque el coloso se sacuda.

Esto convierte la lanza en tu herramienta de progresión vertical: la tiras a lo alto, subes
por el lazo, te paras encima, la recuperas y repites. **Ese es el bucle de escalada del juego.**

### 4.4 Recuperación (`Returning`)
Vuelve por una curva Bezier hacia la mano (no en línea recta: se ve mucho mejor).
Hay una `catch_window` — atraparla en el momento justo da un frame de invulnerabilidad y
encadena directo a `spear_thrust_1`. Detalle pequeño, enorme en sensación.

**Límite de diseño:** una sola lanza. La escasez es lo que la hace interesante — decidir dónde
la clavas es una decisión táctica, no un recurso.

---

## 5. El lazo / gancho (estilo TotK)

`RopeSystem` con tres modos, seleccionados por contexto de lo que apuntas:

| Objetivo | Modo | Comportamiento |
|---|---|---|
| Punto de anclaje fijo | **Zip** | Te tira hacia él, mantienes momentum al llegar |
| Superficie por encima | **Swing** | Restricción de distancia + balanceo pendular |
| `RigidBody3D` | **Pull / Ultrahand** | Lo traes hacia ti, o lo agarras y lo colocas |
| Coloso | **Ride** | Te quedas colgado; puedes bombear para ganar altura |

Implementación del balanceo: **no** uses un joint de física para el jugador. Restricción
analítica — si `distancia > longitud`, proyecta la posición al radio y elimina la componente
radial de la velocidad. Es estable, predecible y afinable. El visual de la cuerda sí puede ser
verlet puramente cosmético.

`AnchorPoint` es un componente que se cuelga en el nivel; los colosos llevan varios en el pelaje
y las salientes de piedra.

---

## 6. Colosos

### 6.1 Composición del nodo
```
Colossus (Node3D)
├── Skeleton3D + AnimationTree           <- se mueve por root motion
├── GripSurfaces/       Area3D por hueso, marca dónde se puede agarrar
├── ClimbColliders/     StaticBody3D que siguen huesos (el "suelo" caminable)
├── WeakPoints/         WeakPoint ×N, con estado oculto/expuesto y HP
├── AnchorPoints/       objetivos válidos del lazo
├── HurtBoxes/          para el combate en suelo
├── ShakeDirector       decide cuándo y con qué fuerza sacudirse
└── ColossusBrain       FSM de fases
```

### 6.2 El ciclo de combate del coloso
```
DORMANT -> AWARE -> GROUND_PHASE (te ataca de pie; buscas la apertura)
					  └─ tú rompes su guardia / clavas la lanza / enganchas
						 -> CLIMB_PHASE (plataformas sobre él, él se sacude)
							-> WEAKPOINT_EXPOSED (ventana corta, apuñalas)
							   -> PHASE_TRANSITION (cambia la geometría escalable)
								  -> vuelve a GROUND o CLIMB
									 -> DEATH
```

### 6.3 `ShakeDirector` — la tensión
No sacude al azar. Es un director: mide dónde estás en su cuerpo, cuánta stamina te queda y
cuánto llevas escalando, y elige el evento de sacudida. Debe fallar a propósito a veces:
si siempre te tira, es frustrante; si nunca, es aburrido. Objetivo: **el jugador casi se cae**.

Al sacudirse, el jugador entra en `ClimbBrace`: se agarra, la stamina baja rápido, y el input
solo permite aguantar. Cuando pasa, tienes una ventana de oro para avanzar.

### 6.4 Regla de diseño
> Diseña cada coloso primero como un **nivel de plataformas estático**. Constrúyelo, juégalo
> con el jugador escalando una estatua quieta. Solo cuando ese nivel sea divertido, ponlo a
> caminar. Si no funciona quieto, no va a funcionar en movimiento.

---

## 7. Cámara

`CameraRig` propio (no `SpringArm3D` a secas) con modos apilables:

| Modo | Cuándo | Qué hace |
|---|---|---|
| `Explore` | por defecto | Órbita suave, mira ligeramente hacia arriba, encuadra el horizonte |
| `Combat` | enemigo cercano | Baja, se acerca, encuadra a los dos |
| `Climb` | escalando | Se pega a la superficie, orienta el "arriba" al `SurfaceContext` |
| `Colossus` | boss activo | **FramingDirector**: mantiene coloso + jugador en cuadro, retrocede automáticamente para vender la escala |
| `Aim` | apuntando | Sobre el hombro, FOV reducido |
| `Cinematic` | scripted | Raíles |

Todos comparten: **collision solving** por shapecast, amortiguación por resorte crítico,
y `CameraShake` aditivo por perfiles (`ShakeProfile`: amplitud, frecuencia, decaimiento, ejes).

**Detalle estético:** la cámara debe hacer que el jugador **entre en oscuridad y salga a la luz**
(punto 2.1 del doc de arte). En los arcos y portales, un `CameraHint` de nivel lo fuerza.

---

## 8. Stamina — el balanceador maestro

Una sola barra gobierna: escalar, planear, correr, dashear y aguantar sacudidas.
Los ataques **no** gastan stamina (esto no es un souls).

- Regeneración instantánea al tocar suelo seguro, lenta mientras cuelgas.
- Se muestra solo cuando baja del 100% (HUD diegético).
- Cada upgrade del juego es +stamina o +eficiencia de un verbo, nunca +daño.
- El agotamiento en escalada no mata: te hace resbalar un tramo. La muerte es la caída larga.

---

## 9. Herramientas internas (constrúyelas pronto, ahorran meses)

1. **`Gym.tscn`** — sala de pruebas: rampas de todos los ángulos, huecos de distintas anchuras,
   paredes, bordes, muñecos de combate, y un panel para editar `PlayerTuning` en vivo.
2. **`ColossusTestRoom.tscn`** — una plataforma que se traslada, rota y sacude con los mismos
   parámetros que un coloso real. Aquí se depura `SurfaceContext` sin tocar un boss.
3. **`DebugOverlay`** — estado actual de la FSM, velocidad, contenido del buffer de input,
   contactos del suelo, stamina, ventanas de cancelación activas. Con `F3`.
4. **Validador de paleta** — un script de editor que recorre los materiales y avisa si un
   material de entorno rompe el límite de saturación de `01_DIRECCION_ARTE.md`.
5. **Grabador de replays de input** — grabar 10 s de input y reproducirlos. Imprescindible
   para afinar el feel sin volverse loco repitiendo la misma entrada a mano.

---

## 10. Riesgos técnicos conocidos

| Riesgo | Mitigación |
|---|---|
| Física sobre superficie móvil (jitter, atravesar) | `SurfaceContext` desde el día 1 + Jolt + `ColossusTestRoom`. Nunca parchear después. |
| La FSM se convierte en spaghetti | Estados como nodos con transiciones declaradas; prohibido `if estado ==` fuera de la FSM. |
| El coloso rompe el rendimiento | LOD agresivo, `GripSurfaces` activadas solo por proximidad, colisión escalable solo del tramo cercano. |
| El combate flashy choca con el tono contemplativo | El combate se **encierra** en recintos; el mundo abierto queda en silencio. |
| Demasiadas animaciones | Tiers T0/T1/T2. Prohibido animar T1 antes de cerrar T0. |
| El look pintado "hierve" en movimiento | Overlay de pinceladas a 12 fps y anclado a la profundidad, no a la pantalla. |


---

## 11. BACKLOG DE FÍSICAS — **no implementar todavía**

> **Estado: solo diseño.** Nada de esta sección está construido ni debe construirse
> hasta que la Fase 4 (coloso #1) esté cerrada. Se documenta ahora porque condiciona
> decisiones de rig y de arquitectura que es caro deshacer después.

### 11.1 Active Ragdoll — reacción procedural al entorno

La idea: los personajes dejan de ser cápsulas con animación encima y pasan a ser
**cuerpos físicos controlados por animación**. La animación no manda la pose: manda
un objetivo, y unos controladores PD empujan los huesos hacia él. Todo lo que se
interponga —una pared, una cuesta, un golpe, otro cuerpo— deforma la pose sin que
haya que animar ese caso.

Lo que aporta al juego, en concreto:
- **Los golpes tienen dirección real.** Un mandoble lateral tuerce el torso hacia
  donde vino, no reproduce `hit_light_L`. Con 8 reacciones animadas se cubren 8
  casos; con active ragdoll se cubren todos.
- **El coloso se lee mejor.** Un jugador agarrado del pelaje que se balancea con la
  sacudida vende la escala mucho más que un clip de `climb_shake_hold`.
- **La muerte deja de ser un clip.** Lo que hoy resuelve `Ragdoll.gd` (un cuerpo
  rígido que sale despedido) sería el mismo sistema, pero articulado.

Bocetos técnicos, para no perderlos:
- `PhysicalBoneSimulator3D` sobre el rig, con arranque por regiones: primero solo
  torso y brazos, las piernas siguen siendo animación pura hasta que caminar sea
  estable.
- **Mezcla animación↔física por hueso y por evento**, no global. Un golpe sube la
  mezcla física del torso a 0.8 durante 300 ms y la devuelve a 0.
- Controladores PD con ganancias por hueso, expuestas en un Resource igual que
  `PlayerTuning`.
- Riesgo real: el active ragdoll pelea con `SurfaceContext`. Sobre un coloso en
  movimiento, los huesos físicos viven en espacio de mundo mientras el personaje
  vive en el marco del coloso. **Hay que resolver eso ANTES de escribir una línea.**

### 11.2 Grappler con cuerda física real

Referencia: el gancho de **Loader** (Risk of Rain 2) — la cuerda no es un raíl,
es una cuerda: tiene masa, se tensa, acumula momentum y se puede usar para
golpear llegando lanzado.

Diferencia con el `RopeSystem` de la Fase 3 (§5): allí la cuerda es una
**restricción analítica** —estable, predecible, barata— y el visual es cosmético.
Aquí sería al revés: la simulación ES la mecánica.

- Cadena de partículas verlet con restricciones de distancia, varias iteraciones
  por tick.
- El jugador es la última partícula: la cuerda le transmite fuerza de verdad, no
  le teleporta.
- El puñetazo al llegar es consecuencia del momentum acumulado, no un `AttackData`
  con daño fijo: el daño sale de la velocidad de impacto.
- Riesgo: una cuerda verlet mal amortiguada explota o se vuelve elástica. Necesita
  su propia sala de pruebas antes de tocar el juego.

**Orden sugerido:** primero 11.1 sobre los Guardianes (cuerpos pequeños, fallos
baratos), después sobre el jugador, y solo entonces 11.2. Nunca los dos a la vez.
