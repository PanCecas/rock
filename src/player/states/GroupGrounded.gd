extends PlayerStateGroup
## Transiciones que comparten TODOS los estados de suelo.
## Si esto viviera repetido en cada hoja, la FSM sería el spaghetti que el doc de
## arquitectura avisa de evitar.


func shared_update(delta: float) -> void:
	# Suelo firme = stamina llena. No es un souls: el recurso limita el traversal,
	# no castiga el estar de pie.
	player.stamina.regenerar(tuning.stamina_regen_suelo, delta)
	player.recargar_aire()

	# --- 1) DONDE ESTOY. Va antes que todo lo demas y no lo salta ningun guardia.
	#
	# Aqui vivia el bug del "floating fall": estas comprobaciones estaban DESPUES
	# del `return` de `maneja_ataques()`, que declaran Surf, Slide, SlideKick y
	# Crouch. Salirse de una plataforma surfeando no cambiaba de estado nunca, y
	# como Surf y Slide fuerzan `set_vertical(-2)` cada frame, el personaje se
	# quedaba flotando y bajando a dos metros por segundo.
	#
	# Un guardia de INPUT no puede cancelar una transicion de TERRENO. El coyote
	# time lo gestiona Fall, no aqui, para que un salto pulsado 100 ms despues de
	# salirse del borde siga contando.
	if not player.is_on_floor():
		fsm.cambiar(&"Fall", {"coyote": true})
		return

	# ESCALAR GANA A RESBALAR, y el orden importa. Lo que deja de ser caminable es
	# exactamente lo que empieza a ser escalable, asi que la primera superficie que
	# puedes trepar es tambien la primera por la que te resbalas. Con el slide
	# delante, pedir agarre en una rampa justo por encima del limite no servia de
	# nada: te tiraba antes de mirar si querias subir.
	#
	# Y aqui SI se mira el boton de agarre, no solo la adherencia automatica: desde
	# el suelo era el unico sitio donde pulsar agarre no hacia absolutamente nada.
	if player.pared.hay_pared and fsm.actual.name != &"Climb":
		var quiere_agarrar := buffer.is_held(InputActions.GRAB) or player.adherencia_lista()
		if quiere_agarrar and not player.stamina.vacia():
			fsm.cambiar(&"Climb")
			return

	# SLOPE LIMIT: por encima del limite no se anda, se resbala. Es la otra mitad
	# de la regla —o trepas, o te caes—, y la que impide subir andando por una
	# pared casi perpendicular.
	if player.suelo.demasiado_empinado() and fsm.actual.name != &"Slide":
		fsm.cambiar(&"Slide", {"forzado": true})
		return

	# TECHO BAJO: si no cabes de pie, te agachas quieras o no. Es lo que hace que
	# un tunel sea un obstaculo y no una sugerencia.
	if player.techo_bloquea() and not player.esta_agachado():
		fsm.cambiar(&"Crouch", {"forzado": true})
		return

	# --- 2) QUE HAGO. A partir de aqui si mandan los guardias de las hojas.
	#
	# El salto se pregunta desde el buffer, nunca desde Input directamente.
	# Si la hoja tiene su propio salto (Crouch, Surf), el grupo no se lo roba.
	if not (fsm.actual != null and fsm.actual.maneja_salto()):
		if player.consumir_salto():
			# SIDE JUMP: si venias corriendo y acabas de pedir la direccion
			# contraria, el salto sale mas alto y hacia el nuevo rumbo.
			# El side jump NO se resuelve aqui: pasa por su propio estado porque
			# ocurre en dos tiempos —plantar y saltar— y un grupo no puede
			# sostener una maniobra que dura varios frames.
			if player.ventana_sidejump > 0.0:
				var dir := sc.direccion_movimiento(buffer.move_vector(), player.camara())
				fsm.cambiar(&"SideJump", {"direccion": dir})
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
		# EMBESTIDA EN PRIMERA PERSONA: el mismo boton, pero lanzado EN CARRERA. No
		# es un ataque nuevo, es el pesado de siempre comprometido a una direccion
		# y visto desde dentro. Por debajo de `fps_velocidad_min` sale el pesado
		# normal: es una maniobra de carrera, no un modo que se pida parado.
		var corriendo := motor.rapidez_plana() >= tuning.fps_velocidad_min
		fsm.cambiar(&"Attack", {
			"datos": player.ataque_pesado, "indice": 1, "primera_persona": corriendo,
		})
		return
	if buffer.consume(InputActions.LOCK_ON):
		player.targeting.alternar_fijado()
