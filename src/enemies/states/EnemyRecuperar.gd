extends EnemyState
## Los frames de recuperacion: la ventana en la que el jugador castiga. Al salir
## arma la cadencia, que es lo que impide que el enemigo sea una picadora.

func physics_update(delta: float) -> void:
	enemigo.motor.frenar(delta)
	if t >= enemigo.ataque.frames_a_seg(enemigo.ataque.frames_recuperacion):
		enemigo.espera = enemigo.cadencia
		fsm.cambiar(&"Acercarse")
