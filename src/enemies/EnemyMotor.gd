class_name EnemyMotor
extends RefCounted
## COMO se mueve un enemigo. Lo unico que separa a un guardian de un volador.
##
## Existe porque `Guardian.gd` asumia suelo —`is_on_floor()`, gravedad manual,
## `velocity.y` a mano— dentro de la misma funcion que decidia a quien atacar. Con
## eso, escribir un enemigo que vuela o que nada obligaba a duplicar el script
## entero para cambiar tres lineas de fisica.
##
## `vuela = true` apaga la gravedad y permite moverse en los tres ejes. Ese es todo
## el cambio: la IA no se entera.

var vuela: bool = false
var gravedad: float = 30.0
var aceleracion: float = 24.0

var _e: CharacterBody3D


func _init(cuerpo: CharacterBody3D) -> void:
	_e = cuerpo


## Gravedad y pegado al suelo. En vuelo no hace nada.
##
## OJO con el `elif`: pegarse al suelo solo si NO vamos hacia arriba. Un `else`
## incondicional borraba el `lanzamiento` de los AttackData en el mismo frame del
## impacto —el enemigo seguia tocando suelo cuando se le asignaba la velocidad—
## asi que ningun ataque conseguia mandar a nadie por los aires.
func aplicar_gravedad(delta: float) -> void:
	if vuela:
		return
	if not _e.is_on_floor():
		_e.velocity.y -= gravedad * delta
	elif _e.velocity.y <= 0.0:
		_e.velocity.y = -2.0


## Acelera hacia una direccion. En vuelo el eje vertical cuenta; en suelo no, para
## que perseguir a un jugador que esta encima no despegue al enemigo.
func mover(dir: Vector3, velocidad: float, delta: float) -> void:
	var deseada := dir * velocidad
	_e.velocity.x = move_toward(_e.velocity.x, deseada.x, aceleracion * delta)
	_e.velocity.z = move_toward(_e.velocity.z, deseada.z, aceleracion * delta)
	if vuela:
		_e.velocity.y = move_toward(_e.velocity.y, deseada.y, aceleracion * delta)


## `tasa` va en m/s2. El original usaba 1.2 POR FRAME sin delta —72 m/s2 a 60 Hz—,
## que es un frenado casi instantaneo. Se conserva ese comportamiento porque es el
## que hace que un enemigo se plante en seco al telegrafiar.
func frenar(delta: float, tasa: float = 72.0) -> void:
	_e.velocity.x = move_toward(_e.velocity.x, 0.0, tasa * delta)
	_e.velocity.z = move_toward(_e.velocity.z, 0.0, tasa * delta)
	if vuela:
		_e.velocity.y = move_toward(_e.velocity.y, 0.0, tasa * delta)


func rapidez_plana() -> float:
	return Vector2(_e.velocity.x, _e.velocity.z).length()
