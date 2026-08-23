extends PlayerStateGroup
## Transiciones compartidas por todo lo que pasa en el aire.
##
## El ORDEN es una decisión de diseño, no casualidad:
##   aterrizar > borde > wall-jump > pared > dash > doble salto > planeo > escalar
##
## Agarrar un borde gana a todo: un jugador que pulsa dash a 5 cm de un canto casi
## siempre quería el canto. Y el wall-jump gana al doble salto: junto a un muro,
## pulsar salto significa rebotar, no gastar el salto aéreo.


func shared_update(delta: float) -> void:
	player.stamina.regenerar(tuning.stamina_regen_colgado * 0.5, delta)

	# 1) Aterrizar.
	if player.is_on_floor() and motor.get_vertical() <= 0.0:
		var impacto := player.impacto_ultimo
		if impacto > tuning.aterrizaje_duro:
			fsm.cambiar(&"Landing", {"impacto": impacto})
			return
		# Recuperar el surf: saltar en mitad de una linea rapida no deberia
		# costarte la linea.
		var quiere_surf := buffer.is_held(InputActions.DASH) or buffer.is_held(InputActions.SPRINT)
		if player.surf_pendiente > 0.0 and quiere_surf and not player.stamina.vacia():
			fsm.cambiar(&"Surf", {
				"direccion": motor.direccion_plana(),
				"rapidez": player.surf_rapidez,
			})
			return
		if buffer.move_vector().length() > 0.25:
			fsm.cambiar(&"Move")
		else:
			fsm.cambiar(&"Idle")
		return

	# 2) El borde manda sobre todo lo demás.
	if fsm.actual.name != &"LedgeClimb" and player.borde.hay_borde and motor.get_vertical() < 1.0:
		if player.tiempo_sin_borde <= 0.0:
			fsm.cambiar(&"LedgeHang")
			return

	# 3) WALL-JUMP. Con perdón: la pared sigue valiendo `pared_coyote` segundos
	#    después de perder el contacto. Sin eso, encadenar dos muros exige
	#    precisión de frame y es justo lo que hace que se sienta incómodo.
	if fsm.actual.name != &"WallRun" and player.pared.reciente(tuning.pared_coyote):
		if player.consumir_salto():
			player.saltar_de_pared()
			fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true})
			return

	# 4) Pegarse a la pared: correr si la llevas al costado con velocidad,
	#    resbalar si vas contra ella. No hace falta empujar hacia el muro: basta
	#    con chocar, como en Mario. Exigir input hacía que se sintiera esquivo.
	if player.pared.hay_pared and fsm.actual.name != &"Dash":
		var contra_pared := -sc.plano(player.velocity).dot(sc.plano(player.pared.normal).normalized())
		var quiere := buffer.move_vector().length() > 0.3 or contra_pared > tuning.wallslide_entrada_min
		if quiere:
			var puede_correr := (
				player.pared.lado != 0
				and player.wallrun_disponible
				and motor.rapidez_plana() >= tuning.wallrun_velocidad_min
				and buffer.move_vector().length() > 0.3
			)
			if puede_correr and fsm.actual.name != &"WallRun":
				fsm.cambiar(&"WallRun")
				return
			if not puede_correr and motor.get_vertical() < 0.0 and fsm.actual.name != &"WallSlide":
				fsm.cambiar(&"WallSlide")
				return

	# 5) Combate aereo. El plunge es el pesado: cae a plomo y revienta en area.
	if buffer.consume(InputActions.PARRY):
		fsm.cambiar(&"Parry")
		return
	if player.ataque_aereo != null and buffer.consume(InputActions.ATTACK_LIGHT):
		fsm.cambiar(&"AirAttack", {"datos": player.ataque_aereo})
		return
	if player.ataque_plunge != null and buffer.consume(InputActions.ATTACK_HEAVY):
		fsm.cambiar(&"Plunge")
		return
	if buffer.consume(InputActions.LOCK_ON):
		player.targeting.alternar_fijado()

	# 6) Dash aereo.
	if player.puede_dashear() and buffer.consume(InputActions.DASH):
		fsm.cambiar(&"Dash")
		return

	# 7) Doble salto. Requiere una pulsación NUEVA: mantener el salto planea, no
	#    salta, así que las dos acciones dejan de pelearse por la misma tecla.
	if player.saltos_aereos > 0 and player.consumir_salto():
		player.saltos_aereos -= 1
		fsm.cambiar(&"Jump", {"numero": 2})
		return

	# 8) PLANEO: mantener el botón de salto en el aire, a partir del ápice.
	#    El retardo evita que un saltito corto abra la capa nada más despegar.
	if fsm.actual.name != &"Glide" and motor.get_vertical() <= 0.0:
		if player.tiempo_en_aire > tuning.planeo_retardo_despliegue:
			if buffer.is_held(InputActions.GLIDE) and not player.stamina.vacia():
				fsm.cambiar(&"Glide")
				return

	# 9) Escalada a mano sobre superficie marcada.
	if player.pared.hay_pared and player.pared.escalable and buffer.is_held(InputActions.GRAB):
		if fsm.actual.name != &"Climb" and not player.stamina.vacia():
			fsm.cambiar(&"Climb")
