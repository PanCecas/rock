class_name LedgeSensor
extends Node
## Detecta bordes agarrables. Es el sensor que más decide si el juego se siente
## generoso o tacaño, así que incluye el "ledge assist": si el jugador falla el
## borde por menos de `ledge_assist` metros, se le concede igual.
##
## Método clásico de tres rayos:
##   1. A la altura del pecho hacia delante debe FALLAR  -> no hay muro en la cara
##   2. A la altura de la cintura hacia delante debe ACERTAR -> hay pared que agarrar
##   3. Desde arriba y adelante hacia abajo debe ACERTAR  -> ese es el canto

@export_range(0.1, 3.0, 0.05) var altura_pecho: float = 1.75
@export_range(0.1, 3.0, 0.05) var altura_cintura: float = 1.05
## Cuánto por encima de la cabeza empieza el rayo que busca el canto.
@export_range(0.1, 3.0, 0.05) var sonda_arriba: float = 2.4
@export_range(0.0, 89.0, 1.0) var angulo_max_pared: float = 35.0

var hay_borde: bool = false
## Punto exacto del canto, en espacio de mundo.
var punto: Vector3 = Vector3.ZERO
var normal_pared: Vector3 = Vector3.FORWARD
var colisionador: Node3D = null
## True si el agarre se concedió por asistencia y no por alcance real.
var asistido: bool = false

var _p: PlayerController


func _ready() -> void:
	_p = get_parent() as PlayerController


## Busca borde en la dirección indicada (normalmente hacia donde mira el jugador).
func sondear(direccion: Vector3) -> void:
	hay_borde = false
	asistido = false
	if _p == null or direccion.is_zero_approx():
		return

	var sc := _p.superficie
	var dir := sc.plano(direccion).normalized()
	if dir.is_zero_approx():
		return

	# Primero al alcance nominal; si falla, se reintenta con la asistencia.
	if _intentar(dir, _p.tuning.ledge_alcance):
		return
	if _intentar(dir, _p.tuning.ledge_alcance + _p.tuning.ledge_assist):
		asistido = true


func _intentar(dir: Vector3, alcance: float) -> bool:
	var sc := _p.superficie
	var espacio := _p.get_world_3d().direct_space_state
	var base := _p.global_position
	var excluir: Array[RID] = [_p.get_rid()]

	# 1. A la altura del pecho no puede haber pared: si la hay, no es un canto.
	var pecho := base + sc.up * altura_pecho
	var q1 := PhysicsRayQueryParameters3D.create(pecho, pecho + dir * alcance, Layers.SUELO_JUGADOR)
	q1.exclude = excluir
	if not espacio.intersect_ray(q1).is_empty():
		return false

	# 2. A la altura de la cintura sí tiene que haberla.
	var cintura := base + sc.up * altura_cintura
	var q2 := PhysicsRayQueryParameters3D.create(cintura, cintura + dir * alcance, Layers.SUELO_JUGADOR)
	q2.exclude = excluir
	var pared := espacio.intersect_ray(q2)
	if pared.is_empty():
		return false

	var n := pared.normal as Vector3
	# Una pared casi tumbada no es un borde: es una rampa, y se sube andando.
	if rad_to_deg(acos(clampf(sc.plano(n).normalized().dot(-dir), -1.0, 1.0))) > angulo_max_pared:
		return false

	# 3. Buscar el canto hacia abajo, DESDE ENCIMA DEL PUNTO DE IMPACTO.
	#    Anclarlo al impacto y no a una fracción del alcance es lo que hace que el
	#    agarre funcione igual pegado a la pared que al límite de la asistencia.
	var horiz: Vector3 = (pared.position as Vector3) + dir * 0.25
	var arriba := horiz + sc.up * (sonda_arriba - altura_cintura)
	var q3 := PhysicsRayQueryParameters3D.create(
		arriba, horiz - sc.up * 0.1, Layers.SUELO_JUGADOR
	)
	q3.exclude = excluir
	var canto := espacio.intersect_ray(q3)
	if canto.is_empty():
		return false

	# El canto tiene que ser pisable, no otra pared.
	if (canto.normal as Vector3).dot(sc.up) < 0.6:
		return false

	var altura := sc.vertical((canto.position as Vector3) - base)
	if altura > _p.tuning.ledge_altura_max or altura < 0.2:
		return false

	hay_borde = true
	punto = canto.position
	normal_pared = n
	colisionador = pared.collider as Node3D
	return true


## Posición donde debe quedar el jugador colgando de este borde.
func pose_colgado() -> Vector3:
	var sc := _p.superficie
	return punto + sc.plano(normal_pared).normalized() * 0.32 - sc.up * altura_cintura


## Posición final tras subir el borde.
func pose_encima() -> Vector3:
	var sc := _p.superficie
	return punto - sc.plano(normal_pared).normalized() * 0.45 + sc.up * 0.05


func debug_line() -> String:
	if not hay_borde:
		return "—"
	return "sí%s  h=%.2f" % [" (asistido)" if asistido else "", _p.superficie.vertical(punto - _p.global_position)]
