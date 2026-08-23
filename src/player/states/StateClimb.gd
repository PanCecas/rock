extends PlayerState
## Escalada libre sobre superficies marcadas como CLIMBABLE.
##
## Es el estado que más va a usarse en el juego final: la piel de los colosos será
## una superficie escalable en movimiento. Por eso todo el movimiento se calcula
## en el plano de la pared y no en coordenadas de mundo.

var _normal: Vector3 = Vector3.ZERO


func enter(_msg: Dictionary = {}) -> void:
	_normal = player.pared.normal
	player.velocity = Vector3.ZERO
	player.orientar_a(-sc.plano(_normal))
	sc.set_frame(player.pared.colisionador)


func exit(siguiente: StringName = &"") -> void:
	if not fsm.es_categoria(siguiente, &"Attached"):
		sc.set_frame(null)


func physics_update(delta: float) -> void:
	if not buffer.is_held(InputActions.GRAB):
		player.tiempo_sin_borde = 0.2
		fsm.cambiar(&"Fall")
		return
	if not player.pared.hay_pared or not player.pared.escalable:
		# Llegar arriba del todo: si hay canto, se sube; si no, se cae.
		if player.borde.hay_borde:
			fsm.cambiar(&"LedgeClimb")
		else:
			fsm.cambiar(&"Fall")
		return

	_normal = player.pared.normal
	player.velocity = Vector3.ZERO

	var entrada := buffer.move_vector()
	if entrada.length() > 0.15:
		# Ejes de la pared: arriba real y lateral real, no los del mundo.
		var lateral := sc.up.cross(sc.plano(_normal)).normalized()
		var arriba := sc.plano(_normal).normalized().cross(lateral).normalized()
		if arriba.dot(sc.up) < 0.0:
			arriba = -arriba
		var mov := (lateral * entrada.x - arriba * entrada.y).normalized()
		player.global_position += mov * tuning.escalada_velocidad * delta
		player.stamina.drenar(tuning.stamina_escalar, delta)
	else:
		# Agarre tenso: quedarse quieto también cuesta, solo que mucho menos.
		player.stamina.drenar(tuning.stamina_escalar * 0.25, delta)

	# Pegarse a la pared para seguir el relieve.
	player.global_position -= sc.plano(_normal).normalized() * 0.6 * delta

	# Salto de escalada: te despegas hacia donde apuntas.
	if player.consumir_salto():
		if player.stamina.gastar(tuning.stamina_escalar * 2.0):
			var salida := sc.plano(_normal).normalized()
			motor.impulso(salida, tuning.walljump_lateral * 0.7)
			player.tiempo_sin_borde = 0.15
			fsm.cambiar(&"Jump", {"numero": 1}, true)


func debug_line() -> String:
	return "stam %.0f%%" % (player.stamina.fraccion() * 100.0)
