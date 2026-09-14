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
	# del `return` de `maneja_ataques()`, que declaraban Surf, Slide, SlideKick y
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
	if player.escalada_habilitada() and player.pared.hay_pared and fsm.actual.name != &"Climb":
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
	# ZIP A LA LANZA, antes que el salto: desde el suelo sirve para SUBIR a una
	# lanza clavada en alto, y si el salto se lo comiera nunca saldria.
	if intentar_cuerda():
		return

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
			# PERTIGA: si hay una lanza clavada al lado, el salto se apoya en
			# ella y sube mucho mas. Va DESPUES del side jump —ese es un
			# gesto que ya empezaste y no se le quita— y antes del salto
			# normal, porque teniendo pertiga a mano el salto raso no es lo
			# que estas pidiendo.
			if player.hay_pertiga():
				fsm.cambiar(&"Jump", {"numero": 1}, true)
				player.impulsar_pertiga()
				return
			fsm.cambiar(&"Jump", {"numero": 1}, true)
			return

	# SHIFT EN EL SUELO ES EL SLIDE, no el dash.
	#
	# Los dos eran «el boton de ir rapido en linea recta» y el slide es el que lee
	# el terreno: acelera cuesta abajo, frena cuesta arriba y se encadena con el
	# salto. El dash se queda donde sigue significando algo —EN EL AIRE, como
	# esquive— y el surf sigue estando donde estaba: manteniendo.
	#
	# Sin stamina ni cargas, igual que el slide de siempre: lo que lo limita es su
	# propia friccion y su duracion, no un recurso.
	if not (fsm.actual != null and fsm.actual.maneja_deslizamiento()):
		if buffer.consume(InputActions.DASH):
			fsm.cambiar(&"Slide")
			return

	# Combate. Solo queda el parry, que SI es una transicion: te planta y te deja
	# quieto durante su ventana.
	#
	# El corte de espada no esta aqui y no es un olvido: no cambia de estado, asi
	# que lo resuelve el controlador. Y la patada tampoco: en el suelo el Espacio
	# salta, y patear es lo que hace el Espacio EN EL AIRE.
	if buffer.consume(InputActions.PARRY):
		fsm.cambiar(&"Parry")
		return

	if buffer.consume(InputActions.LOCK_ON):
		player.targeting.alternar_fijado()
