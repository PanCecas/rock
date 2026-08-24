extends PlayerState
## Buceo. Movimiento 3D completo: la cámara decide hacia dónde nadas, incluida la
## vertical, que es lo que separa bucear de "nadar más hondo".
##
## Tres cosas lo hacen sentir agua y no vacío:
##
##   · ORIENTACIÓN POR VELOCIDAD. El cuerpo se alinea con el vector de nado, con
##     pitch y yaw reales. Si apuntas al fondo, el personaje pica hacia el fondo.
##   · DERIVA. Al soltar los controles no se congela: oscila. Un cuerpo quieto en
##     mitad del agua se lee como un error del juego, no como una pausa.
##   · STAMINA SOLO AL NADAR. Flotar no cansa. Antes drenaba siempre y convertía
##     cualquier travesía en una cuenta atrás.
##
## Entrar desde un DIVE gana profundidad y dibuja la curva del esquema.

var _reloj: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	player.set_altura_colision(1.0)
	player.set_alabeo(0.0)
	_reloj = randf() * TAU  # fase aleatoria: dos entradas seguidas no se calcan

	if bool(msg.get("clavado", false)):
		# CLAVADO: se conserva la velocidad del dive y se le suma penetración.
		# Es la curva profunda del esquema, y la recompensa por entrar bien.
		var dir: Vector3 = msg.get("direccion", motor.direccion_plana())
		if not dir.is_zero_approx():
			motor.impulso(dir, maxf(motor.rapidez_plana(), tuning.dive_impulso))
		motor.set_vertical(-tuning.dive_penetracion)
		EventBus.camara_shake.emit(0.5, 0.2)
		CombatFX.onda(
			player.get_parent(),
			Vector3(player.global_position.x, player.agua.nivel, player.global_position.z),
			player.color_de(&"blanco_tiza"), 3.0
		)
	else:
		motor.set_vertical(minf(motor.get_vertical(), -tuning.buceo_impulso))


func exit(siguiente: StringName = &"") -> void:
	# Entre estados de agua la orientacion 3D sigue mandando y cada uno decide: no
	# se toca nada, o el cuerpo daria un tirón en el frame de relevo.
	#
	# Al SALIR del agua, en cambio, hay que devolverlo a la vertical. El nado
	# escribe pitch y roll; la logica de tierra solo escribe yaw, asi que sin esto
	# el personaje se iba al aire con la ultima inclinacion que tuviera buceando.
	# Ese era el "sale torcido" al romper la superficie.
	if not fsm.es_categoria(siguiente, &"Water"):
		player.enderezar()


func physics_update(delta: float) -> void:
	_reloj += delta
	var entrada := buffer.move_vector()
	var cam := player.camara()

	# Movimiento 3D de verdad: se usa la base COMPLETA de la cámara, con su
	# componente vertical. Proyectarla al plano convertiría el buceo en nadar
	# contra un techo invisible.
	var dir := Vector3.ZERO
	if cam != null and entrada.length() > 0.15:
		dir = (-cam.global_basis.z * -entrada.y + cam.global_basis.x * entrada.x).normalized()

	var mult := tuning.nado_sprint_mult if player.quiere_sprint() else 1.0
	var deseada := dir * tuning.buceo_velocidad * mult

	var subiendo := buffer.is_held(InputActions.JUMP)
	if subiendo:
		deseada += Vector3.UP * tuning.buceo_ascenso * mult
	elif buffer.is_held(InputActions.CROUCH):
		deseada += Vector3.DOWN * tuning.buceo_ascenso * 0.8

	var activo := not deseada.is_zero_approx()

	if activo:
		player.velocity = player.velocity.lerp(deseada, 1.0 - exp(-tuning.agua_rozamiento * delta))
		# Solo se gasta stamina nadando de verdad. Flotar es gratis.
		player.stamina.drenar(tuning.agua_stamina * mult, delta)
		# El cuerpo apunta a DONDE NADA, no a donde mira la cámara: si el vector
		# de velocidad baja, el personaje pica.
		player.orientar_a_3d(player.velocity, delta)
	else:
		_derivar(delta)

	# Romper la superficie devuelve a nado de superficie, sin pedir permiso.
	if not player.agua.sumergido() and motor.get_vertical() >= 0.0:
		fsm.cambiar(&"Swim")
		return

	_atacar()


## Suspensión: el cuerpo se frena casi del todo y queda oscilando. La onda mueve
## la velocidad, no la posición directamente, para que siga respetando colisiones.
func _derivar(delta: float) -> void:
	player.velocity = player.velocity.lerp(
		Vector3.ZERO, 1.0 - exp(-tuning.agua_rozamiento * 0.5 * delta)
	)
	var onda := sin(_reloj * TAU * tuning.deriva_frecuencia)
	player.velocity.y += onda * tuning.deriva_amplitud * delta * 60.0 * 0.05
	player.derivar_visual(onda, tuning.deriva_balanceo, delta)
	player.stamina.regenerar(tuning.stamina_regen_colgado, delta)


func _atacar() -> void:
	if player.ataque_agua_pesado != null and buffer.consume(InputActions.ATTACK_HEAVY):
		fsm.cambiar(&"WaterAttack", {
			"datos": player.ataque_agua_pesado,
			"impulso": tuning.agua_ataque_pesado_impulso,
			"direccion": player.direccion_nado(),
		})
		return
	if player.ataque_agua_ligero != null and buffer.consume(InputActions.ATTACK_LIGHT):
		fsm.cambiar(&"WaterAttack", {
			"datos": player.ataque_agua_ligero,
			"impulso": tuning.agua_ataque_ligero_impulso,
			"direccion": player.direccion_nado(),
		})


func maneja_ataques() -> bool:
	return true


func debug_line() -> String:
	var estado := "SPRINT" if player.quiere_sprint() else ""
	if player.velocity.length() < 0.6:
		estado = "deriva"
	return "prof %.1f m  %s   salto = subir" % [player.agua.profundidad, estado]
