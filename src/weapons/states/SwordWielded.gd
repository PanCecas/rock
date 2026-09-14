extends SwordState
## EN LA MANO. Sigue al dueño y espera a que corten o la tiren.
##
## No se cuelga de un hueso porque todavia no hay esqueleto: va a un desfase fijo
## del cuerpo, al costado CONTRARIO al de la lanza. Cuando exista el rig, esto es
## lo unico que cambia.


func enter(_msg: Dictionary = {}) -> void:
	espada.visible = true
	espada.objetivo = null
	espada.vuelo = Vector3.ZERO


func physics_update(_delta: float) -> void:
	if espada.dueno == null or not is_instance_valid(espada.dueno):
		return
	espada.global_position = espada.punto_de_mano()
	# EN VERTICAL, al costado, igual que la lanza y por la misma razon: apuntando
	# al frente queda centrada en la mano y media hoja sale por la espalda. Lo
	# cazo el screenshot test la primera vez que se probo con la lanza.
	espada.apuntar_a(Vector3.UP)


func debug_line() -> String:
	return "EN MANO"
