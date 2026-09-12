extends EnemyState
## AGARRADO. Cuelga de la daga del jugador y ya no decide nada.
##
## **Este estado no mueve al enemigo: lo mueve `StateWhirl` desde el otro lado.**
## Es la misma división que hay en el balanceo, con los papeles cambiados — allí
## el jugador es la masa y la lanza el ancla; aquí el jugador es el ancla y el
## enemigo la masa—, y por eso la restricción vive en el estado del JUGADOR: es él
## quien la controla con el stick.
##
## Lo único que hace este estado es **quitarse de en medio**: apaga la IA, apaga la
## gravedad del juego —el que zarandea aplica la suya, simétrica, por la regla dura
## #16— y deja que `move_and_slide()` siga corriendo para que el cuerpo choque con
## el mundo. Un cuerpo colgado que atraviesa paredes no se lee como un cuerpo.
##
## **Y HIERE.** Su hitbox pasa al equipo del jugador mientras dura: un cuerpo a
## quince metros por segundo es un arma, y esa es media gracia de la mecánica.

## Equipo al que pertenecía antes de que lo agarraran. Se restaura al soltarlo: si
## se dejara en 0, un enemigo suelto seguiría hiriendo a los suyos para siempre.
var _equipo_previo: int = 1


func enter(_msg: Dictionary = {}) -> void:
	enemigo.velocity = Vector3.ZERO
	if enemigo.hitbox != null:
		_equipo_previo = enemigo.hitbox.equipo
		enemigo.hitbox.equipo = 0
		enemigo.hitbox.nuevo_swing()


func exit(_siguiente: StringName = &"") -> void:
	if enemigo.hitbox != null:
		enemigo.hitbox.equipo = _equipo_previo


func physics_update(_delta: float) -> void:
	# A propósito vacío. Quien escribe `velocity` es `StateWhirl`, y si aquí se
	# tocara habría dos sitios peleándose por el mismo cuerpo — que es exactamente
	# el bug del arrastre del coloso (regla dura #19) en otra forma.
	pass


func debug_line() -> String:
	return "AGARRADO  %.1f m/s" % enemigo.velocity.length()
