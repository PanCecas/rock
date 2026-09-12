extends PlayerState
## Subir el canto. Movimiento escriptado y corto: se interpola la posición en vez
## de dejar que la física decida, porque una subida a base de fuerzas se atasca en
## las esquinas y es exactamente donde el jugador no perdona un fallo.
##
## Cuando existan animaciones, esta interpolación la sustituye el root motion del
## clip `traversal/ledge_climb_up`.

const DURACION := 0.36

var _desde: Vector3 = Vector3.ZERO
var _hasta: Vector3 = Vector3.ZERO


func enter(msg: Dictionary = {}) -> void:
	_desde = player.global_position
	var punto: Vector3 = msg.get("punto", player.borde.punto)
	var normal: Vector3 = msg.get("normal", player.borde.normal_pared)
	_hasta = punto - sc.plano(normal).normalized() * 0.45 + sc.up * 0.05
	player.velocity = Vector3.ZERO
	player.stamina.gastar(tuning.stamina_escalar * 1.5)


func physics_update(_delta: float) -> void:
	var p := clampf(t / DURACION, 0.0, 1.0)
	# Primero sube, luego entra: en diagonal el personaje atraviesa el canto.
	var vertical := ease(minf(p * 1.6, 1.0), 0.4)
	var horizontal := ease(maxf((p - 0.35) / 0.65, 0.0), 0.6)

	var subida := sc.up * sc.vertical(_hasta - _desde) * vertical
	var entrada := sc.plano(_hasta - _desde) * horizontal
	player.global_position = _desde + subida + entrada

	if p >= 1.0:
		player.global_position = _hasta
		player.tiempo_sin_borde = 0.25
		player.recargar_aire()
		fsm.cambiar(&"Idle")


func debug_line() -> String:
	return "%.0f%%" % (100.0 * clampf(t / DURACION, 0.0, 1.0))
