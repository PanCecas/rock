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

**HITO 1 — CUMPLIDO.** Confirmado por el autor tras jugarlo: el circuito se corre
y apetece repetirlo, que era el unico filtro que importaba y el unico que no se
puede automatizar.

Se cerro despues de siete rondas de correccion de feel (2.2 a 2.05) que salieron
justamente de jugarlo: el dash que desemboca en surf, el salto que se quedaba
pegado, el patinaje de seis metros al soltar el stick y el peso del salto son
todos hallazgos de este hito, no del diseno sobre papel.

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

## PLAN DE TRABAJO — orden de ataque tras el Hito 1

Con el Hito 1 cerrado, esto es lo que hay sobre la mesa y en qué orden se hace.
El criterio de orden no es el entusiasmo: es **qué bloquea a qué**, y después
**qué relación coste/percepción tiene**. Una tarde de audio cambia más la
experiencia percibida que dos semanas de sistema nuevo.

---

### P0 — Deuda que bloquea · ~1 semana

Nada de esto es contenido. Todo esto es lo que impide que el contenido salga bien.

**P0.1 · Extraer la FSM de `Guardian.gd`** — *el cuello de botella real*

`Guardian.gd` mezcla hoy tres cosas en un archivo: la IA (dormido, acercarse,
telegrafiar, atacar, recuperar), la física (`is_on_floor()`, gravedad manual) y la
presentación (material, color, ondas). Eso bloquea **tres** cosas a la vez: el
director de grupo, el coloso mediano y los enemigos acuáticos.

Cómo se hace: la misma estructura que ya usa el jugador —`StateMachine` +
`EnemyState`— porque duplicar un patrón que ya funciona cuesta menos que inventar
uno nuevo y se lee igual. El cuerpo queda como orquestador, igual que
`PlayerController`. Lo que hoy es `Estado.ACERCARSE` pasa a ser un nodo con
`enter/exit/physics_update`.

Criterio de terminado: escribir un enemigo que nade **sin tocar** el script del
Guardián terrestre.

**P0.2 · Escala unificada de screen shake**

Hoy el shake sale desde ~15 sitios con valores escritos a mano en cada estado
(`0.3`, `0.45`, `1.1`…). No hay forma de saber si un picado sacude más que un
parry sin leer quince archivos, y ajustar la intensidad global es imposible.

Cómo se hace: exactamente como el hitstop, que ya tiene su escala documentada en
`docs/03 §3.2`. Cuatro niveles nombrados —ligero, pesado, parry, coloso— en
`PlayerTuning`, y `EventBus.camara_shake` recibe el nivel, no el número.

Criterio de terminado: un solo parámetro sube o baja **todo** el shake del juego.

**P0.3 · Audio mínimo** — *el multiplicador de juice más barato que existe*

`content/audio/` está vacío. Un golpe sin sonido se siente flojo por muy buena que
sea la física, y ningún ajuste de números compensa eso.

Lo mínimo que cambia la percepción de todo lo demás, por orden de impacto:
1. **Impacto de golpe** (ligero / pesado / parry), enganchado a `EventBus.hit_landed`
   y a `hitstop_requested`. El sonido tiene que salir en el frame del hitstop, no
   después: es el mismo instante o no se lee como el mismo evento.
2. **Pasos** por velocidad, y **aterrizaje** por `player_landed` con el flag `dura`
   que ya viaja en la señal.
3. **Viento por velocidad** en surf y planeo. Es lo que vende la velocidad cuando
   el escenario es gris.
4. **Respiración** en la escalada, ligada a la stamina. La visión ya la señala como
   clave para la tensión de los colosos.

Todas las señales necesarias **ya existen** en `EventBus`. Es cablear, no diseñar.

**P0.4 · Sincronizar el roadmap** — las fases cerradas dicen "3 grupos y 13
estados", "11 ataques" y "12 comprobaciones". Hoy son 5 y 27, 20 y 122.

---

### P1 — Fase 3: lanza y lazo · 2–3 semanas

