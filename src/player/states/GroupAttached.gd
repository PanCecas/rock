extends PlayerStateGroup
## Colgado o escalando. Aquí el jugador está pegado a la geometría: no hay gravedad,
## la stamina baja y soltarse es una decisión.
##
## En la Fase 4 estos mismos estados funcionarán sobre el pelaje de un coloso sin
## cambiar una línea: la geometría se mueve, pero el SurfaceContext lo absorbe.


func shared_update(_delta: float) -> void:
	# Sin stamina te resbalas. No mata: la muerte es la caída larga que venga
	# después. Salvo para los estados que ya pagaron su coste de golpe al entrar:
	# a esos cancelarlos por agotamiento es cobrarles dos veces.
	if player.stamina.vacia() and not (fsm.actual != null and fsm.actual.resiste_agotamiento()):
		fsm.cambiar(&"Fall", {"resbalon": true})
		return

	# Soltarse a propósito.
	if buffer.consume(InputActions.CROUCH):
		player.tiempo_sin_borde = 0.35
		fsm.cambiar(&"Fall")
		return

	if player.puede_dashear() and buffer.consume(InputActions.DASH):
		player.tiempo_sin_borde = 0.25
		fsm.cambiar(&"Dash")
