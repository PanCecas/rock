extends PlayerState
## Agachado. Cápsula a la mitad y, sobre todo, el FRENO del sistema de movimiento:
## agacharse llevando velocidad no te congela de golpe, te va parando (Mario 64).
##
## Tiene dos verbos propios:
##   · SALTO FUERTE: quieto y agachado, saltar sube mucho más. Sin volteretas —el
##     backflip se quitó porque la voltereta se rompía y no aportaba nada que el
##     impulso no diera ya—.
##   · SLIDE KICK: atacar con velocidad acumulada dispara la patada deslizante,
##     el salto de conejo de Mario 64, con hitbox.
##
## Y no se sale cuando quieres: si hay techo encima, te quedas agachado. Eso es
## lo que convierte un túnel bajo en un obstáculo de verdad.


func enter(_msg: Dictionary = {}) -> void:
	player.pedir_postura(tuning.agachado_altura)
	player.wallrun_disponible = true


func physics_update(delta: float) -> void:
	# La postura se PIDE cada frame. No hay que restaurarla al salir: en cuanto
	# este estado deja de pedirla, el controlador levanta al personaje solo si
	# hay hueco. Eso es lo que impide quedarse encogido sin motivo.
	player.pedir_postura(tuning.agachado_altura)
	var entrada := buffer.move_vector()
	var rapidez := motor.rapidez_plana()

	# SLIDE KICK: solo con velocidad. Es la recompensa por llegar lanzado, no un
	# ataque más que se pueda hacer desde parado.
	if rapidez >= tuning.slide_velocidad_min * 0.6 and player.ataque_slide_kick != null \
			and player.cd_slide_kick <= 0.0:
		if buffer.consume(InputActions.ATTACK_LIGHT):
			_slide_kick()
			return

	# Patada baja: la versión desde parado.
	if player.ataque_agachado != null:
		if buffer.consume(InputActions.ATTACK_LIGHT) or buffer.consume(InputActions.ATTACK_HEAVY):
			fsm.cambiar(&"Attack", {"datos": player.ataque_agachado, "indice": 1})
			return

	if player.consumir_salto():
		_saltar()
		return

	# FRICCIÓN. Si llegas con velocidad, agacharte te va parando; si ya estás
	# quieto, puedes reptar despacio. Es el freno del juego, y por eso decelera
	# en vez de cortar: cortar en seco se siente como chocar contra el aire.
	if rapidez > tuning.velocidad_agachado:
		motor.frenar(tuning.crouch_friccion, delta)
	else:
		var dir := sc.direccion_movimiento(entrada, player.camara())
		motor.acelerar(dir * tuning.velocidad_agachado, tuning.aceleracion_suelo * 0.7, delta)
	motor.set_vertical(-2.0)

	# Levantarse: hay que soltar el botón Y tener hueco encima.
	if not buffer.is_held(InputActions.CROUCH) and not player.techo_bloquea():
		fsm.cambiar(&"Move" if entrada.length() > 0.2 else &"Idle")


## Quieto: salto MUY fuerte, sin voltereta. En movimiento: salto normal, para no
## premiar agacharse como forma de ir rápido —de eso ya se encarga el surf—.
func _saltar() -> void:
	if motor.rapidez_plana() < tuning.crouch_quieto:
		motor.set_vertical(tuning.velocidad_salto_agachado())
		EventBus.camara_shake.emit(0.35, 0.14)
		CombatFX.onda(
			player.get_parent(), player.global_position + Vector3.UP * 0.1,
			player.color_de(&"crema_bruma"), 1.5
		)
		fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true, "sin_corte": true}, true)
	else:
		fsm.cambiar(&"Jump", {"numero": 1}, true)


## Patada deslizante: te lanza hacia delante casi a ras de suelo, con hitbox.
func _slide_kick() -> void:
	var dir := motor.direccion_plana()
	if dir.is_zero_approx():
		dir = player.direccion_frontal()
	motor.impulso(dir, tuning.slide_kick_impulso)
	motor.set_vertical(tuning.slide_kick_vertical)
	player.orientar_a(dir)
	fsm.cambiar(&"SlideKick", {"direccion": dir})


func maneja_ataques() -> bool:
	return true


func maneja_salto() -> bool:
	return true


func debug_line() -> String:
	var extra := "  TECHO" if player.techo_bloquea() else ""
	var rapidez := motor.rapidez_plana()
	if rapidez > tuning.velocidad_agachado:
		return "frenando %.1f m/s%s" % [rapidez, extra]
	return "quieto → salto fuerte%s" % extra
