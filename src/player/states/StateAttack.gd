extends PlayerState
## Ataque en suelo. Un solo estado para toda la cadena: el AttackData dice qué
## golpe es, cuánto dura, cuándo pega y con qué encadena.
##
## REGLA (CLAUDE.md #1 y arquitectura §3.1): aquí no hay ni un número de combate.
## Si un golpe hay que afinarlo, se toca su .tres.

var _datos: AttackData
var _frame: int = 0
var _conectado: bool = false
var _dir: Vector3 = Vector3.ZERO
var _indice: int = 1


func enter(msg: Dictionary = {}) -> void:
	_datos = msg.get("datos", player.ataque_ligero)
	_indice = int(msg.get("indice", 1))
	_frame = 0
	_conectado = false

	_dir = _direccion_ataque()
	player.orientar_a(_dir)
	player.hitbox.nuevo_swing()
	# Amortiguar lo que traías, NO borrarlo. Poner la velocidad a cero en cada
	# golpe es lo que hace que un combo se sienta como una animación en la que te
	# quedas clavado en vez de como una pelea en la que sigues mandando.
	player.velocity = sc.plano(player.velocity) * 0.45 + sc.up * sc.vertical(player.velocity)


func physics_update(delta: float) -> void:
	if _datos == null:
		fsm.cambiar(&"Idle")
		return

	_frame += 1
	_avanzar(delta)
	motor.set_vertical(-2.0)

	if _datos.activo_en(_frame):
		if player.hitbox.golpear(_datos, _dir) > 0:
			_al_conectar()

	if _cancelaciones():
		return

	# Encadenar al siguiente golpe de la cadena ligera.
	if _datos.siguiente != null and _frame >= _datos.frame_cadena:
		if buffer.consume(InputActions.ATTACK_LIGHT):
			# reentrar=true: encadenar es volver a entrar en Attack con otro golpe.
			fsm.cambiar(&"Attack", {"datos": _datos.siguiente, "indice": _indice + 1}, true)
			return

	if _frame >= _datos.total_frames():
		fsm.cambiar(&"Move" if buffer.move_vector().length() > 0.2 else &"Idle")


## El ataque encara al objetivo del soft-lock si lo hay; si no, a donde apuntes.
func _direccion_ataque() -> Vector3:
	if _datos != null and _datos.autoencarar:
		var hacia := player.targeting.direccion_a_objetivo()
		if not hacia.is_zero_approx():
			return hacia
	var entrada := sc.direccion_movimiento(buffer.move_vector(), player.camara())
	if not entrada.is_zero_approx():
		return entrada
	return player.direccion_frontal()


## Movimiento durante el golpe: la estocada del propio ataque MÁS lo que pida el
## jugador, escalado por `movilidad` del .tres.
##
## Se acelera hacia el objetivo en vez de fijar la velocidad de golpe: mezclar un
## empujón duro con input da tirones, y aquí lo que se busca es poder reposicionarse
## en mitad de la cadena sin romperla.
func _avanzar(delta: float) -> void:
	var progreso := float(_frame) / maxf(float(_datos.total_frames()), 1.0)
	var objetivo := _dir * (_datos.avance * _datos.avance_en(progreso))

	var entrada := buffer.move_vector()
	if _datos.movilidad > 0.0 and entrada.length() > 0.2:
		var deseada := sc.direccion_movimiento(entrada, player.camara())
		objetivo += deseada * tuning.velocidad_correr * _datos.movilidad

	if objetivo.length_squared() > 0.01:
		motor.acelerar(objetivo, tuning.aceleracion_suelo * 0.9, delta)
	else:
		motor.frenar(tuning.frenado_suelo, delta)


func _al_conectar() -> void:
	_conectado = true
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

	if buffer.peek(InputActions.JUMP, tuning.jump_buffer):
		if g.puede_cancelar(&"jump", _datos, _frame, _conectado):
			buffer.consume(InputActions.JUMP, tuning.jump_buffer)
			fsm.cambiar(&"Jump", {"numero": 1})
			return true

	if buffer.peek(InputActions.PARRY):
		if g.puede_cancelar(&"parry", _datos, _frame, _conectado):
			buffer.consume(InputActions.PARRY)
			fsm.cambiar(&"Parry")
			return true

	return false


func debug_line() -> String:
	if _datos == null:
		return "—"
	var fase := "windup"
	if _datos.activo_en(_frame):
		fase = "ACTIVO"
	elif _frame >= _datos.frames_windup + _datos.frames_activo:
		fase = "recup"
	return "L%d f%d/%d %s%s" % [
		_indice, _frame, _datos.total_frames(), fase, "  hit" if _conectado else ""
	]
