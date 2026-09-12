extends EnemyState
## ANTICIPACION de la carga. Se planta, encara al jugador, y al terminar FIJA el
## rumbo.
##
## Este estado es la mecanica entera del embestidor. Su duracion es la ventana en
## la que el jugador decide qué hacer, asi que es el numero mas importante del
## enemigo: corto, es injusto; largo, es inofensivo.
##
## Encara SOLO durante la anticipacion. En cuanto empieza la carga deja de girar,
## y por eso se puede esquivar.

func enter(_msg: Dictionary = {}) -> void:
	enemigo.velocity = Vector3.ZERO


func physics_update(delta: float) -> void:
	if not enemigo.objetivo_valido():
		fsm.cambiar(&"Dormido")
		return

	enemigo.motor.frenar(delta)
	# Se sigue apuntando hasta el ultimo frame: el jugador tiene que ver a donde
	# va a salir disparado, o la esquiva es adivinar.
	enemigo.encarar(enemigo.hacia_objetivo())

	if t >= enemigo.anticipacion:
		# El rumbo sale del FRENTE, y el frente lo da una sola funcion (`frente()`).
		# Aqui habia un `-global_basis.z` escrito a mano que, con el `encarar()`
		# invertido, fijaba el rumbo justo al reves: la carga salia HUYENDO del
		# jugador. Se veia como un bicho que se asusta y se va, no como un toro.
		fsm.cambiar(&"Embestir", {"rumbo": enemigo.frente()})


func debug_line() -> String:
	return "apuntando %.0f%%" % (100.0 * t / maxf(enemigo.anticipacion, 0.001))
