extends SpearState
## En el suelo sin haberse clavado: se le acabó el vuelo en el aire.
##
## Cae hasta tocar suelo y ahí se queda, recogible. NO pone plataforma: una lanza
## tumbada en el suelo no es un sitio donde subirse.

const GRAVEDAD := 24.0

var _vy: float = 0.0
var _posada: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_vy = 0.0
	_posada = false
	lanza.soltar_plataforma()


func physics_update(delta: float) -> void:
	if _posada:
		return
	_vy -= GRAVEDAD * delta
	var desde := lanza.global_position
	var hasta := desde + Vector3.UP * _vy * delta
	var espacio := lanza.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(desde, hasta, lanza.capas_clavado)
	var r := espacio.intersect_ray(q)
	if not r.is_empty():
		lanza.global_position = (r.position as Vector3) + Vector3.UP * 0.06
		_posada = true
		_vy = 0.0
		return
	lanza.global_position = hasta
	# Tumbada, que es como se lee "esto se recoge, no se pisa".
	lanza.apuntar_a(Vector3(lanza.direccion.x, 0.0, lanza.direccion.z))
