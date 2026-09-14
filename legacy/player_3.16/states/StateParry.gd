extends PlayerState
## Parry. Ventana corta, castigo real al fallar.
##
## Los tres tiempos vienen de PlayerTuning (§3.4 de la arquitectura):
##   · `parry_ventana`           — 0.16 s en los que desvías
##   · `parry_ventana_perfecta`  — los primeros 0.06 s, con premio extra
##   · `parry_recuperacion_fallo`— 0.4 s vulnerable si no llega nada. Debe doler.
##
## El estado no busca golpes: se los traen. `interceptar()` lo llama el
## PlayerController cuando una Hitbox enemiga alcanza la Hurtbox del jugador.

var _resuelto: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_resuelto = false
	player.velocity = sc.con_vertical(Vector3.ZERO, minf(sc.vertical(player.velocity), 0.0))
	var hacia := player.targeting.direccion_a_objetivo()
	if not hacia.is_zero_approx():
		player.orientar_a(hacia)


func physics_update(delta: float) -> void:
	motor.frenar(tuning.frenado_suelo, delta)
	if not player.is_on_floor():
		motor.aplicar_gravedad(delta, 0.5)
	else:
		motor.set_vertical(-2.0)

	if _resuelto:
		return

	# Pasada la ventana entra la recuperación: aquí es donde fallar cuesta.
	var total := tuning.parry_ventana + tuning.parry_recuperacion_fallo
	if t >= total:
		fsm.cambiar(&"Move" if buffer.move_vector().length() > 0.2 else &"Idle")


## Lo llama PlayerController.recibir_golpe(). Devuelve un Golpe.Resultado.
func interceptar(golpe: Golpe) -> int:
	if _resuelto or t > tuning.parry_ventana:
		return Golpe.Resultado.IMPACTO

	var perfecto := t <= tuning.parry_ventana_perfecta
	_resuelto = true
	_celebrar(golpe, perfecto)
	EventBus.parry_success.emit(perfecto)

	# Contraataque inmediato solo en el perfecto: el premio por afinar.
	if perfecto:
		fsm.cambiar(&"Attack", {"datos": player.ataque_contra, "indice": 1})
	else:
		fsm.cambiar(&"Idle")

	return Golpe.Resultado.PARRY_PERFECTO if perfecto else Golpe.Resultado.PARRY


func _celebrar(golpe: Golpe, perfecto: bool) -> void:
	var pos := player.global_position + Vector3.UP * 1.1
	var color := player.color_de(&"blanco_tiza" if perfecto else &"azul_claro")

	HitstopManager.golpe(tuning.hitstop_parry * (1.4 if perfecto else 1.0), [player, golpe.atacante])
	EventBus.camara_shake.emit(1.2 if perfecto else 0.7, 0.18)
	CombatFX.impacto(player.get_parent(), pos, color, 1.6 if perfecto else 1.0)
	CombatFX.onda(player.get_parent(), pos, color, 3.2 if perfecto else 2.0)

	player.stamina.llenar()
	player.recargar_aire()


func debug_line() -> String:
	if _resuelto:
		return "PARRY"
	if t <= tuning.parry_ventana_perfecta:
		return "PERFECTO %.0f ms" % ((tuning.parry_ventana_perfecta - t) * 1000.0)
	if t <= tuning.parry_ventana:
		return "abierto %.0f ms" % ((tuning.parry_ventana - t) * 1000.0)
	return "FALLO — vulnerable"
