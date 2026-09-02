class_name Spear
extends Node3D
## LA LANZA. Cuerpo y orquestador; la lógica vive en su máquina de estados.
##
## Mismo patrón que `Enemigo` + `EnemyStateMachine`, y por la misma razón: seis
## comportamientos con reglas distintas metidos en un `match` dentro de
## `_physics_process` es exactamente el archivo de 372 líneas que hubo que
## extraer en la 3.03. Aquí se empieza ya extraído.
##
##   Holstered -> Wielded -> InFlight -> Embedded | Grounded -> Returning
##
## `docs/03_ARQUITECTURA_MECANICAS.md §4` tiene el diseño completo.
##
## **Una sola lanza.** No es una limitación técnica: la escasez es lo que hace
## que decidir dónde la clavas sea una decisión y no un trámite.

signal clavada(punto: Vector3, normal: Vector3)
signal recuperada
signal estado_cambiado(nombre: StringName)

@export var tuning: SpearTuning
@export var ataque: AttackData
@export var palette: Palette
## Quién la lanzó. Decide el equipo de la hitbox: sin esto se hiere a sí mismo.
@export var dueno_path: NodePath

## Superficies en las que se clava.
##
## Incluye el mundo sólido y NO solo la capa `SPEAR_STICK`. Obligar a etiquetar
## cada muro a mano es una tarea que se olvida, y el fallo resultante —"la lanza
## no se clava aquí y no sé por qué"— es invisible. `SPEAR_STICK` queda para lo
## que es clavable SIN ser mundo sólido.
@export_flags_3d_physics var capas_clavado: int = Layers.WORLD | Layers.COLOSSUS_SURFACE | Layers.SPEAR_STICK

@onready var fsm: SpearStateMachine = $FSM
@onready var hitbox: Hitbox = $Hitbox
@onready var visual: Node3D = $Visual
@onready var plataforma: StaticBody3D = $Plataforma
@onready var cordon: Cordon = $Cordon

var dueno: Node3D = null
## Dirección de vuelo. La escribe `InFlight`.
var direccion: Vector3 = Vector3.FORWARD
## Punto y normal del clavado. Los escribe `Embedded`.
var punto_clavado: Vector3 = Vector3.ZERO
var normal_clavado: Vector3 = Vector3.UP
## EN QUE se clavo. Lo necesita la Fase 4 —una lanza clavada en un coloso es un
## asidero que se mueve con el— y de paso hace depurable el vuelo.
var cuerpo_clavado: Node3D = null

var _mat: StandardMaterial3D


func _ready() -> void:
	if tuning == null:
		tuning = SpearTuning.new()
	if palette == null:
		palette = GameState.palette
	dueno = get_node_or_null(dueno_path) as Node3D
	_preparar_visual()
	if cordon != null:
		cordon.palette = palette
	soltar_plataforma()
	if hitbox != null:
		hitbox.dueno = self
		hitbox.equipo = 0
	fsm.configurar(self)


func _physics_process(delta: float) -> void:
	if HitstopManager.global_activo():
		return
	fsm.physics_update(delta)


## El cordon se tiende en `_process`, a ritmo de RENDER, y no con la fisica.
##
## Sus dos extremos cuelgan de cosas que la interpolacion de fisica dibuja suaves
## —la mano del jugador y el asta—. Tendiendolo a 60 Hz, la cuerda daba saltos
## contra un personaje que iba fluido: el defecto se veia justo donde mas duele,
## enganchado y a toda velocidad.
func _process(_delta: float) -> void:
	_tender_cordon()


## El cordon se tiende desde la MANO, no desde el asta: la lanza clavada esta a
## treinta metros y lo que cuelga del jugador es la cuerda, no el arma.
##
## Solo existe cuando la lanza esta fuera de la mano. Guardada o empunada no
## cuelga de nada, y dibujar una cuerda de cero metros da una mancha en pantalla.
func _tender_cordon() -> void:
	if cordon == null:
		return
	var fuera := not en_mano() and fsm.nombre_actual() != &"Holstered"
	cordon.tender(_mano_dibujada(), get_global_transform_interpolated().origin,
		fuera and dueno != null)


