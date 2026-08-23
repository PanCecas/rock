extends PlayerStateGroup
## Todo lo que pasa dentro del agua.
##
## El agua no es "suelo con otra gravedad": es un tercer medio con sus propias
## reglas, y por eso tiene grupo propio. Aquí no hay coyote time, ni doble salto,
## ni dash: los verbos de tierra no se cuelan.
##
## Lo único que el grupo resuelve es salir: si ya no hay agua, se cae.


func shared_update(delta: float) -> void:
	if not player.agua.en_agua:
		fsm.cambiar(&"Fall")
		return

	# Nadar cansa, pero despacio: el agua es una vía, no un castigo. Ahogarse por
	# stamina convertiría cada travesía en un examen y no es lo que se busca.
	player.stamina.drenar(tuning.agua_stamina, delta)
	player.recargar_aire()
	player.wallrun_disponible = true
