extends EnemyState
## En el suelo. La ventana es larga a proposito: es lo que le da una razon
## ofensiva a agacharse, y el premio por acertar la patada baja.

func physics_update(delta: float) -> void:
	enemigo.motor.frenar(delta)
	if t >= enemigo.derribo:
		fsm.cambiar(&"Acercarse")


func debug_line() -> String:
	return "%.2f s" % maxf(enemigo.derribo - t, 0.0)
