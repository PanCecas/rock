# ROCK — Integración de modelos, animaciones y escenarios de Blender

**Este documento se usa DESPUÉS de cerrar los tweaks de mecánica, no antes.** Todo
lo que hay aquí sustituye cápsulas grises por modelos reales; hacerlo antes de que
el feel esté cerrado significa reafinar cada número dos veces, y la regla dura #7
del proyecto dice exactamente eso: *el feel se prueba con cápsulas grises antes de
que exista una sola animación*.

Lo que sigue es un procedimiento, no una guía de opciones. Cuando el proyecto ya
tiene una solución para algo, se dice cuál y se usa esa: no hay dos formas de
hacer cada paso.

---

## 0. Qué NO hay que tocar

La lista importa tanto como el procedimiento, porque el error caro aquí es
reescribir sistemas que ya funcionan para "adaptarlos al modelo".

| Sistema | Por qué sobrevive intacto |
|---|---|
| `PlayerController` + la FSM de 28 estados | No conocen la malla. El único nodo visual que tocan es `Visual`, y solo su yaw/pitch/roll. |
| `SurfaceContext` · `LocomotionMotor` | Trabajan sobre `velocity` y el collider. Ningún hueso interviene. |
| `Enemigo` + `EnemyStateMachine` | Igual: `visual` es un `MeshInstance3D` que se puede sustituir por un `Node3D` con el modelo dentro. |
| `AttackData` y las hitboxes | La hitbox es una **consulta de forma** desde el centro del cuerpo (`alcance`, `radio`, `altura`, `arco_grados`), no un hueso. Los modelos no la cambian. |
| `Palette` y sus reglas de croma | Los materiales del modelo se validan contra ella igual que los de las cápsulas. |
| Toda la suite de tests | 249 comprobaciones que no miran mallas. Si una se pone roja al meter el modelo, es que el modelo movió algo que no debía. |

**El collider manda sobre la malla, siempre.** El personaje mide 1.8 m de cápsula
y esa cápsula es la que camina, choca y escala. Si el modelo mide 2.1 m, se
**escala el modelo**, no el collider: cambiar el collider reafinaría los ~200
números de `PlayerTuning` que se calibraron contra él.

---

## 1. Exportar desde Blender

### 1.1 Formato: glTF 2.0 (`.glb`), y no otro

Godot 4 importa glTF de forma nativa y es el único formato con soporte de primera
para skinning + animaciones + materiales PBR. FBX necesita un convertidor externo
y `.blend` directo obliga a tener Blender instalado en cada máquina que abra el
proyecto.

Usar **`.glb`** (binario, un solo archivo) y no `.gltf` + carpeta: un archivo
suelto no puede perder sus texturas al mover la carpeta.

### 1.2 Ajustes obligatorios del exportador

En Blender, `File > Export > glTF 2.0`:

| Sección | Ajuste | Por qué |
|---|---|---|
| Format | **glTF Binary (.glb)** | Un solo archivo. |
| Include | **Limit to: Selected Objects** | Evita exportar luces y cámaras de trabajo. |
| Transform | **+Y Up** activado | Es el convenio de Godot. Sin esto el personaje sale tumbado. |
| Data > Mesh | **Apply Modifiers** activado | O el Mirror y el Subsurf no llegan. |
| Data > Mesh | **Tangents** activado si hay normal map | Godot los necesita para el normal mapping. |
| Data > Armature | **Export Deformation Bones only** | Los huesos de control (IK targets, pole targets) no deben viajar: engordan el skeleton y confunden el retarget. |
| Animation | **Group by NLA Track** | Cada acción sale como un clip con su nombre. |
| Animation | **Always Sample Animations** activado | Las curvas con interpolación de Blender no siempre se traducen; muestreadas, sí. |

### 1.3 Antes de exportar, en Blender

1. **Aplicar escala y rotación** (`Ctrl+A > All Transforms`) en el modelo y el
   armature. Una escala sin aplicar llega a Godot como un `scale` en el nodo y
   rompe el IK.
