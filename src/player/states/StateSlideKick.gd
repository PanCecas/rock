extends PlayerState
## Patada deslizante — el salto de conejo de Mario 64.
##
## Sale del agachado en movimiento y te lanza hacia delante casi a ras de suelo,
## con la hitbox viva todo el trayecto. No es un golpe con ventana activa: es un
## desplazamiento que hace daño, igual que el clavado.
##
## Al acabar te deja agachado, no de pie: encadenar patada tras patada es posible
## y es exactamente el tipo de tontería que hace divertido un plataformero.

var _dir: Vector3 = Vector3.ZERO
var _aterrizado: bool = false


func enter(msg: Dictionary = {}) -> void:
	_dir = msg.get("direccion", motor.direccion_plana())
	if _dir.is_zero_approx():
		_dir = player.direccion_frontal()
	_aterrizado = false
	player.pedir_postura(tuning.agachado_altura)
	player.hitbox.nuevo_swing()
	player.orientar_a(_dir)
	EventBus.camara_shake.emit(0.3, 0.12)
	CombatFX.arco(
		player.get_parent(), player.global_position + Vector3.UP * 0.4, _dir,
		player.color_de(&"oro_palido"), 1.8
	)


func physics_update(delta: float) -> void:
	player.pedir_postura(tuning.agachado_altura)
	var datos: AttackData = player.ataque_slide_kick
	motor.aplicar_gravedad(delta)

	if datos != null and player.hitbox.golpear(datos, _dir) > 0:
		HitstopManager.golpe(datos.hitstop, [player])
		EventBus.camara_shake.emit(datos.shake, 0.14)
		CombatFX.impacto(
			player.get_parent(), player.global_position + Vector3.UP * 0.5,
			player.color_de(datos.color_vfx), 1.2
		)

	if player.is_on_floor():
		if not _aterrizado:
			_aterrizado = true
		# Ya en el suelo, la patada se arrastra y frena, pero con SU rozamiento: con
		# el del agachado se paraba en dos metros y no llegaba a ser movilidad.
		motor.frenar(tuning.slide_kick_friccion, delta)
		motor.set_vertical(-2.0)

	if _aterrizado and motor.rapidez_plana() < tuning.velocidad_agachado:
		# Se sale agachado, no de pie: encadenar patadas es parte del juguete.
		fsm.cambiar(&"Crouch")


func debug_line() -> String:
	return "%.1f m/s%s" % [motor.rapidez_plana(), "  suelo" if _aterrizado else "  aire"]
