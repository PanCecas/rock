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


## ZIP A LA LANZA, compartido. Devuelve true si ha cambiado de estado.
##
## Vive aqui —y no repetido en cada grupo— porque es UNA regla: "si hay lanza
## fuera de la mano y pulsas la cuerda, te tira hacia ella". Los grupos solo
## deciden DONDE en su orden preguntarlo, que es lo unico que cambia entre ellos.
##
## Y va detras de las preguntas de TERRENO en cada grupo, nunca delante: el
## corolario de la regla dura #13 dice que un guardia de accion no puede cancelar
## una transicion de terreno, y ahi vivio el "floating fall".
func intentar_zip() -> bool:
	var l: Spear = player.lanza
	if l == null or not is_instance_valid(l) or l.en_mano():
		return false
	if not buffer.consume(InputActions.ROPE):
		return false
	if not player.stamina.gastar(tuning.zip_stamina):
		return false
	fsm.cambiar(&"SpearZip", {}, true)
	return true


## Al entrar en cualquier hoja de este grupo.
func on_enter_hijo(_hoja: PlayerState) -> void:
	pass
