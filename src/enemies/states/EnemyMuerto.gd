extends EnemyState
## Terminal. No sale de aqui: el cuerpo lo libera `_al_morir`, con ragdoll o
## desplomandose. Existe como estado para que nada mas pueda interrumpirlo.

func physics_update(delta: float) -> void:
	enemigo.motor.frenar(delta, 40.0)