La fase que toca. Su detalle está justo debajo, sin cambios.

Una sola nota nueva, aprendida de las siete rondas de corrección: **la lanza y el
lazo se prueban en el Gym antes de existir en el mundo**, y con los tres tests
—funcional, de medición y visual— desde el primer día. El coste de añadir una toma
al `TestVisual` es una línea; el coste de descubrir en la Fase 5 que la lanza
clavada se ve torcida es una semana.

---

### P2 — Bestiario · 3–4 semanas · **necesita P0.1**

**P2.1 · Grupos de enemigos** (`SquadDirector`). La dificultad sale de agrupar, no
de engordar. Detalle completo en `project.md §3.1`.

**P2.2 · Coloso mediano de torso escalable.** El puente pedagógico hacia la Fase 4,
y el primer consumidor real del `SurfaceContext` con marco móvil. Detalle en
`project.md §3.2`.

Este orden importa: el coloso mediano **antes** del coloso #1, no después.

---

### P3 — Fase 4: el coloso · sin cambios

---

### P4 — El lobo · después de la Fase 3

Montura viva. Detalle en `project.md §4`. La mitad del trabajo no es montar: es
cómo se comporta cuando **no** lo montas.

---

### Fuera del plan, a propósito

- **Animaciones y modelos 3D.** Regla dura #7: el feel se prueba con cápsulas
  grises. Sigue siendo cierto, pero con una fecha de caducidad: cuando el
  personaje tenga peso visual, algunos números habrá que revisarlos. No es motivo
  para adelantarlo; sí para no seguir puliendo decimales indefinidamente.
- **Active Ragdoll y grappler verlet** (`docs/03 §11`). Sin tocar hasta que la
  Fase 4 esté cerrada.

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

### Correccion 2.4 — sobre la 2.3
- El **ataque de dash es una ESTOCADA**: mantiene la velocidad durante toda la
  anticipacion y la ventana activa en vez de frenar en seco. Un golpe lanzado
  desde una carrera tiene que conservar la carrera.
- El **surf pierde el temporizador**. Un timeout obligaba a redashear cada segundo
  para mantener la velocidad, justo lo contrario de la sensacion continua que se
  busca. Ahora se sostiene mientras se mantenga Shift; la stamina es el limite.
- La locomocion sin Shift pasa de escalera de tres peldanos elegida por la fuerza
  del stick (saltaba de 3.2 a 7.5 de golpe, se sentia como un interruptor) a una
  **rampa continua por carrerilla** con suavizado exponencial.
- Bug encontrado de paso: un giro brusco de camara invertia el significado de
  "adelante" y el dash lo leia como peticion de pivote, frenando sin que el
  jugador lo pidiera. El pivote exige ahora intencion sostenida
  (`dash_pivote_frames`).

### Correccion 2.5 — salto, momentum y frenada
- **Puerta unica del salto** en el controlador: consumir una pulsacion invalida
  las demas y hay intervalo minimo entre saltos. 1 pulsacion = 1 salto.
- **Clamp duro** de velocidad horizontal justo antes de mover. En un solo sitio a
  proposito: imposible de olvidar al anadir el siguiente verbo.
- El ataque de dash es un **corte con overshoot**: te lleva al otro lado del
  objetivo y sales en combate, no parado.
- El **surf sobrevive al salto** (`surf_persistencia`) y al salir se sale
  corriendo.
- El **pivote solo existe en suelo**. Frenar en seco es una maniobra de pies.

Bug encontrado de paso, y de los caros: `StateMachine` llamaba a `exit()` ANTES
de reasignar `actual`, asi que cualquier estado que preguntara por su destino
desde `exit()` recibia su propio nombre. Afectaba a `StateLedgeHang` y
`StateClimb`, que por eso nunca soltaban el marco del `SurfaceContext`. Ahora
`exit()` recibe el destino como parametro.

