extends SpearState
## VUELVE A LA MANO, y por una CURVA, no en línea recta.
##
## `docs/03 §4.4` lo pide y tiene razón: en recta parece que se teletransporta.
## La curva es lo que hace legible que la lanza VUELVE. Bezier cuadrático con el
## punto de control apartado del segmento, así que el arco existe aunque el dueño
## se mueva mientras tanto. Con `arco_retorno` a cero degenera en la recta, que
## es exactamente lo que debe pasar.

var _desde: Vector3 = Vector3.ZERO
var _control: Vector3 = Vector3.ZERO
var _avance: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	lanza.soltar_plataforma()
	_desde = lanza.global_position
	_avance = 0.0
	var hasta := lanza.punto_de_mano()
	var medio := (_desde + hasta) * 0.5
	var lateral := (hasta - _desde).cross(Vector3.UP)
	if lateral.is_zero_approx():
		lateral = Vector3.RIGHT
	_control = medio + lateral.normalized() * tuning.arco_retorno \
		+ Vector3.UP * tuning.arco_retorno * 0.5


func physics_update(delta: float) -> void:
	var hasta := lanza.punto_de_mano()
	var largo: float = maxf(_desde.distance_to(hasta), 0.001)
	_avance += (tuning.velocidad_retorno * delta) / largo
	var u: float = clampf(_avance, 0.0, 1.0)

	var pos := _desde.lerp(_control, u).lerp(_control.lerp(hasta, u), u)
	lanza.apuntar_a(pos - lanza.global_position)
	lanza.global_position = pos

	if u >= 1.0 or pos.distance_to(hasta) <= tuning.radio_atrape:
		lanza.recuperada.emit()
		fsm.cambiar(&"Wielded")


func debug_line() -> String:
	return "VOLVIENDO  %.0f%%" % (_avance * 100.0)
