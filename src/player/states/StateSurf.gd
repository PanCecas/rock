extends PlayerState
## La carrera rápida del juego, y el tramo fluido que sigue al esquive.
##
## El dash es un ESQUIVE: corto, seco, unidireccional. Si al terminarlo sigues
## manteniendo Shift, no frenas: entras aquí.
##
## NO CADUCA. Mientras mantengas Shift sigues surfeando; al soltarlo, sales. Un
## temporizador obligaba a redashear cada segundo para mantener la velocidad, que
## es justo lo contrario de la sensación continua que se busca. El único límite es
## la stamina.
##
## Escalera completa de velocidad:
##   sin Shift  ->  caminar -> trotar -> correr  (rampa progresiva por tiempo)
##   con Shift  ->  dash (esquive) -> SURF (fluido y sostenido)

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
	# Surfeando se va agachado: la capsula baja a la mitad. Ademas de venderlo
	# visualmente, es lo que deja pasar por los tuneles sin soltar la velocidad.
	player.pedir_postura(tuning.agachado_altura)


func exit(siguiente: StringName = &"") -> void:
	player.set_alabeo(0.0)
	# Saltar NO cancela el surf: se marca pendiente y se recupera al aterrizar.
	# Perder la linea rapida por haber saltado un bache es exactamente el tipo de
	# castigo que rompe el ritmo de un juego de movilidad.
	if fsm.es_aereo(siguiente) and _shift_mantenido():
		player.surf_pendiente = tuning.surf_persistencia
		player.surf_rapidez = _rapidez


func physics_update(delta: float) -> void:
	player.pedir_postura(tuning.agachado_altura)
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

	# El envión del dash se gasta y queda la velocidad de crucero. A partir de ahí
	# se sostiene indefinidamente: el surf es la carrera rápida, no un impulso.
	_rapidez = maxf(_rapidez - tuning.surf_friccion * delta, tuning.surf_crucero)

	motor.impulso(_dir, _rapidez)
	# Pegarse al suelo SOLO si hay suelo. Forzar la vertical en el aire es lo que
	# convertia salirse de una plataforma en un descenso flotante.
	if player.is_on_floor():
		motor.set_vertical(-2.0)
	else:
		_terminar_en_aire()
		return

	_alabeo = lerpf(_alabeo, -giro * tuning.surf_alabeo, 1.0 - exp(-7.0 * delta))
	player.set_alabeo(_alabeo)

	# El salto del surf es suyo, y tiene dos formas:
	#   agachado -> LONG JUMP: convierte el momentum en distancia, no en altura.
	#   normal   -> salto corriente, pero el surf queda pendiente y se recupera
	#               al aterrizar (lo marca exit()).
	if player.consumir_salto():
		if buffer.is_held(InputActions.CROUCH):
			motor.impulso(_dir, _rapidez * tuning.longjump_mult)
			motor.set_vertical(tuning.longjump_vertical)
			EventBus.camara_shake.emit(0.3, 0.14)
			fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true, "sin_corte": true}, true)
		else:
			fsm.cambiar(&"Jump", {"numero": 1}, true)
		return

	# Deslizarse desde el surf: entras al slide con toda la velocidad acumulada.
	if buffer.consume(InputActions.CROUCH):
		fsm.cambiar(&"Slide")
		return

	# Los DOS ataques de surf. Se gestionan aqui —y `maneja_ataques()` impide que
	# GroupGrounded los intercepte— porque atacar surfeando tiene que dar un golpe
	# de surf, no el ataque de suelo de siempre.
	#
	#   ligero -> estocada de esgrima: rapida, hacia donde miras, proyectandote
	#             hacia delante y conservando la forma fluida del surf.
	#   pesado -> frenazo en seco y empujon fuerte que manda al enemigo atras.
	if player.ataque_surf_pesado != null and buffer.consume(InputActions.ATTACK_HEAVY):
		fsm.cambiar(&"Attack", {"datos": player.ataque_surf_pesado, "indice": 1, "desde_surf": true})
		return
	if player.ataque_surf_ligero != null and buffer.consume(InputActions.ATTACK_LIGHT):
		fsm.cambiar(&"Attack", {
			"datos": player.ataque_surf_ligero, "indice": 1,
			"desde_surf": true, "direccion": _dir,
		})
		return


## Salir del surf es volver a la locomoción normal, que arranca su rampa desde la
## velocidad que traigas.
func _terminar() -> void:
	fsm.cambiar(&"Move" if buffer.move_vector().length() > 0.2 else &"Idle")


## Los ataques y el salto del surf son suyos: el grupo no puede robarle la
## pulsacion y convertirlos en la version generica.
## Salirse de la plataforma corta el surf, pero no la LINEA: se marca pendiente
## igual que al saltar, asi que caer a la siguiente plataforma manteniendo Shift
## te devuelve surfeando. Perder la velocidad por un desnivel seria el mismo
## castigo que perderla por saltar, y ya decidimos que ese castigo sobra.
func _terminar_en_aire() -> void:
	fsm.cambiar(&"Fall")


func maneja_ataques() -> bool:
	return true


func maneja_salto() -> bool:
	return true


func _shift_mantenido() -> bool:
	return buffer.is_held(InputActions.DASH) or buffer.is_held(InputActions.SPRINT)


func debug_line() -> String:
	return "%.1f m/s  stam %.0f%%" % [_rapidez, player.stamina.fraccion() * 100.0]
