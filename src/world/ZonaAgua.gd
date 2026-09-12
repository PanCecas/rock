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
	# SUBDIVIDIDO: el shader desplaza el vertice, y sin vertices no hay nada que
	# desplazar. Nueve por lado es barato y ya deja que el borde ondule.
	plano.subdivide_width = 9
	plano.subdivide_depth = 9
	plano.material = _material_agua()

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


## El material de la superficie: `agua.gdshader` con los colores de la Palette.
##
## Los tres colores entran desde aqui y no estan escritos en el shader, por la
## regla dura #9. El shader trae valores por defecto solo para que se pueda abrir
## y ver algo en el editor sin una escena montada.
func _material_agua() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://src/art/shaders/agua.gdshader")
	m.set_shader_parameter("color_poco", palette.cian_cielo)
	m.set_shader_parameter("color_hondo", palette.cobalto)
	m.set_shader_parameter("color_espuma", palette.blanco_tiza)
	return m


## Congela las olas en una fase fija, o las suelta con un valor negativo.
##
## Existe para el screenshot test y vive AQUI y no en el test porque el material
## es de esta clase: que una herramienta externa vaya rebuscando el `MeshInstance3D`
## y el `PlaneMesh` para llegar al shader es exactamente como se rompe un test la
## proxima vez que cambie la estructura interna.
##
## Es el mismo gancho que `Cordon.asentar()`, y por la misma razon: una superficie
## animada nunca puede ser una referencia estable si cada pasada la fotografia en
## una fase distinta.
func congelar_olas(t: float) -> void:
	if _malla == null or not is_instance_valid(_malla):
		return
	var m := _malla.mesh as PlaneMesh
	if m == null:
		return
	var mat := m.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("tiempo_fijo", t)
