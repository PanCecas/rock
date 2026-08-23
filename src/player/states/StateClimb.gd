extends PlayerState
## Escalada libre sobre superficies marcadas como CLIMBABLE.
##
## Es el estado que más va a usarse en el juego final: la piel de los colosos será
## una superficie escalable en movimiento. Por eso todo el movimiento se calcula
## en el plano de la pared y no en coordenadas de mundo.

var _normal: Vector3 = Vector3.ZERO


func enter(_msg: Dictionary = {}) -> void:
	_normal = player.pared.normal
	player.velocity = Vector3.ZERO
	player.orientar_a(-sc.plano(_normal))
	sc.set_frame(player.pared.colisionador)


func exit(siguiente: StringName = &"") -> void:
	if not fsm.es_categoria(siguiente, &"Attached"):
		sc.set_frame(null)


func physics_update(delta: float) -> void:
	# Ya no exige mantener el agarre: si has llegado aqui insistiendo contra el
	# muro, sueltas con salto o agachandote, no dejando de pulsar algo que quiza
	# nunca pulsaste. Es lo que hace que la adherencia automatica tenga sentido.
	if buffer.consume(InputActions.CROUCH):
		player.tiempo_sin_borde = 0.2
		fsm.cambiar(&"Fall")
		return
	if not player.pared.hay_pared or not (player.pared.escalable or tuning.escalada_universal):
		# Llegar arriba del todo: si hay canto, se sube; si no, se cae.
		if player.borde.hay_borde:
			fsm.cambiar(&"LedgeClimb")
		else:
			fsm.cambiar(&"Fall")
		return

	_normal = player.pared.normal
	player.velocity = Vector3.ZERO

	var entrada := buffer.move_vector()
	if entrada.length() > 0.15:
		# Ejes de la pared: arriba real y lateral real, no los del mundo.
		var lateral := sc.up.cross(sc.plano(_normal)).normalized()
		var arriba := sc.plano(_normal).normalized().cross(lateral).normalized()
		if arriba.dot(sc.up) < 0.0:
			arriba = -arriba
		var mov := (lateral * entrada.x - arriba * entrada.y).normalized()
		player.global_position += mov * tuning.escalada_velocidad * delta
		player.stamina.drenar(tuning.stamina_escalar * _coste(), delta)
	else:
		# Agarre tenso: quedarse quieto también cuesta, solo que mucho menos.
		player.stamina.drenar(tuning.stamina_escalar * 0.25 * _coste(), delta)

	# Pegarse a la pared para seguir el relieve.
	player.global_position -= sc.plano(_normal).normalized() * 0.6 * delta

	# IMPULSO DE ESCALADA (Shift): un tiron en la direccion 2D que estes pidiendo
	# sobre la pared. Es el sprint de escalada de Breath of the Wild: cuesta
	# stamina de golpe y sube mucho mas rapido que trepar.
	if buffer.consume(InputActions.DASH) and entrada.length() > 0.2:
		if player.stamina.gastar(tuning.escalada_impulso_stamina):
			var lat := sc.up.cross(sc.plano(_normal)).normalized()
			var arr := sc.plano(_normal).normalized().cross(lat).normalized()
			if arr.dot(sc.up) < 0.0:
				arr = -arr
			var salto := (lat * entrada.x - arr * entrada.y).normalized()
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
	var lateral := sc.up.cross(sc.plano(_normal)).normalized()
	var arriba := sc.plano(_normal).normalized().cross(lateral).normalized()
	if arriba.dot(sc.up) < 0.0:
		arriba = -arriba

	var dir := (arriba - sc.plano(_normal).normalized() * 0.25 + lateral * entrada.x * 0.5).normalized()
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
	return 1.0 if player.pared.escalable else tuning.escalada_coste_liso


func debug_line() -> String:
	return "stam %.0f%%  %s" % [
		player.stamina.fraccion() * 100.0,
		"asidero" if player.pared.escalable else "roca lisa",
	]
