extends PlayerState
## ZIP A LA LANZA: te tira hacia ella. Es el modo Zip de `docs/03 §5`.
##
## Dos usos, y son distintos aunque el código sea el mismo:
##
##   · **con la lanza EN VUELO** -> te acercas. La lanza va hacia el enemigo y tú
##     detrás: llegas con ella.
##   · **con la lanza CLAVADA** -> te retiras, o subes. La tiras a lo alto y te
##     subes tú.
##
## **Impulso, nunca teletransporte.** Un salto de posición sin comprobar el camino
## es como se acaba dentro de la geometría, y este proyecto ya tiene un antiatasco
## para las veces que eso pasa solo. Aquí no hace falta comprobar nada a mano: se
## escribe velocidad y `move_and_slide` para contra lo que haya. El muro te para
## porque es un muro, no porque un rayo lo haya predicho.
##
## Escribe `velocity` en 3D directamente en vez de usar `motor.acelerar()`, y es
## deliberado: el motor separa plano y vertical porque TODA la locomoción de
## tierra es así. Un zip a una lanza clavada a doce metros de altura no lo es.

var _objetivo: Vector3 = Vector3.ZERO
var _agotado: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_agotado = false
	player.enderezar()
	# La cámara y el cuerpo miran hacia donde te tira: sin esto llegas de espaldas.
	var hacia := _punto() - player.global_position
	player.orientar_a(hacia)
	EventBus.camara_shake.emit(0.25, 0.1)


func physics_update(delta: float) -> void:
	if not _valido():
		_soltar()
		return

	_objetivo = _punto()
	var hacia := _objetivo - player.global_position
	var dist := hacia.length()

	if dist <= tuning.zip_radio_llegada:
		_llegar()
		return

	if t >= tuning.zip_duracion_max:
		_soltar()
		return

	# Sin gravedad: durante el tirón manda la cuerda, no el peso.
	var deseada := hacia.normalized() * tuning.zip_velocidad
	player.velocity = player.velocity.move_toward(deseada, tuning.zip_aceleracion * delta)

	# ATASCADO. Si hay un muro entre tú y la lanza, `move_and_slide` te para y la
	# distancia deja de bajar. Sin esto te quedarías empujando piedra hasta que
	# venciera el tiempo, que se lee como que el juego se ha colgado.
	if player.is_on_wall() and t > 0.25:
		_soltar()


func exit(_siguiente: StringName = &"") -> void:
	# Se conserva momentum, que es LO que hace útil el zip: si al llegar te
	# frenaras en seco solo serviría para colocarte, nunca para encadenar.
	if not _agotado:
		player.velocity *= tuning.zip_conserva


## ¿Sigue habiendo a dónde ir? La lanza en la mano no es un destino.
func _valido() -> bool:
	var l: Spear = player.lanza
	if l == null or not is_instance_valid(l):
		return false
	return not l.en_mano()


func _punto() -> Vector3:
	var l: Spear = player.lanza
	if l == null or not is_instance_valid(l):
		return player.global_position
	return l.global_position


func _llegar() -> void:
	# Un pelín hacia arriba al llegar: aterrizar justo sobre una lanza clavada en
	# horizontal pide ese margen, y sin él te quedas colgando del canto.
	player.velocity += sc.up * 2.0
	_salir()


func _soltar() -> void:
	_agotado = true
	_salir()


func _salir() -> void:
	if player.is_on_floor():
		fsm.cambiar(&"Idle")
	else:
		fsm.cambiar(&"Fall")



## El zip se paga entero al empezar. Quedarse a cero a mitad de vuelo no puede
## soltarte: no es un agarre que se sostiene, es un tiron que ya esta lanzado.
func resiste_agotamiento() -> bool:
	return true


func debug_line() -> String:
	return "ZIP  %.1f m" % player.global_position.distance_to(_objetivo)
