extends PlayerState
## Nado en superficie. Movimiento 2D sobre el plano del agua, con el cuerpo
## flotando a una altura fija.
##
## La flotación es un muelle hacia el nivel del agua, no una condición booleana:
## así entrar desde una caída se amortigua solo y el personaje emerge en vez de
## aparecer clavado en la superficie.
##
## Salidas: `crouch` (C) bucea · salto salta fuera del agua.

## Cuánto del cuerpo queda por encima de la línea de flotación.
const CALADO := 1.05


func enter(_msg: Dictionary = {}) -> void:
	player.set_altura_colision(1.0)
	player.set_alabeo(0.0)
	# Cortar la caída al entrar: llegar a 40 m/s y seguir bajando hunde al
	# personaje hasta el fondo antes de que el muelle pueda hacer nada.
	motor.set_vertical(maxf(motor.get_vertical(), -3.0))


func physics_update(delta: float) -> void:
	var entrada := buffer.move_vector()
	var dir := sc.direccion_movimiento(entrada, player.camara())
	motor.acelerar(dir * tuning.nado_velocidad, tuning.agua_rozamiento * 2.0, delta)

	# Muelle hacia la línea de flotación.
	var objetivo := player.agua.nivel - CALADO
	var error := objetivo - player.global_position.y
	var vy := motor.get_vertical() + error * tuning.agua_flotacion * delta
	motor.set_vertical(lerpf(vy, 0.0, 1.0 - exp(-tuning.agua_rozamiento * delta)))

	if player.orientar_si_se_mueve():
		pass

	# Bucear.
	if buffer.consume(InputActions.CROUCH):
		fsm.cambiar(&"Underwater", {"direccion": dir})
		return

	# Saltar fuera del agua. No usa `consumir_salto()` a propósito: no gasta
	# saltos aéreos, es una salida del medio, no un salto.
	if buffer.consume(InputActions.JUMP, tuning.jump_buffer):
		motor.set_vertical(tuning.velocidad_salto() * 0.75)
		player.recargar_aire()
		fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true, "sin_corte": true}, true)


func debug_line() -> String:
	return "%.1f m/s   C = bucear" % motor.rapidez_plana()
