extends PlayerState
## El tramo fluido entre el esquive y la carrera.
##
## El dash es un ESQUIVE: corto, seco, unidireccional. Si al terminarlo sigues
## manteniendo Shift, no frenas: entras aquí. Surf es un estado deslizante y muy
## pilotable —la idea es "como el agua"— que conserva el momentum del dash, se
## agota solo y entrega el testigo al sprint.
##
## Esa es la escalera completa de velocidad:
##   sin Shift  ->  caminar / trotar
##   Shift      ->  dash (esquive) -> SURF (fluido) -> sprint (sostenido)
##
## Antes esto no existía y el dash intentaba ser las dos cosas: por eso se sentía
## largo y raro. Separarlos deja que cada uno haga bien una sola cosa.

var _dir: Vector3 = Vector3.ZERO
var _rapidez: float = 0.0
var _alabeo: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	_dir = msg.get("direccion", motor.direccion_plana())
	if _dir.is_zero_approx():
		_dir = player.direccion_frontal()
	_rapidez = maxf(float(msg.get("rapidez", 0.0)), tuning.surf_velocidad)
	_alabeo = 0.0
	player.orientar_a(_dir)


func exit() -> void:
	player.set_alabeo(0.0)


func physics_update(delta: float) -> void:
	# Soltar Shift corta el surf en el acto: es un estado que se sostiene a mano.
	if not _shift_mantenido() or player.stamina.vacia():
		_terminar()
		return

	player.stamina.drenar(tuning.surf_stamina, delta)

	# Pilotar. El giro es alto a propósito: es LO que hace que esto se sienta
	# fluido en vez de un empujón con inercia.
	var entrada := buffer.move_vector()
	var giro := 0.0
	if entrada.length() > 0.2:
		var deseada := sc.direccion_movimiento(entrada, player.camara())
		if not deseada.is_zero_approx():
			var peso: float = clampf(deg_to_rad(tuning.surf_giro_grados_seg) * delta, 0.0, 1.0)
			var nueva := _dir.slerp(deseada, peso).normalized()
			giro = signf(sc.up.dot(_dir.cross(nueva)))
			_dir = nueva

	# La velocidad decae hacia el sprint: al acabar el surf ya vas a su ritmo y
	# la transición a correr no se nota como un frenazo.
	_rapidez = maxf(_rapidez - tuning.surf_friccion * delta, tuning.velocidad_sprint)

	motor.impulso(_dir, _rapidez)
	motor.set_vertical(-2.0)

	_alabeo = lerpf(_alabeo, -giro * tuning.surf_alabeo, 1.0 - exp(-7.0 * delta))
	player.set_alabeo(_alabeo)

	# Deslizarse desde el surf: entras al slide con toda la velocidad acumulada.
	if buffer.consume(InputActions.CROUCH):
		fsm.cambiar(&"Slide")
		return

	# Ataque en carrera: el golpe hereda el momentum del surf.
	if player.ataque_dash != null and buffer.consume(InputActions.ATTACK_LIGHT):
		fsm.cambiar(&"Attack", {"datos": player.ataque_dash, "indice": 1})
		return

	if t >= tuning.surf_duracion:
		_terminar()


## Salir del surf es entrar en Move. Si Shift sigue pulsado, Move ya corre en
## sprint por sí solo, así que la escalera se completa sin un estado extra.
func _terminar() -> void:
	fsm.cambiar(&"Move" if buffer.move_vector().length() > 0.2 else &"Idle")


func _shift_mantenido() -> bool:
	return buffer.is_held(InputActions.DASH) or buffer.is_held(InputActions.SPRINT)


func debug_line() -> String:
	return "%.1f m/s  %.0f%%" % [_rapidez, 100.0 * t / maxf(tuning.surf_duracion, 0.001)]
