extends EnemyState
## GUARD BREAK. Completamente abierto hasta que la postura se restaura sola —lo
## avisa `PoiseComponent.restaurada`, no un temporizador de aqui—, para que el
## unico reloj de la postura sea el del componente.

func physics_update(delta: float) -> void:
	enemigo.motor.frenar(delta)


func debug_line() -> String:
	return "ABIERTO"
