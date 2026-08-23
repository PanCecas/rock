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
	# Frenar lo que traías: el avance del ataque lo pone el propio AttackData.
	player.velocity = sc.con_vertical(Vector3.ZERO, sc.vertical(player.velocity))


func physics_update(delta: float) -> void:
	if _datos == null:
		fsm.cambiar(&"Idle")
		return

	_frame += 1
	_avanzar()
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


## Empuje hacia delante durante el golpe. Sin esto los combos se quedan cortos y
## hay que perseguir al enemigo entre golpe y golpe, que es lo que los mata.
func _avanzar() -> void:
	var progreso := float(_frame) / maxf(float(_datos.total_frames()), 1.0)
	var fuerza: float = _datos.avance * _datos.avance_en(progreso)
	if fuerza > 0.01:
		motor.impulso(_dir, fuerza)
	else:
		motor.frenar(tuning.frenado_suelo, 1.0 / AttackData.FPS)


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