## La mano TAL Y COMO SE DIBUJA este frame, no en el ultimo tick de fisica.
##
## Misma razon que en `CameraRig._punto_objetivo()`: con la interpolacion activada
## `global_position` es un valor escalonado a 60 Hz y lo que se ve del personaje
## va a ritmo de render. La version de fisica —`punto_de_mano()`— se queda como
## esta porque la usan `Wielded` y `Returning`, que corren en fisica y tienen que
## hablar en la misma moneda que el resto del movimiento.
func _mano_dibujada() -> Vector3:
	if dueno == null or not is_instance_valid(dueno):
		return global_position
	var t := dueno.get_global_transform_interpolated()
	return t.origin + Vector3.UP * 0.95 + t.basis.x * 0.45


# --- Servicios para los estados -----------------------------------------------

## ¿Está disponible para lanzarla?
func en_mano() -> bool:
	return fsm.nombre_actual() == &"Wielded"


## ¿Está la lanza AHÍ FUERA, en un sitio del mundo al que se pueda ir?
##
## **Es la pregunta que hay que hacer antes de tirar de la cuerda**, y no
## `not en_mano()`. `en_mano()` solo es cierto en `Wielded`, así que con la lanza
## GUARDADA —que es como empieza la partida— su negación daba `true` y la cuerda
## se enganchaba a una lanza invisible.
##
## Y `Holstered` no actualiza su posición: la lanza guardada se queda con la
## transformada de la última vez, que al arrancar es el punto de spawn. Con eso,
## pulsar Z en lo alto del coloso te lanzaba de vuelta al centro del mapa. El
## usuario lo reportó como *"un bug raro al subirse a la cima del gigante, y con
## la Z sin tener equipada la lanza"*: son el mismo fallo visto desde arriba, que
## es donde el viaje se nota.
func esta_fuera() -> bool:
	var n := fsm.nombre_actual()
	return n == &"InFlight" or n == &"Embedded" or n == &"Grounded"


func clavada_en_algo() -> bool:
	return fsm.nombre_actual() == &"Embedded"


## Lanza la lanza. Lo llama el jugador; el estado hace el resto.
func lanzar(desde: Vector3, hacia: Vector3) -> bool:
	# Vale tambien GUARDADA: la desenfunda y la tira en un solo gesto. Obligar a
	# sacarla primero convertiria el lanzamiento en dos pulsaciones, y de eso ya
	# se quejo el usuario con razon.
	var n := fsm.nombre_actual()
	if n != &"Wielded" and n != &"Holstered":
		return false
	global_position = desde
	# Un teletransporte no se interpola: sin esto la lanza se dibuja barriendo
	# desde donde estuviera guardada hasta la mano en un solo frame.
	reset_physics_interpolation()
	fsm.cambiar(&"InFlight", {"direccion": hacia})
	return true


## Guarda o saca la lanza. ES el cambio de moveset: empunada manda su set de
## ataques, guardada mandan los de siempre.
##
## Gasta una tecla, si —`swap_weapon`, que ya existia y estaba sin usar— pero es
## de otra categoria que el resto: tirar y engancharse son cosas que haces
## CONSTANTEMENTE; decidir con que arma peleas es una decision que tomas y
## mantienes. Y el caso comun —tirarla— no la necesita: el boton de la lanza la
## desenfunda solo.
func alternar_empunada() -> bool:
	var n := fsm.nombre_actual()
	if n == &"Wielded":
		fsm.cambiar(&"Holstered")
		return true
	if n == &"Holstered":
		fsm.cambiar(&"Wielded")
		return true
	return false


## Pide que vuelva. Vale desde clavada y desde el suelo.
func recuperar() -> bool:
	var actual := fsm.nombre_actual()
	if actual != &"Embedded" and actual != &"Grounded" and actual != &"InFlight":
		return false
	fsm.cambiar(&"Returning")
	return true


