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

	# 0) El agua manda sobre todo lo demas: si hay agua, se entra al agua. Y la
	#    forma de entrar depende de como llegues, no de donde caigas.
	if player.agua.en_agua:
		fsm.cambiar(&"Swim")
		return

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
			fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true}, true)
			return

	# 3.5) PRIORIDAD 1 — ESCALAR. Mantener el agarre gana a wall-run y wall-jump.
	#      Con tres verbos compitiendo por la misma pared hace falta una regla que
	#      el jugador pueda tener en la cabeza, y "si agarro, escalo" es la mas
	#      simple que existe: la ambiguedad solo queda entre los dos que NO pides
	#      explicitamente, y esa se resuelve por angulo.
	if player.pared.hay_pared and buffer.is_held(InputActions.GRAB):
		var vale_pared := player.pared.escalable or tuning.escalada_universal
		if vale_pared and fsm.actual.name != &"Climb" and not player.stamina.vacia():
			fsm.cambiar(&"Climb")
			return

	# 4) PARED. La ambiguedad entre wall-run y wall-jump se resuelve por el ANGULO
	#    con el que llegas, no por de que lado te queda el muro:
	#
	#      de frente (angulo pequeno con la normal) -> no hay componente a lo
	#        largo del muro que aprovechar. Rebotas: wall-slide y wall-jump.
	#      rozando (angulo grande) -> ya vas casi paralelo. Correr es la lectura
	#        natural: wall-run.
	#
	#    Antes lo decidia `pared.lado`, que es una propiedad del sensor y no de
	#    tu intencion, y por eso los dos verbos se pisaban.
	if player.pared.hay_pared and fsm.actual.name != &"Dash":
		var normal := sc.plano(player.pared.normal).normalized()
		var avance := motor.direccion_plana()
		var contra_pared := -sc.plano(player.velocity).dot(normal)
		var quiere := buffer.move_vector().length() > 0.3 or contra_pared > tuning.wallslide_entrada_min

		if quiere:
			# Angulo entre el avance y la normal. 0 = de frente, 90 = rozando.
			var grados := 0.0
			if not avance.is_zero_approx():
				grados = rad_to_deg(avance.angle_to(-normal))
			var oblicuo := grados >= tuning.pared_umbral_frontal

			var puede_correr := (
				oblicuo
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

	# Si la hoja gestiona sus propios ataques (Dive), el grupo no se los roba.
	# Este guardia existia solo en GroupGrounded y por eso el DiveAttack no
	# llegaba a ejecutarse: la segunda pulsacion se convertia en ataque aereo.
	if fsm.actual != null and fsm.actual.maneja_ataques():
		return
	if player.ataque_aereo != null and buffer.consume(InputActions.ATTACK_LIGHT):
		fsm.cambiar(&"AirAttack", {"datos": player.ataque_aereo})
		return
	# DIVE: atacar en el aire llevando carrera es un clavado, no un picado. Sale
	# igual desde correr que desde surfear: lo que importa es el momentum.
	if motor.rapidez_plana() >= tuning.dive_velocidad_min and motor.get_vertical() < 2.0:
		if buffer.consume(InputActions.ATTACK_HEAVY) or buffer.consume(InputActions.ATTACK_LIGHT):
			fsm.cambiar(&"Dive", {"direccion": motor.direccion_plana()})
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

	# 7) Doble salto. Requiere una pulsación NUEVA, y se pide con `reentrar=true`
	#    porque casi siempre se salta ESTANDO YA en Jump: sin eso la FSM rechazaba
	#    la transición a sí misma, la pulsación y el salto aéreo se gastaban, y no
	#    pasaba nada. Ese era el salto que "se quedaba pegado".
	if player.saltos_aereos > 0 and player.consumir_salto():
		player.saltos_aereos -= 1
		fsm.cambiar(&"Jump", {"numero": 2}, true)
		return

	# 8) PLANEO: mantener el botón de salto en el aire, a partir del ápice.
	#    El retardo evita que un saltito corto abra la capa nada más despegar.
	if fsm.actual.name != &"Glide" and motor.get_vertical() <= 0.0:
		if player.tiempo_en_aire > tuning.planeo_retardo_despliegue:
			if buffer.is_held(InputActions.GLIDE) and not player.stamina.vacia():
				fsm.cambiar(&"Glide")
				return