### Correccion 2.6 — el salto que se quedaba pegado
- **Causa raiz encontrada:** el doble salto se pide casi siempre ESTANDO YA en
  `Jump`, y la FSM rechaza las transiciones a si misma. Consumia la pulsacion y el
  salto aereo, y no saltaba. Los 11 sitios que saltan piden ahora `reentrar=true`.
- El `salto_intervalo_min` de la 2.5 tambien se comia el doble toque rapido: a 0.
  `InputBuffer.invalidar()` ya garantiza una pulsacion = un salto sin bloquear.
- **Altura variable continua:** impulso de altura maxima siempre, y al soltar se
  RECORTA a la velocidad de altura minima. Un multiplicador fijo dejaba solo dos
  alturas posibles.
- **Ataques de surf:** el grupo corria antes que la hoja y le robaba la pulsacion,
  asi que atacar surfeando daba el ataque de suelo. Ahora la hoja los reclama con
  `maneja_ataques()`. Shift+ligero es una estocada que vuelve al surf; Shift+pesado
  es un frenazo plantado con empujon.
- **Dash aereo + Shift** marca el surf pendiente y el aterrizaje entra solo.

### Correccion 2.7 — agachado, techo, escalada BotW y patada baja
- Estado `Crouch`, capsula a la mitad con transicion suave, y `CeilingSensor` con
  shapecast: bajo un techo bajo NO te puedes levantar. Un tunel pasa a ser un
  obstaculo de verdad y no una sugerencia.
- Salto alto desde agachado quieto y **long jump** desde surf agachado.
- Escalada universal estilo BotW: cualquier pared, limitada por stamina. La roca
  lisa cuesta `escalada_coste_liso` veces mas que un asidero marcado.
- **Patada baja** con `AttackData.derribo`: tumba al enemigo (`Estado.DERRIBADO`)
  y abre una ventana larga para rematar.
- Tunel de 1.2 m en el Gym como banco de pruebas del techo.

**Tercera aparicion del mismo fallo estructural:** los grupos corren antes que las
hojas y les roban el input. El salto alto y el long jump no existian porque
`GroupGrounded` se quedaba la pulsacion. Ya paso con la cadena de combos y con los
ataques de surf. Ahora hay `maneja_salto()` ademas de `maneja_ataques()`, y esta
como regla dura #13 en CLAUDE.md para que no vuelva a pasar en la Fase 3.

### Correccion 2.8 — agachado, paredes, dive y agua
- **Crouch reactivo** con tres saltos distintos: backflip (doble altura + retroceso),
  side hop (lateral, bajo, con i-frames) y salto normal avanzando. Caminar agachado.
- **Conflicto de paredes resuelto por diseno en dos niveles:** agarre = escalar
  (prioridad 1, sin ambiguedad posible); sin agarre, el ANGULO entre tu avance y la
  normal decide wall-jump (de frente) o wall-run (rozando). Antes lo decidia
  `pared.lado`, que es del sensor y no de tu intencion, y por eso se pisaban.
  Se anaden soltarse hacia atras y el **wall lunge** hacia arriba/diagonales.
- **Dive y DiveAttack:** atacar en el aire con carrera es un clavado con modo
  propio; la segunda pulsacion lo arma y su hitbox vive todo el trayecto lanzando
  enemigos por el aire. Es la unica via deliberada de abrir juego aereo desde que
  el pesado dejo de lanzar en la 2.4.
- **Agua Fase 1:** `ZonaAgua` como Area3D, `WaterSensor`, grupo `Water` propio con
  nado en superficie (flotacion por muelle) y buceo 3D. Entrar en dive gana
  profundidad de verdad. Estanque con torre en el Gym.
- Fase 2 del agua documentada en `project.md`, sin implementar.

**Cuarta y quinta aparicion del fallo de grupos:** el DiveAttack no existia porque
`GroupAirborne` no tenia el guardia de `maneja_ataques()` que si tenia
`GroupGrounded`. La regla dura #13 se amplia: el guardia va en TODOS los grupos.