2. **Origen en los pies, en el centro del personaje.** El `CharacterBody3D` de
   Godot tiene su origen en el centro de la cápsula, y el modelo se cuelga de un
   `Visual` desplazado; con el origen en la cadera, ese desplazamiento hay que
   adivinarlo.
3. **El personaje mira a −Y en Blender** (que es −Z en Godot tras el cambio de
   ejes). Ver §3: es el convenio del bando enemigo. Para el jugador el visual mira
   a +Z, y eso se corrige con una rotación de 180° en el nodo `Visual`, **no
   reexportando el modelo**.
4. **Nombres de hueso consistentes** entre personajes que compartan animaciones.
   Si el jugador y los enemigos usan el mismo rig, el retarget es gratis.

### 1.4 ¿Conectar el MCP de Blender?

**Respuesta corta: no hace falta, y por ahora no compensa.**

El flujo real es *exportar `.glb` a `content/models/` y Godot lo reimporta solo* —
el editor vigila el sistema de archivos, así que guardar encima del `.glb` ya
actualiza la escena con el modelo dentro. El bucle es: tocas en Blender, exportas
con el mismo nombre, y al volver a Godot ya está. Eso es un atajo de teclado, no
un problema que necesite un servidor MCP en medio.

Un MCP de Blender aportaría algo distinto: **generar o modificar geometría desde
la conversación**. Es útil para blockout y para lotes (renombrar 40 huesos,
exportar 30 props con los mismos ajustes), no para el ida y vuelta de un
personaje. Si se conecta, que sea para eso, y sabiendo que introduce una
dependencia que hay que tener viva para trabajar.

Y hay una razón dura para no meterlo en el camino crítico: **este proyecto ya
tiene tres addons desactivados por ensuciar la consola** (ver `CLAUDE.md §Plugins`).
La regla es "solo se activa lo que se USA". Un MCP entra bajo esa misma regla.

---

## 2. El jugador, paso a paso

### 2.1 Meter el modelo

`Player.tscn` tiene hoy:

```
Player (CharacterBody3D)
├── Collider (CollisionShape3D)   ← cápsula 1.8 m. NO SE TOCA.
├── Visual (Node3D)
│   ├── Cuerpo (MeshInstance3D)   ← la cápsula gris
│   └── Frente (MeshInstance3D)   ← el marcador de morro, en z = +0.3
└── ...
```

1. Instanciar el `.glb` como hijo de `Visual`, al lado de `Cuerpo`.
2. **Borrar `Cuerpo` y `Frente` cuando el modelo ya se vea**, no antes: `Frente`
   es la única forma de comprobar a ojo que el personaje mira a donde cree.
3. Ajustar la **escala del modelo** hasta que su altura coincida con la cápsula.
   Se mide, no se estima: la cápsula es `_altura_base = 1.8`.
4. Ajustar la **posición Y del modelo** para que los pies queden en la base de la
   cápsula, es decir en `y = -0.9` relativo a `Visual`.
5. Rotar el modelo 180° en Y si hace falta, hasta que mire a **+Z**. Ver §3.

`PlayerController._actualizar_visual()` escribe el yaw de `Visual`. El modelo
cuelga de ahí, así que hereda la orientación sin tocar una línea de código.

### 2.2 El AnimationTree

El proyecto lo tiene **planificado y sin construir**: `docs/02_PIPELINE_PERSONAJES_ANIM.md`
lista los ~205 clips por tiers. Lo que hay que respetar al montarlo:

- **`AttackData.anim`** ya existe en cada `.tres` y contiene el nombre del clip
  (`combat/atk_L1`, `combat/atk_H1_spin`, `combat/atk_H2_slam`…). No hay que
  inventar un mapeo: está escrito desde la Fase 2.
- Los tiempos de combate van en **frames a 60 Hz** en el `.tres`, y la animación
  se ajusta a ellos, no al revés. Un `frames_windup = 12` son 0.2 s de anticipación
  y la animación tiene que caber ahí, o el golpe sale antes de que se vea el
  gesto.
