extends SpearState
## En la mano. Sigue al dueño y espera a que la lancen.
##
## No se cuelga de un hueso porque todavía no hay esqueleto: va a un desfase fijo
## del cuerpo. Cuando exista el rig, esto es lo único que cambia.

func enter(_msg: Dictionary = {}) -> void:
	lanza.soltar_plataforma()
	lanza.visible = true


func physics_update(_delta: float) -> void:
	if lanza.dueno == null:
		return
	lanza.global_position = lanza.punto_de_mano()
	# EN VERTICAL, al costado. Apuntando al frente quedaba centrada en la mano y
	# media asta salia por la espalda: el personaje parecia ensartado, no armado.
	# Lo cazo el screenshot test a la primera.
	lanza.apuntar_a(Vector3.UP)
