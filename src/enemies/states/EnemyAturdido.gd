extends EnemyState
## Tambaleo. Su duracion la dicta el ATAQUE que lo provoco (`AttackData.stagger`),
## no el enemigo: es el castigo terrestre, la alternativa a mandarlo por los aires.

func physics_update(delta: float) -> void:
	enemigo.motor.frenar(delta)
	if t >= enemigo.stagger:
		fsm.cambiar(&"Acercarse")


func debug_line() -> String:
	return "%.2f s" % maxf(enemigo.stagger - t, 0.0)
