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

## FASE 1 — El juguete de movimiento · 3–4 semanas · **LA FASE MÁS IMPORTANTE**
**Objetivo:** que moverse sea divertido **sin combate, sin arte y sin enemigos**.

- [ ] `SurfaceContext` (aunque solo haya suelo estático — la arquitectura se pone ahora)
- [ ] FSM del jugador: `Grounded` / `Airborne` / `Attached`
- [ ] Salto con gravedad asimétrica, coyote time, jump buffer, jump cut
- [ ] Dash terrestre y aéreo con cargas
- [ ] Planeo con la capa
- [ ] Deslizamiento, wall-run, wall-slide
- [ ] Detección de bordes: `ledge_catch`, colgado, shimmy, subida, ledge assist
- [ ] Escalada libre sobre superficies marcadas
- [ ] Stamina unificada
- [ ] `CameraRig` con modos `Explore` y `Climb`
- [ ] `DebugOverlay` completo

**HITO 1:** monta una **carrera de obstáculos** en el Gym y crónometra tu mejor tiempo.
Si te apetece repetirla para bajar el tiempo, la fase está aprobada. **Si no, no sigas.**
Este es el único filtro real del proyecto.

---

## FASE 2 — Combate · 3–4 semanas
**Objetivo:** 30 segundos de combo que se sientan bien contra una cápsula.

- [ ] `HitBox` / `HurtBox` / `DamageResolver`
- [ ] `AttackData` como Resource + cadena ligera de 3 golpes
- [ ] `HitstopManager` (congelar AnimationTree, no `time_scale`)
- [ ] Ventanas de cancelación (ataque→dash, dash→ataque, aéreo restaura dash)
- [ ] Parry con ventana normal y perfecta, con todo su feedback
- [ ] Esquiva con i-frames
- [ ] Reacciones de daño, poise, guard break
- [ ] Ataque aéreo y plunge
- [ ] `TargetingSystem` con soft-lock, `CameraMode_Combat`
- [ ] Los 3 Guardianes de Ruina, versión cápsula

**HITO 2:** grábate 30 s peleando contra 3 cápsulas. Si el vídeo se ve bien sin arte y sin
VFX, el combate funciona. El arte solo puede mejorarlo, nunca arreglarlo.

---

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