- **REGLA DURA #5: el hitstop congela el `AnimationTree`, nunca
  `Engine.time_scale`.** `HitstopManager` ya está escrito para eso; al crear el
  `AnimationTree` hay que registrarlo ahí.
- La locomoción es un **`AnimationNodeBlendSpace2D`** alimentado por
  `motor.rapidez_plana()` y la dirección relativa. No hace falta un estado de
  animación por cada estado de la FSM: la FSM tiene 28 y la mayoría comparten
  clip de locomoción.

### 2.3 El orden correcto

1. Modelo dentro, cápsula fuera, **sin animaciones**. Correr el screenshot test:
   las 11 tomas van a cambiar, y ese es el momento de mirar los diffs y regenerar
   las referencias (regla dura #18: solo cuando el cambio visual era el buscado).
2. Solo locomoción (idle / walk / run / jump / fall). Jugar.
3. Combate, clip a clip, comprobando contra los frames del `.tres`.
4. IK (§4). Va el último porque necesita el rig ya asentado.

---

## 3. El convenio de orientación — leer antes de rotar nada

Este proyecto tiene **dos convenios de frente, y los dos son correctos**:

| Quién | Frente | Dónde se escribe |
|---|---|---|
| **Jugador** | **+Z** del nodo `Visual` | `PlayerController.orientar_a()` |
| **Enemigos** | **−Z** del cuerpo | `Enemigo.frente()` |

No hay que unificarlos. Lo que no puede haber es un **tercer** criterio dentro de
uno de los dos: eso fue el bug del parche 3.08, donde `encarar()` apuntaba `+Z`
mientras los cinco lectores del bando enemigo leían `−Z`, y el embestidor cargaba
**huyendo** del jugador.

Traducido al modelo: si el personaje sale mirando al revés, **se rota el nodo del
modelo dentro de `Visual`** y se deja el código en paz.

---

## 4. IK — que los pies y las manos reaccionen al entorno

### 4.1 Qué usar: `SkeletonModifier3D`, y NO `SkeletonIK3D`

Godot 4.7 trae un stack de IK moderno. **`SkeletonIK3D` está marcada como
obsoleta** y no debe usarse en código nuevo. Los modificadores disponibles,
verificados contra este build (`ClassDB.get_inheriters_from_class`):

```
TwoBoneIK3D · FABRIK3D · CCDIK3D · ChainIK3D · SplineIK3D
JacobianIK3D · IterateIK3D · LookAtModifier3D · AimModifier3D
CopyTransformModifier3D · ConvertTransformModifier3D · ModifierBoneTarget3D
SpringBoneSimulator3D · RetargetModifier3D
```

Todos son hijos de `SkeletonModifier3D` y se cuelgan **como nodos hijos del
`Skeleton3D`**, en orden: se aplican de arriba abajo después de la animación.

### 4.2 Pies en el suelo — `TwoBoneIK3D`

Una pierna es cadera → rodilla → pie: exactamente dos huesos, que es para lo que
`TwoBoneIK3D` existe. FABRIK y CCDIK son para cadenas largas (una cola, un
tentáculo) y para una pierna son más caros y menos estables.

Montaje:

```
Skeleton3D
├── TwoBoneIK3D  (pierna izquierda)   → target: Marker3D "IK_Pie_Izq"
├── TwoBoneIK3D  (pierna derecha)     → target: Marker3D "IK_Pie_Der"
└── ...
```

La lógica que mueve los targets es un componente nuevo que hace, por pie y por
frame de física:

1. Un raycast desde el tobillo hacia abajo, sobre la capa **`Layers.SUELO_JUGADOR`**
   —la misma que usa `GroundSensor`, no una nueva—.
2. Si toca, el target va al punto de impacto más el grosor de la suela.
3. La cadera baja hasta la altura del pie más bajo, para que en una pendiente el
   personaje no quede flotando con una pierna estirada.
4. La rotación del pie se alinea con la **normal** del raycast.

Dos avisos medidos que este proyecto ya tiene escritos y aplican aquí:

- **La normal del suelo la clasifica `PlayerTuning.clasificar()`** (regla dura
  #15). El IK **no** puede tener su propio umbral de "esto es suelo": dos
  criterios para la misma rampa es como se llega a que sea *demasiado empinada
  para andar* y *demasiado tumbada para escalar* a la vez.
- **El IK escribe DESPUÉS de la animación y no toca `velocity`.** Es presentación.
  Si el IK empieza a decidir dónde está el suelo, ha dejado de ser IK.

### 4.3 Manos — `TwoBoneIK3D` + `LookAtModifier3D`

Los sitios donde el proyecto ya sabe dónde tiene que estar la mano, y por tanto
donde el IK es gratis:

| Verbo | Punto que ya existe | Archivo |
|---|---|---|
| Lanza empuñada / cordón | `Spear.punto_de_mano()` | `src/weapons/Spear.gd` |
| Anclaje / segunda cuerda | `Anclaje.punto_de_mano()` | `src/weapons/Anclaje.gd` |
| Escalada y agarre de canto | la normal y el punto de `WallSensor` / `LedgeSensor` | `src/player/sensors/` |
| Balanceo y resortera | el ancla que ya calcula el estado | `StateSpearSwing`, `StateSlingshot` |

Es decir: **no hay que calcular nada nuevo para las manos.** Los puntos están
escritos y probados; el IK solo los consume.

`LookAtModifier3D` en el cuello/cabeza para que mire al objetivo del soft-lock
(`TargetingSystem.objetivo()`) es el añadido más barato en juice de toda la lista.

### 4.4 Orden de los modificadores

Importa y es fuente de bugs silenciosos. De primero a último:

1. `RetargetModifier3D` (si las animaciones vienen de otro rig).
2. `LookAtModifier3D` — cabeza.
3. `TwoBoneIK3D` — brazos.
4. `TwoBoneIK3D` — piernas.
5. `SpringBoneSimulator3D` — capa, pelo, correas. Va el último porque reacciona a
   lo que hayan hecho los anteriores.

---

## 5. Animación procedural para enemigos

La arquitectura ya la soporta sin cambios, y por una razón concreta: **`Enemigo`
no llama a ninguna animación**. Los estados deciden comportamiento y escriben
`velocity`; lo que se ve lo pone el nodo `Visual`. Un enemigo procedural es un
`Visual` distinto.

Lo que hay disponible en 4.7 sin escribir un solver:

- **`SpringBoneSimulator3D`** — patas, antenas, colas que reaccionan solas al
  movimiento del cuerpo. Cero código.
- **`ChainIK3D` / `FABRIK3D`** — cadenas largas: un tentáculo, el cuello de algo
  grande.
- **`TwoBoneIK3D`** por pata para un caminar procedural tipo *spider*: los targets
  van por raycast y el ciclo lo lleva un temporizador desfasado por pata.

Para el `ColosoMediano` y la Fase 4 esto es más que un adorno: un coloso es un
**nivel de plataformas en movimiento**, y sus patas tienen que pisar el terreno
real o el jugador ve la geometría atravesarse mientras la escala.

---

## 6. Escenarios de Blender

### 6.1 Las tres condiciones, y son las únicas

Cualquier geometría importada funciona con todos los sistemas del juego si cumple:

1. **Collider en la capa 1 (`WORLD`).**
2. **Escalable en la capa 4 (`CLIMBABLE`)** si se quiere poder trepar por ella a
   mano.
3. **Nada más empinado de 45° es caminable** — por encima se escala hasta 110°, y
   por encima de eso no se hace nada. Lo decide `PlayerTuning.clasificar()`.

Están medidas y verificadas: es lo que dice la sección *Notas* de
`docs/05_TABLERO.md` sobre portabilidad.

### 6.2 Colisión

En Blender, sufijar los objetos de colisión con **`-col`** (o `-colonly` para los
invisibles) hace que Godot les genere el `StaticBody3D` en la importación. Para
terreno complejo eso es lo correcto; para un muro, una caja a mano es más barata
que un trimesh.

**Nunca un trimesh cóncavo para algo que se mueve.** La Fase 4 lo va a pedir con
el coloso, y ahí el collider tiene que ser una composición de formas convexas.

### 6.3 Navegación — ahora sí hace falta

El proyecto tiene el soporte escrito (`Enemigo.rumbo_hacia()`, con
`NavigationAgent3D` opcional) y **hoy no se usa**, porque el Gym se genera por
código y no tiene navmesh: sin él, `rumbo_hacia()` cae a la línea recta, que es
lo que el juego lleva haciendo desde la Fase 2.

Con escenarios reales el paso es:

1. Un **`NavigationRegion3D`** que envuelva la geometría del nivel.
2. Su `NavigationMesh` con `geometry/parsed_geometry_type` en **static colliders**,
   para que parsee lo mismo que pisa el jugador.
3. **Bake en el editor**, no en runtime.
4. Añadir un hijo **`NavigationAgent3D` llamado exactamente `Nav`** a las escenas
   de enemigo que deban rodear obstáculos. El nombre importa: `Enemigo` lo busca
   con `get_node_or_null("Nav")`.

Sin el paso 4, el enemigo sigue yendo recto. Es opcional a propósito: los seis
enemigos que ya existen no lo tienen y no debían cambiar de comportamiento por
que apareciera el sistema.

### 6.4 Materiales

**Regla dura #9: los colores salen de `Palette.tres`, nunca de un hex escrito a
mano.** Un material traído de Blender con su color propio se salta la validación
de croma (regla #8), y `Palette.validar()` no puede avisar de lo que no conoce.

El procedimiento: importar el modelo, y en Godot **sustituir el material** por uno
que lea de la Palette. Para props donde eso sea inviable, medirlos primero con
`tools/medir_paleta.gd` y comprobar que no invaden los tonos reservados
(200–265° azul y 335–25° rojo por encima de croma 0.35).

---

## 7. Orden de ejecución recomendado

Cada paso deja el proyecto jugable. Esa es la propiedad que hay que preservar:
nunca dos cosas rotas a la vez.

| # | Paso | Cómo se comprueba |
|---|---|---|
| 1 | Cerrar los tweaks de mecánica que queden | las 5 suites en verde |
| 2 | Modelo del jugador, sin animaciones | jugar + `TestVisual` (regenerar referencias mirando el diff) |
| 3 | Locomoción básica en `AnimationTree` | jugar |
| 4 | Un escenario de Blender, con sus tres condiciones | `TestFase1` sobre él |
| 5 | Navmesh + `Nav` en un enemigo | ver si rodea una columna |
| 6 | Clips de combate contra los frames del `.tres` | `TestFase2` |
| 7 | Modelos de enemigo | `TestEnemigos` + `TestVisual` |
| 8 | IK de pies | pendientes y escaleras |
| 9 | IK de manos | lanza, escalada, cantos |
| 10 | `SpringBoneSimulator3D` y animación procedural | mirar |

---

## 8. Lo que va a romperse, y por qué

Escrito por adelantado para que cuando pase no parezca un misterio:

| Síntoma | Causa real |
|---|---|
| El personaje flota o se hunde | Origen del modelo en la cadera, no en los pies. §2.1 paso 4. |
| Sale tumbado | Falta **+Y Up** en el exportador. §1.2. |
| Mira al revés | Convenio de orientación. **Rotar el nodo, no el código.** §3. |
| El IK tiembla | Los targets se están escribiendo en `_process` mientras el raycast va en física. Todo el IK va en física, y con la interpolación encendida (regla dura #21bis) el nodo del modelo NO se excluye: se deja interpolar. |
| Las animaciones no encajan con los golpes | Los tiempos los manda el `.tres` en frames a 60 Hz, no el clip. §2.2. |
| Se congela el juego en un impacto | Alguien conectó el hitstop a `Engine.time_scale`. Regla dura #5. |
| El screenshot test se pone rojo entero | Es lo esperado al cambiar las mallas. Mirar los diffs y **entonces** regenerar. Regla dura #18. |
| Un enemigo se queda clavado | `Nav` presente pero sin navmesh bakeado. Debería caer a línea recta; si no lo hace, el agente está devolviendo su propia posición. §6.3. |
