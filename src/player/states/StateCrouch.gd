extends PlayerState
## Agachado. Cápsula a la mitad, movimiento lento, y dos cosas que lo hacen algo
## más que un botón para pasar por huecos:
##
##   · SALTO ALTO (Mario Odyssey): quieto y agachado, saltar sube muchísimo más.
##     Su precio es tener que pararse a cargarlo, así que no compite con el flujo.
##   · PATADA BAJA: atacar desde aquí derriba en vez de tambalear, y el derribo
##     abre una ventana para rematar.
##
## Y no se sale cuando quieres: si hay techo encima, te quedas agachado. Eso es
## lo que convierte un túnel bajo en un obstáculo de verdad.

## Por debajo de esta velocidad el salto agachado cuenta como "estático".
const QUIETO := 1.5


func enter(_msg: Dictionary = {}) -> void:
	player.set_altura_colision(tuning.agachado_altura)
	player.wallrun_disponible = true


func exit(_siguiente: StringName = &"") -> void:
	# Solo se restaura la altura si hay sitio. Si el destino es otro estado
	# agachado (Surf, Slide), ya se encargará él de pedir su propia altura.
	if not player.techo_bloquea():
		player.set_altura_colision(1.0)


func physics_update(delta: float) -> void:
	var entrada := buffer.move_vector()
	var dir := sc.direccion_movimiento(entrada, player.camara())

	motor.acelerar(dir * tuning.velocidad_agachado, tuning.aceleracion_suelo * 0.7, delta)
	motor.set_vertical(-2.0)

	# Patada baja: el ataque desde aquí es otro golpe, no el de siempre.
	if player.ataque_agachado != null:
		if buffer.consume(InputActions.ATTACK_LIGHT) or buffer.consume(InputActions.ATTACK_HEAVY):
			fsm.cambiar(&"Attack", {"datos": player.ataque_agachado, "indice": 1})
			return

	if player.consumir_salto():
		_saltar()
		return

	# Levantarse: hay que soltar el botón Y tener hueco encima.
	if not buffer.is_held(InputActions.CROUCH) and not player.techo_bloquea():
		fsm.cambiar(&"Move" if entrada.length() > 0.2 else &"Idle")


## Quieto: salto alto. En movimiento: salto normal, para no premiar el agacharse
## como forma de ir rápido —de eso ya se encarga el surf—.
func _saltar() -> void:
	if motor.rapidez_plana() < QUIETO:
		var v := sqrt(2.0 * absf(tuning.gravedad_subida) * tuning.altura_salto_agachado)
		motor.set_vertical(v)
		EventBus.camara_shake.emit(0.25, 0.12)
		fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true, "sin_corte": true}, true)
	else:
		fsm.cambiar(&"Jump", {"numero": 1}, true)


## El salto alto es suyo: el grupo no puede convertirlo en un salto normal.
func maneja_salto() -> bool:
	return true


func debug_line() -> String:
	var extra := "  TECHO" if player.techo_bloquea() else ""
	return "%s%s" % ["quieto → salto alto" if motor.rapidez_plana() < QUIETO else "moviendo", extra]
