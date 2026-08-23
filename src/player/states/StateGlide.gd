extends PlayerState
## Planeo con la capa. Caída constante, velocidad horizontal alta y giro lento.
##
## El alabeo del visual no es adorno: a 50 metros de distancia es lo único que
## comunica que estás girando. La capa es el 40% de la personalidad del personaje.

var _alabeo: float = 0.0
var _dir: Vector3 = Vector3.ZERO


func enter(_msg: Dictionary = {}) -> void:
	_dir = motor.direccion_plana()
	if _dir.is_zero_approx():
		_dir = sc.plano(-player.global_basis.z).normalized()
	_alabeo = 0.0
	EventBus.player_glide_toggled.emit(true)


func exit() -> void:
	_alabeo = 0.0
	player.set_alabeo(0.0)
	EventBus.player_glide_toggled.emit(false)


func physics_update(delta: float) -> void:
	if not buffer.is_held(InputActions.GLIDE) or player.stamina.vacia():
		fsm.cambiar(&"Fall")
		return

	player.stamina.drenar(tuning.stamina_planear, delta)

	# Giro lento: planear es comprometerse con una trayectoria.
	var entrada := buffer.move_vector()
	var giro := 0.0
	if entrada.length() > 0.2:
		var deseada := sc.direccion_movimiento(entrada, player.camara())
		var nueva := _dir.slerp(deseada, minf(1.0, deg_to_rad(tuning.planeo_giro_grados_seg) * delta))
		giro = signf(sc.up.dot(_dir.cross(nueva)))
		_dir = nueva.normalized()

	# Picar acelera y hundirse menos al remontar: economía de altura básica.
	var caida := tuning.planeo_caida
	var velocidad := tuning.planeo_velocidad
	if entrada.y > 0.4:          # empujar adelante = picar
		caida *= 1.9
		velocidad *= 1.25
	elif entrada.y < -0.4:       # tirar atrás = remontar
		caida *= 0.55
		velocidad *= 0.75

	motor.impulso(_dir, velocidad)
	motor.set_vertical(lerpf(motor.get_vertical(), caida, 1.0 - exp(-6.0 * delta)))

	_alabeo = lerpf(_alabeo, -giro * tuning.planeo_alabeo, 1.0 - exp(-5.0 * delta))
	player.set_alabeo(_alabeo)


func debug_line() -> String:
	return "%.1f m/s  vy %.1f  stam %.0f%%" % [
		motor.rapidez_plana(), motor.get_vertical(), player.stamina.fraccion() * 100.0
	]
