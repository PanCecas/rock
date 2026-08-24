extends PlayerState
## Escalada libre sobre cualquier superficie que el WallSensor acepte como pared
## (60..95 grados). No solo muros verticales: una rampa empinada tambien se trepa.
##
## Todo se calcula con la NORMAL REAL de la superficie, nunca con su version
## aplanada. Esa era la diferencia entre escalar una pendiente y escalar "como si"
## fuera vertical: con la normal aplanada, el "arriba de la pared" degeneraba en el
## arriba del mundo, el personaje subia en vertical y se despegaba de la rampa, y
## la adherencia empujaba en horizontal en vez de contra la superficie.
##
## Es el estado que mas va a usarse en el juego final: la piel de los colosos sera
## una superficie escalable en movimiento, y casi ninguna parte de un coloso es un
## muro de 90 grados. Por eso todo vive en el plano de la superficie y no en
## coordenadas de mundo.

var _normal: Vector3 = Vector3.ZERO
## Ejes de la superficie: derecha y "cuesta arriba", los dos DENTRO de su plano.
var _lateral: Vector3 = Vector3.ZERO
var _arriba: Vector3 = Vector3.ZERO


func enter(_msg: Dictionary = {}) -> void:
	# LEDGE SNAP: si al subir aparece un canto agarrable, el personaje se ancla a
	# el automaticamente en vez de seguir trepando contra el aire. Es lo que evita
	# el momento tonto de estar escalando por encima del borde sin poder subir.
	if player.borde.hay_borde:
		fsm.cambiar(&"LedgeHang")
		return

	_normal = player.pared.normal
	_recalcular_ejes()
	player.velocity = Vector3.ZERO
	player.orientar_a(-sc.plano(_normal))
	sc.set_frame(player.pared.colisionador)


func exit(siguiente: StringName = &"") -> void:
	if not fsm.es_categoria(siguiente, &"Attached"):
		sc.set_frame(null)
	# Sobre una pendiente el cuerpo queda inclinado. Soltarse tiene que devolverlo
	# a la vertical, o el personaje se va al aire torcido: es el mismo problema que
	# dejaba el nado, y lo resuelve la misma utilidad.
	player.enderezar()


func physics_update(delta: float) -> void:
	# Ya no exige mantener el agarre: si has llegado aqui insistiendo contra el
	# muro, sueltas con salto o agachandote, no dejando de pulsar algo que quiza
	# nunca pulsaste. Es lo que hace que la adherencia automatica tenga sentido.
	if buffer.consume(InputActions.CROUCH):
		player.tiempo_sin_borde = 0.2
		fsm.cambiar(&"Fall")
		return
	if not player.pared.hay_pared or not (player.pared.asidero or tuning.escalada_universal):
		# Llegar arriba del todo: si hay canto, se sube; si no, se cae.
		if player.borde.hay_borde:
			fsm.cambiar(&"LedgeClimb")
		else:
			fsm.cambiar(&"Fall")
		return

	# LEDGE SNAP: si al subir aparece un canto agarrable, el personaje se ancla a
	# el automaticamente en vez de seguir trepando contra el aire. Es lo que evita
	# el momento tonto de estar escalando por encima del borde sin poder subir.
	if player.borde.hay_borde:
		fsm.cambiar(&"LedgeHang")
		return

	_normal = player.pared.normal
	_recalcular_ejes()
	player.velocity = Vector3.ZERO

	var entrada := buffer.move_vector()
	if entrada.length() > 0.15:
		var mov := (_lateral * entrada.x - _arriba * entrada.y).normalized()
		player.global_position += mov * tuning.escalada_velocidad * delta
		player.stamina.drenar(tuning.stamina_escalar * _coste(), delta)
	else:
		# Agarre tenso: quedarse quieto también cuesta, solo que mucho menos.
		player.stamina.drenar(tuning.stamina_escalar * 0.25 * _coste(), delta)

	# Pegarse a la superficie para seguir el relieve, a lo largo de SU normal. En
	# una rampa de 60 grados eso empuja hacia dentro y hacia abajo, que es lo que
	# mantiene al personaje sobre la pendiente en vez de flotando delante de ella.
	player.global_position -= _normal * tuning.escalada_adherencia * delta

	# El cuerpo se inclina con la superficie: su "arriba" es la cuesta arriba de la
	# pared y mira hacia dentro. Una rampa de 60 grados ya no se trepa con la pose
	# de un muro de 90.
	player.orientar_a_3d(-_normal, delta, _arriba)

	# IMPULSO DE ESCALADA (Shift): un tiron en la direccion 2D que estes pidiendo
	# sobre la pared. Es el sprint de escalada de Breath of the Wild: cuesta
	# stamina de golpe y sube mucho mas rapido que trepar.
	if buffer.consume(InputActions.DASH) and entrada.length() > 0.2:
		if player.stamina.gastar(tuning.escalada_impulso_stamina):
			var salto := (_lateral * entrada.x - _arriba * entrada.y).normalized()
			player.global_position += salto * tuning.escalada_impulso * 0.12
			player.velocity = salto * tuning.escalada_impulso
			EventBus.camara_shake.emit(0.25, 0.1)
			CombatFX.impacto(
				player.get_parent(), player.global_position + Vector3.UP * 1.0,
				player.color_de(&"crema_bruma"), 0.7
			)
			return

	# Dos saltos distintos, y los decide hacia donde apuntas:
	#
	#   atras / sin input -> SOLTARSE: salto normal separandote de la pared. Nada
	#     de backflips aqui; el backflip es del agachado y mezclarlos confunde.
	#   arriba / diagonal superior -> WALL LUNGE: impulso a lo largo de la pared
	#     que gana altura de golpe. Es el "buff" de escalar con intencion.
	if player.consumir_salto():
		if player.stamina.gastar(tuning.stamina_escalar * 2.0):
			if entrada.y < -0.4:
				_wall_lunge(entrada)
			else:
				_soltarse()


