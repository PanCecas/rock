extends EnemyState
## Quieto hasta que el jugador entra en su radio de vision.
##
## No es un estado de relleno: es lo que hace que una sala con seis enemigos no se
## convierta en seis enemigos corriendo hacia ti a la vez desde el otro lado.

func physics_update(delta: float) -> void:
	enemigo.motor.frenar(delta)
	var j := enemigo.jugador()
	if j == null or not enemigo.detecta(j):
		# CON RUTA, NO SE VIGILA QUIETO: SE RONDA. La entrega es aqui y no en la
		# FSM para que los seis enemigos que ya existen no cambien nada: sin `ruta`
		# —que es el defecto— esto no se ejecuta y `Dormido` sigue siendo lo que
		# era. Y se pide `existe()` porque el nodo `Patrulla` solo esta en las
		# escenas que patrullan.
		if not enemigo.ruta.is_empty() and fsm.existe(&"Patrulla"):
			fsm.cambiar(&"Patrulla")
		return
	enemigo.objetivo = j
	# A donde se va al despertar lo decide cada enemigo: el guardian persigue, el
	# embestidor se planta a apuntar. El estado de vigilancia es el mismo.
	fsm.cambiar(enemigo.estado_al_despertar())
