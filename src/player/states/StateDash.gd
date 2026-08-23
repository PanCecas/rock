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


func enter(_msg: Dictionary = {}) -> void:
	_era_aereo = not player.is_on_floor()

	_dir = sc.direccion_movimiento(buffer.move_vector(), player.camara())
	if _dir.is_zero_approx():
		_dir = motor.direccion_plana()
	if _dir.is_zero_approx():
		_dir = sc.plano(-player.global_basis.z).normalized()

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

	if _pivotar():
		return

	# Ataque de dash: el golpe sale desde el esquive y hereda su dirección.
	if player.ataque_dash != null and buffer.consume(InputActions.ATTACK_LIGHT):
		fsm.cambiar(&"Attack", {"datos": player.ataque_dash, "indice": 1})
		return

	_corregir_rumbo(delta)
	motor.impulso(_dir, tuning.velocidad_dash())
	motor.set_vertical(0.0)

	# Chocar lo corta en seco en vez de rasparse toda la pared.
	if player.is_on_wall() and t > 0.03:
		_salir()


## PIVOTE (frenada estilo Mario 64): pedir la dirección CONTRARIA en mitad del
## dash no gira, frena en seco y salta.
##
## Es una salida de emergencia con intención: cortas el compromiso del dash, matas
## el momentum y ganas altura para replantear. Y como cuesta un salto aéreo, no
## sale gratis encadenarlo.
##
## Devuelve true si ha pivotado (y por tanto el dash ya no debe seguir).
func _pivotar() -> bool:
	if t < tuning.dash_duracion * tuning.dash_pivote_min:
		return false
	var entrada := buffer.move_vector()
	if entrada.length() < 0.7:
		return false
	var deseada := sc.direccion_movimiento(entrada, player.camara())
	if deseada.is_zero_approx() or deseada.dot(_dir) > tuning.dash_pivote_umbral:
		return false

	# Frenazo: se tira TODO el momentum del dash y se sale despacio hacia atrás.
	motor.impulso(deseada, tuning.dash_pivote_impulso)
	player.orientar_a(deseada)
	player.iframes = maxf(player.iframes, tuning.dash_iframes * 0.5)
	EventBus.camara_shake.emit(0.35, 0.1)
	CombatFX.impacto(
		player.get_parent(), player.global_position + Vector3.UP * 0.15,
		player.color_de(&"crema_bruma"), 0.9
	)
	# `conservar_vertical` porque el salto del pivote lo fijamos aquí: es más alto
	# que un salto normal a propósito.
	motor.set_vertical(tuning.dash_pivote_salto)
	fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true, "sin_corte": true})
	return true


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
func _salir() -> void:
	var mantenido := buffer.is_held(InputActions.DASH) or buffer.is_held(InputActions.SPRINT)

	if not player.is_on_floor():
		motor.impulso(_dir, maxf(tuning.velocidad_correr, motor.rapidez_plana() * tuning.dash_salida_mult))
		fsm.cambiar(&"Fall")
		return

	if mantenido and not player.stamina.vacia():
		fsm.cambiar(&"Surf", {"direccion": _dir, "rapidez": tuning.surf_velocidad})
		return

	# Sin Shift no hay carrera rápida: se cae a trotar y de ahí a caminar.
	motor.impulso(_dir, maxf(tuning.velocidad_correr, motor.rapidez_plana() * tuning.dash_salida_mult))
	fsm.cambiar(&"Move" if buffer.move_vector().length() > 0.2 else &"Idle")


func debug_line() -> String:
	return "%.0f%%  %s  ->%s" % [
		100.0 * t / tuning.dash_duracion,
		"aéreo" if _era_aereo else "suelo",
		"surf" if buffer.is_held(InputActions.DASH) else "move",
	]
