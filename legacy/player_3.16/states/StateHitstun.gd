extends PlayerState
## Encajar un golpe. Corto y cancelable pronto: en un juego cuya premisa es la
## movilidad, un stun largo se siente como que te quitan el mando.

var _duracion: float = 0.25


func enter(msg: Dictionary = {}) -> void:
	var empuje: Vector3 = msg.get("empuje", Vector3.ZERO)
	_duracion = float(msg.get("duracion", 0.25))
	player.velocity = empuje
	player.set_alabeo(0.0)
	var desde: Vector3 = msg.get("desde", Vector3.ZERO)
	if not desde.is_zero_approx():
		player.orientar_a(-desde)


func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		motor.aplicar_gravedad(delta)
	else:
		motor.frenar(tuning.frenado_suelo * 0.7, delta)
		motor.set_vertical(-2.0)

	# A partir de la mitad se puede salir con un dash: recuperarse es una destreza,
	# no una espera.
	if t > _duracion * 0.5 and player.puede_dashear() and buffer.consume(InputActions.DASH):
		fsm.cambiar(&"Dash")
		return

	if t >= _duracion:
		if player.is_on_floor():
			fsm.cambiar(&"Move" if buffer.move_vector().length() > 0.2 else &"Idle")
		else:
			fsm.cambiar(&"Fall")


func debug_line() -> String:
	return "%.0f%%" % (100.0 * t / maxf(_duracion, 0.001))
