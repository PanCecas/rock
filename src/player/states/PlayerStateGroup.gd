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
## UNA sola cosa y un solo gesto:
##
##   lanza CLAVADA  -> te enganchas. Si estas lejos te recoge, y en cuanto llegas
##                     al radio ya estas balanceandote. Sin cambio de estado en
##                     medio y SIN tener que estar en el aire.
##   lanza EN VUELO -> te tira hacia ella. No hay de que colgarse todavia: la
##                     persigues.
##
## Antes esto eran dos verbos separados —zip en el suelo, balanceo en el aire— y
## se sentia clunky con razon: obligaba a dos pulsaciones y a un cambio de estado
## para algo que en la cabeza del jugador es un movimiento. Engancharse a algo
## clavado es UNA accion; que empiece recogiendo cuerda o girando es un detalle de
## donde estabas, no una decision que haya que tomar.
##
## Vive aqui —y no repetido en cada grupo— porque es UNA regla. Los grupos solo
## deciden DONDE en su orden preguntarla, y va detras de las preguntas de TERRENO:
## el corolario de la regla dura #13 dice que un guardia de accion no puede
## cancelar una transicion de terreno.
func intentar_cuerda() -> bool:
	var l: Spear = player.lanza
	if l == null or not is_instance_valid(l) or l.en_mano():
		return false
	if not buffer.consume(InputActions.ROPE):
		return false

	if l.clavada_en_algo():
		fsm.cambiar(&"SpearSwing", {}, true)
		return true

	if not player.stamina.gastar(tuning.zip_stamina):
		return false
	fsm.cambiar(&"SpearZip", {}, true)
	return true


## Al entrar en cualquier hoja de este grupo.
func on_enter_hijo(_hoja: PlayerState) -> void:
	pass