### Correccion 2.9 — clavado, friccion y adherencia
- **Backflip eliminado.** El salto agachado es ahora solo un salto muy fuerte: la
  voltereta se rompia y no aportaba nada que el impulso no diera ya.
- **SIDE JUMP de Mario 64**, detectado en el controlador y no en un estado: el
  giro brusco ocurre antes de que exista nada a lo que llamar "estado de girar".
- **Clavado simplificado a UNA pulsacion**, sin exigir carrera. Velocidad
  horizontal CONSTANTE (fisica de Mario 64) y hitbox viva todo el trayecto que
  manda a los enemigos volando. Los ataques aereos se reparten por CONTEXTO:
  ligero con enemigo cerca golpea, ligero sin nadie clava, pesado pica.
- **Slide acortado (2.5 -> 0.9 s) y cede al agachado**, que es quien te frena con
  `crouch_friccion`. Los dos forman una sola maniobra continua.
- **SLIDE KICK** con hitbox de trayecto que termina dejandote agachado, para poder
  encadenar.
- **Shift en el agua** multiplica nado y buceo.
- **Adherencia automatica**: insistir contra un muro perpendicular engancha solo, y
  entonces se sale con salto o agachandose, no soltando un boton que quiza nunca
  se pulso. **Shift escalando** da el impulso 2D de BotW.

**Leccion para los tests:** comprobar solo el frame final medía timing en vez de
mecanicas. Ahora se usan LATCHES. Y `_reponer()` no ponia la velocidad a cero, asi
que un paso heredaba el impulso del anterior y el jugador estaba en el aire cuando
la comprobacion asumia suelo.

### Correccion 2.01 — landing slide, agua viva y ledge snap
- **Landing slide**: aterrizar con velocidad manteniendo agachado conserva el
  momentum y entra en slide. Gana al aterrizaje duro a proposito.
- **Combate acuatico implementado** (era la Fase 2 documentada): `agua_ligero` y
  `agua_pesado` como impulsos con hitbox, iguales en superficie y buceando.
- **Deriva al bucear**: oscilacion senoidal sobre la velocidad —no sobre la
  posicion, para respetar colisiones— con fase aleatoria al entrar.
- **Orientacion por vector de velocidad** con pitch y yaw reales, via `looking_at`
  + slerp de bases: rotar por Euler cruza el gimbal al apuntar recto arriba/abajo,
  que es exactamente lo que se pide bajo el agua.
- **Stamina acuatica corregida**: el gasto pasa del grupo a cada estado. Flotar no
  cuesta y ademas regenera; solo nadar activamente o atacar consume, y mucho mas
  despacio (4.0 -> 1.2).
- **Ledge snap desde escalada**: al aparecer un canto agarrable durante el Climb,
  el personaje se ancla solo. Elimina el momento tonto de trepar por encima del
  borde sin poder subir.


### Correccion 2.02 — recepcion agachado, rampas escalables y vuelta a la vertical
- **Stationary crouch landing**: caer agachado y CASI PARADO entra en
  `CrouchLanding` y termina en `Crouch`, sin levantarse. Quien elige entre slide y
  recepcion es la velocidad horizontal real, no el boton.
- **Limite de angulo de escalada 60..95 grados** en `WallSensor`, calculado como
  `sc.up.angle_to(hit.normal)` con medio grado de holgura para que 60 exactos
  entren de verdad.
- **Sonda baja del sensor de pared**. Ampliar la horquilla no bastaba: apoyado
  contra una pendiente de 60 grados el PECHO del personaje ya esta por encima de
  la superficie, asi que un solo rayo alto no puede ver una rampa por muchos
  grados que se le permitan. Se anade un rayo a la altura de las rodillas, con
  techo propio (75 grados) para que un escalon vertical no cuente como pared.
- **La escalada usa la NORMAL REAL**, no su version aplanada: ejes de la
  superficie, adherencia a lo largo de la normal y cuerpo inclinado con la
  pendiente. Con la normal aplanada el "arriba de la pared" degeneraba en el
  arriba del mundo y el personaje se despegaba de la rampa.
