extends PlayerState
## Andar, correr y esprintar. Un solo estado con la velocidad objetivo mezclada por
## el input: tres estados separados no aportarían nada y triplicarían transiciones.


func enter(_msg: Dictionary = {}) -> void:
	player.wallrun_disponible = true


func physics_update(delta: float) -> void:
	var entrada := buffer.move_vector()
	if entrada.length() < 0.1 and motor.rapidez_plana() < 0.5:
		fsm.cambiar(&"Idle")
		return

	# Mantener el botón de dash también corre: es la continuación natural de la
	# evasión de NieR, sin tener que soltar y volver a pulsar nada.
	var quiere_sprint := buffer.is_held(InputActions.SPRINT) or buffer.is_held(InputActions.DASH)
	var sprint := quiere_sprint and not player.stamina.vacia()
	var objetivo := motor.velocidad_objetivo(entrada, sprint)
	var dir := sc.direccion_movimiento(entrada, player.camara())

	if sprint and objetivo > 0.0:
		player.stamina.drenar(tuning.stamina_sprint, delta)

	# Si vienes más rápido de lo que pide tu velocidad objetivo —de un dash, de un
	# slide, de una caída larga— la velocidad extra NO se tira: se pierde despacio
	# mientras sigas empujando. Es lo que hace que el dash desemboque en carrera
	# en vez de frenar en seco al frame siguiente.
	var tasa := tuning.aceleracion_suelo
	if motor.rapidez_plana() > objetivo + 0.5:
		tasa = tuning.frenado_momentum

	motor.acelerar(dir * objetivo, tasa, delta)
	motor.set_vertical(-2.0)

	# Deslizarse: hay que llevar velocidad. Es una recompensa por ir rápido, no un
	# botón de agacharse.
	if buffer.consume(InputActions.CROUCH) and motor.rapidez_plana() >= tuning.slide_velocidad_min:
		fsm.cambiar(&"Slide")


func debug_line() -> String:
	return "sprint" if buffer.is_held(InputActions.SPRINT) else ""
