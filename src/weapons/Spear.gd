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

var dueno: Node3D = null
## Dirección de vuelo. La escribe `InFlight`.
var direccion: Vector3 = Vector3.FORWARD
## Punto y normal del clavado. Los escribe `Embedded`.
var punto_clavado: Vector3 = Vector3.ZERO
var normal_clavado: Vector3 = Vector3.UP

var _mat: StandardMaterial3D


func _ready() -> void:
	if tuning == null:
		tuning = SpearTuning.new()
	if palette == null:
		palette = GameState.palette
	dueno = get_node_or_null(dueno_path) as Node3D
	_preparar_visual()
	soltar_plataforma()
	if hitbox != null:
		hitbox.dueno = self
		hitbox.equipo = 0
	fsm.configurar(self)


func _physics_process(delta: float) -> void:
	if HitstopManager.global_activo():
		return
	fsm.physics_update(delta)


# --- Servicios para los estados -----------------------------------------------

## ¿Está disponible para lanzarla?
func en_mano() -> bool:
	return fsm.nombre_actual() == &"Wielded"


func clavada_en_algo() -> bool:
	return fsm.nombre_actual() == &"Embedded"


## Lanza la lanza. Lo llama el jugador; el estado hace el resto.
func lanzar(desde: Vector3, hacia: Vector3) -> bool:
	if not en_mano():
		return false
	global_position = desde
	fsm.cambiar(&"InFlight", {"direccion": hacia})
	return true


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
