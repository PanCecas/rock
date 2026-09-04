# ROCK — Manual de uso

Los otros documentos dicen **qué** hay y **por qué** está así. Este dice **cómo se
usa**: dónde está cada sistema, qué hay que escribir para meterlo en una escena
tuya, y qué números vas a querer tocar.

Es un recetario. Cada receta es autocontenida: puedes leer solo la que necesitas.

| Si buscas… | Ve a |
|---|---|
| Meter modelos y animaciones de **Blender** | `06_INTEGRACION_3D.md` — export, AnimationTree, IK, navmesh. Este doc **no lo repite**, solo dice dónde encaja |
| Por qué la arquitectura es así | `03_ARQUITECTURA_MECANICAS.md` |
| Qué está hecho y qué no | `05_TABLERO.md` |
| Cómo se construye el look | `07_SHADERS.md` |
| Las reglas que no se negocian | `CLAUDE.md`, "Reglas duras del código" |

**Todo lo que hay aquí está verificado contra el código de este repo**, no contra
la documentación. Si una receta no funciona, es un bug de la receta.

---

## 0. Lo mínimo para que una escena tuya funcione

Una escena de juego necesita cuatro cosas, y solo cuatro:

```
MiNivel (Node3D)
├── Sol            DirectionalLight3D
├── WorldMood      WorldEnvironment  + src/art/WorldMood.gd
│                    palette   = content/data/default_palette.tres
│                    sol_path  = ^"../Sol"
├── Player         instancia de src/player/Player.tscn
└── CameraRig      instancia de src/camera/CameraRig.tscn
```

Los **autoloads ya están puestos** en `project.godot` y no hay que tocarlos:
`EventBus`, `GameState`, `HitstopManager`, `DebugOverlay`, `DebugDraw`,
`MenuControles`.

`WorldMood` construye el `Environment` entero desde la `Palette` —niebla, cielo,
tonemap, sombras tintadas— y configura el sol. **No pongas colores a mano en el
Environment**: se los va a comer al arrancar.

Con eso ya tienes un nivel jugable: correr, saltar, dash, planeo, escalada,
paredes, agua. Lo demás son extras que se añaden de uno en uno.

> **Comprueba que funciona:** `godot --path .` y prueba a moverte. **F3** abre el
> panel de debug, **F7** los gizmos 3D, **Escape** el menú de controles.

---

## 1. El jugador

**Dónde:** `src/player/Player.tscn` · lógica en `src/player/`.

Se instancia y ya está. Lo que vas a querer tocar:

| Qué | Dónde |
|---|---|
| Velocidades, saltos, dash, escalada, agua… (~200 números) | `content/data/default_tuning.tres` (`PlayerTuning`) |
| Sus ataques | los `@export var ataque_*` del nodo `Player` |
| Su modelo | el nodo `Visual` — ver §8 |

**El tuning se recarga en caliente con F5.** Editas el `.tres`, pulsas F5 en el
juego y ya está: no hay que reiniciar. Es la forma de afinar el feel.

**Los 27 estados de la FSM** cuelgan de `Player/StateMachine`, agrupados en
`Grounded`, `Airborne`, `Attached`, `Water` y `Combat`. Si añades un verbo nuevo,
lee la **regla dura #13** antes: es el fallo que más veces ha aparecido en este
proyecto.

---

## 2. La lanza y la daga

**Dónde:** `src/weapons/Spear.tscn` y `src/weapons/Anclaje.tscn`.

**No son hijos del jugador.** Viven en el mundo y el jugador guarda una referencia.
La receta completa, copiada de `Gym._dar_lanza()`:

```gdscript
# En el _ready de tu nivel. `jugador` es el PlayerController.
var l := preload("res://src/weapons/Spear.tscn").instantiate() as Spear
l.palette = GameState.palette
l.ataque = load("res://content/data/attacks/lanza_vuelo.tres")
add_child(l)                     # al MUNDO, no al jugador
l.dueno = jugador                # quién la tiró: decide el equipo de la hitbox
l.global_position = jugador.global_position + Vector3.UP
jugador.set("lanza", l)          # y el jugador se entera de que la tiene

# La daga: mismo patrón, pero el jugador guarda una LISTA.
var a := preload("res://src/weapons/Anclaje.tscn").instantiate() as Anclaje
a.palette = GameState.palette
a.dueno = jugador
add_child(a)
jugador.set("dagas", [a] as Array[Anclaje])
```