## Derecha y cuesta arriba de la superficie, las dos contenidas en su plano.
##
## `_lateral` sale horizontal siempre (es el corte del plano con la horizontal) y
## `_arriba` es lo que queda perpendicular: en un muro de 90 grados coincide con
## el arriba del mundo, y en una rampa de 60 se tumba 30 grados. Ese es todo el
## secreto de que la escalada respete la inclinacion.
func _recalcular_ejes() -> void:
	_lateral = sc.up.cross(_normal)
	if _lateral.is_zero_approx():
		# Superficie mirando al cenit: no hay lateral que sacar. No deberia pasar
		# con la horquilla del sensor, pero degradar es mejor que dividir por cero.
		_lateral = sc.plano(player.direccion_frontal())
	_lateral = _lateral.normalized()
	_arriba = _normal.cross(_lateral).normalized()
	if _arriba.dot(sc.up) < 0.0:
		_arriba = -_arriba


## Soltarse hacia atras: salto corriente separandose del muro.
func _soltarse() -> void:
	var salida := sc.plano(_normal).normalized()
	motor.impulso(salida, tuning.walljump_lateral * 0.7)
	player.tiempo_sin_borde = 0.15
	fsm.cambiar(&"Jump", {"numero": 1}, true)


## WALL LUNGE: apuntar arriba o en diagonal superior y saltar impulsa A LO LARGO
## de la pared. Gana altura sin soltarse del todo y deja el agarre disponible, asi
## que encadenar lunges es la forma rapida de subir un muro alto.
func _wall_lunge(entrada: Vector2) -> void:
	var dir := (_arriba - _normal * 0.25 + _lateral * entrada.x * 0.5).normalized()
	player.velocity = dir * tuning.walljump_vertical * 1.05
	player.tiempo_sin_borde = 0.1
	EventBus.camara_shake.emit(0.3, 0.12)
	CombatFX.impacto(
		player.get_parent(), player.global_position + Vector3.UP * 1.0,
		player.color_de(&"crema_bruma"), 0.8
	)
	# Vuelve a Fall y no a Jump: el lunge no es un salto, es un tiron. Si sigues
	# manteniendo el agarre, GroupAirborne te reengancha solo mas arriba.
	fsm.cambiar(&"Fall")


## La roca lisa cansa mas que un asidero marcado. Es lo que sigue haciendo
## especiales a las superficies disenadas para escalar sin prohibir el resto.
func _coste() -> float:
	return 1.0 if player.pared.asidero else tuning.escalada_coste_liso


func debug_line() -> String:
	return "%.0f°  stam %.0f%%  %s" % [
		player.pared.angulo,
		player.stamina.fraccion() * 100.0,
		"asidero" if player.pared.asidero else "roca lisa",
	]
