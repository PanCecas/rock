extends EnemyState
## RECARGA reposicionandose en ZIGZAG. Es la ventana de vulnerabilidad, y todo el
## estado esta disenado para que ESO SE VEA.
##
## Un enemigo a distancia que recarga quieto y escondido es un francotirador: solo
## ensena a buscar cobertura. Este recarga huyendo en zigzag, un movimiento tan
## raro que se aprende a leer en dos encuentros. "Esta haciendo el zigzag" pasa a
## significar "ahora puedo alcanzarlo", y eso convierte su punto debil en una
## invitacion a perseguir.
##
## Tres tramos porque es el minimo que se lee como zigzag: con dos parece que ha
## cambiado de idea.

var _destino: Vector3 = Vector3.ZERO
var _tramo: int = 0
var _lado: float = 1.0


func enter(_msg: Dictionary = {}) -> void:
	_tramo = 0
	# El primer lado se echa a suertes: si siempre empezara por el mismo, el
	# jugador aprenderia a esperarlo ahi y la huida dejaria de ser una huida.
	_lado = 1.0 if randf() < 0.5 else -1.0
	_siguiente_tramo()


func physics_update(delta: float) -> void:
	if not enemigo.objetivo_valido():
		fsm.cambiar(&"Dormido")
		return

	var hacia := _destino - enemigo.global_position
	if hacia.length() < 1.2:
		_tramo += 1
		if _tramo < enemigo.tramos_zigzag:
			_siguiente_tramo()
		else:
			enemigo.motor.frenar(delta, 12.0)
	else:
		enemigo.motor.mover(hacia.normalized(), enemigo.velocidad * 1.6, delta)

	# Sigue mirando al jugador mientras huye: es lo que hace legible que sigue
	# pendiente de ti y que va a volver.
	enemigo.encarar(enemigo.hacia_objetivo())

	if t >= enemigo.recarga:
		enemigo.espera = 0.0
		fsm.cambiar(&"Acercarse")


## Cada tramo sale ALEJANDOSE del jugador, abierto a un lado, y alternando. La
## suma de los tres es una huida; cada uno por separado, un quiebro.
func _siguiente_tramo() -> void:
	var huida := enemigo.global_position - enemigo.objetivo.global_position
	huida.y = 0.0
	if huida.is_zero_approx():
		huida = enemigo.frente()
	huida = huida.normalized().rotated(Vector3.UP, deg_to_rad(enemigo.apertura_zigzag) * _lado)
	_lado = -_lado
	_destino = enemigo.global_position + huida * enemigo.distancia_tramo
	_destino.y = enemigo.punto_de_vuelo().y


func debug_line() -> String:
	return "RECARGA  tramo %d/%d  %.1f s" % [
		_tramo + 1, enemigo.tramos_zigzag, maxf(enemigo.recarga - t, 0.0)]
