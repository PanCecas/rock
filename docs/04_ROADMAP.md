# ROCK — Roadmap de producción

Cada fase termina en un **hito jugable y verificable**. Si el hito no se cumple, no se pasa
de fase. La duración asume 1 persona con ayuda de IA; escala según tu equipo.

---

## FASE 0 — Cimientos · ~~1 semana~~ **HECHA**
**Objetivo:** que el proyecto tenga esqueleto y que el arte esté decidido antes de escribir juego.

- [x] `git init` y estructura de carpetas de `03_ARQUITECTURA_MECANICAS.md §0`
- [x] Autoloads: `EventBus`, `GameState`, `HitstopManager`, `DebugOverlay`
- [x] `Palette.gd` + `default_palette.tres` con todos los hex de `01_DIRECCION_ARTE.md`
- [x] Input map completo (teclado + mando, 27 acciones) y `InputBuffer`
- [x] `Gym.tscn` con rampas, huecos, muros, repisas, torre de 60 m y pilares
- [x] `WorldMood`: niebla crema, tonemap filmic, luz direccional cálida, glow ancho
- [x] `PlayerTuning.tres` con todos los parámetros expuestos y recarga en caliente (F5/F6)
- [x] `Palette.validar()` con la regla de croma corregida sobre datos medidos

**HITO 0 — CUMPLIDO.** Una cápsula cobalto se mueve por el Gym, es lo único saturado del
encuadre, el horizonte se disuelve en crema y el sol proyecta sombras tintadas.

**Lo que se aprendió y cambió el plan:**
1. La regla de saturación del doc de arte (`HSV ≤ 0.35 / ≥ 0.60`) no sobrevive a los hex
   reales. Corregida a techo de croma Okhsl por familia + tonos reservados. Ver `01 §2.3`.
2. Los exports `@export var x: Node3D` no se resuelven al instanciar la escena. Todas las
   referencias a nodos van como `NodePath` + `get_node_or_null()`. Es la regla #10.

## FASE 1 — El juguete de movimiento · ~~3-4 semanas~~ **HECHA**
**Objetivo:** que moverse sea divertido **sin combate, sin arte y sin enemigos**.

- [x] `SurfaceContext` con arrastre por delta de transform (marco estatico de momento)
- [x] `LocomotionMotor`: toda la mate en el plano del SurfaceContext, nunca en XZ del mundo
- [x] FSM jerarquica: 3 grupos (Grounded / Airborne / Attached) + 13 estados
- [x] Salto con gravedad asimetrica, coyote time, jump buffer y jump cut
- [x] Dash terrestre y aereo con cargas, i-frames y conservacion de momentum
- [x] Planeo con picado, remontada y alabeo de capa
- [x] Deslizamiento que ACELERA cuesta abajo, con salto potenciado
- [x] Wall-run con gravedad progresiva, wall-slide y wall-jump alternable
- [x] `LedgeSensor` de 3 rayos + ledge assist, colgado, shimmy y subida escriptada
- [x] Escalada libre sobre CLIMBABLE, con salto de escalada y resbalon por stamina
- [x] `StaminaComponent` unificado: escalar, planear, correr, dashear
- [x] `CameraRig` con modos Explore y Climb interpolados + FOV por velocidad
- [x] `DebugOverlay` completo: FSM, velocidad, buffer, sensores, stamina, marco
- [x] `tools/Circuito.gd`: la carrera de obstaculos con cronometro y 6 checkpoints
- [x] `tools/TestFase1.tscn`: test funcional que recorre los 12 estados

**HITO 1 — pendiente de tu veredicto.** El circuito esta montado y el test automatico
alcanza los 12 estados. Lo que falta es lo unico que no se puede automatizar:
**correrlo y ver si apetece repetirlo**. Ese sigue siendo el filtro del proyecto.

**Lo que se aprendio y cambio el plan:**
1. El rayo del `LedgeSensor` que busca el canto se lanzaba a una fraccion fija del
   alcance, asi que caia POR DELANTE de la pared si el jugador estaba pegado a ella.
   Ahora se ancla al punto de impacto. Sin esto el agarre fallaba justo cuando mas
   se necesita.
