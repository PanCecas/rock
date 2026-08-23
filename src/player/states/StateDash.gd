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

	_corregir_rumbo(delta)
	motor.impulso(_dir, tuning.velocidad_dash())
	motor.set_vertical(0.0)

	# Chocar lo corta en seco en vez de rasparse toda la pared.
	if player.is_on_wall() and t > 0.03:
		_salir()


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


func _salir() -> void:
	# HOLD: el botón sigue pulsado más allá del umbral de tap -> sprint continuo.
	var mantenido := (
		buffer.is_held(InputActions.DASH)
		and buffer.held_time(InputActions.DASH) >= tuning.dash_tap_max
	)
	var sprint := mantenido or buffer.is_held(InputActions.SPRINT)

	# Conservar momentum, no frenar en seco: es lo que encadena los verbos.
	# StateMove deja que esta velocidad extra baje despacio (`frenado_momentum`).
	var suelo: float = tuning.velocidad_sprint if sprint else tuning.velocidad_correr
	motor.impulso(_dir, maxf(suelo, motor.rapidez_plana() * tuning.dash_salida_mult))

	if not player.is_on_floor():
		fsm.cambiar(&"Fall")
		return
	# Manteniendo se sale corriendo aunque el stick esté al ralentí ese frame:
	# soltar el dash no debería costarte la carrera.
	if mantenido or buffer.move_vector().length() > 0.2:
		fsm.cambiar(&"Move")
	else:
		fsm.cambiar(&"Idle")


func debug_line() -> String:
	return "%.0f%%  %s  %s" % [
		100.0 * t / tuning.dash_duracion,
		"aéreo" if _era_aereo else "suelo",
		"HOLD" if buffer.held_time(InputActions.DASH) >= tuning.dash_tap_max else "tap",
	]
