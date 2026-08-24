extends PlayerState
## Quieto en el suelo.


func enter(_msg: Dictionary = {}) -> void:
	player.wallrun_disponible = true


func physics_update(delta: float) -> void:
	var entrada := buffer.move_vector()
	if entrada.length() > 0.15:
		fsm.cambiar(&"Move")
		return
	if buffer.consume(InputActions.CROUCH):
		fsm.cambiar(&"Crouch")
		return

	motor.frenar(tuning.frenado_suelo, delta)
	# Un poco de gravedad pegando al suelo: sin esto el jugador flota en rampas.
	motor.set_vertical(-2.0)