- **Upright Orientation Recovery** (`PlayerController.enderezar()`): al salir del
  agua o soltarse de una pendiente, el cuerpo vuelve a la vertical por slerp
  conservando el yaw. El nado y la escalada escriben pitch y roll; la logica de
  tierra solo escribe yaw, y por eso esos dos ejes se quedaban con la ultima
  inclinacion. Es una transicion, no un guardia por frame: no puede pelearse con
  el dash, el agachado ni el movimiento aereo porque ellos nunca la encienden.
- **Entrada al agua sin chasquido**: `Swim` arranca la misma recuperacion y el
  buceo interpola desde la orientacion que traia. Ademas la referencia de "arriba"
  del nado se transporta de forma continua en vez de saltar entre UP y FORWARD con
  un umbral duro, que era un salto de roll justo al picar al fondo.
- **Rampas de calibracion en el Gym** (45/55/60/70/80/90 grados) con el pie en la
  misma linea, y ocho comprobaciones nuevas en `TestFase2`.


### Correccion 2.03 — postura centralizada, 75..110 y movilidad con recorrido
- **La postura deja de ser un efecto de borde de las transiciones.** Cada estado
  PIDE una altura por frame (`pedir_postura`) y el controlador resuelve
  `quiere agachado + puede levantarse` en un solo sitio. Antes se escribia en
  `enter()` y se restauraba en `exit()`, asi que saltar desde dentro de un tunel
  dejaba al personaje a media altura para siempre: ningun estado aereo restauraba
  nada. Ahora, si nadie pide agacharse y hay hueco, se levanta solo.
- **`agachado_forzado`** separa el agachado que pide el jugador del que impone el
  mundo. El segundo dura exactamente lo que dure la obstruccion.
- **Arreglado el cambio brusco de altura junto a paredes inclinadas.** La sonda de
  techo barria desde los PIES y con el alto completo, asi que su cabeza llegaba
  0.68 m por encima de la del personaje: casi cualquier rampa o saliente contaba
  como techo y forzaba agachado. Ahora sondea solo el hueco que falta, desde la
  coronilla actual hasta la de pie.
- **Una sola clasificacion de superficies** (`PlayerTuning.clasificar`):
  `<75 CAMINABLE`, `75..110 ESCALABLE`, `>110 INVALIDA`, con medio grado de
  holgura en los limites. De ahi salen el sensor de suelo, el de pared, la
  escalada y el `floor_max_angle` del cuerpo. Antes habia dos numeros —50 para el
  suelo y 60..95 para la pared— y podian contradecirse.
  Esto REVIERTE la horquilla 60..95 de la 2.02: 60 y 70 vuelven a ser pendientes.
- **Escalar gana a resbalar.** Lo que deja de ser caminable es exactamente lo que
  empieza a ser escalable, asi que la primera superficie trepable es tambien la
  primera por la que te resbalas. Con el slide delante en `GroupGrounded`, pedir
  agarre en una rampa de 75 grados no servia de nada. Y desde el suelo ahora se
  mira el BOTON de agarre, no solo la adherencia automatica: era el unico sitio
  donde pulsar agarre no hacia nada.
- **Sonda alta en el WallSensor** (hombros) en lugar de la sonda de rodillas de la
  2.02: contra un desplome la pared se te viene encima, y a la altura del pecho
  queda mas lejos que a la de la cabeza. Sin ella, nada por encima de 90 grados se
  detectaba.
- **Movilidad:** carrera 7.8 -> 8.7 m/s; el ataque aereo sale con empuje propio
  (`aereo_impulso`) y avance sostenido; la patada deslizante tiene su rozamiento
  (antes usaba el del agachado y moria en dos metros).
- **Side jump en dos tiempos:** estado `SideJump` propio con una plantada de 0.06 s
  antes del impulso. Frenar y saltar en el mismo frame no se leia como maniobra.
- Rampas del Gym rehechas (60/70/74/75/80/90/100/110/120) y 20 comprobaciones
  nuevas en `TestFase2`.


