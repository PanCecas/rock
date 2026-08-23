extends PlayerState
## Deslizamiento. La regla de diseño: deslizarse cuesta abajo tiene que GANAR
## velocidad. Si solo sirviera para pasar por huecos bajos nadie lo usaría.

var _dir: Vector3 = Vector3.ZERO
var _forzado: bool = false


func enter(msg: Dictionary = {}) -> void:
	_forzado = bool(msg.get("forzado", false))
	_dir = motor.direccion_plana()
	if _dir.is_zero_approx():
		_dir = player.suelo.cuesta_abajo()
	if _dir.is_zero_approx():
		_dir = sc.plano(-player.global_basis.z).normalized()

	if not _forzado:
		motor.impulso(_dir, motor.rapidez_plana() + tuning.slide_impulso)
	player.set_altura_colision(tuning.agachado_altura)


func exit(_siguiente: StringName = &"") -> void:
	if not player.techo_bloquea():
		player.set_altura_colision(1.0)


func physics_update(delta: float) -> void:
	var rapidez := motor.rapidez_plana()

	# La pendiente acelera o frena. Leer el terreno es la habilidad del sistema.
	var pendiente := player.suelo.pendiente_avance
	rapidez += (pendiente / 45.0) * tuning.slide_pendiente * delta
	rapidez -= tuning.slide_friccion * delta

	# Se puede corregir el rumbo un poco, no girar en redondo.
	var entrada := buffer.move_vector()
	if entrada.length() > 0.2:
		var deseada := sc.direccion_movimiento(entrada, player.camara())
		_dir = _dir.slerp(deseada, minf(1.0, 2.2 * delta)).normalized()

	motor.impulso(_dir, maxf(rapidez, 0.0))
	motor.set_vertical(-2.0)

	# Saltar desde un slide da altura extra: es el combo que hace el sistema divertido.
	if player.consumir_salto():
		fsm.cambiar(&"Jump", {"numero": 1, "extra": tuning.slide_salto_extra}, true)
		return

	var acabado := rapidez < tuning.slide_velocidad_min * 0.5 or t > tuning.slide_duracion_max
	if acabado and not player.suelo.demasiado_empinado():
		fsm.cambiar(&"Move" if buffer.move_vector().length() > 0.2 else &"Idle")


func debug_line() -> String:
	return "%.1f m/s  pend %.0f°" % [motor.rapidez_plana(), player.suelo.pendiente_avance]