## Enciende la plataforma sobre la que el jugador puede quedarse DE PIE.
##
## Es la mitad del valor de la mecánica, no un extra: tirarla a lo alto, subir y
## pararse encima es el bucle de progresión vertical del juego (`docs/03 §4.3`).
## Va en `WORLD` porque el jugador ya pisa esa capa; y en `CLIMBABLE` porque el
## `WallSensor` busca ahí lo que se puede agarrar a mano.
func poner_plataforma() -> void:
	if plataforma == null:
		return
	plataforma.process_mode = Node.PROCESS_MODE_INHERIT
	plataforma.collision_layer = Layers.WORLD | Layers.CLIMBABLE
	var forma := plataforma.get_node_or_null("Forma") as CollisionShape3D
	if forma != null:
		forma.disabled = false


## Deja la plataforma en un punto del mundo, independiente de donde este el asta.
func colocar_plataforma(punto: Vector3) -> void:
	if plataforma != null:
		plataforma.global_position = punto


func soltar_plataforma() -> void:
	if plataforma == null:
		return
	plataforma.collision_layer = 0
	var forma := plataforma.get_node_or_null("Forma") as CollisionShape3D
	if forma != null:
		forma.disabled = true


## Dónde queda la lanza cuando la llevas encima. Lo usan `Wielded` y `Returning`
## —una para seguirte y otra para saber a dónde volver— y por eso vive aquí: dos
## copias de este desfase se desincronizan en cuanto exista el rig y la mano deje
## de ser un número.
func punto_de_mano() -> Vector3:
	if dueno == null:
		return global_position
	return dueno.global_position + Vector3.UP * 0.95 + dueno.global_basis.x * 0.45


## Orienta el asta a lo largo de una dirección. La lanza apunta a donde va.
func apuntar_a(dir: Vector3) -> void:
	if dir.is_zero_approx() or visual == null:
		return
	var arriba := Vector3.UP
	if absf(dir.normalized().dot(arriba)) > 0.99:
		arriba = Vector3.FORWARD
	visual.global_basis = Basis.looking_at(dir.normalized(), arriba)


func color_de(nombre: StringName) -> Color:
	if palette == null:
		return Color.WHITE
	var v: Variant = palette.get(nombre)
	return v if v is Color else Color.WHITE


func _preparar_visual() -> void:
	var malla := get_node_or_null("Visual/Asta") as MeshInstance3D
	if malla == null:
		return
	var caja := BoxMesh.new()
	caja.size = Vector3(tuning.grosor, tuning.grosor, tuning.largo)
	malla.mesh = caja
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color_de(&"caliza_sol")
	_mat.roughness = 0.55
	malla.material_override = _mat

	var punta := get_node_or_null("Visual/Punta") as MeshInstance3D
	if punta != null:
		var p := BoxMesh.new()
		p.size = Vector3(tuning.grosor * 1.6, tuning.grosor * 1.6, tuning.largo * 0.18)
		punta.mesh = p
		punta.position = Vector3(0, 0, -tuning.largo * 0.5)
		var mp := StandardMaterial3D.new()
		mp.albedo_color = color_de(&"oro_palido")
		mp.metallic = 0.6
		mp.roughness = 0.3
		punta.material_override = mp

	# La plataforma se dimensiona desde el tuning, no desde la escena: es un
	# número de diseño y tiene que poder tocarse sin abrir el editor.
	var forma := get_node_or_null("Plataforma/Forma") as CollisionShape3D
	if forma != null and forma.shape is BoxShape3D:
		(forma.shape as BoxShape3D).size = Vector3(
			tuning.plataforma_lado, tuning.plataforma_grosor, tuning.plataforma_lado)


func debug_line() -> String:
	return "%s%s" % [fsm.nombre_actual(), "  [clavada]" if clavada_en_algo() else ""]


## ¿Está clavada en CARNE agarrable? Espejo de `Anclaje.en_carne()`.
##
## La lanza atraviesa a casi todo, pero se queda en los bichos pequeños: son los
## que se pueden zarandear, y ese es el papel que iba a tener la segunda daga.
func en_carne() -> bool:
	if not clavada_en_algo() or cuerpo_clavado == null:
		return false
	if not is_instance_valid(cuerpo_clavado) or not (cuerpo_clavado is Enemigo):
		return false
	var e := cuerpo_clavado as Enemigo
	return e.agarrable and e.esta_vivo()


func presa() -> Enemigo:
	return cuerpo_clavado as Enemigo if en_carne() else null
