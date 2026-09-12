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

		# ATERRIZAJES AGACHADO. Los dos ganan al aterrizaje duro a proposito: son
		# la recompensa por haber planificado la caida, y sin esa prioridad una
		# caida buena se sentiria igual que una mala.
		#
		# Quien elige entre ellos es la VELOCIDAD HORIZONTAL REAL, no el input: el
		# boton solo dice "quiero llegar agachado", no dice como llegas.
		#
		#   rapido  -> LANDING SLIDE: la caida se convierte en linea.
		#   parado  -> RECEPCION en cuclillas, y te quedas agachado.
		#   en medio-> el aterrizaje de siempre, que ya funcionaba.
		# La condicion es el BOTON, no la altura de la capsula: `esta_agachado()`
		# sigue siendo cierto durante los 0.12 s que tarda la capsula en volver a
		# subir, y eso convertia cualquier aterrizaje justo despues de un slide en
		# un aterrizaje agachado que nadie habia pedido. El techo si cuenta: bajo un
		# tunel no te vas a levantar, asi que la recepcion en cuclillas es la unica
		# lectura posible.
		if buffer.is_held(InputActions.CROUCH) or player.techo_bloquea():
			var rapidez := motor.rapidez_plana()
			if rapidez >= tuning.landing_slide_min:
				fsm.cambiar(&"Slide", {"aterrizaje": true})
				return
			if rapidez < tuning.landing_crouch_max:
				fsm.cambiar(&"CrouchLanding", {"impacto": impacto})
				return

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
	#    Y el guardia de la regla dura #13: si la hoja se queda el salto, el grupo
	#    NO se lo roba. Aqui habia un `fsm.actual.name != "WallRun"` —un
	#    `if state == "x"` de los que prohibe la regla #2— que hacia justo eso pero
	#    solo para un estado y por su nombre. El guardia existia en `GroupGrounded`
	#    y NO aqui, que es exactamente el fallo que la regla avisa que se repite.
	if not (fsm.actual != null and fsm.actual.maneja_salto()):
		if player.pared.reciente(tuning.pared_coyote):
			if player.consumir_salto():
				player.saltar_de_pared()
				fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true}, true)
				return

	# 3.5) PRIORIDAD 1 — ESCALAR. Mantener el agarre gana a wall-run y wall-jump.
	#      Con tres verbos compitiendo por la misma pared hace falta una regla que
	#      el jugador pueda tener en la cabeza, y "si agarro, escalo" es la mas
	#      simple que existe: la ambiguedad solo queda entre los dos que NO pides
	#      explicitamente, y esa se resuelve por angulo.
	var vale_pared := player.pared.asidero or tuning.escalada_universal
	var quiere_agarrar := buffer.is_held(InputActions.GRAB) or player.adherencia_lista()
	if player.pared.hay_pared and quiere_agarrar:
		if vale_pared and fsm.actual.name != &"Climb" and not player.stamina.vacia():
			fsm.cambiar(&"Climb")
			return

	# 4) PARED. UN SOLO NUMERO decide, y es el mismo que decide si te agarras:
	#    `player.angulo_contra_pared()`, el angulo entre tu avance y la normal.
	#
	#      por debajo de `pared_umbral_frontal` -> vas DE FRENTE. No hay componente
	#        a lo largo del muro que aprovechar: rebotas. Wall-slide y wall-jump,
	#        o escalar si insistes.
	#      por encima -> vas ROZANDO, ya casi paralelo. Correr es la lectura
	#        natural: wall-run.
	#
	#    Antes esto media la direccion de MOVIMIENTO con 55 grados mientras la
	#    adherencia media la de INPUT DESEADO con 49.5: dos vectores distintos
	#    decidiendo lo mismo. Con momentum divergen, asi que las dos podian ser
	#    ciertas a la vez —de ahi que se sintiera que "quiere hacer todo a la
	#    vez"— y entre 49.5 y 55 no saltaba ninguna.
	#
	# El wall-run y el wall-slide piden ADEMAS una pared casi vertical. Escalar
	# vale desde el slope limit (45), pero correr por una ladera de 50 grados no se
	# sostiene ni fisica ni visualmente.
	if player.pared.hay_pared and player.pared.angulo >= tuning.wallrun_angulo_min 			and not fsm.en_categoria(&"Dash"):
		var normal := sc.plano(player.pared.normal).normalized()
		var contra_pared := -sc.plano(player.velocity).dot(normal)
		var quiere := buffer.move_vector().length() > 0.3 or contra_pared > tuning.wallslide_entrada_min

		if quiere:
			var rozando := player.angulo_contra_pared() >= tuning.pared_umbral_frontal
			var puede_correr := (
				rozando
				and player.wallrun_disponible
				and motor.rapidez_plana() >= tuning.wallrun_velocidad_min
				and buffer.move_vector().length() > 0.3
			)
			if puede_correr:
				fsm.cambiar(&"WallRun")
				return
			if not rozando and motor.get_vertical() < 0.0:
				fsm.cambiar(&"WallSlide")
				return

	# 4.5) LA CUERDA. Detras del terreno y delante del combate: si hay lanza fuera
	#      de la mano, tirar de la cuerda gana a atacar. Es un verbo de posicion y
	#      estas en el aire; atacar puede esperar medio segundo. En el aire y con
	#      la lanza clavada, esto te cuelga: es el balanceo.
	if intentar_cuerda():
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
	# LOS DOS ATAQUES AEREOS SON CLAVADOS, y se diferencian en el peso.
	#
	# El ligero era "golpe aereo si hay enemigo, clavado si no", y eso tenia dos
	# problemas: el clavado casi nunca salia cuando importaba —justo al atacar a
	# alguien— y el jugador no podia predecir cual de los dos iba a ejecutar. Un
	# boton que hace dos cosas segun el contexto no se aprende, se sufre.
	#
	#   ligero -> DIVE: se proyecta adelante y abajo. Es movilidad ademas de golpe.
	#   pesado -> DIVE PESADO: mas lejos y mas plomo, y REBOTA en la cabeza del
	#             enemigo para encadenar el siguiente.
	# EL PICADO VA PRIMERO, y fuera de la espera del clavado. Es otro verbo, con
	# otro gesto y otro coste; meterlo detras del cooldown hacia que agachado +
	# pesado dejara de responder durante medio segundo despues de cada clavado.
	if buffer.is_held(InputActions.CROUCH) and player.ataque_plunge != null:
		if buffer.consume(InputActions.ATTACK_HEAVY):
			fsm.cambiar(&"Plunge")
			return

	# CON LA LANZA EMPUNADA, el aire tambien cambia de moveset.
	#
	# Va ANTES de `cd_dive` a proposito: esa espera es de los clavados y estos no
	# lo son. Estrangular la lanza con el cooldown de otro verbo es como se llega a
	# que un arma "no responda" sin motivo visible.
	var lanza_aereo := player.ataque_aereo_ligero_actual()
	if lanza_aereo != null and buffer.consume(InputActions.ATTACK_LIGHT):
		fsm.cambiar(&"AirAttack", {"datos": lanza_aereo})
		return
	var lanza_giro := player.ataque_aereo_pesado_actual()
	if lanza_giro != null and buffer.consume(InputActions.ATTACK_HEAVY):
		fsm.cambiar(&"AirAttack", {"datos": lanza_giro})
		return

	# La espera vale para los DOS clavados: son el mismo verbo con distinto peso, y
	# un cooldown que solo mire a uno se esquiva alternandolos. Las pulsaciones se
	# consumen igualmente para que no se queden en el buffer y disparen solas al
	# cumplirse la espera.
	if player.cd_dive > 0.0:
		buffer.consume(InputActions.ATTACK_LIGHT)
		buffer.consume(InputActions.ATTACK_HEAVY)
		return
	if buffer.consume(InputActions.ATTACK_LIGHT):
		fsm.cambiar(&"Dive", {"direccion": motor.direccion_plana()})
		return
	if buffer.consume(InputActions.ATTACK_HEAVY):
		fsm.cambiar(&"Dive", {"direccion": motor.direccion_plana(), "pesado": true})
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