### Correccion 2.04 — floating fall, slope limit real y clavados encadenables
- **BUG "floating fall" resuelto.** Salirse de una plataforma surfeando o
  deslizandose no cambiaba de estado: el personaje se quedaba flotando y bajando
  a 2 m/s. La causa no era la fisica sino el ORDEN de `GroupGrounded`: el `return`
  de `maneja_ataques()` —que declaran Surf, Slide, SlideKick y Crouch— dejaba
  fuera todo lo que venia despues, incluida la comprobacion de haber perdido el
  suelo. Ahora las preguntas de TERRENO van primero y las de ACCION despues.
  Surf y Slide ademas solo se pegan al suelo si hay suelo.
- **Slope limit a 45 grados.** La frontera caminar/escalar baja de 75 a 45: con 75
  se subia andando por paredes casi perpendiculares y no se leia como andar. Sigue
  siendo UN solo numero (`climb_angulo_min`) del que salen el sensor de suelo, el
  de pared, la escalada y el `floor_max_angle`.
- **`wallrun_angulo_min` (70°)** como requisito EXTRA del wall-run y el wall-slide.
  No es una segunda clasificacion: escalar una ladera de 50 grados tiene sentido,
  correr en horizontal por ella no.
- **Vuelve la sonda de rodillas** al WallSensor. Con el limite en 45 reaparece la
  geometria de la 2.02: contra una pendiente tumbada el pecho queda por encima de
  la superficie y su rayo nace dentro del collider.
- **DOMO DE CALIBRACION en el Gym.** Media esfera que recorre todos los angulos de
  0 a 90 sin un escalon, con un anillo dorado en la latitud exacta del limite. Es
  la forma honesta de ver donde esta el umbral: subes andando hasta que dejas de
  poder. El anillo se calcula del tuning, asi que se mueve solo si el numero cambia.
- **Los dos ataques aereos son clavados.** El ligero era "golpe aereo si hay
  enemigo, clavado si no", y eso hacia que el clavado no saliera justo cuando
  importaba. Ahora ligero = DIVE siempre, y sale hacia delante Y ABAJO desde el
  primer frame (`dive_vertical_inicial`): arrancaba con vertical 0 y por eso la
  trayectoria empezaba plana y no se leia como un clavado.
- **Clavado pesado con REBOTE.** Al clavarse sobre un enemigo se le pisa la cabeza
  y se sale despedido hacia arriba con todo repuesto, asi que se encadena de
  cabeza en cabeza. El picado vertical no se pierde: se muda a agachado + pesado.
- **Patada deslizante:** mas impulso y menos rozamiento —llega mas lejos que
  nunca— pero con `slide_kick_cooldown`. Encadenarla superaba al surf, y la
  movilidad mas rapida sostenida tiene que seguir siendo el surf.
- **Velocidades:** correr 8.7 -> 9.4; surf 15/11 -> 17.5/13.5. La plantada del
  side jump sube a 0.09 s para que se vea.


### Correccion 2.05 — el patinaje, el peso del salto y el picado que paga la altura
- **Arreglado el "ice skating".** `StateMove` trataba igual dos situaciones muy
  distintas: ir mas rapido que la rampa por traer momentum de un dash, y ir mas
  rapido porque acabas de soltar el stick. Las dos caian en `frenado_momentum`
  (6 m/s2), asi que `frenado_suelo` —que existe desde la Fase 1— no llegaba a
  usarse NUNCA en locomocion normal. Medido: soltar a velocidad de carrera
  patinaba **6.04 m en 1.35 s**. Ahora son **1.30 m en 0.28 s**.
- **`frenado_soltar` (26.0)**, parametro propio para el patinaje: `frenado_suelo`
  lo multiplican ademas el aterrizaje (x1.6) y el picado (x2), y son tres cosas
  que se ajustan por separado.
