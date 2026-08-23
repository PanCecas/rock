class_name LocomotionMotor
extends RefCounted
## Las matemáticas de movimiento que comparten todos los estados.
##
## Trabaja SIEMPRE en el espacio del SurfaceContext: nada de asumir que el plano
## horizontal es XZ ni que la gravedad apunta a -Y. Cuando llegue el primer coloso,
## este archivo no se toca.

var _p: PlayerController


func _init(jugador: PlayerController) -> void:
	_p = jugador


## Acelera la componente horizontal hacia la velocidad deseada.
func acelerar(deseado: Vector3, tasa: float, delta: float) -> void:
	var sc := _p.superficie
	var vertical := sc.vertical(_p.velocity)
	var plano := sc.plano(_p.velocity).move_toward(deseado, tasa * delta)
	_p.velocity = plano + sc.up * vertical


## Frena la componente horizontal hasta parar.
func frenar(tasa: float, delta: float) -> void:
	acelerar(Vector3.ZERO, tasa, delta)


## Gravedad asimétrica: subir flotante, caer contundente. Es medio game feel gratis.
## `mult` permite gravedad reducida (wall-run) o nula (planeo, escalada).
func aplicar_gravedad(delta: float, mult: float = 1.0) -> void:
	if is_zero_approx(mult):
		return
	var sc := _p.superficie
	var vy := sc.vertical(_p.velocity)
	var g: float = _p.tuning.gravedad_subida if vy > 0.0 else _p.tuning.gravedad_caida
	vy = maxf(vy + g * mult * delta, _p.tuning.velocidad_terminal)
	_p.velocity = sc.con_vertical(_p.velocity, vy)


## Fija la velocidad vertical de golpe (saltos, impulsos).
func set_vertical(valor: float) -> void:
	_p.velocity = _p.superficie.con_vertical(_p.velocity, valor)


func get_vertical() -> float:
	return _p.superficie.vertical(_p.velocity)


## Velocidad horizontal en m/s.
func rapidez_plana() -> float:
	return _p.superficie.plano(_p.velocity).length()


## Dirección horizontal actual, o Vector3.ZERO si está parado.
func direccion_plana() -> Vector3:
	var v := _p.superficie.plano(_p.velocity)
	return v.normalized() if v.length_squared() > 0.01 else Vector3.ZERO


## Velocidad objetivo según el input y si se está esprintando.
func velocidad_objetivo(entrada: Vector2, sprint: bool) -> float:
	if entrada.length() < 0.25:
		return 0.0
	if sprint:
		return _p.tuning.velocidad_sprint
	if entrada.length() < 0.65:
		return _p.tuning.velocidad_caminar
	return _p.tuning.velocidad_correr


## Empuja al jugador en una dirección conservando o no lo que ya llevaba.
func impulso(direccion: Vector3, magnitud: float, conservar: bool = false) -> void:
	var sc := _p.superficie
	var nuevo := direccion.normalized() * magnitud
	if conservar:
		_p.velocity += nuevo
	else:
		_p.velocity = sc.con_vertical(nuevo, sc.vertical(_p.velocity))
