extends SwordState
## LA VUELTA. Persigue la mano hasta que la atrapas.
##
## **Persigue, no interpola**, y esa es la diferencia con el retorno de la lanza.
## La lanza vuelve por una Bezier que se calcula al salir, y le sirve porque
## vuelve cuando TU la llamas: estas parado decidiendo. La espada vuelve sola
## mientras tu sigues corriendo, saltando y encadenando, asi que su destino se
## mueve — una curva calculada de antemano llegaria a donde estabas.
##
## **Y SIGUE CORTANDO.** Se abre swing nuevo al entrar, asi que un enemigo ya
## tocado en la ida se lleva otro a la vuelta. Es lo que hace que tirarla contra
## un grupo valga la pena y lo que convierte una tirada en dos pasadas pateables.
##
## El techo de `retorno_max` no es decoracion: quedarse sin arma para siempre por
## una esquina rara no es un castigo interesante, es una partida rota.

var _atrapada: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_atrapada = false
	espada.objetivo = null
	var rapidez := maxf(espada.vuelo.length(), tuning.velocidad_retorno)
	var hacia := _hacia_mano()
	if not hacia.is_zero_approx():
		espada.direccion = hacia.normalized()
	espada.vuelo = espada.direccion * rapidez
	if espada.hitbox != null:
		espada.hitbox.nuevo_swing()
	espada.armar_hurtbox(true)


func exit(siguiente: StringName) -> void:
	if siguiente == &"Wielded" or siguiente == &"Swing":
		espada.armar_hurtbox(false)


func physics_update(delta: float) -> void:
	if espada.dueno == null or not is_instance_valid(espada.dueno):
		return

	var hacia := _hacia_mano()
	var distancia := hacia.length()
	if distancia <= tuning.radio_atrape:
		_atrapar()
		return

	# EL GIRO ES ACOTADO tambien aqui. Clavar el rumbo a la mano cada frame haria
	# que la espada saliera disparada de lado si el jugador cruza por delante de
	# ella; asi describe la curva y se ve venir.
	var peso: float = clampf(deg_to_rad(tuning.giro_retorno) * delta, 0.0, 1.0)
	espada.direccion = espada.direccion.slerp(hacia.normalized(), peso).normalized()
	espada.vuelo = espada.direccion * tuning.velocidad_retorno

	var paso := tuning.velocidad_retorno * delta
	# **NO SE PASA DE LARGO.** A 30 m/s el paso es medio metro; sin este tope, con
	# el jugador acercandose la espada puede saltarse el radio de atrape en un
	# frame y quedarse orbitando la mano para siempre. Un arma que da vueltas
	# alrededor tuya sin volver se lee como un bug, y lo es.
	paso = minf(paso, distancia)
	espada.global_position += espada.direccion * paso
	espada.girar_en_vuelo(delta)
	espada.apuntar_a(espada.direccion)

	if espada.ataque_vuelo != null and espada.hitbox != null:
		if espada.hitbox.golpear(espada.ataque_vuelo, espada.direccion) > 0:
			CombatFX.impacto(espada.get_parent(), espada.global_position,
				espada.color_de(&"carmesi"), 0.9)

	# TECHO DE SEGURIDAD: si tarda demasiado, vuelve de golpe.
	if t >= tuning.retorno_max:
		_atrapar()


func _hacia_mano() -> Vector3:
	return espada.punto_de_mano() - espada.global_position


func _atrapar() -> void:
	if _atrapada:
		return
	_atrapada = true
	espada.vuelo = Vector3.ZERO
	espada.global_position = espada.punto_de_mano()
	# Volver a la mano es un salto de posicion: sin esto se dibuja un barrido
	# cruzando el mapa en un frame (regla dura #21bis).
	espada.reset_physics_interpolation()
	espada.recuperada.emit()
	fsm.cambiar(&"Wielded")


func debug_line() -> String:
	return "VUELVE  %.1f m" % _hacia_mano().length()
