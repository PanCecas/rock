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

	# Un slide de aterrizaje no anade impulso: CONSERVA el que traias. Sumarle el
	# empujon de un slide normal convertiria cada caida en una catapulta.
	if bool(msg.get("aterrizaje", false)):
		motor.impulso(_dir, motor.rapidez_plana())
	elif not _forzado:
		motor.impulso(_dir, motor.rapidez_plana() + tuning.slide_impulso)
	player.pedir_postura(tuning.agachado_altura)


func physics_update(delta: float) -> void:
	player.pedir_postura(tuning.agachado_altura)
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
	# Igual que el surf: si el suelo se acaba, el slide se acaba. Mantener la
	# vertical clavada en -2 hacia que pasarse de largo de una plataforma fuera
	# una caida flotante en vez de una caida.
	if not player.is_on_floor():
		fsm.cambiar(&"Fall")
		return
	motor.set_vertical(-2.0)

	# Patada deslizante tambien desde el slide, con la misma espera.
	if player.ataque_slide_kick != null and player.cd_slide_kick <= 0.0 \
			and buffer.consume(InputActions.ATTACK_LIGHT):
		var d := motor.direccion_plana()
		if d.is_zero_approx():
			d = _dir
		motor.impulso(d, tuning.slide_kick_impulso)
		motor.set_vertical(tuning.slide_kick_vertical)
		fsm.cambiar(&"SlideKick", {"direccion": d})
		return

	# Saltar desde un slide da altura extra: es el combo que hace el sistema divertido.
	if player.consumir_salto():
		fsm.cambiar(&"Jump", {"numero": 1, "extra": tuning.slide_salto_extra}, true)
		return

	# El slide CEDE al agachado, no se levanta. Quien te para es el crouch con su
	# friccion, y asi los dos forman una sola maniobra continua en vez de dos
	# cosas que compiten.
	var acabado := rapidez < tuning.slide_velocidad_min * 0.5 or t > tuning.slide_duracion_max
	if acabado and not player.suelo.demasiado_empinado():
		if buffer.is_held(InputActions.CROUCH) or player.techo_bloquea():
			fsm.cambiar(&"Crouch")
		else:
			fsm.cambiar(&"Move" if buffer.move_vector().length() > 0.2 else &"Idle")


## Deslizarse contra un muro tampoco es pedir trepar por el: el slide se entra
## con velocidad y termina donde termina. Mismo criterio que el surf y el dash.
func adherencia_automatica() -> bool:
	return false


func maneja_ataques() -> bool:
	return true


func debug_line() -> String:
	return "%.1f m/s  pend %.0f°" % [motor.rapidez_plana(), player.suelo.pendiente_avance]
