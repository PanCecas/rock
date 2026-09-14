class_name Proyectil
extends Node3D
## Disparo del volador. Viaja recto y muere al tocar algo o al caducar.
##
## Usa la MISMA `Hitbox` por consulta de forma que el resto del combate, no un
## `Area3D`: un Area llega con un frame de retraso, y un proyectil que se mueve a
## 22 m/s recorre 37 cm en ese frame. A esa velocidad el retraso se ve.
##
## Golpea una sola vez y desaparece. Un proyectil que atraviesa y sigue pegando
## sería otra mecánica —una lanza, un rayo— y merecería su propio script.

@export var velocidad: float = 22.0
@export var vida: float = 4.0
@export var radio_visual: float = 0.18
@export var palette: Palette

@onready var hitbox: Hitbox = $Hitbox

var _dir: Vector3 = Vector3.FORWARD
var _datos: AttackData
var _t: float = 0.0


func _ready() -> void:
	if palette == null:
		palette = GameState.palette
	_pintar()


## Lo llama quien dispara. `dueno` decide el equipo de la hitbox: sin eso el
## proyectil heriría a quien lo lanzó.
func lanzar(direccion: Vector3, vel: float, datos: AttackData, dueno: Node3D) -> void:
	_dir = direccion.normalized()
	velocidad = vel
	_datos = datos
	if hitbox != null:
		hitbox.dueno = self
		hitbox.equipo = 1
		hitbox.nuevo_swing()
	if dueno != null:
		look_at(global_position + _dir, Vector3.UP)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= vida:
		queue_free()
		return

	global_position += _dir * velocidad * delta

	if _datos != null and hitbox != null and hitbox.golpear(_datos, _dir) > 0:
		CombatFX.impacto(get_parent(), global_position, _color(), 0.8)
		queue_free()
		return

	# Contra geometría: un rayo del tramo recorrido ESTE frame, no una consulta
	# puntual. A 22 m/s una consulta por frame se salta paredes finas enteras.
	var espacio := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position - _dir * velocidad * delta, global_position, Layers.WORLD)
	if not espacio.intersect_ray(q).is_empty():
		CombatFX.impacto(get_parent(), global_position, _color(), 0.5)
		queue_free()


func _pintar() -> void:
	var malla := get_node_or_null("Malla") as MeshInstance3D
	if malla == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color()
	mat.emission_enabled = true
	mat.emission = _color()
	mat.emission_energy_multiplier = 1.6
	malla.material_override = mat


func _color() -> Color:
	if palette == null:
		return Color.WHITE
	var v: Variant = palette.get(&"carmesi")
	return v if v is Color else Color.WHITE
