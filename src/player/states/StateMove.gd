extends PlayerState
## Locomoción normal: caminar, trotar y correr. Un solo estado, porque los tres
## no son estados: son puntos de una rampa continua.
##
## La CARRERILLA es el mecanismo. Mientras mantienes la dirección se acumula
## tiempo y la velocidad objetivo recorre caminar -> trotar -> correr; al soltar,
## se pierde. Antes esto era una escalera elegida por la fuerza del stick, saltaba
## de 3.2 a 7.5 de golpe y se sentía como un interruptor.
##
## Encima de esa rampa hay un suavizado exponencial (`suavizado_velocidad`) para
## que el objetivo no dé tirones. Es independiente del framerate, a diferencia de
## un lerp con factor fijo: a 30 y a 144 fps se siente igual.
##
## La velocidad ALTA no vive aquí: eso es Shift -> Dash -> Surf.

## Carrerilla acumulada, en segundos.
var _carrerilla: float = 0.0
## Velocidad objetivo suavizada. Es lo que evita el tirón al cruzar los peldaños.
var _objetivo_suave: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	player.wallrun_disponible = true
	# Se hereda la velocidad con la que se llega, así el aterrizaje de un salto o
	# la salida de un surf no reinician la carrerilla a cero.
	var traida: float = float(msg.get("rapidez", motor.rapidez_plana()))
	_objetivo_suave = traida
	_carrerilla = _carrerilla_para(traida)


func physics_update(delta: float) -> void:
	var entrada := buffer.move_vector()
	var fuerza := clampf(entrada.length(), 0.0, 1.0)

	if fuerza < 0.1 and motor.rapidez_plana() < 0.5:
		fsm.cambiar(&"Idle")
		return

	# Acumular o perder carrerilla. Mantener Shift no acelera aquí: la pulsación ya
	# habrá disparado el dash, y el dash entrega al surf.
	if fuerza > 0.25:
		_carrerilla = minf(_carrerilla + delta, tuning.tiempo_a_correr)
	else:
		_carrerilla = maxf(0.0, _carrerilla - delta * tuning.perdida_carrerilla)

	var objetivo := motor.velocidad_por_carrerilla(_carrerilla, fuerza)
	# Suavizado exponencial: framerate-independiente, a diferencia de un lerp con
	# factor fijo. `suavizado_velocidad` es la constante de tiempo en segundos.
	_objetivo_suave = lerpf(
		_objetivo_suave, objetivo,
		1.0 - exp(-delta / maxf(tuning.suavizado_velocidad, 0.001))
	)

	var dir := sc.direccion_movimiento(entrada, player.camara())

	# Ir mas rapido de lo que pide la rampa significa DOS cosas distintas, y
	# tratarlas igual era la causa del "ice skating":
	#
	#   sigo empujando -> traigo momentum de un dash, un surf o un slide. Esa
	#     velocidad extra no se tira, se pierde despacio. Es la regla de siempre.
	#   he soltado     -> quiero PARAR. Frenar a `frenado_momentum` (6 m/s2) hacia
	#     que soltar el stick a velocidad de carrera patinara 6 metros. Aqui manda
	#     `frenado_soltar`. Antes caia aqui `frenado_momentum` y por eso soltar el
	#     stick a velocidad de carrera patinaba seis metros.
	#
	# Y hay que bajar el OBJETIVO, no la TASA. `motor.acelerar()` mueve el vector
	# entero hacia el deseado con una sola tasa, asi que bajarla no solo frena:
	# tambien impide GIRAR. Con `frenado_momentum` (6 m/s2) salir del surf cuesta
	# abajo a 15.8 m/s costaba **1.43 s de linea recta** antes de obedecer al
	# stick — medido en el Gym, y es el "no puedo direccionar al personaje" que se
	# reporto dos veces. Frenar despacio era el diseno; no obedecer, no.
	#
	# Bajando el objetivo la regla del momentum queda intacta —la rapidez extra se
	# sigue perdiendo a 6 m/s2, porque el techo se recalcula cada frame desde la
	# rapidez actual— y el giro conserva la autoridad de siempre.
	var tasa := tuning.aceleracion_suelo
	var techo := _objetivo_suave
	if motor.rapidez_plana() > _objetivo_suave + 0.5:
		if fuerza > 0.25:
			techo = move_toward(
				motor.rapidez_plana(), _objetivo_suave, tuning.frenado_momentum * delta)
		else:
			# Soltar el stick no deja direccion que pedir, asi que aqui bajar la
			# tasa no le quita el control a nadie: es solo la frenada.
			tasa = tuning.frenado_soltar

	motor.acelerar(dir * techo, tasa, delta)
	motor.set_vertical(-2.0)

	# Deslizarse exige llevar velocidad: es la recompensa por haber cogido
	# carrerilla. Sin ella, agacharse es agacharse.
	if buffer.consume(InputActions.CROUCH):
		fsm.cambiar(&"Slide" if motor.rapidez_plana() >= tuning.slide_velocidad_min else &"Crouch")


## Carrerilla equivalente a una velocidad dada, para heredarla sin saltos.
func _carrerilla_para(v: float) -> float:
	if v <= tuning.velocidad_caminar:
		return 0.0
	if v <= tuning.velocidad_trotar:
		var f: float = (v - tuning.velocidad_caminar) / maxf(tuning.velocidad_trotar - tuning.velocidad_caminar, 0.001)
		return f * tuning.tiempo_a_trotar
	var f2: float = (v - tuning.velocidad_trotar) / maxf(tuning.velocidad_correr - tuning.velocidad_trotar, 0.001)
	return tuning.tiempo_a_trotar + clampf(f2, 0.0, 1.0) * (tuning.tiempo_a_correr - tuning.tiempo_a_trotar)


func debug_line() -> String:
	var etiqueta := "caminar"
	if _objetivo_suave > tuning.velocidad_trotar - 0.3:
		etiqueta = "correr" if _objetivo_suave > tuning.velocidad_correr - 0.6 else "trotar"
	return "%s  %.1f/%.1f m/s  carrerilla %.2fs" % [
		etiqueta, motor.rapidez_plana(), _objetivo_suave, _carrerilla
	]
