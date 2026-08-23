extends PlayerState
## Buceo. Movimiento 3D completo: la cámara decide hacia dónde nadas, incluida la
## vertical, que es lo que separa bucear de "nadar más hondo".
##
## Entrar aquí desde un DIVE no es lo mismo que entrar cayendo: el clavado gana
## profundidad y dibuja la curva del esquema. Una caída normal solo se hunde un
## poco y sube a flotar.
##
## Salida: mantener salto asciende, y al romper la superficie se pasa a nado de
## superficie automáticamente.


func enter(msg: Dictionary = {}) -> void:
	player.set_altura_colision(1.0)
	player.set_alabeo(0.0)

	if bool(msg.get("clavado", false)):
		# CLAVADO: se conserva la velocidad del dive y se le suma penetración.
		# Es la curva profunda del esquema, y la recompensa por haber entrado bien.
		var dir: Vector3 = msg.get("direccion", motor.direccion_plana())
		if not dir.is_zero_approx():
			motor.impulso(dir, maxf(motor.rapidez_plana(), tuning.dive_impulso))
		motor.set_vertical(-tuning.dive_penetracion)
		EventBus.camara_shake.emit(0.5, 0.2)
		CombatFX.onda(
			player.get_parent(),
			Vector3(player.global_position.x, player.agua.nivel, player.global_position.z),
			player.color_de(&"blanco_tiza"), 3.0
		)
	else:
		motor.set_vertical(minf(motor.get_vertical(), -tuning.buceo_impulso))


func physics_update(delta: float) -> void:
	var entrada := buffer.move_vector()
	var cam := player.camara()

	# Movimiento 3D de verdad: se usa la base COMPLETA de la cámara, con su
	# componente vertical. Proyectarla al plano convertiría el buceo en nadar
	# en un techo invisible.
	var dir := Vector3.ZERO
	if cam != null and entrada.length() > 0.15:
		dir = (-cam.global_basis.z * -entrada.y + cam.global_basis.x * entrada.x).normalized()

	var deseada := dir * tuning.buceo_velocidad

	# Mantener salto sube. Es el ascenso, no un salto.
	if buffer.is_held(InputActions.JUMP):
		deseada += Vector3.UP * tuning.buceo_ascenso
	elif buffer.is_held(InputActions.CROUCH):
		deseada += Vector3.DOWN * tuning.buceo_ascenso * 0.8

	player.velocity = player.velocity.lerp(deseada, 1.0 - exp(-tuning.agua_rozamiento * delta))

	if not dir.is_zero_approx():
		player.orientar_a(dir)

	# Romper la superficie devuelve a nado de superficie, sin pedir permiso.
	if not player.agua.sumergido() and motor.get_vertical() >= 0.0:
		fsm.cambiar(&"Swim")


func debug_line() -> String:
	return "prof %.1f m   salto = subir" % player.agua.profundidad
