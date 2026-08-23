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
	if buffer.consume(InputActions.JUMP, tuning.jump_buffer):
		fsm.cambiar(&"Jump", {"numero": 1})
		return

	if player.puede_dashear() and buffer.consume(InputActions.DASH):
		fsm.cambiar(&"Dash")
		return

	# Combate. El parry va ANTES que el ataque: si el jugador pulsa las dos casi a
	# la vez, casi siempre estaba reaccionando a algo que venia.
	if buffer.consume(InputActions.PARRY):
		fsm.cambiar(&"Parry")
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