**Hay UNA lanza y UNA daga a propósito.** La escasez es lo que convierte "dónde la
clavo" en una decisión. Si duplicas, tendrás que llevar la cuenta de cuál está
dónde, y eso no es una mecánica: es contabilidad.

Números en `SpearTuning` (`src/weapons/SpearTuning.gd`): velocidad de vuelo,
alcance, imantado, tamaño de la plataforma, largo de cuerda, resortera.

---

## 3. Un enemigo

**Dónde:** `src/enemies/` — `Guardian.tscn`, `Embestidor.tscn`, `Volador.tscn`,
`ColosoMediano.tscn`.

```gdscript
var g := preload("res://src/enemies/Guardian.tscn").instantiate() as Enemigo
g.palette = GameState.palette
g.ataque = load("res://content/data/attacks/guardian_lancero.tres")
add_child(g)
g.global_position = Vector3(4, 0, -6)
```

**Ponle SIEMPRE un `ataque`**, aunque no vaya a atacar: su estado `Recuperar` lo
lee al recibir un golpe y sin él revienta. (Excepción: el `ColosoMediano`, cuyo
único trabajo es dejarse escalar.)

Los `@export` que más se tocan:

| Export | Qué hace |
|---|---|
| `vista` | radio del cono de visión, en metros. `0` = ciego (útil en pruebas) |
| `alcance_ataque`, `cadencia` | cuándo y cada cuánto pega |
| `agarrable` | si la daga y la lanza **se le quedan clavadas** y se le puede zarandear |
| `vuela` | única diferencia de física entre el volador y el terrestre |
| `ruta` | puntos de patrulla. Vacío = se queda quieto |
| `velocidad`, `aceleracion`, `velocidad_giro` | locomoción |

**Para pacificarlo en una prueba:** `g.vista = 0.0` y `g.fsm.cambiar(&"Dormido")`.

### 3.1 Un enemigo NUEVO

Cada enemigo **declara sus propios estados en su `.tscn`**, así que añadir uno no
toca a los demás: el volador no comparte una línea de IA con el guardián.

1. Duplica `Guardian.tscn` y renómbralo.
2. En el `FSM`, quita los estados que no quieras y añade los tuyos (`Node` con un
   script que extienda `EnemyState`).
3. Cambia `Visual/Cuerpo` por tu modelo.
4. Ajusta los `@export`.

La estructura mínima que el código espera dentro del `.tscn`:

```
MiEnemigo (CharacterBody3D)  + src/enemies/Enemigo.gd
├── Collider   CollisionShape3D
├── Visual     Node3D          ← aquí va tu modelo
├── Salud      Node            + HealthComponent.gd
├── Poise      Node            + PoiseComponent.gd
├── Hitbox     Node3D          + Hitbox.gd
├── Hurtbox    Area3D          + Hurtbox.gd  (con su CollisionShape3D "Forma")
└── FSM        Node            + EnemyStateMachine.gd
    └── un Node por estado
```

