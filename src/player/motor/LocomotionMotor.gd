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


## Velocidad objetivo de la locomoción normal a partir de la carrerilla acumulada.
##
## Antes esto era una escalera de tres peldaños elegida por la fuerza del stick:
## saltaba de 3.2 a 7.5 de golpe y se sentía como un interruptor. Ahora la
## carrerilla (segundos manteniendo la dirección) recorre caminar -> trotar ->
## correr de forma continua, y el stick solo pone el techo: media presión camina.
func velocidad_por_carrerilla(carrerilla: float, fuerza_stick: float) -> float:
	var t := _p.tuning
	var v: float
	if carrerilla <= t.tiempo_a_trotar:
		v = lerpf(t.velocidad_caminar, t.velocidad_trotar, carrerilla / maxf(t.tiempo_a_trotar, 0.001))
	else:
		var tramo: float = (carrerilla - t.tiempo_a_trotar) / maxf(t.tiempo_a_correr - t.tiempo_a_trotar, 0.001)
		v = lerpf(t.velocidad_trotar, t.velocidad_correr, clampf(tramo, 0.0, 1.0))
	# El stick manda como techo: empujar a medias camina aunque lleves carrerilla.
	return v * clampf(fuerza_stick, 0.0, 1.0)


## Empuja al jugador en una dirección conservando o no lo que ya llevaba.
func impulso(direccion: Vector3, magnitud: float, conservar: bool = false) -> void:
	var sc := _p.superficie
	var nuevo := direccion.normalized() * magnitud
	if conservar:
		_p.velocity += nuevo
	else:
		_p.velocity = sc.con_vertical(nuevo, sc.vertical(_p.velocity))
