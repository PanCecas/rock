extends EnemyState
## La ANTICIPACION. Es lo unico que hace entrenable el parry: si el ataque no se ve
## venir, acertar es loteria y el jugador deja de intentarlo.
##
## Dura lo que diga `frames_windup` del AttackData, asi que alargar el aviso de un
## enemigo es tocar su .tres, no su codigo.

func physics_update(delta: float) -> void:
	enemigo.motor.frenar(delta)
	enemigo.encarar(enemigo.hacia_objetivo())
	if t >= enemigo.ataque.frames_a_seg(enemigo.ataque.frames_windup):
		enemigo.hitbox.nuevo_swing()
		enemigo.frame_ataque = enemigo.ataque.frames_windup
		fsm.cambiar(&"Atacar")


func debug_line() -> String:
	var total: float = enemigo.ataque.frames_a_seg(enemigo.ataque.frames_windup)
	return "aviso %.0f%%" % (100.0 * t / maxf(total, 0.001))
