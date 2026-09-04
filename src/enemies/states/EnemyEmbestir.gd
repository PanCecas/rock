extends EnemyState
## LA CARGA. Rumbo FIJO, a toda velocidad, hasta chocar con una pared, alcanzar al
## jugador o agotarse.
##
## No corrige la direccion ni un grado. Es lo que hace que apartarse funcione: si
## persiguiera durante la carga seria un misil teledirigido y la unica respuesta
## posible seria correr. Al ir en linea recta, el gesto correcto pasa a ser
## quedarse quieto y apartarse en el ultimo momento.

var _rumbo: Vector3 = Vector3.ZERO
## Se golpea una sola vez por carga: sin esto la hitbox arrolla al jugador varios
## frames seguidos y le quita media barra de un pasillo.
var _golpeado: bool = false


func enter(msg: Dictionary = {}) -> void:
	_rumbo = msg.get("rumbo", enemigo.frente())
	_rumbo.y = 0.0
	_rumbo = _rumbo.normalized()
	_golpeado = false
	enemigo.hitbox.nuevo_swing()
	EventBus.camara_shake.emit(0.25, 0.12)


func physics_update(delta: float) -> void:
	# CORRECCION DE RUMBO, y por defecto CERO. Ver `Embestidor.giro_en_carga`: es
	# un numero para poder castigar al que se aparta demasiado pronto, no una
	# puerta para que la carga persiga. A cero, esto no hace nada y la carga es la
	# linea recta de siempre.
	if enemigo.giro_en_carga > 0.0 and enemigo.objetivo_valido():
		var hacia := enemigo.hacia_objetivo()
		if not hacia.is_zero_approx():
			_rumbo = _girar_hacia(_rumbo, hacia.normalized(),
				deg_to_rad(enemigo.giro_en_carga) * delta)
		# El cuerpo acompaña al rumbo: cargar de lado se veria como un patinazo.
		enemigo.encarar(_rumbo)

	enemigo.velocity.x = _rumbo.x * enemigo.velocidad_carga
	enemigo.velocity.z = _rumbo.z * enemigo.velocidad_carga

	if not _golpeado and enemigo.ataque != null:
		if enemigo.hitbox.golpear(enemigo.ataque, _rumbo) > 0:
			_golpeado = true
			HitstopManager.golpe(enemigo.ataque.hitstop, [enemigo])

	# CONTRA LA PARED: aturdido y abierto. Es la recompensa por esquivar, y lo que
	# convierte al embestidor en un puzle de posicionamiento en vez de en un saco.
	if enemigo.is_on_wall():
		fsm.cambiar(&"Estrellado")
		return

	# Tope de seguridad: sin el, un fallo en campo abierto lo manda al horizonte.
	if t >= enemigo.duracion_carga:
		enemigo.espera = enemigo.cadencia
		fsm.cambiar(&"Acercarse")


## Gira `desde` hacia `hasta` como mucho `maximo` radianes, en el plano. Se hace a
## mano y no con `rotate_toward` porque eso trabaja sobre angulos y aqui hay dos
## vectores: convertir a yaw y volver introduce el salto de ±180 grados.
func _girar_hacia(desde: Vector3, hasta: Vector3, maximo: float) -> Vector3:
	var angulo := desde.angle_to(hasta)
	if angulo <= maximo or angulo < 0.0001:
		return hasta
	var eje := desde.cross(hasta)
	if eje.is_zero_approx():
		return desde
	return desde.rotated(eje.normalized(), maximo).normalized()


func debug_line() -> String:
	return "CARGA %.1f m/s%s" % [enemigo.motor.rapidez_plana(), "  hit" if _golpeado else ""]
