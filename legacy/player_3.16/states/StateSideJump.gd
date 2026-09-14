extends PlayerState
## SIDE JUMP de Mario 64, en DOS TIEMPOS: primero se planta, despues salta.
##
## Antes era un solo frame: el impulso lateral y el vertical se aplicaban a la vez
## que se cortaba la carrera, y por eso no se leia como una maniobra sino como un
## salto raro que ademas cambiaba de direccion. Lo que hace legible el gesto es la
## PAUSA: el personaje clava los pies, y solo entonces sale disparado.
##
## La preparacion es corta a proposito —unas cinco centesimas—: lo justo para que
## se vea, no lo bastante para que se sienta como un retardo de input.

var _dir: Vector3 = Vector3.ZERO


func enter(msg: Dictionary = {}) -> void:
	_dir = msg.get("direccion", Vector3.ZERO)
	if _dir.is_zero_approx():
		_dir = player.direccion_frontal()
	player.ventana_sidejump = 0.0
	player.orientar_a(_dir)
	# El frenazo empieza YA, y con el pie en el suelo: es la plantada.
	motor.set_vertical(-2.0)
	EventBus.camara_shake.emit(0.16, 0.07)
	CombatFX.onda(
		player.get_parent(), player.global_position + Vector3.UP * 0.1,
		player.color_de(&"crema_bruma"), 1.0
	)


func physics_update(delta: float) -> void:
	# Frenado muy agresivo: la inercia vieja tiene que estar muerta ANTES de que
	# llegue el impulso nuevo, o el salto sale mezclado con la carrera anterior y
	# vuelve a leerse como una sola cosa.
	motor.frenar(tuning.sidejump_frenado, delta)
	motor.set_vertical(-2.0)

	if t < tuning.sidejump_frenazo:
		return

	motor.impulso(_dir, tuning.sidejump_lateral)
	motor.set_vertical(tuning.velocidad_salto() * tuning.sidejump_mult)
	EventBus.camara_shake.emit(0.3, 0.12)
	EventBus.camara_realinear.emit(_dir, tuning.camara_realinea_walljump)
	# `sin_corte`: el boton se pulso hace cinco centesimas y puede estar ya
	# soltado. Recortar el salto por eso seria castigar la propia preparacion.
	fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true, "sin_corte": true}, true)


## El salto ya se consumio al entrar aqui. Sin este guardia, el grupo veria la
## pulsacion todavia en el buffer y lanzaria un salto normal en mitad de la
## plantada. Ver regla dura #13 de CLAUDE.md.
func maneja_salto() -> bool:
	return true


func maneja_ataques() -> bool:
	return true


func debug_line() -> String:
	return "plantando %.0f%%" % (100.0 * t / maxf(tuning.sidejump_frenazo, 0.001))
