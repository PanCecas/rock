extends PlayerState
## Evasión estilo NieR: Automata. Se entra desde suelo, aire y colgado, por eso
## vive fuera de los tres grupos.
##
## Dos diferencias con un dash clásico y las dos importan:
##
## 1. NO BLOQUEA LA DIRECCIÓN. Puedes corregir el rumbo mientras dura
##    (`dash_giro_grados_seg`). Un dash que ignora el stick se siente escriptado;
##    uno que responde se siente como una decisión que sigues tomando.
## 2. TAP vs HOLD. Soltar = evasión corta y se acabó. Mantener = la evasión
##    desemboca en sprint continuo sin soltar el botón ni volver a pulsarlo.
##
## Durante el dash la gravedad se apaga del todo: un dash que se hunde no es un dash.

var _dir: Vector3 = Vector3.ZERO
var _era_aereo: bool = false
## Rapidez del esquive. SUELO: `max(la que traías, velocidad_dash())`. Ver `enter`.
var _rapidez: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_era_aereo = not player.is_on_floor()

	_dir = sc.direccion_movimiento(buffer.move_vector(), player.camara())
	if _dir.is_zero_approx():
		_dir = motor.direccion_plana()
	if _dir.is_zero_approx():
		_dir = sc.plano(-player.global_basis.z).normalized()

	# UN SUELO, NO UN VALOR. Misma lección que la patada y la misma llamada
	# culpable: `motor.impulso()` con `conservar = false` REEMPLAZA el vector
	# horizontal entero, y aquí se escribía cada frame. Dashear saliendo de un arco
	# a 34 m/s te dejaba a 30: el esquive te cobraba 4 m/s por usarlo. El dash
	# GARANTIZA su velocidad; si llegabas más rápido, mandas tú. Regla dura #29.
	_rapidez = maxf(motor.rapidez_plana(), tuning.velocidad_dash())

	if _era_aereo:
		player.dash_cargas -= 1
	player.stamina.gastar(tuning.stamina_dash)
	player.iframes = tuning.dash_iframes
	player.orientar_a(_dir)
	EventBus.player_dashed.emit(_dir)


func physics_update(delta: float) -> void:
	if t >= tuning.dash_duracion:
		_salir()
		return


	_corregir_rumbo(delta)
	motor.impulso(_dir, _rapidez)
	motor.set_vertical(0.0)

	# Chocar lo corta en seco en vez de rasparse toda la pared.
	if player.is_on_wall() and t > 0.03:
		_salir()


## EL PIVOTE SE MUDO A `StateSlide`. Desde el 4.04 el dash solo existe EN EL
## AIRE, y el pivote siempre estuvo prohibido en vuelo —«frenar en seco es una
## maniobra de pies»—, asi que aqui se habia quedado en codigo que no se podia
## alcanzar. Lo cazo `TestFase2`, que seguia pidiendoselo al dash.


## La corrección que separa una evasión viva de un empujón escriptado.
func _corregir_rumbo(delta: float) -> void:
	var entrada := buffer.move_vector()
	if entrada.length() < 0.25:
		return
	var deseada := sc.direccion_movimiento(entrada, player.camara())
	if deseada.is_zero_approx():
		return
	var peso: float = clampf(deg_to_rad(tuning.dash_giro_grados_seg) * delta, 0.0, 1.0)
	_dir = _dir.slerp(deseada, peso).normalized()
	player.orientar_a(_dir)


## El dash NO decide la velocidad de salida: decide a qué estado entrega.
##
##   Shift mantenido + suelo  ->  SURF (el tramo fluido que luego da paso al sprint)
##   Shift suelto             ->  Move / Idle, conservando algo de momentum
##   en el aire               ->  Fall
## Un dash es un ESQUIVE de 0.12 s. Nadie esquiva hacia una pared para trepar por
## ella, y el agarre a mano sigue estando ahi para quien si lo quiera.
func adherencia_automatica() -> bool:
	return false


func _salir() -> void:
	var mantenido := buffer.is_held(InputActions.DASH) or buffer.is_held(InputActions.SPRINT)

	if not player.is_on_floor():
		motor.impulso(_dir, maxf(tuning.velocidad_correr, motor.rapidez_plana() * tuning.dash_salida_mult))
		# Dash en el aire manteniendo Shift: se marca el surf pendiente y el
		# aterrizaje entra en surf solo. Encadenar aire y suelo no deberia exigir
		# soltar y volver a pulsar en el frame exacto del contacto.
		if mantenido:
			player.surf_pendiente = tuning.surf_persistencia
			player.surf_rapidez = maxf(tuning.surf_velocidad, motor.rapidez_plana())
		fsm.cambiar(&"Fall")
		return

	if mantenido and not player.stamina.vacia():
		fsm.cambiar(&"Surf", {"direccion": _dir, "rapidez": tuning.surf_velocidad})
		return

	# Sin Shift no hay carrera rápida: se cae a trotar y de ahí a caminar.
	motor.impulso(_dir, maxf(tuning.velocidad_correr, motor.rapidez_plana() * tuning.dash_salida_mult))
	fsm.cambiar(&"Move" if buffer.move_vector().length() > 0.2 else &"Idle")


## El techo del esquive es su propia rapidez, y se declara en vez de dejar que el
## soft cap la vaya mordiendo: un dash dura 0.12 s y su velocidad es un número
## fijo del verbo, no momentum acumulado que tenga que decaer.
func techo_velocidad() -> float:
	return maxf(_rapidez, tuning.velocidad_dash())


func debug_line() -> String:
	return "%.0f%%  %s  ->%s" % [
		100.0 * t / tuning.dash_duracion,
		"aéreo" if _era_aereo else "suelo",
		"surf" if buffer.is_held(InputActions.DASH) else "move",
	]
