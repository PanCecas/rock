extends PlayerStateGroup
## Todo lo que pasa dentro del agua.
##
## El agua no es "suelo con otra gravedad": es un tercer medio con sus propias
## reglas, y por eso tiene grupo propio. Aquí no hay coyote time, ni doble salto,
## ni dash: los verbos de tierra no se cuelan.
##
## Lo único que el grupo resuelve es salir: si ya no hay agua, se cae.


func shared_update(_delta: float) -> void:
	if not player.agua.en_agua:
		fsm.cambiar(&"Fall")
		return

	# La stamina la decide cada estado, NO el grupo: flotar quieto no puede costar
	# lo mismo que nadar a fondo. Drenar aqui hacia que el agua cansara incluso
	# estando parado, y convertia cualquier travesia en una cuenta atras.
	player.recargar_aire()
	player.wallrun_disponible = true
