extends EnemyState
## Quieto hasta que el jugador entra en su radio de vision.
##
## No es un estado de relleno: es lo que hace que una sala con seis enemigos no se
## convierta en seis enemigos corriendo hacia ti a la vez desde el otro lado.

func physics_update(delta: float) -> void:
	enemigo.motor.frenar(delta)
	var j := enemigo.jugador()
	if j == null or not enemigo.detecta(j):
		return
	enemigo.objetivo = j
	# A donde se va al despertar lo decide cada enemigo: el guardian persigue, el
	# embestidor se planta a apuntar. El estado de vigilancia es el mismo.
	fsm.cambiar(enemigo.estado_al_despertar())
