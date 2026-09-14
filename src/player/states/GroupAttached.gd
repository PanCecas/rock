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

	# LA CUERDA, QUE AQUI NO ESTABA. Es el fallo de la regla dura #13 visto del
	# reves: en vez de un guardia que falta en un grupo, era la ACCION COMPARTIDA
	# la que existia en `Grounded` y en `Airborne` y no aqui. Con eso, **escalando
	# o colgado de un canto la Z no hacia absolutamente nada** —ni balanceo, ni
	# zip, ni resortera, ni zarandeo— y el sintoma era el peor posible: silencio.
	#
	# Medido en el diagnostico de la 3.12: adherido a la pared escalable, con la
	# lanza clavada, seis frames de Z no producian ni una transicion; el mismo
	# gesto desde el suelo si producia transicion.
	#
	# Va DETRAS de las preguntas de terreno —agotamiento y soltarse— y DELANTE
	# del dash, igual que en los otros dos grupos: el corolario de la regla #13
	# dice que un guardia de accion no puede cancelar una transicion de terreno.
	if intentar_cuerda():
		return

	# AQUI ESTUVO LA PATADA, y en el 4.06 se fue con el duplicado.
	#
	# Entro en la 4.00 arreglando un fallo real de la regla dura #13 —colgado del
	# arco, el boton de ataque no hacia absolutamente nada— y ese fallo ya no
	# existe porque el boton de ataque ya no patea: patea el Espacio. Desde el
	# arco el Espacio da un SALTO ENTERO (`StateGrapple`), y el paso 7 de
	# `GroupAirborne` convierte el siguiente en patada. La cadena del criterio de
	# exito sigue en pie: cuerda -> salto -> patada -> pared -> cuerda.
	#
	# **Y cortar si se puede desde aqui**, sin que este grupo tenga que enterarse:
	# el corte no cambia de estado, asi que colgado de un canto o a mitad del arco
	# el click funciona igual que en el suelo.
	if player.puede_dashear() and buffer.consume(InputActions.DASH):
		player.tiempo_sin_borde = 0.25
		fsm.cambiar(&"Dash")
