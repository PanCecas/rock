extends PlayerStateGroup
## Transiciones que comparten TODOS los estados de suelo.
## Si esto viviera repetido en cada hoja, la FSM sería el spaghetti que el doc de
## arquitectura avisa de evitar.


func shared_update(delta: float) -> void:
	# Suelo firme = stamina llena. No es un souls: el recurso limita el traversal,
	# no castiga el estar de pie.
	player.stamina.regenerar(tuning.stamina_regen_suelo, delta)
	player.recargar_aire()

	# El salto se pregunta desde el buffer, nunca desde Input directamente.
	# Si la hoja tiene su propio salto (Crouch, Surf), el grupo no se lo roba.
	if not (fsm.actual != null and fsm.actual.maneja_salto()):
		if player.consumir_salto():
			# SIDE JUMP: si venias corriendo y acabas de pedir la direccion
			# contraria, el salto sale mas alto y hacia el nuevo rumbo.
			if player.ventana_sidejump > 0.0:
				var dir := sc.direccion_movimiento(buffer.move_vector(), player.camara())
				if not dir.is_zero_approx():
					motor.impulso(dir, tuning.sidejump_lateral)
					player.orientar_a(dir)
				motor.set_vertical(tuning.velocidad_salto() * tuning.sidejump_mult)
				player.ventana_sidejump = 0.0
				EventBus.camara_shake.emit(0.3, 0.12)
				fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true, "sin_corte": true}, true)
				return
			fsm.cambiar(&"Jump", {"numero": 1}, true)
			return

	if player.puede_dashear() and buffer.consume(InputActions.DASH):
		fsm.cambiar(&"Dash")
		return

	# Combate. El parry va ANTES que el ataque: si el jugador pulsa las dos casi a
	# la vez, casi siempre estaba reaccionando a algo que venia.
	if buffer.consume(InputActions.PARRY):
		fsm.cambiar(&"Parry")
		return

	# Si la hoja gestiona sus propios ataques (Surf), el grupo no se los roba.
	if fsm.actual != null and fsm.actual.maneja_ataques():
		return

	if player.ataque_ligero != null and buffer.consume(InputActions.ATTACK_LIGHT):
		fsm.cambiar(&"Attack", {"datos": player.ataque_ligero, "indice": 1})
		return
	if player.ataque_pesado != null and buffer.consume(InputActions.ATTACK_HEAVY):
		fsm.cambiar(&"Attack", {"datos": player.ataque_pesado, "indice": 1})
		return
	if buffer.consume(InputActions.LOCK_ON):
		player.targeting.alternar_fijado()

	# Perder el suelo: el coyote time lo gestiona Fall, no aquí, para que un salto
	# pulsado 100 ms después de salirse del borde siga contando.
	if not player.is_on_floor():
		fsm.cambiar(&"Fall", {"coyote": true})
		return

	# Una pendiente imposible te tira: no puedes quedarte quieto en un tejado.
	if player.suelo.demasiado_empinado() and fsm.actual.name != &"Slide":
		fsm.cambiar(&"Slide", {"forzado": true})
		return

	# ADHERENCIA: insistir contra un muro perpendicular acaba enganchandote.
	if player.adherencia_lista() and fsm.actual.name != &"Climb":
		fsm.cambiar(&"Climb")
		return

	# TECHO BAJO: si no cabes de pie, te agachas quieras o no. Es lo que hace que
	# un tunel sea un obstaculo y no una sugerencia.
	if player.techo_bloquea() and not player.esta_agachado():
		fsm.cambiar(&"Crouch", {"forzado": true})
