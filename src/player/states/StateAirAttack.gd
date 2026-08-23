extends PlayerState
## Ataque aéreo. Casi igual que el de suelo salvo por LA regla que define el
## combate del juego:
##
##   conectar un golpe en el aire RESTAURA una carga de dash.
##
## Ese único detalle convierte el combate en un juego de mantenerte arriba: si
## aciertas, sigues; si fallas, caes. Ver docs/03_ARQUITECTURA_MECANICAS.md §3.3.

var _datos: AttackData
var _frame: int = 0
var _conectado: bool = false
var _dir: Vector3 = Vector3.ZERO


func enter(msg: Dictionary = {}) -> void:
	_datos = msg.get("datos", player.ataque_aereo)
	_frame = 0
	_conectado = false
	_dir = _direccion_ataque()
	player.orientar_a(_dir)
	player.hitbox.nuevo_swing()
	# Frenar la caída al golpear: flotar un instante da tiempo a encadenar.
	motor.set_vertical(minf(motor.get_vertical(), 1.5))


func physics_update(delta: float) -> void:
	if _datos == null:
		fsm.cambiar(&"Fall")
		return

	_frame += 1
	# Gravedad reducida durante el golpe: es lo que sostiene los combos aéreos.
	motor.aplicar_gravedad(delta, 0.35)

	var progreso := float(_frame) / maxf(float(_datos.total_frames()), 1.0)
	var objetivo := _dir * (_datos.avance * _datos.avance_en(progreso) * 0.7)
	var entrada := buffer.move_vector()
	if _datos.movilidad > 0.0 and entrada.length() > 0.2:
		objetivo += sc.direccion_movimiento(entrada, player.camara()) * tuning.velocidad_correr * _datos.movilidad
	if objetivo.length_squared() > 0.01:
		motor.acelerar(objetivo, tuning.aceleracion_aire, delta)

	if _datos.activo_en(_frame):
		if player.hitbox.golpear(_datos, _dir) > 0:
			_al_conectar()

	if player.is_on_floor() and _frame > _datos.frames_windup:
		fsm.cambiar(&"Idle")
		return

	if _cancelaciones():
		return

	if _datos.siguiente != null and _frame >= _datos.frame_cadena:
		if buffer.consume(InputActions.ATTACK_LIGHT):
			fsm.cambiar(&"AirAttack", {"datos": _datos.siguiente}, true)
			return

	if _frame >= _datos.total_frames():
		fsm.cambiar(&"Fall")


func _direccion_ataque() -> Vector3:
	if _datos != null and _datos.autoencarar:
		var hacia := player.targeting.direccion_a_objetivo()
		if not hacia.is_zero_approx():
			return hacia
	var entrada := sc.direccion_movimiento(buffer.move_vector(), player.camara())
	return entrada if not entrada.is_zero_approx() else player.direccion_frontal()


func _al_conectar() -> void:
	_conectado = true
	# LA regla del sistema.
	player.dash_cargas = maxi(player.dash_cargas, tuning.dash_cargas_aire)
	player.saltos_aereos = maxi(player.saltos_aereos, 1)
	# Y un pequeño rebote hacia arriba: te quedas arriba mientras aciertes.
	motor.set_vertical(maxf(motor.get_vertical(), 2.2))

	HitstopManager.golpe(_datos.hitstop, [player])
	EventBus.camara_shake.emit(_datos.shake, 0.12)
	CombatFX.arco(
		player.get_parent(),
		player.global_position + Vector3.UP * _datos.altura + _dir * (_datos.alcance * 0.45),
		_dir,
		player.color_de(_datos.color_vfx),
		_datos.alcance * 0.9
	)


func _cancelaciones() -> bool:
	var g := grupo as PlayerStateGroup
	if g == null:
		return false
	if player.puede_dashear() and buffer.peek(InputActions.DASH):
		if g.puede_cancelar(&"dash", _datos, _frame, _conectado):
			buffer.consume(InputActions.DASH)
			fsm.cambiar(&"Dash")
			return true
	if player.saltos_aereos > 0 and buffer.peek(InputActions.JUMP, tuning.jump_buffer):
		if g.puede_cancelar(&"jump", _datos, _frame, _conectado):
			player.consumir_salto()
			player.saltos_aereos -= 1
			fsm.cambiar(&"Jump", {"numero": 2})
			return true
	return false


func debug_line() -> String:
	if _datos == null:
		return "—"
	return "aéreo f%d/%d%s" % [_frame, _datos.total_frames(), "  hit" if _conectado else ""]
