class_name GroundSensor
extends Node
## Lee el suelo bajo el jugador: si lo hay, con qué inclinación, y sobre QUÉ nodo.
##
## Ese último dato es el que alimenta al SurfaceContext. Hoy siempre devuelve el
## mundo estático; en la Fase 4 devolverá el hueso de un coloso y todo lo demás
## seguirá funcionando sin cambios.

## Hasta dónde busca suelo por debajo de los pies.
@export_range(0.1, 5.0, 0.05) var alcance: float = 1.2
## Radio del abanico de rayos. Detecta bordes y evita que un solo rayo mienta.
@export_range(0.0, 1.0, 0.05) var radio: float = 0.28

var hay_suelo: bool = false
var normal: Vector3 = Vector3.UP
var punto: Vector3 = Vector3.ZERO
var distancia: float = INF
var colisionador: Node3D = null
## Grados de inclinación del suelo respecto al `up` actual.
var pendiente: float = 0.0
## Componente de la pendiente en la dirección de avance. Positivo = cuesta abajo.
var pendiente_avance: float = 0.0

var _p: PlayerController


func _ready() -> void:
	_p = get_parent() as PlayerController


func sondear() -> void:
	if _p == null:
		return
	var sc := _p.superficie
	var espacio := _p.get_world_3d().direct_space_state
	var origen := _p.global_position + sc.up * 0.25

	hay_suelo = false
	distancia = INF
	colisionador = null
	var acumulada := Vector3.ZERO
	var golpes := 0

	# Un rayo central y cuatro en cruz: un solo rayo se cae por cualquier grieta.
	for offset in _offsets(sc):
		var desde := origen + offset
		var hasta := desde - sc.up * (alcance + 0.25)
		var params := PhysicsRayQueryParameters3D.create(desde, hasta, Layers.SUELO_JUGADOR)
		params.exclude = [_p.get_rid()]
		var r := espacio.intersect_ray(params)
		if r.is_empty():
			continue
		golpes += 1
		acumulada += r.normal as Vector3
		var d: float = desde.distance_to(r.position as Vector3) - 0.25
		if d < distancia:
			distancia = d
			punto = r.position
			colisionador = r.collider as Node3D

	if golpes == 0:
		normal = sc.up
		pendiente = 0.0
		pendiente_avance = 0.0
		return

	hay_suelo = true
	normal = (acumulada / float(golpes)).normalized()
	pendiente = rad_to_deg(acos(clampf(normal.dot(sc.up), -1.0, 1.0)))

	# Cuesta abajo positivo: es lo que acelera el deslizamiento.
	var avance := _p.motor.direccion_plana()
	pendiente_avance = 0.0 if avance.is_zero_approx() else -avance.dot(sc.plano(normal).normalized()) * pendiente


## ¿La pendiente es demasiado empinada para quedarse de pie?
func demasiado_empinado() -> bool:
	return hay_suelo and pendiente > _p.tuning.angulo_max_suelo


## Dirección de máxima pendiente hacia abajo, para deslizarse.
func cuesta_abajo() -> Vector3:
	var sc := _p.superficie
	var d := sc.plano(normal)
	return d.normalized() if d.length_squared() > 0.001 else Vector3.ZERO


func _offsets(sc: SurfaceContext) -> Array[Vector3]:
	var b := _p.global_basis
	var x := sc.plano(b.x).normalized() * radio
	var z := sc.plano(b.z).normalized() * radio
	return [Vector3.ZERO, x, -x, z, -z]


func debug_line() -> String:
	if not hay_suelo:
		return "sin suelo"
	return "%.0f°  d=%.2f  %s" % [pendiente, distancia, colisionador.name if colisionador else "?"]
