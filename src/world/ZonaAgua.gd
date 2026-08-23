@tool
class_name ZonaAgua
extends Area3D
## Volumen de agua. Es un Area3D y no un cuerpo sólido: se atraviesa, y lo que
## cambia es el ESTADO del jugador, no la colisión.
##
## Expone dos cosas que el jugador necesita cada frame: dónde está la superficie
## y cuánto se está hundiendo. Todo lo demás (flotar, nadar, bucear) lo decide la
## FSM, porque es una decisión de game feel y no de física.

## Altura de la superficie en espacio de mundo. Se deriva de la forma para que
## mover el agua en el editor no obligue a tocar ningún número.
var nivel: float = 0.0

@export var tamano: Vector3 = Vector3(24.0, 10.0, 24.0):
	set(v):
		tamano = v
		if is_inside_tree():
			_reconstruir()

@export var palette: Palette:
	set(v):
		palette = v
		if is_inside_tree():
			_reconstruir()

var _malla: MeshInstance3D
var _forma: CollisionShape3D


func _ready() -> void:
	if not Engine.is_editor_hint() and palette == null:
		palette = GameState.palette
	add_to_group(&"agua")
	collision_layer = Layers.AGUA
	collision_mask = 0
	monitorable = true
	monitoring = false
	_reconstruir()


func _reconstruir() -> void:
	for hijo in [_malla, _forma]:
		if hijo != null and is_instance_valid(hijo):
			hijo.queue_free()

	var caja := BoxShape3D.new()
	caja.size = tamano
	_forma = CollisionShape3D.new()
	_forma.shape = caja
	add_child(_forma)

	nivel = global_position.y + tamano.y * 0.5

	if palette == null:
		return

	# Superficie translúcida: solo la cara de arriba. El volumen entero teñido
	# tapa lo que hay dentro, y bajo el agua hay que poder ver.
	var plano := PlaneMesh.new()
	plano.size = Vector2(tamano.x, tamano.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(palette.cian_cielo.r, palette.cian_cielo.g, palette.cian_cielo.b, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.15
	mat.metallic = 0.2
	plano.material = mat

	_malla = MeshInstance3D.new()
	_malla.mesh = plano
	_malla.position.y = tamano.y * 0.5
	_malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_malla)


## Altura de la superficie, en mundo. La recalcula por si el agua se ha movido.
func superficie() -> float:
	return global_position.y + tamano.y * 0.5


## Profundidad a la que está un punto. Negativa = por encima del agua.
func profundidad(punto: Vector3) -> float:
	return superficie() - punto.y
