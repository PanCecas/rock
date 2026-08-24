extends PlayerState
## Correr por una pared lateral. Dura poco y no se puede repetir en la misma pared
## sin tocar suelo: si no, se convierte en volar.
##
## La gravedad crece durante el recorrido en vez de cortarse de golpe al final.
## Así el jugador siente que se le acaba el tiempo antes de que se le acabe.

var _dir: Vector3 = Vector3.ZERO
var _lado: int = 0


func enter(_msg: Dictionary = {}) -> void:
	_lado = player.pared.lado
	_dir = player.pared.direccion_carrera(motor.direccion_plana())
	player.wallrun_disponible = false
	motor.set_vertical(maxf(motor.get_vertical(), 0.0))
	player.orientar_a(_dir)


func exit(_siguiente: StringName = &"") -> void:
	player.set_alabeo(0.0)


func physics_update(delta: float) -> void:
	if not player.pared.hay_pared or player.pared.lado != _lado:
		fsm.cambiar(&"Fall")
		return
	if t > tuning.wallrun_duracion:
		fsm.cambiar(&"Fall")
		return

	_dir = player.pared.direccion_carrera(_dir)
	motor.impulso(_dir, tuning.wallrun_velocidad)
	motor.impulso(-sc.plano(player.pared.normal), 1.5, true)

	# La gravedad entra progresivamente: aviso de que se acaba.
	var progreso := t / tuning.wallrun_duracion
	var vy := motor.get_vertical() + tuning.wallrun_gravedad * progreso * progreso * delta * 3.0
	motor.set_vertical(vy)

	# Inclinar el cuerpo hacia la pared: el alabeo es lo que lo hace legible.
	player.set_alabeo(float(_lado) * 22.0)

	if player.consumir_salto():
		# Saltar de un wall-run sale más fuerte y más hacia delante que de un
		# wall-slide: llevas velocidad y el salto tiene que respetarla.
		player.saltar_de_pared(1.12)
		fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true}, true)


func debug_line() -> String:
	return "%s  %.0f%%" % ["dcha" if _lado > 0 else "izda", 100.0 * t / tuning.wallrun_duracion]