> **Ojo con el frente (regla dura #21):** los enemigos miran a **−Z**. El jugador
> mira a **+Z** en su nodo `Visual`. Los dos convenios conviven a propósito; lo
> prohibido es un tercero. Orienta tu modelo a −Z en Blender y no lo toques desde
> código: para eso está `Enemigo.frente()`.

---

## 4. Un ataque

**Dónde:** `content/data/attacks/*.tres` — son `Resource` de tipo `AttackData`.

Crea uno nuevo en el editor (`New Resource → AttackData`) o duplica el más
parecido. Los tiempos van **en frames a 60 Hz**, no en segundos:

```
frames_windup       6     anticipación — el telegrafiado
frames_activo       4     ventana en la que hace daño
frames_recuperacion 12    resaca
```

Lo demás por grupos: `Daño` (daño, poise, empuje, lanzamiento, stagger),
`Hitbox` (alcance, radio, altura, arco en grados, máximo de objetivos),
`Movimiento` (avance, estocada, overshoot, frenazo, `movilidad`) y
`Feedback` (hitstop, shake).

Tres que no son obvios y valen mucho:

- **`golpes`** — impactos con **un solo gesto**. El giro del combo pesado son dos.
- **`boton_cadena`** — con qué botón encadena al siguiente. Es lo que hace que un
  botón siga significando lo mismo dentro y fuera de un combo.
- **`etiquetas`** — p. ej. `perforante`. Es lo que abre los puntos débiles.

Luego se lo asignas a quien lo use: un `@export var ataque_*` del jugador, el
`ataque` de un enemigo, o el `ataque` de la lanza.

---

## 5. Un punto débil (colosos)

**Dónde:** `src/colossus/WeakPoint.gd`. Se cuelga como hijo de una `Hurtbox`.

```
llave           = &"perforante"   ← la etiqueta del AttackData que lo abre
multiplicador   = 3.5             ← daño con la llave
sin_llave       = 0.15            ← daño sin ella. Casi nada, a propósito
golpes_para_abrir = 3
abre_remate     = true
```

Emite `punto_debil_golpeado(golpe, critico)` y `remate_disponible`. Es la interfaz
contra colosos: **el arma correcta importa**, y sin ella pegar ahí no sirve.

---

## 6. Agua

**Dónde:** `src/world/ZonaAgua.gd`, sobre un `Area3D`.

```gdscript
var agua := preload("res://src/world/ZonaAgua.gd").new()
agua.tamano = Vector3(24, 10, 24)
agua.palette = GameState.palette
add_child(agua)
agua.global_position = Vector3(0, -2, 0)
```

Es un **volumen que se atraviesa**, no un cuerpo sólido: lo que cambia es el
ESTADO del jugador, no la colisión. Nadar, bucear, el clavado y el combate
acuático salen solos. La superficie la dibuja `agua.gdshader` con los colores de
la Palette.

Para una captura estable: `agua.congelar_olas(3.7)`.

---

## 7. El mundo vivo — hierba, luciérnagas y bandada

**Dónde:** `src/world/Pasto.gd`, `Luciernagas.gd`, `Bandada.gd`.
**Banco:** `tools/Claro.tscn`. **En el juego:** `Gym._claro()`, en (9, 0, −13).

Los tres se crean por código, se añaden al árbol y se colocan. Nada más:

```gdscript
# HIERBA
var p := preload("res://src/world/Pasto.gd").new()
p.area = Vector2(20, 20)        # metros
p.densidad = 11.0               # briznas por m² — ES el número de coste
add_child(p)
p.global_position = Vector3(9, 0, -13)
# Sigue al jugador solo si lo hay: se engancha a EventBus.player_spawned.
# Si quieres que siga a otra cosa:  p.seguir(mi_nodo)

# LUCIÉRNAGAS
var l := preload("res://src/world/Luciernagas.gd").new()
l.cuantas = 140
l.area = Vector3(18, 4.5, 18)
l.parpadeo_segundos = 3.0
add_child(l)
l.global_position = Vector3(9, 0.6, -13)

# BANDADA
var b := preload("res://src/world/Bandada.gd").new()
b.criaturas = 14
b.radio = 9.5                   # radio del circuito
b.vuelta_segundos = 20.0        # cuánto tarda una vuelta
add_child(b)
b.global_position = Vector3(9, 10, -13)
```

**La hierba se siembra sola en su primer frame de física**, lanzando un rayo por
brizna para pegarla al suelo. Por eso necesita que haya suelo debajo, en la capa
`WORLD`. Si sale vacía, es que no lo había.

### 7.1 El viento

**No es un parámetro del parche: es un campo.** Vive en
`project.godot > [shader_globals]` y el shader lo evalúa desde `TIME` y la posición
de mundo, así que dos parches separados por medio mapa sacan el mismo valor sin
coordinarse. Para una racha o una tormenta:

```gdscript
RenderingServer.global_shader_parameter_set(&"viento_fuerza", 1.2)
RenderingServer.global_shader_parameter_set(&"viento_direccion", Vector4(1, 0, 0, 0))
```

Los cinco: `viento_direccion` (xz), `viento_fuerza`, `viento_escala` (bajo = ondas
anchas), `viento_velocidad`, `viento_temblor`.

### 7.2 El rastro

Doce huellas. La 0 es el jugador **en vivo**; las once restantes son por donde ha
pasado, y su frescura baja hasta cero en `rastro_duracion` segundos. Se ajusta con
`rastro_paso` (metros entre huella y huella), `rastro_radio`, `aplaste_empuje`,
`aplaste_hundir` y `aplaste_sombra`.

Para dejar una huella **sin jugador** —un enemigo pesado, un coloso, una captura—:

```gdscript
pasto.pisar(punto_en_mundo)
```

### 7.3 La escolta — que la bandada te rodee

Sale sola: `Bandada` adopta al jugador que anuncie `EventBus.player_spawned`, o se
le dice con `bandada.seguir(nodo)`. Te acercas al circuito y unas cuantas dejan de
volarlo y te rodean; te alejas y se sueltan y vuelven.

Los cuatro números que lo gobiernan:

| Export | Qué decide |
|---|---|
| `escolta_radio` | desde qué distancia **al territorio** se oye la llamada |
| `escolta_fraccion` | qué parte de la bandada es de las curiosas — o sea, **cuántas** vienen |
| `escolta_fuerza` | cuánto más fuerte tira el jugador que la propia bandada. **Por debajo de 1 no viene nadie**: el grupo gana siempre |
| `orbita_radio` · `orbita_alto` · `orbita_vueltas` | la forma del círculo que hacen |

Y una cosa que conviene entender antes de tocarlos: **quién viene no se elige.**
Cada criatura tiene dos rasgos fijos —su frecuencia propia y su curiosidad— y de
ellos sale todo. La curiosidad decide quién oye la llamada; la ecuación de
Kuramoto con forzamiento decide quién puede aguantar el ritmo:

    engancha  ⟺  |ωᵢ − Ω| ≤ Aᵢ

Como los dos rasgos son fijos, **vienen siempre las mismas**. Eso es deliberado y
es mejor que un sorteo: se aprende a reconocerlas.

### 7.4 Perturbar los enjambres

Pasar entre las luciérnagas o cruzar la bandada las desordena, y el grupo se
recompone solo. Es la interacción entera:

```gdscript
luciernagas.perturbar_cerca(jugador.global_position, 2.0)
bandada.perturbar_cerca(jugador.global_position, 6.0)
```

---

## 8. El enjambre de Kuramoto, para otra cosa

**Dónde:** `src/generative/Enjambre.gd`. **Banco:** `tools/Jardin.tscn`.

`Enjambre` **no dibuja ni suena**: lleva las fases y publica valores. La bandada,
las luciérnagas y las Criaturas de Tela son tres manifestaciones del mismo modelo.
Si quieres una cuarta —un altar que late, una manada, un coro—, **no escribas otro
Kuramoto**: usa este.

```gdscript
var e := Enjambre.new()
e.tuning = EnjambreTuning.new().a_ritmo(0.5)   # medio de rápido
e.tuning.agentes = 40
e.palette = GameState.palette
add_child(e)

# Y en tu _process, por agente:
var ciclo  := e.ciclo_de(i)     # 0..1, sube y baja una vez por vuelta
var fase   := e.fase_de(i)      # radianes — para trayectorias
var desvio := e.desvio_de(i)    # 0..1, cuánto se aparta del grupo
var r      := e.orden           # 0 disperso · 1 al unísono
```

Que **todo cuelgue del mismo número** es lo que hace que se lea como una cosa viva
y no como cinco efectos sueltos. Del ciclo salen color, opacidad, escala,
recorrido y pitch; del desvío, la desaturación y el volumen.

**Sonido:** el enjambre emite `ciclo(pitches, amplitudes, orden)` cada frame de
física y ahí acaba su responsabilidad. No hay un solo `AudioStreamPlayer` — quien
quiera hacerlos sonar, los lee.

**`a_ritmo(f)`** te da una copia del modelo a otra velocidad. Escala `ω` y `K` por
`f` y `k_subida`/`k_bajada` por `f²`, porque son 1/s². No lo hagas a mano.

### 8.1 El marcapasos — que algo de fuera tire del enjambre

Es Kuramoto con forzamiento externo, y sirve para cualquier cosa que "llame" a un
enjambre: el jugador, un altar, una hoguera, un coloso despertando.

```gdscript
# Quién marca el paso, y a qué ritmo. Ω decide QUIÉN puede seguirle.
enjambre.marcapasos_omega = tuning.frecuencia_base

# Y cada frame, a quién alcanza la llamada y con qué fuerza:
for i in n:
    enjambre.pedir_tiron(i, fuerza)      # caduca cada frame, como pedir_postura()

# Luego se lee quién ha enganchado:
var e := enjambre.enganche_de(i)         # 0..1, suavizado
var cuantos := enjambre.enganchados()
```

Tres cosas que hay que saber o no funciona:

1. **`pedir_tiron` caduca cada frame.** Si dejas de pedirlo, el enganche decae solo
   y el enjambre vuelve a lo suyo. Un tirón que se queda puesto es un altar que
   sigue llamando después de apagarse.
2. **La fuerza se mide contra `k_max`**, que es lo que tira el propio grupo de los
   suyos. Por debajo de eso no despegas a nadie de la formación.
3. **Quien engancha deja de contar para el grupo** (el orden pesa por
   `1 − enganche`). Sin eso, el enjambre persigue a sus propias escoltas y en
   cuanto una engancha se van todas.

---

### 8.2 La estación de jam — el enjambre que SUENA

Ocho puestos en corro tocando juntos, estilo *Sky*. Es la tercera manifestación
del mismo Kuramoto (bandada, luciérnagas, esto) y la primera que usa el `pitch` y
la `amplitud` que `Enjambre` llevaba dos parches publicando sin que nadie
escuchara.

**Ponerla en una escena** — dos líneas, como todo lo demás:

```gdscript
var jam := EstacionJam.new()
add_child(jam)
jam.global_position = Vector3(-16, 0, 14)
jam.seguir(jugador)          # opcional: sin esto adopta al del EventBus
```

Ya está: se monta el corro, se sintetiza el sonido y empieza a tocar. **No lleva
colisión** —ni la tarima, ni los taburetes, ni los músicos— a propósito: es
escenografía con audio, y un obstáculo en medio del Gym rompería las medidas de
movimiento sin avisar.

**Qué se oye, y por qué está bien sin tocar nada:**

| | |
|---|---|
| `compas_segundos` | Lo único que se juzga de oído. 1.7 s por vuelta de cada músico. |
| `golpes_por_compas` | A 1 suena a campanas; a 2 empieza a sonar a banda. |
| `escala` | **Pentatónica mayor.** Es la regla entera: sin segundas menores ni tritonos, ocho voces sin director no pueden chocar. Cámbiala y pierdes esa garantía. |
| `registro_grados` | Cuántos GRADOS separan el puesto grave del agudo. **En grados, no en semitonos** — ver abajo. |
| `fuerza_llamada` | La `A` de `\|ωᵢ − Ω\| ≤ A`. Tiene que ser comparable a la dispersión de frecuencias o te siguen los ocho. |
| `fraccion_curiosa` | Qué mitad del corro te presta atención. |

**Dos trampas que ya costaron sangre aquí:**

1. **El registro va en grados de la escala, no en semitonos.** Repartir 24
   semitonos entre ocho puestos da saltos de 3.43; redondeando salen notas que no
   están en la pentatónica, y sumarles un grado bueno da una nota mala. Medido:
   **143 de 480 combinaciones caían fuera**. Contando en grados no hay forma de
   salirse — la escala pasa de ser una intención a ser una invariante.
2. **Si la llamada es fuerte, te siguen todos.** Exactamente el mismo fallo que
   tuvo la escolta de la bandada. Aquí hicieron falta las dos cosas: bajar `A`
   hasta el orden de la dispersión, y la `curiosidad` como segundo rasgo fijo,
   porque el acoplamiento del grupo arrastra detrás a quien por sí solo no podría
   seguirte.

**La hoja de notas** se abre con **E** estando al lado del corro. Son dos rejillas
y hacen cosas distintas:

| | |
|---|---|
| **TECLADO** 5×3 | Suena *ahora*. Es la audición: pruebas una nota y ya, no escribe nada, así que puedes trastear encima de lo que está sonando. |
| **HOJA** 8 × 16 | Se escribe. **Una columna por músico, una fila por paso**: marcar una celda es decirle a *ese* de los ocho que ataque en *ese* momento. |

Y el cabezal **no lo lleva un temporizador de la interfaz: lo lleva la fase media
del enjambre**. Eso es lo que fusiona las dos mitades en vez de ponerlas una al
lado de la otra — cuanto más juntos van los ocho, mejor tocan lo que escribiste;
desordenados, el compás sale torcido. Con la hoja vacía vuelven a improvisar
solos: no hay modo que elegir, lo dice el contenido.

Desde código:

```gdscript
jam.alternar_celda(paso, asiento)   # enciende o apaga
jam.pulsar_tecla(t)                 # audición, 0..14
jam.borrar_hoja()                   # todos a improvisar otra vez
jam.panel.abrir()                   # sin acercarse
```

**El rombo y el círculo no son decoración**: el rombo marca los grados *pilares*
de la pentatónica —la tónica y la quinta— y el círculo los demás. Sin eso son
quince cuadrados iguales y no hay dónde apoyar la vista.

**Cada celda dice su nota**, en solfeo y con octava (SOL3, LA4), y la hoja lleva
la nota *raíz* de cada músico como cabecera de columna. Y hay dos mandos:

| | |
|---|---|
| **COMPÁS** −/+ | El único número de la estación que se juzga de oído. Reescala el modelo entero en vivo (`cambiar_compas`), sin devolver el corro al caos. |
| **TONO** ‹/› | Recorre los siete naturales. **Cambiar de tono no estropea lo escrito**: la hoja dice *quién* toca y *cuándo*, no en qué altura. |

**Y mientras la hoja está abierta, no se juega.** Ni mover, ni atacar, ni girar la
cámara. No es una pausa —el mundo sigue corriendo, que para eso se abre— sino un
corte de input en el `InputBuffer`; ver la regla dura #26. Si montas otra interfaz
modal, emite `EventBus.interfaz_modal` y ya está: no toques al jugador.

**Los ocho se distinguen entre sí** por dos canales que no mienten: el **tamaño**
sale de su registro (cuerpo grande, sonido grave) y el **color** de su grado en la
escala, que es el mismo número que decide si la rejilla lo pinta rombo o círculo.
El brillo queda libre para el golpe. Si cambias `registro_grados`, las tres cosas
se mueven juntas — salen todas de `grado_de()`.

**Colgar algo de cada golpe** —una luz, una vibración, una partícula— sin tocar el
sintetizador:

```gdscript
jam.golpe.connect(func(puesto: int, hz: float) -> void:
    ...)
```

Es la misma idea que `Enjambre.ciclo`: el sistema publica hechos y quien quiera
que los use.

---

## 9. Con tus modelos de Blender

`06_INTEGRACION_3D.md` cubre el pipeline: formato, ajustes del exportador, escala,
AnimationTree, IK, navmesh, materiales. **Léelo antes.** Lo que sigue es solo el
mapa de *dónde encaja cada modelo* en lo que ya está construido.

| Lo que modelas | Dónde entra | Convenio que tiene que respetar |
|---|---|---|
| **Jugador** | nodo `Visual` de `Player.tscn` (hoy una cápsula) | mira a **+Z**. Origen en los pies |
| **Enemigo** | `Visual/Cuerpo` de su `.tscn` | mira a **−Z**. Origen en los pies |
| **Lanza / daga** | `Visual/Asta` y `Visual/Punta` de `Spear.tscn` | ver el aviso de abajo |
| **Brizna de hierba** | `Pasto.malla` (`@export var malla: Mesh`) | `UV.y = 1` en la base, `0` en la punta. Origen en la base |
| **Criatura voladora** | `Bandada.malla` (`@export var malla: Mesh`) | tumbada hacia **−Z**. `UV.y = 0` cabeza, `1` cola |
| **Criatura de tela** | `Visual` de `src/generative/CriaturaTela.tscn` | ninguno — **pero no la rotes nunca** |
| **Músico de la jam** | `Musico0..7` de `EstacionJam` (hoy cápsulas) | sentado, origen en la base del taburete. **No lo rotes**: la estación solo mueve posición, escala y color |
| **Luciérnaga** | no lo modeles | es un billboard de dos gradientes. Un modelo se vería peor y costaría más |
| **Escenario** | ver `06 §6` | tres condiciones, y son las únicas |

**Aviso sobre la lanza:** su malla se construye por código en
`Spear._preparar_visual()`, así que un modelo puesto en el editor se pierde al
arrancar. Para meter el tuyo, cambia esa función (o bórrale las dos líneas que
asignan `mesh`). Es la única de la lista que todavía no tiene punto de entrada
limpio.

**Aviso sobre las UV de la hierba:** no es un capricho. De `UV.y` salen *a la vez*
el gradiente de color y el factor de doblado, y con la convención al revés la
hierba se dobla desde la punta y crece hacia abajo. Si tu brizna sale rara, mira
las UV antes que el shader.

### 9.1 Los colores, siempre desde la Palette

Regla dura #9: **ningún hex escrito a mano** fuera de `Palette.gd`.

```gdscript
var m := StandardMaterial3D.new()
m.albedo_color = GameState.palette.musgo_medio
```

Y en un shader, un `uniform vec4 ... : source_color` alimentado desde código:

```gdscript
mat.set_shader_parameter(&"color_base", GameState.palette.musgo_medio)
```

Los nombres están en `src/art/palette/Palette.gd`. Hay un validador:
`palette.validar()` devuelve las infracciones del reparto de croma, y
`tools/medir_paleta.gd` imprime croma y luminancia reales. **Mide antes de decidir
que un color queda bien.**

---

## 10. Depurar lo que hagas

| Tecla | Qué |
|---|---|
| **F3** | panel de texto: estado, velocidad, stamina, sensores |
| **F7** | gizmos 3D en el mundo |
| **F5** | recargar `PlayerTuning` en caliente |
| **F6** | recargar `Palette` en caliente |
| **F4** | respawnear los guardianes de la Arena |
| **Escape** | menú de controles (lee el InputMap en vivo: no puede mentir) |

Para dibujar los tuyos, desde cualquier sitio:

```gdscript
DebugDraw.esfera(punto, 0.3, GameState.palette.oro_palido)
DebugDraw.linea(desde, hasta, GameState.palette.carmesi)
DebugDraw.cono(origen, direccion, 45.0, 12.0, color)
DebugDraw.rayo(origen, direccion, largo, color)
DebugDraw.caja(centro, tam, color)
DebugDraw.punto(centro, 0.1, color)
```

**Cuesta cero apagado**: toda entrada sale por `if not activo: return`. Puedes
dejarlos puestos.

Y una línea de texto en el panel:

```gdscript
DebugOverlay.set_line("mi_sistema", "lo que sea %.2f" % valor)
```

---

## 11. Probar lo que hagas

Tres tests, y **ninguno sustituye a otro**:

```bash
godot --headless --path . tools/TestFase1.tscn        # la FSM llega a los estados
godot --headless --path . tools/TestFase2.tscn        # combate, agua, paredes
godot --headless --path . tools/TestLanza.tscn        # la lanza y la cuerda
godot --headless --path . tools/TestEnemigos.tscn     # los enemigos
godot --headless --path . tools/TestMundoVivo.tscn    # hierba, luciérnagas, bandada
godot --headless --path . tools/TestEnjambre.tscn     # el modelo generativo
godot --headless --path . tools/TestMenu.tscn         # el menú no miente
godot --path . --resolution 960x540 tools/TestVisual.tscn   # 14 capturas. NECESITA GPU
```

El funcional comprueba que se **llega** a un estado; el de medición cronometra
cómo se **siente**; el visual comprueba que se **ve** bien estando ahí. Media
docena de bugs de este proyecto —el cuerpo torcido al salir del agua, la cápsula
partida junto a una rampa— pasaron los funcionales sin despeinarse.

**El screenshot test se corre siempre**, también cuando el cambio "no toca lo
visual". Y **no se hace trampa**: regenerar una referencia con `-- actualizar` para
que pase convierte el test en un sello de goma. Solo se regenera cuando el cambio
visual era **el que se buscaba**, y solo después de mirar el mapa de diff en
`user://visual/` y comprobar que lo que cambió es lo que tenía que cambiar.

Si el diff enseña algo que no esperabas, **eso no es una baseline vieja: es un
bug.** Ha pasado tres veces y las tres había un bug.

---

## 12. Las trampas que ya nos han costado

Las que muerden **usando** los sistemas, no desarrollándolos. Las reglas completas
están en `CLAUDE.md`.

1. **Exports a nodos siempre `NodePath` + `get_node_or_null()`.** Un
   `@export var x: Node3D` no se resuelve al instanciar la escena y te deja la
   referencia en `null` sin avisar.
2. **Ningún número mágico en `.gd`.** Si lo vas a tocar para que "se sienta bien",
   va en un `.tres` o en un `@export`.
3. **Todo teletransporte llama a `reset_physics_interpolation()`.** Sin eso, un
   respawn se dibuja como un barrido cruzando el mapa entero en un frame.
4. **Lo que muevas por código en `_process` va fuera de la interpolación**
   (`physics_interpolation_mode = OFF`). Dentro se interpola dos veces.
5. **Al servidor de render no se le pregunta el estado del juego.**
   `MultiMesh.get_instance_transform()` devuelve la identidad en headless: lo que
   le mandes, guárdalo también de tu lado.
6. **Un valor absoluto no distingue "va hacia ti" de "se va de ti".** Cuando midas
   un SENTIDO, mide con signo.
7. **Un test que fuerza el estado no prueba que se pueda LLEGAR a él.** Prueba los
   verbos por su camino de entrada real: la tecla y el `InputBuffer`.
8. **Un test no puede depender de la IA.** Si una comprobación necesita un golpe
   enemigo, entrégalo a mano con `recibir_golpe()`.

---

## Apéndice — dónde está cada cosa

```
src/
├── player/      jugador: controlador, FSM (27 estados), sensores, motor, tuning
├── camera/      CameraRig propio (el de Phantom está escrito y sin cablear)
├── combat/      AttackData, Hitbox, Hurtbox, salud, poise, targeting, FX
├── enemies/     Enemigo + EnemyMotor + FSM propia · 4 arquetipos
├── weapons/     lanza (FSM propia), daga/anclaje, cordón, tuning
├── colossus/    WeakPoint — la interfaz contra colosos
├── world/       agua · hierba · luciérnagas · bandada
├── generative/  el enjambre de Kuramoto y las Criaturas de Tela
├── art/         Palette, WorldMood, shaders
├── core/        autoloads: EventBus, GameState, HitstopManager, Debug*, Layers
├── input/       InputBuffer y InputActions
└── ui/          menú de controles

content/
├── data/        default_tuning.tres · default_palette.tres · attacks/*.tres
└── levels/      Main.tscn

tools/
├── Gym.gd            sala de pruebas del movimiento (+ EL CLARO)
├── Arena.gd          patio de combate
├── Circuito.gd       carrera de obstáculos con cronómetro
├── Jardin.tscn       banco del sistema generativo
├── Claro.tscn        banco del mundo vivo
├── Test*.tscn        los tests
└── baseline/         las 14 referencias del screenshot test
```
