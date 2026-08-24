# ROCK — Pipeline de Personajes, Concept y Animación

---

## 1. Reparto de personajes

| # | Personaje | Rol | Prioridad |
|---|---|---|---|
| C01 | **El Errante** (protagonista) | Capa azul cobalto, pelo oro pálido. Único personaje jugable. | T0 |
| C02 | **La Sombra** | Criatura pequeña y negra que te sigue/guía (la figura oscura de la referencia). Sin combate: marca dirección, reacciona al peligro. | T1 |
| C03–C05 | **Guardianes de Ruina** ×3 | Constructos de piedra. Existen SOLO para que el combate cuerpo a cuerpo tenga con qué practicar. Tipos: *Lancero* (agresivo), *Escudo* (objetivo de parry), *Vigía* (a distancia). | T1 |
| C06+ | **Colosos** ×5–8 | El contenido real. Cada uno es un rig y un set de animación propio. | T0 (el #1), T2 (el resto) |
| A01 | **Bandadas** | Pájaros blancos, boids. Sin rig — vertex animation. | T1 |

> **Decisión de alcance:** los Guardianes existen porque pediste combate flashy, y un combate
> flashy necesita un saco de boxeo con reglas. Pero son POCOS y ESCASOS en el mundo. El silencio
> de SotC se conserva porque aparecen solo en recintos concretos (patios, criptas), no vagando.

---

## 2. Especificación del rig del protagonista

**Base:** esqueleto humanoide compatible con Mixamo/Rigify (para poder comprar/retargetear
animaciones de relleno) + huesos extra propios.

```
Root (root motion)
└─ Hips
   ├─ Spine1..3, Neck, Head
   │   └─ Eye_L/R, Jaw            (mínimo; el rostro casi no se ve)
   ├─ Shoulder/Arm/Forearm/Hand + 5 dedos ×2
   └─ UpLeg/Leg/Foot/Toe ×2
Extras propios:
   ├─ Weapon_Hand_R              (socket espada)
   ├─ Weapon_Hand_L              (socket lanza / arco)
   ├─ Holster_Back               (socket lanza envainada)
   ├─ Cape_Root -> Cape_01..05   (cadena de física, 5 huesos)
   ├─ Cape_Side_L/R              (2 huesos por lado, para que se abra al planear)
   ├─ Hair_01..03
   └─ IK_Hand_L/R, IK_Foot_L/R   (targets para agarre y suelo irregular)
```

**Presupuesto:** ~65–75 huesos. La **capa es el 40% de la personalidad del personaje** —
no la escatimes: es lo que hace legible el planeo y el dash desde 50 metros.

**Sistema de capa:** `SpringBoneSimulator3D` de Godot 4 (nativo) con sobrescritura por
animación en clips clave (`glide_deploy`, `parry_success`) para poses heroicas.

---

## 3. Lista de animaciones del protagonista

Notación: `T0` = necesario para el vertical slice · `T1` = juego completo · `T2` = pulido.
Total estimado: **~205 clips**.

### 3.1 LOCOMOCIÓN — 22 clips
`idle` · `idle_var_A/B` (respiración, mirar alrededor) · `turn_90_L/R` · `turn_180`
`walk_start` · `walk_loop` · `walk_stop` · `run_loop` · `run_stop_L/R` · `run_turn_180`
`sprint_loop` · `crouch_idle` · `crouch_walk` · `slope_up_loop` · `slope_down_loop`
`land_to_idle` · `land_to_run` · `nudge_wall` · `edge_teeter` — **T0** (variantes y crouch → T1)

### 3.2 AIRE Y SALTO — 16 clips
`jump_start` · `jump_rise` · `jump_apex` · `fall_loop` · `fall_long` (terror, brazos)
`double_jump_flip` · `air_drift_L/R` · `land_soft` · `land_medium` · `land_hard`
`land_roll` · `land_crash` · `wall_bump_air` · `air_stall` · `air_turn` — **T0**

### 3.3 PLANEO (la capa) — 10 clips
`glide_deploy` · `glide_loop` · `glide_bank_L/R` · `glide_dive_tuck` · `glide_pullup`
`glide_stall` · `glide_cancel` · `glide_land` · `glide_hit` — **T0**

### 3.4 DASH — 11 clips
`dash_ground_F/B/L/R` · `dash_air_F/B/L/R` · `dash_recovery` · `dash_chain`
`dash_perfect` (esquiva justa, con destello) — **T0**

### 3.5 DESLIZAMIENTO Y PARED — 12 clips
`slide_enter` · `slide_loop` · `slide_exit` · `slide_jump` · `slide_under` (bajo un arco)
`wallrun_L/R_loop` · `wallrun_enter` · `wallrun_end_jump` · `wallslide_loop`
`wallslide_jump` · `vault_low` — **T1** (los `slide_*` → T0)

### 3.6 BORDES Y ESCALADA — 24 clips · **crítico para colosos**
`ledge_catch` (desde caída) · `ledge_hang_idle` · `ledge_shimmy_L/R`
`ledge_shimmy_corner_in/out` · `ledge_climb_up` · `ledge_jump_up` · `ledge_jump_back`
`ledge_drop` · `climb_idle` · `climb_up/down/L/R` (blendspace 2D) · `climb_corner`
`climb_leap_up` · `climb_strain_loop` (agarre tenso — el latido de SotC)
`climb_slip` (stamina baja) · `climb_shake_hold` (el coloso se sacude, tú aguantas)
`climb_thrown_off` · `climb_to_stand` · `climb_from_stand` · `climb_exhausted` — **T0**

### 3.7 COMBATE — ESPADA — 30 clips
- Cadena ligera: `atk_L1` `atk_L2` `atk_L3` `atk_L4_finisher`
- Pesado: `atk_H_charge_start` `atk_H_charge_loop` `atk_H_release` `atk_H_2`
- Direccional: `atk_dash` `atk_sprint` `atk_from_slide`
- Aéreo: `atk_air_1` `atk_air_2` `atk_plunge_start` `atk_plunge_loop` `atk_plunge_impact`
  `atk_launcher` `atk_juggle`
- Defensa: `parry_ready` `parry_success` `parry_perfect` `parry_fail` `parry_counter`
- Esquiva: `dodge_roll_F/B/L/R` `dodge_perfect_flourish`
- Armado: `draw_sword` `sheath_sword` — **T0** (finisher, juggle, launcher → T1)

### 3.8 LANZA — 20 clips · **sistema propio**
`spear_equip` · `spear_stance_idle` · `spear_thrust_1/2/3` · `spear_sweep`
`spear_vault` (pértiga: te impulsas con la lanza clavada) · `spear_spin_defend`
`spear_aim_start` · `spear_aim_loop` · `spear_aim_walk` · `spear_throw_ground`
`spear_throw_air` · `spear_throw_charged` · `spear_recall_call` · `spear_catch`
`spear_pickup_ground` · `spear_pull_from_surface` · `spear_planted_hang`
(colgado de la lanza clavada) · `spear_planted_climb_on` — **T0**

### 3.9 LAZO / GANCHO — 14 clips
`rope_aim` · `rope_fire` · `rope_attach` · `rope_swing_loop` · `rope_swing_release`
`rope_zip_pull` · `rope_pull_object` · `rope_reel_loop` · `rope_wrap` · `rope_ride_colossus`
`rope_cut` · `rope_miss` · `rope_swing_to_glide` · `rope_swing_attack` — **T1**

### 3.10 ARCO — 8 clips
`bow_draw` · `bow_aim_loop` · `bow_release` · `bow_aim_air` (cámara lenta)
`bow_aim_while_climbing` (disparar agarrado — momento SotC puro) · `bow_reload`
`bow_cancel` · `bow_no_ammo` — **T1**

### 3.11 REACCIONES Y DAÑO — 16 clips
`hit_light_F/B/L/R` · `hit_heavy` · `hit_launched` · `hit_wallslam` · `knockdown`
`getup_fast` · `getup_slow` · `stagger` · `guard_break` · `death_hit` · `death_fall`
`respawn_wake` · `exhausted_breath` — **T1** (`hit_light_*` y `death_*` → T0)

### 3.12 COLOSO — INTERACCIÓN — 12 clips
`colossus_land_impact` (aterrizas encima) · `colossus_brace_loop` (aguantas la sacudida)
`weakpoint_stab_start` · `weakpoint_stab_loop` · `weakpoint_stab_end` · `weakpoint_pull_out`
`blown_off` · `ride_stumble_L/R` · `colossus_slide_down` · `grip_desperate`
`mount_from_rope` · `mount_from_spear` — **T0**

### 3.13 MUNDO Y CINEMÁTICA — 10 clips
`interact_pickup` · `interact_push_loop` · `interact_lever` · `rest_sit` · `rest_getup`
`pray_altar` · `look_up_awe` (mirar al coloso, para las presentaciones) · `whistle`
`idle_cinematic` · `walk_cinematic_slow` — **T2**

### Resumen por tier
| Tier | Clips | Cuándo |
|---|---|---|
| **T0** | ~95 | Vertical slice (Fases 1–4) |
| **T1** | ~75 | Juego completo (Fase 6) |
| **T2** | ~35 | Pulido (Fase 7) |

---

## 4. Animación de colosos

Cada coloso necesita su **propio set**, pero la plantilla se repite:

```
IDLE:       idle_dormant, idle_alert, breathe_loop, look_at_player
LOCOMOCIÓN: walk_loop, walk_turn_L/R, walk_start/stop, stomp_step
ATAQUES:    attack_swipe, attack_slam, attack_stomp, attack_ranged (según diseño)
REACCIÓN:   flinch_light, flinch_heavy, stagger_kneel (ventana de escalada),
			recover_from_kneel
ANTI-JUGADOR (lo más importante):
			shake_light, shake_violent, scratch_at_player, roll_body,
			slam_body_against_wall
FASES:      phase_transition_01/02, enrage
MUERTE:     death_stagger, death_collapse (largo, 8–15 s, cinematográfico)
```

**Regla de producción:** las animaciones de un coloso se autoran **con el jugador de pie
encima**. Si no puedes probar el agarre mientras animas, la anim se va a tirar. Por eso el
`ColossusTestRoom` (una plataforma que se sacude con los mismos parámetros) es la
**primera herramienta** que hay que construir en la Fase 4.

---

## 5. Lista de concept art

### 5.1 Personaje (C01) — 8 láminas
1. **Turnaround** (frente / 3-4 / perfil / espalda) a escala junto a una puerta de 2 m
2. **Silueta en negro puro** ×6 variantes → elige la que se lee mejor a 200 px de alto
3. Hoja de la **capa**: en reposo, corriendo, planeando, en el aire — cómo se abre
4. **Callouts de materiales** con los hex exactos de la paleta
5. Hoja de **poses de acción** (dash, parry, lanzamiento de lanza)
6. Rostro y expresiones (mínimo: casi no se ve, no lo sobretrabajes)
7. **Armas**: espada, lanza con 3 variantes de punta, dispositivo del lazo, arco
8. **Color key**: el personaje sobre fondo crema, sobre verde oscuro, y a contraluz

### 5.2 Colosos — 5 láminas por coloso
1. **Estudio de silueta** (6 opciones, en negro, contra crema)
2. **Comparativa de escala** con el personaje y con una torre conocida del mundo
3. **Mapa de agarres**: la lámina pintada con amarillo donde se escala y rojo donde no.
   *Este es el documento de diseño real, no el arte.*
4. **Puntos débiles** y sus dos estados (oculto / expuesto)
5. Detalle de materiales: pelaje, musgo, piedra, metal antiguo

### 5.3 Entorno — por zona
1. **Mood keyframe**: una pintura grande, la postal de la zona ← define el color grading
2. **Color key en escala de grises** de la misma escena (comprobar el valor)
3. **Kit modular de ruinas**: arcos, muros, columnas, escaleras, suelos — dibujado por piezas
4. **Landmark**: la silueta que se ve desde toda la zona y te orienta
5. Hoja de **vegetación** (hierba, hiedra, árboles) con su rampa de color

### 5.4 VFX — 1 hoja de estilo
Arcos de espada, destello de parry, polvo de aterrizaje, líneas de viento del planeo, impacto
en punto débil, estela del lazo. **Todo en colores de acento; blanco puro solo en el parry
perfecto.**

### 5.5 UI
HUD mínimo y diegético: anillo de stamina (aparece solo cuando baja), cargas de lanza.
Sin barra de vida numérica — el daño se comunica con el viraje de color de pantalla y la postura.

---

## 6. Pipeline técnico de arte

```
Concept 2D (con la paleta bloqueada)
   └─> Blockout gris en Godot        <- se JUEGA antes de modelar nada
		└─> Modelado (Blender)        low-poly, silueta primero
			 └─> UV + textura         colores planos + AO horneado, sin PBR complejo
				  └─> Rig (Rigify)
					   └─> Animación (Blender, root motion en el hueso Root)
							└─> Export glTF 2.0 (.glb) -> Godot
								 └─> AnimationTree + AnimationLibrary por sistema
									  └─> Test en el Gym -> iterar
```

**Reglas de export**
- glTF 2.0 (`.glb`). Una `AnimationLibrary` por sistema (`locomotion`, `combat`, `traversal`,
  `spear`, `rope`) para no acabar con un `AnimationPlayer` de 200 pistas.
- Nomenclatura estricta `sistema/accion_variante`: `combat/atk_L2`, `traversal/ledge_shimmy_L`.
- **Root motion activado** en ataques y traslados escriptados; desactivado en locomoción.
- 30 fps de autoría; Godot interpola.
- Cada clip de ataque lleva sus **method tracks**: `hitbox_on`, `hitbox_off`,
  `cancel_window_open`, `vfx_spawn`, `sfx`, `camera_shake`.

**Regla de oro:** nunca se anima un clip de combate antes de que exista su `AttackData` y se
haya probado con una **cápsula gris**. El feel se afina con cubos; el arte solo lo viste.

---

## 7. Blender → Godot, paso a paso

Todo lo de abajo es **específico de este proyecto**. La parte genérica de un pipeline
glTF está en cualquier tutorial; lo que no está en ningún tutorial es cómo encaja un
personaje real en un `PlayerController` que ya lleva escritos siete meses de reglas.

### 7.1 Ajustes de Blender antes de modelar

| Ajuste | Valor | Por qué |
|---|---|---|
| Unit System | Metric, **1.0 = 1 m** | Godot es métrico. Si Blender está a otra escala, el `.glb` llega escalado y todo el tuning miente. |
| Altura del personaje | **1.8 m exactos** | Es la altura de la cápsula (`_altura_base`). Cualquier otra cosa obliga a reescalar en Godot, y el escalado se pelea con `pedir_postura()`. |
| Orientación | mirando a **−Y** en Blender | Blender exporta a glTF rotando: −Y de Blender acaba siendo **−Z** en Godot, que es el "adelante" de un `Node3D`. |
| Transform | **Apply All** antes de riguear | Escala o rotación sin aplicar viaja al `.glb` y descoloca los `BoneAttachment3D`. |
| Origen | **entre los pies**, en (0,0,0) | El origen del `PlayerController` está en los pies. Si el modelo tiene el origen en la cadera, flota o se hunde medio metro. |

### 7.2 Presupuesto

- **Malla:** 8–15 k triángulos. Es un juego de silueta y color plano, no de detalle.
- **Texturas:** 1 atlas de 1024², colores planos + AO horneado. Sin normal map, sin
  roughness/metallic complejos: chocarían con la dirección de arte (`01_DIRECCION_ARTE.md`).
- **Materiales:** 1, máximo 2 (cuerpo + capa). Cada material extra es un draw call.
- **Huesos:** 65–75, según §2.
- **Regla de croma:** el personaje es lo único saturado del encuadre (pilar P3). Sus
  colores salen de `Palette.tres`, no del color picker de Blender.

### 7.3 Export glTF desde Blender

Formato **glTF Binary (.glb)**. Casillas que importan:

- Include → **Limit to: Selected Objects** (malla + armature, nada más).
- Transform → **+Y Up** ✔
- Data → Mesh: Apply Modifiers ✔ · Normals ✔ · UVs ✔ · **Tangents ✘** (no hay normal map).
- Data → Armature: **Export Deformation Bones Only ✘** — los huesos de socket
  (`Weapon_Hand_R`, `Holster_Back`) no deforman nada y aun así hacen falta.
- Animation → **Group by NLA Track** ✔ · Always Sample Animations ✔ · **30 fps**.
- Animation → Optimize Animation Size ✘ *(recorta claves y se come poses de 2 frames,
  que en un ataque de 4 frames activos es la mitad del golpe)*.

**El nombre de cada NLA track es el nombre del clip en Godot.** De ahí sale la
nomenclatura `sistema/accion_variante` de §6, y de ahí sale que el `AnimationTree`
pueda pedir `combat/atk_L2` sin traducción intermedia.

### 7.4 Import en Godot

En el `.glb` importado, pestaña Import:
- **Root Type:** `Node3D` · **Root Name:** `Modelo`.
- **Skins → Use Named Skins** ✔.
- **Animation → Import** ✔, **Trimming** ✔, **Remove Immutable Tracks** ✔.
- **Save to File** las animaciones a `content/characters/anim/*.res`, agrupadas en una
  `AnimationLibrary` por sistema. Un `AnimationPlayer` con 205 pistas es ingobernable.
- Marcar el `.glb` como **"Advanced… → Skeleton3D → Retarget"** solo si vienen clips de
  Mixamo. Los propios no lo necesitan.

### 7.5 Dónde enchufarlo — **la parte que sí es de este proyecto**

El modelo sustituye a los dos `MeshInstance3D` grises que hoy cuelgan de `Visual`:

```
Player (PlayerController)
├─ Visual (Node3D)          <- NO se toca: lo escribe el controlador
│   └─ Modelo (el .glb)     <- aquí entra el personaje
│       └─ Skeleton3D
│           ├─ BoneAttachment3D "Mano_R" -> socket espada
│           └─ BoneAttachment3D "Espalda" -> socket lanza
├─ Collider (CapsuleShape3D)
└─ …
```

**Cinco trampas que el código actual te va a poner, y cómo esquivarlas:**

1. **`Visual` no se toca.** El controlador le escribe `rotation.y`, `rotation.z`,
   `quaternion` y `scale.y`. El modelo va **dentro**, como hijo. Si metes el `.glb`
   en el sitio de `Visual`, el import lo pisará y perderás las referencias.
2. **`pedir_postura()` aplica `visual.scale.y`.** Al agacharse, hoy el personaje se
   *aplasta* al 50%. Con una cápsula da el pego; con un humano es grotesco. Cuando
   exista el modelo hay que cambiar esa línea por una **animación de agachado** y dejar
   que la cápsula de colisión encoja sola. Está anotado como deuda: el sistema de
   postura ya está centralizado (regla dura #14), así que es **una** línea.
3. **`orientar_a_3d()` escribe `visual.quaternion`.** El modelo debe colgar de `Visual`
   con transform identidad; cualquier rotación propia se suma y sale torcido.
4. **`HitstopManager` congela el primer `AnimationTree` que encuentra** bajo el nodo.
   Hoy no hay ninguno, así que el hitstop es solo la micro-pausa global. En cuanto
   exista el `AnimationTree`, la otra mitad del sistema se enciende **sola**.
5. **Los `method tracks` sustituyen a los frames del `AttackData`.** Hoy la hitbox se
   abre por número de frame (`frames_windup`). Cuando el clip tenga `hitbox_on`, los dos
   tienen que decir lo mismo o el golpe saldrá desincronizado de la animación.
   Recomendación: que el `.tres` siga mandando y el clip se anime **contra** él, no al
   revés. El feel ya está afinado; la animación lo viste.

### 7.6 Orden de trabajo recomendado

No modeles los 205 clips. El orden que minimiza trabajo tirado:

1. **T-pose + rig + 6 clips** (`idle`, `walk`, `run`, `jump`, `fall`, `land`) y méteselo
   al juego. Ahí ya vas a descubrir que la mitad de los números de `PlayerTuning` se
   sienten distintos con un cuerpo que tiene peso visual.
2. **Reajusta el tuning** con el modelo puesto. Corre `tools/MedirMovimiento.tscn` antes
   y después para saber qué has cambiado de verdad.
3. **Añade una toma al `TestVisual`** con el modelo. A partir de ahí, cualquier
   regresión de pose se caza sola.
4. Solo entonces, los clips de combate — y cada uno después de que su `AttackData` esté
   cerrado.

**La razón de este orden:** el paso 1 cuesta una semana y puede invalidar decisiones de
las siete correcciones de feel. Descubrirlo con 6 clips es barato; descubrirlo con 205,
no.
