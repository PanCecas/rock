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
var _overshoot_hecho: bool = false
var _desde_surf: bool = false
## EMBESTIDA EN PRIMERA PERSONA. El pesado lanzado en carrera mete la camara en la
## cabeza del personaje y bloquea el rumbo al frente de camara. No es un cambio de
## camara con un ataque encima: el bloqueo de rotacion es LA mecanica —te
## comprometes a una direccion y ya no la corriges— y la primera persona es lo que
## lo hace legible.
var _primera_persona: bool = false


func enter(msg: Dictionary = {}) -> void:
	_datos = msg.get("datos", player.ataque_ligero)
	_indice = int(msg.get("indice", 1))
	_desde_surf = bool(msg.get("desde_surf", false))
	_primera_persona = bool(msg.get("primera_persona", false))
	_frame = 0
	_conectado = false
	_overshoot_hecho = false

	# Una estocada lanzada desde el surf va hacia donde SURFEAS, no hacia el
	# enemigo mas cercano: la linea que llevas es la decision que ya has tomado.
	var heredada: Vector3 = msg.get("direccion", Vector3.ZERO)
	_dir = heredada.normalized() if not heredada.is_zero_approx() else _direccion_ataque()
	if _primera_persona:
		# En primera persona el rumbo lo pone la CAMARA, no el autoencarado ni la
		# velocidad: estas mirando por los ojos del personaje y el golpe tiene que
		# ir donde miras, o el modo miente.
		var cam := player.camara()
		if cam != null:
			var frente := sc.plano(-cam.global_basis.z)
			if not frente.is_zero_approx():
				_dir = frente.normalized()
		player.primera_persona = true
	player.orientar_a(_dir)
	player.hitbox.nuevo_swing()
	# Una estocada NO frena: hereda toda la velocidad con la que llegas. El resto
	# de golpes amortiguan al 45%, que ya es no borrarla —clavarse en cada golpe
	# hace que un combo se sienta como una animación en vez de como una pelea.
	var retencion: float = 0.45
	if _datos != null:
		if _datos.frenazo:
			retencion = 0.0   # plantado: el golpe pesado para en seco
		elif _datos.estocada:
			retencion = 1.0   # atraviesa: hereda toda la velocidad
	player.velocity = sc.plano(player.velocity) * retencion + sc.up * sc.vertical(player.velocity)


## La primera persona se apaga SIEMPRE al salir, pase lo que pase: si el ataque se
## cancela con un dash a mitad, la camara tiene que volver igual. Un modo de camara
## que depende de terminar bien es un modo del que te quedas atrapado.
func exit(_siguiente: StringName = &"") -> void:
	if _primera_persona:
		player.primera_persona = false


func physics_update(delta: float) -> void:
	if _datos == null:
		fsm.cambiar(&"Idle")
		return

	_frame += 1
	# ROTACION BLOQUEADA AL FRENTE DE CAMARA mientras dura la embestida. Es lo que
	# la convierte en una carga y no en un ataque normal visto desde cerca.
	if _primera_persona and t < tuning.fps_duracion:
		var cam := player.camara()
		if cam != null:
			var frente := sc.plano(-cam.global_basis.z)
			if not frente.is_zero_approx():
				_dir = frente.normalized()
				player.orientar_a(_dir)
	_avanzar(delta)
	motor.set_vertical(-2.0)

	if _datos.activo_en(_frame):
		if player.hitbox.golpear(_datos, _dir) > 0:
			_al_conectar()
	elif not _overshoot_hecho and _datos.overshoot > 0.0 and _frame > _datos.frames_windup:
		# OVERSHOOT: al cerrarse la ventana activa, un empujon extra que te lleva
		# AL OTRO LADO del objetivo. Es lo que convierte la estocada en un corte:
		# atraviesas en vez de quedarte clavado delante.
		# SUMA sobre lo que ya llevas: fijar la velocidad al valor del overshoot
		# frenaba la estocada en vez de empujarla. El clamp global pone el techo.
		_overshoot_hecho = true
		motor.impulso(_dir, motor.rapidez_plana() + _datos.overshoot)

	if _cancelaciones():
		return

	# Encadenar al siguiente golpe de la cadena ligera.
	if _datos.siguiente != null and _frame >= _datos.frame_cadena:
		if buffer.consume(InputActions.ATTACK_LIGHT):
			# reentrar=true: encadenar es volver a entrar en Attack con otro golpe.
			fsm.cambiar(&"Attack", {"datos": _datos.siguiente, "indice": _indice + 1}, true)
			return

	if _frame >= _datos.total_frames():
		# Tras un corte se sale EN COMBATE, no parado: si hay objetivo se vuelve a
		# locomocion con el soft-lock vivo, que es lo que mantiene el modo de
		# camara Combat y deja el siguiente golpe a un clic.
		# Volver al surf mantiene la forma fluida entre golpe y golpe.
		var shift := buffer.is_held(InputActions.DASH) or buffer.is_held(InputActions.SPRINT)
		if _desde_surf and _datos.vuelve_a_surf and shift and player.is_on_floor():
			if not player.stamina.vacia():
				fsm.cambiar(&"Surf", {"direccion": _dir, "rapidez": motor.rapidez_plana()})
				return
		var hay_objetivo := player.targeting.objetivo() != null
		if buffer.move_vector().length() > 0.2 or hay_objetivo:
			fsm.cambiar(&"Move")
		else:
			fsm.cambiar(&"Idle")


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
	if _datos.frenazo:
		# Plantado de principio a fin: ni avance del ataque ni input del jugador.
		motor.frenar(tuning.frenado_suelo * 3.0, delta)
		return

	var objetivo := _dir * (_datos.avance * _datos.avance_en(progreso))
	var tasa := tuning.aceleracion_suelo * 0.9

	if _datos.estocada:
		# Velocidad sostenida hasta cerrar la ventana activa; después se suelta.
		var fin_activo := _datos.frames_windup + _datos.frames_activo
		if _frame <= fin_activo:
			objetivo = _dir * _datos.estocada_velocidad
			tasa = tuning.aceleracion_suelo * 2.5
		else:
			# La recuperación desacelera sola, sin frenazo: sigues avanzando.
			var caida := float(_frame - fin_activo) / maxf(float(_datos.frames_recuperacion), 1.0)
			objetivo = _dir * _datos.estocada_velocidad * (1.0 - caida)
			tasa = tuning.frenado_momentum

	var entrada := buffer.move_vector()
	if _datos.movilidad > 0.0 and entrada.length() > 0.2:
		var deseada := sc.direccion_movimiento(entrada, player.camara())
		objetivo += deseada * tuning.velocidad_correr * _datos.movilidad

	if objetivo.length_squared() > 0.01:
		motor.acelerar(objetivo, tasa, delta)
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
		if g.puede_cancelar(&"jump", _datos, _frame, _conectado) and player.consumir_salto():
			fsm.cambiar(&"Jump", {"numero": 1}, true)
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
