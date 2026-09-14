extends PlayerState
## Deslizamiento. La regla de diseño: deslizarse cuesta abajo tiene que GANAR
## velocidad. Si solo sirviera para pasar por huecos bajos nadie lo usaría.

var _dir: Vector3 = Vector3.ZERO
var _forzado: bool = false
## Frames seguidos pidiendo la direccion contraria. El pivote exige constancia.
var _frames_opuesto: int = 0


## Polvo al entrar: el slide es el verbo que mas raspa el suelo de todo el
## moveset, y sin nada que levantar se lee como deslizarse sobre hielo.
func _polvo() -> void:
	if player.feedback != null:
		player.feedback.polvo(0.7)


func enter(msg: Dictionary = {}) -> void:
	_polvo()
	_frames_opuesto = 0
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
	# EL PIVOTE VA LO PRIMERO: es una salida, y una salida que se pregunta tarde
	# es una salida que el resto del estado puede haberse comido.
	if _pivotar():
		return
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

	# MANTENER SHIFT LO CONVIERTE EN SURF. Es el mismo reparto que tenia el dash
	# —toque una cosa, mantenido otra— y por eso usa su mismo numero: la escalera
	# de velocidad sigue teniendo una sola forma aunque haya cambiado de peldaño.
	if (t >= tuning.dash_tap_max and buffer.is_held(InputActions.DASH)
			and not player.stamina.vacia() and not _forzado):
		fsm.cambiar(&"Surf", {
			"direccion": _dir, "rapidez": maxf(rapidez, tuning.surf_crucero)})
		return

	# Saltar desde un slide da altura extra: es el combo que hace el sistema
	# divertido, y desde el 4.04 es LITERALMENTE Shift + Espacio.
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


## PIVOTE (frenada estilo Mario 64): pedir la dirección CONTRARIA en mitad del
## deslizamiento no gira, frena en seco y salta.
##
## **Vivía en el dash, y se mudó aquí con él.** El pivote siempre fue una
## maniobra de PIES —«en el aire no hay de dónde agarrarse», decía su propio
## comentario— y por eso estaba prohibido en vuelo. Cuando el dash de suelo pasó a
## ser el slide, el pivote se quedó en código inalcanzable: el único dash que
## queda es el aéreo, y ahí nunca se permitió. Moverlo conserva el verbo en el
## sitio donde significa lo mismo; borrarlo habría sido perder una salida de
## emergencia que nadie pidió quitar.
##
## Es eso: cortas el compromiso del deslizamiento, matas el momentum y ganas
## altura para replantear.
##
## Devuelve true si ha pivotado (y por tanto el slide ya no debe seguir).
func _pivotar() -> bool:
	if not player.is_on_floor():
		_frames_opuesto = 0
		return false
	if t < tuning.slide_duracion_max * tuning.dash_pivote_min:
		return false
	var entrada := buffer.move_vector()
	var deseada := sc.direccion_movimiento(entrada, player.camara())
	if (entrada.length() < 0.7 or deseada.is_zero_approx()
			or deseada.dot(_dir) > tuning.dash_pivote_umbral):
		_frames_opuesto = 0
		return false

	# La intención tiene que SOSTENERSE. Un giro brusco de cámara cambia lo que
	# significa "adelante" durante un frame y eso se leía como una frenada que el
	# jugador no había pedido.
	_frames_opuesto += 1
	if _frames_opuesto < tuning.dash_pivote_frames:
		return false

	# Frenazo: se tira TODO el momentum y se sale despacio hacia atrás.
	motor.impulso(deseada, tuning.dash_pivote_impulso)
	player.orientar_a(deseada)
	player.iframes = maxf(player.iframes, tuning.dash_iframes * 0.5)
	EventBus.camara_shake.emit(0.35, 0.1)
	CombatFX.impacto(
		player.get_parent(), player.global_position + Vector3.UP * 0.15,
		player.color_de(&"crema_bruma"), 0.9
	)
	# `conservar_vertical` porque el salto del pivote lo fijamos aquí: es más alto
	# que un salto normal a propósito, y `sin_corte` porque no lo pidió el botón.
	motor.set_vertical(tuning.dash_pivote_salto)
	fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true, "sin_corte": true}, true)
	return true


## Y el slide tambien: mientras deslizas, Shift ya esta haciendo su trabajo —se
## mantiene para pasar a surf—, asi que el grupo no puede reentrarlo cada frame.
func maneja_deslizamiento() -> bool:
	return true


func debug_line() -> String:
	return "%.1f m/s  pend %.0f°" % [motor.rapidez_plana(), player.suelo.pendiente_avance]
