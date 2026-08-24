class_name Hitbox
extends Node3D
## Caja que hace daño. NO es un Area3D: hace una consulta de forma en el momento
## exacto en que se abre la ventana activa.
##
## Un Area3D se actualiza en el tick de física y llega con un frame de retraso, que
## en un combate de ventanas de 4 frames es un 25% de error. La consulta directa
## golpea en el frame que dice el AttackData, ni antes ni después.

signal impacto(golpe: Golpe)
signal fallo()

## Para no golpearse a sí mismo ni a los aliados. 0 = jugador, 1 = enemigos.
@export var equipo: int = 0
@export var dueno_path: NodePath = ^".."

var dueno: Node3D = null
## Objetivos ya tocados por el swing actual: un golpe no toca dos veces.
var _tocados: Array[int] = []


func _ready() -> void:
	dueno = get_node_or_null(dueno_path) as Node3D


## Abre un swing nuevo. Llamar al entrar en la ventana activa.
func nuevo_swing() -> void:
	_tocados.clear()


## Ejecuta la consulta. Devuelve cuántos objetivos NUEVOS ha tocado.
func golpear(datos: AttackData, adelante: Vector3) -> int:
	if dueno == null or datos == null:
		return 0

	var espacio := dueno.get_world_3d().direct_space_state
	var dir := Vector3(adelante.x, 0.0, adelante.z)
	dir = dir.normalized() if not dir.is_zero_approx() else -dueno.global_basis.z

	var centro := dueno.global_position + Vector3.UP * datos.altura + dir * (datos.alcance * 0.5)

	var forma := SphereShape3D.new()
	forma.radius = datos.radio

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = forma
	params.transform = Transform3D(Basis.IDENTITY, centro)
	params.collision_mask = Layers.HURTBOX
	params.collide_with_areas = true
	params.collide_with_bodies = false

	var golpes := 0
	for r in espacio.intersect_shape(params, datos.max_objetivos * 2):
		var hb := r.collider as Hurtbox
		if hb == null or hb.equipo == equipo:
			continue
		if _tocados.has(hb.get_instance_id()):
			continue

		# El arco descarta lo que está a la espalda: un mandoble no golpea detrás.
		var hacia := hb.global_position - dueno.global_position
		hacia.y = 0.0
		if not hacia.is_zero_approx():
			var angulo := rad_to_deg(dir.angle_to(hacia.normalized()))
			if angulo > datos.arco_grados:
				continue

		_tocados.append(hb.get_instance_id())
		var punto := hb.global_position
		var golpe := Golpe.new(dueno, datos, punto, (punto - dueno.global_position).normalized())
		hb.recibir(golpe)
		impacto.emit(golpe)
		golpes += 1
		if golpes >= datos.max_objetivos:
			break

	if golpes == 0:
		fallo.emit()
	return golpes
