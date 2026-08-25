extends EnemyState
## La ventana activa. La hitbox se consulta solo en los frames que dice el
## AttackData, ni uno antes ni uno despues.

func physics_update(delta: float) -> void:
	enemigo.frame_ataque += 1
	var datos := enemigo.ataque

	if datos.activo_en(enemigo.frame_ataque):
		# Algunos arquetipos avanzan al golpear: castiga quedarse justo fuera de
		# rango esperando a que el swing pase de largo.
		var avance := enemigo.avance_al_golpear()
		if avance > 0.0:
			var adelante := -enemigo.global_basis.z
			enemigo.velocity.x = adelante.x * avance
			enemigo.velocity.z = adelante.z * avance
		enemigo.hitbox.golpear(datos, -enemigo.global_basis.z)
	else:
		enemigo.motor.frenar(delta)

	if enemigo.frame_ataque >= datos.frames_windup + datos.frames_activo:
		fsm.cambiar(&"Recuperar")


func debug_line() -> String:
	return "f%d" % enemigo.frame_ataque
