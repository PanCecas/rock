extends PlayerState
## Clavado. ATACAR EN EL AIRE, y ya: una sola pulsación, sin segundo paso y sin
## exigir carrera previa. Pedir las dos cosas hacía que el ataque aéreo más
## visible del juego no apareciera casi nunca.
##
## Física de Mario 64: **velocidad horizontal CONSTANTE** en caída libre. Ni
## rozamiento ni aceleración; solo la gravedad tira. Eso es lo que hace que la
## trayectoria se pueda leer de un vistazo y planificar antes de saltar.
##
## La hitbox vive TODO el trayecto. No es un golpe con ventana activa: es un
## proyectil que eres tú, y al impactar manda al enemigo por los aires.
##
## Si el clavado termina en agua, la entrada gana profundidad de verdad y dibuja
## la curva submarina del esquema.

var _dir: Vector3 = Vector3.ZERO
var _rapidez: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	_dir = msg.get("direccion", motor.direccion_plana())
	if _dir.is_zero_approx():
		_dir = player.direccion_frontal()

	# El impulso inicial separa un clavado de una caída: sales hacia delante y
	# hacia abajo. Y esa velocidad horizontal ya no vuelve a cambiar.
	_rapidez = maxf(motor.rapidez_plana(), tuning.dive_impulso)
	motor.impulso(_dir, _rapidez)
	motor.set_vertical(minf(motor.get_vertical(), 0.0))

	player.hitbox.nuevo_swing()
	player.orientar_a(_dir)
	player.set_alabeo(0.0)
	EventBus.camara_shake.emit(0.35, 0.14)
	CombatFX.arco(
		player.get_parent(), player.global_position + Vector3.UP * 0.9, _dir,
		player.color_de(&"azul_claro"), 2.0
	)


func physics_update(delta: float) -> void:
	_pilotar(delta)

	# Velocidad horizontal CONSTANTE. Es la física de Mario 64 y la razón de que
	# el clavado sea predecible.
	motor.impulso(_dir, _rapidez)
	var vy := motor.get_vertical() + tuning.dive_gravedad * delta
	motor.set_vertical(maxf(vy, tuning.velocidad_terminal))

	# La hitbox está viva desde el primer frame. `nuevo_swing()` no se repite, así
	# que cada enemigo se lleva un solo golpe por clavado.
	var datos: AttackData = player.ataque_dive
	if datos != null and player.hitbox.golpear(datos, _dir) > 0:
		HitstopManager.golpe(datos.hitstop, [player])
		EventBus.camara_shake.emit(datos.shake, 0.16)
		CombatFX.impacto(
			player.get_parent(), player.global_position + Vector3.UP * 0.9,
			player.color_de(datos.color_vfx), 1.3
		)

	if player.agua.en_agua:
		fsm.cambiar(&"Underwater", {"clavado": true, "direccion": _dir})
		return

	if player.is_on_floor():
		# Contra el suelo, un clavado es un aterrizaje duro. Duele porque lo has
		# elegido tú.
		fsm.cambiar(&"Landing", {"impacto": player.impacto_ultimo})


## El clavado se puede corregir, pero poco: es un compromiso, no un planeo.
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


## La pulsación de ataque es suya: sin esto el grupo la convierte en un ataque
## aéreo normal y el clavado no llega a existir. Ver regla dura #13 de CLAUDE.md.
func maneja_ataques() -> bool:
	return true


func debug_line() -> String:
	return "%.1f m/s constante  vy %.1f" % [_rapidez, motor.get_vertical()]
