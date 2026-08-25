extends EnemyState
## Persigue hasta ponerse a distancia de ataque, y espera su turno.
##
## Un enemigo que mantiene distancia (el Vigia) usa el mismo estado: la diferencia
## esta en `distancia_deseada()`, no en un estado aparte, porque acercarse y
## alejarse son el mismo problema con el signo cambiado.

func physics_update(delta: float) -> void:
	if not enemigo.objetivo_valido():
		fsm.cambiar(&"Dormido")
		return

	var hacia := enemigo.hacia_objetivo()
	var dist := hacia.length()
	enemigo.encarar(hacia)

	var minima := enemigo.distancia_minima()
	if minima > 0.0 and dist < minima:
		# Demasiado cerca: retroceder. Es lo que obliga al jugador a perseguir en
		# vez de quedarse pegado.
		enemigo.motor.mover(-hacia.normalized(), enemigo.velocidad, delta)
		return

	if dist > enemigo.alcance_ataque:
		enemigo.motor.mover(hacia.normalized(), enemigo.velocidad, delta)
		return

	enemigo.motor.frenar(delta)
	if enemigo.espera <= 0.0 and enemigo.ataque != null:
		fsm.cambiar(enemigo.estado_de_ataque())


func debug_line() -> String:
	return "%.1f m" % enemigo.hacia_objetivo().length()
