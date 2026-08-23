extends PlayerState
## Agachado. Cápsula a la mitad, movimiento lento, y dos cosas que lo hacen algo
## más que un botón para pasar por huecos:
##
##   · SALTO ALTO (Mario Odyssey): quieto y agachado, saltar sube muchísimo más.
##     Su precio es tener que pararse a cargarlo, así que no compite con el flujo.
##   · PATADA BAJA: atacar desde aquí derriba en vez de tambalear, y el derribo
##     abre una ventana para rematar.
##
## Y no se sale cuando quieres: si hay techo encima, te quedas agachado. Eso es
## lo que convierte un túnel bajo en un obstáculo de verdad.



func enter(_msg: Dictionary = {}) -> void:
	player.set_altura_colision(tuning.agachado_altura)
	player.wallrun_disponible = true


func exit(_siguiente: StringName = &"") -> void:
	# Solo se restaura la altura si hay sitio. Si el destino es otro estado
	# agachado (Surf, Slide), ya se encargará él de pedir su propia altura.
	if not player.techo_bloquea():
		player.set_altura_colision(1.0)


func physics_update(delta: float) -> void:
	var entrada := buffer.move_vector()
	var dir := sc.direccion_movimiento(entrada, player.camara())

	motor.acelerar(dir * tuning.velocidad_agachado, tuning.aceleracion_suelo * 0.7, delta)
	motor.set_vertical(-2.0)

	# Patada baja: el ataque desde aquí es otro golpe, no el de siempre.
	if player.ataque_agachado != null:
		if buffer.consume(InputActions.ATTACK_LIGHT) or buffer.consume(InputActions.ATTACK_HEAVY):
			fsm.cambiar(&"Attack", {"datos": player.ataque_agachado, "indice": 1})
			return

	if player.consumir_salto():
		_saltar()
		return

	# Levantarse: hay que soltar el botón Y tener hueco encima.
	if not buffer.is_held(InputActions.CROUCH) and not player.techo_bloquea():
		fsm.cambiar(&"Move" if entrada.length() > 0.2 else &"Idle")


## Tres saltos distintos según lo que estés haciendo. Es lo que convierte
## agacharse en un verbo con vocabulario propio en vez de en un modificador.
##
##   quieto        -> BACKFLIP: el doble de fuerza vertical y retroceso hacia
##                    atrás. La parábola sale del empujón, no de la animación.
##   input lateral -> SIDE HOP: brinco rápido y BAJO para evadir de lado.
##   avanzando     -> salto normal, para no premiar agacharse como forma de ir
##                    rápido; de eso ya se encarga el surf.
func _saltar() -> void:
	var entrada := buffer.move_vector()
	var quieto := motor.rapidez_plana() < tuning.crouch_quieto and entrada.length() < 0.25

	if quieto:
		_backflip()
		return

	# Lateral dominante sobre el avance: es una evasión, no un desplazamiento.
	if absf(entrada.x) > absf(entrada.y) + 0.15:
		_side_hop(entrada)
		return

	fsm.cambiar(&"Jump", {"numero": 1}, true)


func _backflip() -> void:
	var atras := -player.direccion_frontal()
	motor.impulso(atras, tuning.backflip_retroceso)
	motor.set_vertical(tuning.velocidad_salto() * tuning.backflip_mult)
	player.girar_visual(tuning.backflip_giro_visual)
	EventBus.camara_shake.emit(0.4, 0.16)
	CombatFX.onda(
		player.get_parent(), player.global_position + Vector3.UP * 0.1,
		player.color_de(&"crema_bruma"), 1.6
	)
	fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true, "sin_corte": true}, true)


func _side_hop(entrada: Vector2) -> void:
	var lateral := sc.direccion_movimiento(Vector2(signf(entrada.x), 0.0), player.camara())
	if lateral.is_zero_approx():
		lateral = sc.plano(player.global_basis.x) * signf(entrada.x)
	motor.impulso(lateral, tuning.sidehop_lateral)
	motor.set_vertical(tuning.sidehop_vertical)
	player.iframes = maxf(player.iframes, tuning.dash_iframes)
	player.orientar_a(lateral)
	fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true, "sin_corte": true}, true)


## El salto alto es suyo: el grupo no puede convertirlo en un salto normal.
func maneja_salto() -> bool:
	return true


func debug_line() -> String:
	var extra := "  TECHO" if player.techo_bloquea() else ""
	var entrada := buffer.move_vector()
	var etiqueta := "quieto → BACKFLIP"
	if motor.rapidez_plana() >= tuning.crouch_quieto or entrada.length() >= 0.25:
		etiqueta = "lateral → side hop" if absf(entrada.x) > absf(entrada.y) + 0.15 else "avanzando"
	return "%s%s" % [etiqueta, extra]
