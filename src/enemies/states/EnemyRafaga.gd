extends EnemyState
## RAFAGA de tres disparos con separacion corta entre ellos.
##
## Tres y no uno porque un disparo suelto se esquiva sin pensar; tres obligan a
## comprometerse con una direccion de esquiva. Y separados por poco tiempo, para
## que se lean como UN ataque y no como tres decisiones del enemigo.

var _disparados: int = 0
var _siguiente: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_disparados = 0
	_siguiente = 0.0


func physics_update(delta: float) -> void:
	if not enemigo.objetivo_valido():
		fsm.cambiar(&"Dormido")
		return

	# Se mantiene la altura y se encara mientras dispara: apuntar es lo unico que
	# hace en este estado, asi que si no encarara el jugador no sabria a quien.
	_sostener_altura(delta)
	enemigo.encarar(enemigo.hacia_objetivo())

	_siguiente -= delta
	if _siguiente <= 0.0 and _disparados < enemigo.disparos:
		enemigo.disparar()
		_disparados += 1
		_siguiente = enemigo.separacion

	if _disparados >= enemigo.disparos and _siguiente <= 0.0:
		fsm.cambiar(&"Recargar")


## Frena en horizontal pero sostiene la altura de vuelo. Sin esto el volador se
## queda a la altura a la que le pillo el ataque y acaba pegado al suelo.
func _sostener_altura(delta: float) -> void:
	enemigo.motor.frenar(delta, 12.0)
	var deseada: float = enemigo.punto_de_vuelo().y - enemigo.global_position.y
	enemigo.velocity.y = clampf(deseada * 2.0, -4.0, 4.0)


func debug_line() -> String:
	return "%d/%d disparos" % [_disparados, enemigo.disparos]
