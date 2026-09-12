class_name PlayerStateGroup
extends PlayerState
## Nodo agrupador de la FSM jerárquica: Grounded, Airborne, Attached.
##
## El grupo corre ANTES que la hoja y resuelve las transiciones compartidas por
## todos sus hijos: "cualquier estado de suelo puede saltar", "cualquier estado de
## aire puede agarrar un borde". Sin esto cada hoja repetiría los mismos ocho ifs y
## la FSM se convertiría en el spaghetti que el doc de arquitectura avisa de evitar.

var nombre: StringName = &""


func _ready() -> void:
	nombre = name


## Se ejecuta antes que la hoja. Si cambia de estado, la hoja ya no corre.
func shared_update(_delta: float) -> void:
	pass


## LA CUERDA, compartida. Devuelve true si ha cambiado de estado.
##
## **UN verbo, un boton, un arco.** Hasta el 3.16 esta funcion repartia entre
## cuatro —zarandeo, resortera, balanceo y zip— y lo que decidia cual salia era
## cuantos puntos tenias clavados y donde. Eso obligaba a llevar la cuenta de dos
## armas para saber que iba a hacer un boton, y ninguno de los cuatro terminaba
## solo: los cuatro eran MODOS. Ahora el ancla la pone el nivel, esta ahi, se ve,
## y engancharse es una sola pulsacion.
##
## Sigue viviendo aqui —y no repetida en cada grupo— porque es UNA regla. Los
## grupos solo deciden DONDE preguntarla dentro de su orden, y va detras de las
## preguntas de TERRENO: el corolario de la regla dura #13 dice que un guardia de
## accion no puede cancelar una transicion de terreno.
func intentar_cuerda() -> bool:
	# SI LA HOJA SE QUEDA LA CUERDA, EL GRUPO NO SE LA ROBA. Regla dura #13, y
	# aqui pesa doble: `Grapple` vive en `Attached`, o sea que el grupo que
	# resuelve la Z es el mismo al que pertenece. Sin esto, colgado y con la Z
	# pulsada se reentraria en el estado cada frame y el arco no avanzaria nunca.
	if fsm.actual != null and fsm.actual.maneja_cuerda():
		return false

	# UNA POR TIEMPO DE VUELO. Se pregunta ANTES de buscar ancla porque es la
	# comprobacion barata, y ANTES de consumir la pulsacion porque una pulsacion
	# tragada sin efecto es indistinguible de un boton que no responde.
	if not player.cuerda_disponible:
		return false

	# Y SE BUSCA ANTES DE CONSUMIR, por lo mismo. Si no hay nada a lo que
	# engancharse, la pulsacion sigue viva: el jugador que pulsa Z medio segundo
	# antes de que el ancla entre en el cono se merece que le cuente.
	var ancla := player.buscar_ancla()
	if ancla == null:
		return false
	if not buffer.consume(InputActions.ROPE):
		return false

	fsm.cambiar(&"Grapple", {"ancla": ancla}, true)
	return true


## Al entrar en cualquier hoja de este grupo.
func on_enter_hijo(_hoja: PlayerState) -> void:
	pass