2. Encadenar los ifs de pared dejaba al jugador sin wall-slide despues de gastar el
   wall-run en ese muro: chocaba y caia a plomo. `puede_correr` se calcula entero
   antes de decidir.
3. Niebla y perspectiva aerea son efectos DISTINTOS. El circuito de 150 m demostro
   que `fog_density` come legibilidad a media distancia mientras que
   `fog_aerial_perspective` solo tine la silueta lejana. El look de la referencia lo
   da la segunda: se subio a 0.78 y se bajo la densidad a menos de la mitad.
4. `--script` no registra los autoloads, asi que cualquier test que use un tipo con
   `class_name` que a su vez toque `EventBus` no compila. Los tests van como ESCENA.
6. **Segundo pase de feel: referencias concretas.** El dash pasa a evasion de
   NieR (corta, con correccion de rumbo, y tap/hold para encadenar a sprint), el
   planeo vuelve a "mantener" pero sin robarle la pulsacion al doble salto, y el
   wall-jump se rehace estilo Mario 3D: vertical absoluto y fuerte, coyote de
   pared, enganche por choque sin exigir input, y realineado suave de camara.
5. **Pase de feel tras jugarlo.** Cinco correcciones que solo aparecen con el mando
   en la mano: dos acciones en la misma tecla se robaban la pulsacion (doble salto
   contra planeo), el wall-jump tiraba todo el momentum a lo largo del muro y salia
   siempre igual, el dash frenaba en seco al aterrizar, la capsula se atascaba en
   las esquinas interiores, y saltar colgado de un canto solo sabia subir.

## FASE 2 — Combate · ~~3-4 semanas~~ **HECHA**
**Objetivo:** 30 segundos de combo que se sientan bien contra una capsula.

- [x] `Hitbox` por consulta de forma (no Area3D: un Area llega con un frame de
	  retraso y en ventanas de 4 frames eso es un 25% de error), `Hurtbox`, `Golpe`
- [x] `AttackData` como Resource, tiempos en FRAMES a 60 Hz. 11 ataques en .tres
- [x] `HitstopManager` conectado: micro-pausa global + congelado de participantes
- [x] Cadena ligera L1-L2-L3 con finisher, pesado que LANZA al aire
- [x] Ventanas de cancelacion con reglas por defecto en `GroupCombat`
- [x] Aereo 1-2: conectar en el aire RESTAURA una carga de dash
- [x] Picado con suspension, caida y onda de area
- [x] Parry normal y perfecto, con contraataque solo en el perfecto
- [x] `HealthComponent`, `PoiseComponent` con GuardBreak, `StateHitstun`
- [x] `TargetingSystem` soft-lock + `CameraMode_Combat` + shake por `EventBus`
- [x] `CombatFX`: arcos, impactos y ondas con colores de la Palette
- [x] Los 3 Guardianes de Ruina (Lancero, Escudo, Vigia) y `tools/Arena.gd`
- [x] `tools/TestFase2.tscn`: 12 comprobaciones funcionales

**HITO 2 — pendiente de tu veredicto.** El test cubre que la cadena encadena, que
el dano llega, que las cancelaciones abren cuando deben y que el parry convierte
un golpe en una apertura. Lo que no se automatiza: **grabar 30 s y ver si el video
se sostiene sin arte**. Si se sostiene, el arte solo puede mejorarlo.

**Lo que se aprendio y cambio el plan:**
1. `StateMachine.cambiar()` rechazaba las transiciones a uno mismo, asi que
   encadenar `Attack -> Attack` con otro AttackData se ignoraba EN SILENCIO. Se
   anade `reentrar` explicito: un bucle accidental sigue siendo imposible por
   defecto, pero la cadena se pide a proposito.
2. La hitbox NO puede ser un Area3D. Con ventanas activas de 4 frames, el frame de
   retraso de las areas es un 25% de error. Se resuelve con `intersect_shape` en
   el frame exacto que dice el .tres.
3. Hay ~2 frames de latencia entre `Input.action_press()` desde codigo y que el
   InputBuffer lo vea. Cualquier test de combate tiene que contar con ellos o mide
   ventanas que no existen.

