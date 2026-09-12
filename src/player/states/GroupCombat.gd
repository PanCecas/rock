extends PlayerStateGroup
## Estados de combate. El grupo aporta poco a propósito, y desde el parche 4.00
## aporta aún menos: los tres que quedan —la patada, el parry y el hitstun— duran
## menos de medio segundo cada uno y terminan solos. Durante uno de ellos el
## jugador no debe caerse a otro estado por accidente.
##
## **Aquí vivían las reglas de cancelación**, que eran lo que hacía cancelable una
## cadena de combo: cuándo se puede dashear, saltar o encadenar dentro de un golpe.
## Con una sola acción ofensiva de 0.25 s no hay nada que cancelar —la ventana
## entera dura menos que la mayoría de aquellas ventanas de cancelación— así que
## se fueron con la cadena. Quien decide ahora cuándo termina un gesto es su
## propio número (regla dura #27).


func shared_update(delta: float) -> void:
	# Los ataques NO gastan stamina: esto no es un souls. Pero tampoco regenera a
	# tope mientras peleas, o el sprint infinito trivializaría el reposicionamiento.
	if player.is_on_floor():
		player.stamina.regenerar(tuning.stamina_regen_suelo * 0.35, delta)
