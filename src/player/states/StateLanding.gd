extends PlayerState
## Aterrizaje duro. Cuesta control durante un instante: es lo que le da peso a una
## caída larga sin tener que quitar vida.
##
## Un aterrizaje normal NO pasa por aquí: va directo a Idle o Move.

var _duracion: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	var impacto: float = float(msg.get("impacto", 0.0))
	# Cuanto más fuerte el golpe, más dura la recuperación, con techo.
	var exceso: float = (impacto - tuning.aterrizaje_duro) / 20.0
	_duracion = tuning.aterrizaje_duro_duracion * clampf(1.0 + exceso, 1.0, 2.2)
	player.wallrun_disponible = true


func physics_update(delta: float) -> void:
	motor.frenar(tuning.frenado_suelo * 1.6, delta)
	motor.set_vertical(-2.0)

	# Cancelar el aterrizaje rodando: el jugador experto no pierde tiempo.
	if buffer.consume(InputActions.DASH) and player.puede_dashear():
		fsm.cambiar(&"Dash")
		return

	if t >= _duracion:
		fsm.cambiar(&"Move" if buffer.move_vector().length() > 0.2 else &"Idle")


func debug_line() -> String:
	return "%.0f%%" % (100.0 * t / maxf(_duracion, 0.001))
