extends SpearState
## SUSPENDIDA EN EL AIRE: la lanza deja de ser un arma y pasa a ser un SITIO.
##
## Vuela corto, frena y **se queda flotando** unos segundos. Mientras está ahí es
## lo único del juego a lo que se le puede dar una patada sin que desaparezca —
## una diana de pogo que te fabricas tú donde no hay nada.
##
## **Y ese era el agujero de la patada.** Medido en `MedirPatada`: conectar con un
## enemigo dice `victima: MURIO en el acto`. Con 200 de daño y 999 de poise todo
## se muere de un golpe, así que «conectar y rebotar» no llegaba a ser un bucle:
## había un rebote y se acabó lo que había que pisar. Para que sea un bucle hace
## falta algo que SOBREVIVA al golpe, y eso no se arregla bajando un número de
## daño —eso es balance— sino teniendo un objeto que no es un enemigo.
##
## Lo que la hace pateable es una `Hurtbox` del bando contrario (`equipo = 1`),
## encendida solo aquí. O sea que **la patada no sabe que esto existe**: la
## consulta de `Hitbox` es la de siempre y encuentra una hurtbox más. Un verbo
## nuevo que no toca el verbo viejo.
##
## Al recibir la patada se cae (`Spear.recibir_golpe`). **Una lanzada, un pogo**:
## si se quedara flotando se podría subir por ella indefinidamente, y eso es una
## escalera al cielo con pasos extra.

## Bamboleo del flotado, en metros. No es decoración: una lanza absolutamente
## quieta en el aire se lee como un objeto olvidado por el motor, y hay que
## distinguir de un vistazo "esto está vivo y se puede patear" de "esto se cayó".
const BAMBOLEO := 0.12

var _centro: Vector3 = Vector3.ZERO


func enter(_msg: Dictionary = {}) -> void:
	_centro = lanza.global_position
	lanza.soltar_plataforma()
	# Se pone de pie, que es la postura que dice "soy un escalón" en vez de
	# "soy un proyectil". `Grounded` hace lo contrario y por lo mismo.
	lanza.apuntar_a(Vector3.UP)
	lanza.armar_hurtbox(true)
	CombatFX.onda(lanza.get_parent(), _centro, lanza.color_de(&"oro_palido"), 1.2)


func exit(_siguiente: StringName) -> void:
	lanza.armar_hurtbox(false)


func physics_update(_delta: float) -> void:
	# Flota en el sitio. No hay gravedad aquí a propósito: el jugador tiene que
	# poder apuntar a donde la dejó, y un blanco que cae es un blanco que hay que
	# predecir además de alcanzar.
	var fase := t * TAU / maxf(tuning.suspension_bamboleo, 0.05)
	lanza.global_position = _centro + Vector3.UP * (sin(fase) * BAMBOLEO)

	if t >= tuning.suspension_duracion:
		fsm.cambiar(&"Grounded")


func debug_line() -> String:
	return "SUSPENDIDA  quedan %.1fs" % maxf(0.0, tuning.suspension_duracion - t)