## FASE 3 — Lanza y lazo · 2–3 semanas
- [ ] `SpearSystem` completo: equipar, moveset, apuntar, lanzar, clavar, recuperar, atrapar
- [ ] Lanza clavada = `ClimbAnchor` + `PlatformSurface` + pértiga (`spear_vault`)
- [ ] `RopeSystem`: zip, swing (restricción analítica), pull de `RigidBody3D`
- [ ] Arco con apuntado en cámara lenta
- [ ] Puzzle-gym: una sección vertical que **solo** se puede superar combinando
	  lanza + lazo + planeo

**HITO 3:** subir una torre de 60 m sin tocar una escalera.

---

## FASE 4 — Coloso #1 · 4–6 semanas · **el vertical slice**
- [ ] `ColossusTestRoom` (plataforma que se traslada, rota y sacude) — **primero esto**
- [ ] `SurfaceContext` validado sobre superficie móvil: cero jitter, cero atravesar
- [ ] `ColossusController`, `GripSurface`, `WeakPoint`, `ColossusPhase`
- [ ] `ShakeDirector` con su curva de tensión
- [ ] `ClimbBrace` (aguantar la sacudida) y `climb_thrown_off`
- [ ] `CameraMode_Colossus` con `FramingDirector`
- [ ] El coloso #1 completo: 3 fases, 2 puntos débiles, muerte cinematográfica
- [ ] Música dinámica por fase

**HITO 4:** un desconocido derrota al coloso #1 sin que le expliques nada, y al terminar
dice "qué grande era". Ese es el test.

---

## FASE 5 — La estética · 3 semanas *(puede solaparse desde la Fase 2)*
- [ ] `banded_surface.gdshader` con luz en 3 bandas y sombra tintada
- [ ] Post: desaturación por profundidad + overlay de pinceladas a 12 fps + viñeta
- [ ] Niebla con `fog_aerial_perspective` afinada
- [ ] Hierba en `MultiMesh` con viento
- [ ] Bandadas de pájaros (boids)
- [ ] Hoja de VFX aplicada: arcos de espada, parry, polvo, líneas de viento
- [ ] Validador de paleta corriendo en editor
- [ ] Kit modular de ruinas y el primer landmark

**HITO 5:** un pantallazo cualquiera pasa el **test de aceptación estético**
(`01_DIRECCION_ARTE.md §5`) sin retoques.

---

## FASE 6 — Contenido · 12–20 semanas
- [ ] Colosos #2 a #5 (o #8)
- [ ] El mundo: 3–4 zonas conectadas, cada una con su `Palette` y su landmark
- [ ] La Sombra (compañero) y su comportamiento
- [ ] Animaciones T1 completas
- [ ] Audio: pasos por material, viento, la respiración del jugador (clave para la tensión)
- [ ] Guardado, opciones, menús
- [ ] Progresión: upgrades de stamina y de verbos de movimiento

---

## BACKLOG DE FÍSICAS — **no implementar todavía**
Active Ragdoll (reacciones procedurales al entorno) y grappler con cuerda física
real estilo Loader. Diseño en `03_ARQUITECTURA_MECANICAS.md §11`. No se toca hasta
que la Fase 4 esté cerrada: el active ragdoll choca de frente con `SurfaceContext`
y esa pelea hay que ganarla antes de escribir código.

---

## FASE 7 — Pulido · 4–6 semanas
- [ ] **Game feel pass** completo: cada transición de estado revisada a 1/4 de velocidad
- [ ] Accesibilidad: remapeo, asistencia de agarre, desactivar shake, escala de subtítulos
- [ ] Rendimiento: LODs, occlusion culling, presupuesto de 16 ms
- [ ] Animaciones T2
- [ ] Build, firma, distribución

---

## Orden de ataque recomendado (qué construir literalmente primero)

```
1. Carpetas + autoloads + Palette          <- 1 día
2. Gym gris + WorldEnvironment con niebla   <- 1 día   (ya se ve bonito, motiva)
3. InputBuffer + DebugOverlay               <- 1 día   (te ahorra semanas)
4. FSM vacía + Idle/Move/Fall               <- 2 días
5. Salto con TODOS los perdones             <- 2 días
6. SurfaceContext (con suelo estático)      <- 2 días  <- NO LO POSPONGAS
7. Dash -> Planeo -> Slide -> Bordes        <- 2 semanas
8. HITO 1: la carrera de obstáculos
```
