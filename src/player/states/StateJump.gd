extends PlayerState
## Fase de subida del salto. Aquí vive el jump cut, que es el perdón más importante
## después del coyote time: el jugador decide la altura soltando el botón.

var _corte_usado: bool = false


func enter(msg: Dictionary = {}) -> void:
	_corte_usado = false
	var numero: int = int(msg.get("numero", 1))
	var extra: float = float(msg.get("extra", 0.0))

	# El wall-jump ya ha fijado su propia vertical (absoluta y mas fuerte); si la
	# sobrescribieramos aqui, el rebote de pared seria un salto normal cualquiera.
	if not bool(msg.get("conservar_vertical", false)):
		motor.set_vertical(tuning.velocidad_salto() + extra)
	player.consumir_coyote()

	# El doble salto redirige el impulso hacia donde apuntas: si no, se siente
	# como un pegote y no como una decisión.
	if numero >= 2:
		var entrada := buffer.move_vector()
		if entrada.length() > 0.25:
			var dir := sc.direccion_movimiento(entrada, player.camara())
			motor.impulso(dir, maxf(motor.rapidez_plana(), tuning.velocidad_correr * 0.85))

	EventBus.player_jumped.emit(numero)


func physics_update(delta: float) -> void:
	motor.aplicar_gravedad(delta)
	player.control_aereo(delta)

	# Jump cut: soltar durante la subida acorta el salto.
	if not _corte_usado and not buffer.is_held(InputActions.JUMP):
		if motor.get_vertical() > 0.0:
			motor.set_vertical(motor.get_vertical() * tuning.jump_cut)
		_corte_usado = true

	if motor.get_vertical() <= 0.0:
		fsm.cambiar(&"Fall")


func debug_line() -> String:
	return "vy %.1f%s" % [motor.get_vertical(), "  cortado" if _corte_usado else ""]