- **El salto vuelve a pesar.** `aceleracion_aire` 25 -> 12, y el techo del control
  aereo pasa de `velocidad_correr` a `control_aereo_techo` (3.2). Antes un salto
  desde parado alcanzaba la velocidad maxima de carrera SIN tocar el suelo: la
  carrerilla no servia para nada porque el aire te la regalaba.
- **PICADO ESCALADO POR ALTURA DE CAIDA.** Dano, radio, aturdimiento y empuje
  crecen con la caida entre `plunge_altura_min` (2.5 m) y `plunge_altura_max`
  (20 m), y pasados `plunge_derribo_desde` (12 m) el aturdimiento se convierte en
  DERRIBO. Es el unico ataque del juego cuya fuerza la decide una decision de
  traversal: sin el, subir una torre y bajar peleando son dos juegos distintos que
  comparten personaje.
  El `AttackData` se DUPLICA antes de escalarlo — el recurso es compartido y
  mutarlo dejaria el picado potenciado para el resto de la partida.
- **`tools/MedirMovimiento.tscn`**, en la linea de `medir_paleta.gd`: cronometra
  el feel en vez de opinar sobre el, con modo A/B (`-- antes`) que reproduce los
  valores previos sin tocar codigo ni git.
- Los constantes magicos del picado (`SUSPENSION`, `VELOCIDAD_CAIDA`) pasan a
  tuning (regla dura #1).


### Correccion 3.0 — la rampa que no se podia subir y el clavado espameable
- **NINGUNA rampa del campo del Gym se podia subir andando**, y llevaba asi desde la
  Fase 0. Se reporto sobre la de 45 grados, pero fallaban las cinco. Causa: las
  rampas estaban centradas a `largo/2 * sin(a)`, y con eso su cara util arrancaba a
  `grosor/2 * cos(a)` de altura —un labio de 13 a 25 cm en el pie—. `CharacterBody3D`
  no sube escalones por su cuenta. Ahora van hundidas para que la cara arranque bajo
  el suelo. Medido: 15 grados sube 1.94 m, 25 sube 3.25, 35 sube 4.45, 45 sube 5.52.
- **El limite de pendiente pasa a ser INCLUSIVO.** La holgura estaba aplicada al reves:
  con `floor_max_angle = climb_angulo_min - 0.5`, una rampa de 45 grados exactos caia
  en tierra de nadie —ni suelo para el motor ni pared estable para la FSM— y el
  jugador entraba en bucle Move -> Climb -> Fall sin subir un metro. Un "slope limit
  de 45" que rechaza una rampa de 45 es una trampa.
- **Coyote de pared** (`escalada_coyote`, 0.18 s). Perder el contacto un frame ya no
  es soltarse. Sobre relieve irregular el sensor parpadea, y ese parpadeo era la otra
  mitad del bucle.
- **Espera entre clavados** (`dive_cooldown`, 0.5 s). Machacar salto + ataque
  encadenaba QUINCE clavados por segundo: saltar, clavarse, aterrizar y volver a
  saltar cabe en cuatro frames. Medido: 15 -> 1.8 clavados/s, y la velocidad
  sostenida baja de 10.3 a 2.7 m/s. El pico sigue en 21 m/s, que es correcto: un
  clavado suelto debe ser rapido; lo que no puede es repetirse sin pausa.
  El picado (agachado + pesado) queda FUERA de esa espera: es otro verbo.
- **Screenshot tests** (`tools/TestVisual.tscn`), 7 tomas contra `tools/baseline/`.
  Estrenados en esta misma correccion: cazaron el cambio de geometria de las rampas y
  el mapa de diff confirmo que solo cambiaban sus bordes.
- Pipeline de Blender a Godot documentado al detalle en `02_PIPELINE_PERSONAJES_ANIM.md §7`.


### Parche 3.01 — los dos clavados dejan de ser el mismo, y el ritmo de la cadena

Parte del parche pedido. Lo que NO entra y por que, al final de la entrada.

- **El clavado ligero es ahora un CLAVADO.** Estaba en 21 m/s horizontales y -7 de
  vertical, y el pesado en 25/-11: la misma parabola tendida con otro nombre, y sin
  forma de distinguirlos jugando. El ligero pasa a 13/-17 —cae mas de lo que
  avanza— y el pesado se queda como el que viaja.
- **Rebote con HANG TIME y sin doble salto.** Al pisar la cabeza de un enemigo se
  suspende la gravedad `dive_hangtime` (0.30 s) y se levanta la espera del clavado,
  para poder encadenar sobre otra cabeza. Se devuelve el DASH pero **no** el salto
  aereo: reponerlo convertiria la cadena en vuelo infinito —siempre habria forma de
  corregir el error de calculo— y sin el, cada rebote es un compromiso.
  El hang time vive en `LocomotionMotor.aplicar_gravedad`, asi que vale en Fall,
  Jump y Glide sin que ninguno tenga que saber que existe.
- **EMBESTIDA EN PRIMERA PERSONA.** El pesado lanzado por encima de
  `fps_velocidad_min` (7.5 m/s) mete la camara en la cabeza y **bloquea el rumbo al
  frente de camara** durante `fps_duracion`. El bloqueo es la mecanica —te
  comprometes a una direccion y ya no la corriges—; la primera persona es lo que lo
  hace legible. Parado sale el pesado de siempre.
  No hace falta una segunda camara: `CameraRig` ya interpola entre modos, asi que
  un modo `Primera` con `dist 0` y `altura 1.42` da la transicion suavizada gratis.
  Se apaga en `exit()` pase lo que pase: un modo de camara del que te quedas
  atrapado si el ataque se cancela es peor que no tenerlo.
- **RITMO DE LA CADENA.** El combate se sentia generico porque los tres golpes
  duraban casi lo mismo (windup 5/5/8, recuperacion 10/11/20): una cadena sin ritmo
  es una animacion repetida. Ahora es **corto-corto-LARGO** —L1 14 frames, L2 14 y
  mas rapido de entrada, L3 39 con windup de 11 que se ve venir— y el hitstop
  escala de 0.04 a 0.14 para que el finisher aterrice con peso.

**PLUGINS INSTALADOS.** Los cuatro, fijados a release y no a `main`:
`phantom_camera` v0.11.0.3 · `cyclops_level_builder` v1.5.0_dev_2 ·
`dialogic` 2.0-alpha-20 · `inventory-system` addon-2.13.0.

Tres son GDScript puro y cero binarios. El de inventario es un GDExtension en C++
cuyo release trae **125 MB** de `.dll`/`.so` para seis plataformas; en el repo se
dejan solo los 19 MB de Windows. Se comprobo que la extension carga de verdad:
`Inventory` e `ItemDefinition` aparecen en el `ClassDB`.

Los autoloads que los plugins registran en `_enable_plugin()` estan escritos a mano
en `project.godot`, porque instalar por linea de comandos no ejecuta ese metodo.

Quedan **instalados y activos, pero sin integrar**: ninguna funcionalidad del juego
los usa todavia. Integrarlos es trabajo aparte, y en el caso de Phantom Camera
implica migrar un `CameraRig` propio que deduce el modo de la categoria del estado
—una decision de arquitectura buena— al sistema de prioridades del plugin.

**Lo que NO entra en este parche, y por que:**
- **El inventario BotW.** `src/ui/` esta vacio: no hay una sola linea de UI, ni HUD,
  ni navegacion de menus, ni gestion de foco. Un inventario paginado con arrastrar y
  soltar no es una funcionalidad, es la primera capa de UI del proyecto entero.
- **Los dos enemigos nuevos** (volador y embestidor). Bloqueados por el **P0** de
  este mismo roadmap: `Guardian.gd` son 372 lineas que mezclan IA, fisica y
  presentacion, con la FSM como un `match` dentro de `_physics_process`. Escribir
  dos enemigos encima significa triplicar ese archivo. Extraer la FSM primero los
  hace baratos; no hacerlo los hace deuda por triplicado.

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
