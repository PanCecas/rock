extends PlayerState
## Caída. Guarda el coyote time: durante `coyote_time` tras salirse de un borde el
## salto todavía cuenta como salto de suelo, no como doble salto.
##
## Sin esto, cada salto al filo de una plataforma se siente como una traición.

var _coyote: float = 0.0
var _resbalon: bool = false


func enter(msg: Dictionary = {}) -> void:
	_resbalon = bool(msg.get("resbalon", false))
	_coyote = tuning.coyote_time if bool(msg.get("coyote", false)) else 0.0
	if _resbalon:
		# Al resbalarse por falta de stamina te separas un poco de la pared, o
		# vuelves a engancharte inmediatamente y no se entiende qué pasó.
		motor.impulso(sc.plano(player.pared.normal), 2.5, true)
		player.tiempo_sin_borde = 0.45


func physics_update(delta: float) -> void:
	if _coyote > 0.0:
		_coyote -= delta
		# Salto de suelo tardío: no gasta el salto aéreo.
		if buffer.consume(InputActions.JUMP, tuning.jump_buffer):
			fsm.cambiar(&"Jump", {"numero": 1})
			return

	motor.aplicar_gravedad(delta)
	player.control_aereo(delta)


func debug_line() -> String:
	if _coyote > 0.0:
		return "coyote %.0f ms" % (_coyote * 1000.0)
	return "vy %.1f" % motor.get_vertical()
