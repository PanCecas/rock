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
	# ENTRAR AL AGUA SIN CHASQUIDO. Nadar en superficie es un cuerpo derecho, y
	# aqui se llega desde cualquier cosa: un clavado con el morro hacia abajo, una
	# caida, o emerger buceando. Se interpola a la vertical en vez de imponerla,
	# que es lo que daba el volteo raro al tocar el agua.
	player.enderezar()
	# Cortar la caída al entrar: llegar a 40 m/s y seguir bajando hunde al
	# personaje hasta el fondo antes de que el muelle pueda hacer nada.
	motor.set_vertical(maxf(motor.get_vertical(), -3.0))


func physics_update(delta: float) -> void:
	var entrada := buffer.move_vector()
	var dir := sc.direccion_movimiento(entrada, player.camara())
	# Shift tambien vale en el agua: nadar rapido es un verbo, no un lujo.
	var mult := tuning.nado_sprint_mult if player.quiere_sprint() else 1.0
	motor.acelerar(dir * tuning.nado_velocidad * mult, tuning.agua_rozamiento * 2.0, delta)

	# Solo cansa nadar de verdad. Flotar es gratis y ademas recupera.
	if entrada.length() > 0.2:
		player.stamina.drenar(tuning.agua_stamina * mult, delta)
	else:
		player.stamina.regenerar(tuning.stamina_regen_colgado, delta)

	# Muelle hacia la línea de flotación.
	var objetivo := player.agua.nivel - CALADO
	var error := objetivo - player.global_position.y
	var vy := motor.get_vertical() + error * tuning.agua_flotacion * delta
	motor.set_vertical(lerpf(vy, 0.0, 1.0 - exp(-tuning.agua_rozamiento * delta)))

	if player.orientar_si_se_mueve():
		pass

	# Los ataques tambien existen en superficie, y son los mismos: un impulso con
	# hitbox. No hay dos movesets, hay uno que respeta el medio.
	if player.ataque_agua_pesado != null and buffer.consume(InputActions.ATTACK_HEAVY):
		fsm.cambiar(&"WaterAttack", {
			"datos": player.ataque_agua_pesado,
			"impulso": tuning.agua_ataque_pesado_impulso,
			"direccion": player.direccion_nado(),
		})
		return
	if player.ataque_agua_ligero != null and buffer.consume(InputActions.ATTACK_LIGHT):
		fsm.cambiar(&"WaterAttack", {
			"datos": player.ataque_agua_ligero,
			"impulso": tuning.agua_ataque_ligero_impulso,
			"direccion": player.direccion_nado(),
		})
		return

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


func maneja_ataques() -> bool:
	return true


func debug_line() -> String:
	return "%.1f m/s%s   C = bucear" % [motor.rapidez_plana(), "  SPRINT" if player.quiere_sprint() else ""]
