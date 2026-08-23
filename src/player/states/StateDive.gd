extends PlayerState
## Clavado. Se entra atacando en el aire CON velocidad: el dive nace del momentum,
## y por eso sale igual desde correr que desde surfear —lo que importa es que
## llegues lanzado, no de qué estado vienes—. Sin carrera, atacar en el aire sigue
## siendo el picado vertical de siempre.
##
## Es un modo propio, no una variante de caer: gravedad más fuerte, empuje hacia
## delante y giro reducido. Dibuja la parábola de clavado del esquema.
##
## Pulsar ataque OTRA VEZ durante el dive lo convierte en DiveAttack. Y si el
## clavado termina en agua, la entrada es un clavado de verdad: se gana
## profundidad en vez de quedarse flotando.

var _dir: Vector3 = Vector3.ZERO


func enter(msg: Dictionary = {}) -> void:
	_dir = msg.get("direccion", motor.direccion_plana())
	if _dir.is_zero_approx():
		_dir = player.direccion_frontal()
	# El impulso inicial es lo que separa un clavado de una caída: sales hacia
	# delante y hacia abajo, no te dejas caer.
	motor.impulso(_dir, maxf(motor.rapidez_plana(), tuning.dive_impulso))
	motor.set_vertical(minf(motor.get_vertical(), 0.0))
	player.orientar_a(_dir)
	player.set_alabeo(0.0)


func physics_update(delta: float) -> void:
	_pilotar(delta)
	motor.impulso(_dir, motor.rapidez_plana())
	var vy := motor.get_vertical() + tuning.dive_gravedad * delta
	motor.set_vertical(maxf(vy, tuning.velocidad_terminal))

	# Segunda pulsación: el clavado se arma.
	if player.ataque_dive != null:
		if buffer.consume(InputActions.ATTACK_LIGHT) or buffer.consume(InputActions.ATTACK_HEAVY):
			fsm.cambiar(&"DiveAttack", {"direccion": _dir})
			return

	if player.agua.en_agua:
		fsm.cambiar(&"Underwater", {"clavado": true, "direccion": _dir})
		return

	if player.is_on_floor():
		# Contra el suelo, un clavado es un aterrizaje duro. Duele porque lo has
		# elegido tú.
		fsm.cambiar(&"Landing", {"impacto": player.impacto_ultimo})


## La segunda pulsacion es SUYA. Sin esto GroupAirborne la convertia en un
## ataque aereo normal y el DiveAttack no llegaba a existir. Cuarta aparicion del
## mismo patron: ver regla dura #13 en CLAUDE.md.
func maneja_ataques() -> bool:
	return true


func _pilotar(delta: float) -> void:
	var entrada := buffer.move_vector()
	if entrada.length() < 0.2:
		return
	var deseada := sc.direccion_movimiento(entrada, player.camara())
	if deseada.is_zero_approx():
		return
	var peso: float = clampf(deg_to_rad(tuning.dive_giro_grados_seg) * delta, 0.0, 1.0)
	_dir = _dir.slerp(deseada, peso).normalized()
	player.orientar_a(_dir)


func debug_line() -> String:
	return "%.1f m/s  vy %.1f" % [motor.rapidez_plana(), motor.get_vertical()]
