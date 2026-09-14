extends EnemyState
## Contra la pared. Aturdido y completamente abierto durante un buen rato.
##
## Es la mitad que hace que merezca la pena esquivar: sin esta ventana, apartarse
## solo evitaria el dano, y evitar dano no es una recompensa, es no ser castigado.

func enter(_msg: Dictionary = {}) -> void:
	enemigo.velocity = Vector3.ZERO
	EventBus.camara_shake.emit(0.7, 0.25)
	CombatFX.onda(
		enemigo.get_parent(), enemigo.global_position + Vector3.UP * 0.5,
		enemigo.color_de(&"crema_bruma"), 2.6
	)


func physics_update(delta: float) -> void:
	enemigo.motor.frenar(delta)
	if t >= enemigo.aturdido_muro:
		enemigo.espera = enemigo.cadencia
		fsm.cambiar(&"Acercarse")


func debug_line() -> String:
	return "ESTRELLADO %.1f s" % maxf(enemigo.aturdido_muro - t, 0.0)
