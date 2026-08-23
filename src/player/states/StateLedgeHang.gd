extends PlayerState
## Colgado de un canto. Sin gravedad, la stamina baja despacio, y desde aquí se
## puede subir, desplazarse de lado, saltar o soltarse.
##
## En la Fase 4 este mismo estado sostendrá al jugador de una cornisa de coloso
## mientras el bicho camina: el SurfaceContext se encarga del arrastre.

var _punto: Vector3 = Vector3.ZERO
var _normal: Vector3 = Vector3.FORWARD


func enter(_msg: Dictionary = {}) -> void:
	_punto = player.borde.punto
	_normal = player.borde.normal_pared
	player.global_position = player.borde.pose_colgado()
	player.velocity = Vector3.ZERO
	player.orientar_a(-sc.plano(_normal))
	player.recargar_aire()
	# Enganchar el marco de referencia: si el borde se mueve, el jugador va con él.
	sc.set_frame(player.borde.colisionador)


func exit() -> void:
	if fsm.actual != null and fsm.actual.categoria != &"Attached":
		sc.set_frame(null)


func physics_update(delta: float) -> void:
	player.velocity = Vector3.ZERO
	player.stamina.drenar(tuning.stamina_escalar * 0.35, delta)

	var entrada := buffer.move_vector()

	# Subir: empujar hacia arriba. Salto ya NO sube, salta.
	if entrada.y < -0.5:
		fsm.cambiar(&"LedgeClimb", {"punto": _punto, "normal": _normal})
		return

	# Saltar DESDE el canto. Sin input sales hacia arriba; con input, hacia donde
	# apuntes. Y se recarga el aire, así que encadenas el doble salto en el vacío:
	# es la maniobra que abre las rutas verticales del juego.
	if buffer.consume(InputActions.JUMP, tuning.jump_buffer):
		_saltar_del_canto(entrada)
		return

	# Soltarse hacia abajo.
	if entrada.y > 0.6:
		player.tiempo_sin_borde = 0.35
		fsm.cambiar(&"Fall")
		return

	# Desplazamiento lateral sobre el canto.
	if absf(entrada.x) > 0.3:
		var lateral := sc.up.cross(sc.plano(_normal)).normalized()
		var destino := player.global_position + lateral * signf(entrada.x) * tuning.shimmy_velocidad * delta
		if _hay_canto_en(destino):
			player.global_position = destino
			player.stamina.drenar(tuning.stamina_escalar * 0.4, delta)


func _saltar_del_canto(entrada: Vector2) -> void:
	if not player.stamina.gastar(tuning.stamina_escalar * 1.2):
		return
	var direccion := sc.direccion_movimiento(entrada, player.camara())
	if direccion.is_zero_approx():
		# Sin input: un empujón mínimo hacia fuera para no rozar la pared al subir.
		direccion = sc.plano(_normal).normalized() * 0.35
	# El salto de canto no se despega para atrás salvo que lo pidas: si empujas
	# hacia la pared quieres subir en vertical, no rebotar.
	motor.impulso(direccion, tuning.walljump_lateral * 0.85)
	player.recargar_aire()
	# Bloqueo corto del reenganche, o vuelves a agarrarte al mismo canto al instante.
	player.tiempo_sin_borde = 0.3
	fsm.cambiar(&"Jump", {"numero": 1, "extra": tuning.velocidad_salto() * 0.12})


## Comprueba que el canto siga existiendo antes de deslizarse a ese punto: sin
## esto el jugador se sale por el extremo de la repisa flotando.
func _hay_canto_en(pos: Vector3) -> bool:
	var espacio := player.get_world_3d().direct_space_state
	var arriba := pos + sc.up * 1.6
	var q := PhysicsRayQueryParameters3D.create(
		arriba - sc.plano(_normal).normalized() * 0.35,
		arriba - sc.plano(_normal).normalized() * 0.35 - sc.up * 0.9,
		Layers.SUELO_JUGADOR
	)
	q.exclude = [player.get_rid()]
	return not espacio.intersect_ray(q).is_empty()


func debug_line() -> String:
	return "stam %.0f%%" % (player.stamina.fraccion() * 100.0)
