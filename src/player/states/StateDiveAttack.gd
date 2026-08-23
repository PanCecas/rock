extends PlayerState
## El clavado armado. Misma trayectoria que el Dive, pero con la hitbox viva
## durante TODO el trayecto: no es un golpe con ventana activa, es un proyectil
## que eres tú.
##
## Lanza a los enemigos por el aire (`lanzamiento` en su .tres), que es lo único
## que hoy abre el juego aéreo desde el suelo: el pesado dejó de hacerlo en la
## corrección 2.4 a propósito, y esta es la vía deliberada para recuperarlo.

var _dir: Vector3 = Vector3.ZERO
var _golpeados: int = 0


func enter(msg: Dictionary = {}) -> void:
	_dir = msg.get("direccion", motor.direccion_plana())
	if _dir.is_zero_approx():
		_dir = player.direccion_frontal()
	_golpeados = 0
	player.hitbox.nuevo_swing()
	player.orientar_a(_dir)
	EventBus.camara_shake.emit(0.4, 0.15)
	CombatFX.arco(
		player.get_parent(), player.global_position + Vector3.UP * 0.9, _dir,
		player.color_de(&"azul_claro"), 2.2
	)


func physics_update(delta: float) -> void:
	var datos: AttackData = player.ataque_dive
	motor.impulso(_dir, maxf(motor.rapidez_plana(), tuning.dive_impulso))
	var vy := motor.get_vertical() + tuning.dive_gravedad * delta
	motor.set_vertical(maxf(vy, tuning.velocidad_terminal))

	# La hitbox vive todo el trayecto. `nuevo_swing()` no se vuelve a llamar, así
	# que cada enemigo se lleva un solo golpe por clavado.
	if datos != null and player.hitbox.golpear(datos, _dir) > 0:
		_golpeados += 1
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
		fsm.cambiar(&"Landing", {"impacto": player.impacto_ultimo})


func debug_line() -> String:
	return "ARMADO  %d impacto(s)" % _golpeados
