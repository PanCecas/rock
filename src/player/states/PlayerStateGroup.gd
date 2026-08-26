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
## Un solo boton y una sola idea —"tirar de la cuerda"—, pero hace dos cosas
## segun donde estes, y la regla es lo bastante corta para tenerla en la cabeza:
##
##   **en el suelo la cuerda te SUBE; en el aire te SOSTIENE.**
##
## Con la lanza en vuelo siempre tira, porque no hay de que colgarse todavia:
## vas detras de ella.
##
## Esto no es un boton contextual de los que el proyecto evita. La INTENCION es
## siempre la misma; lo que cambia es que tengas suelo debajo o no, que es algo
## que el jugador ya sabe sin mirar.
##
## Vive aqui —y no repetido en cada grupo— porque es UNA regla. Los grupos solo
## deciden DONDE en su orden preguntarla, que es lo unico que cambia entre ellos,
## y va detras de las preguntas de TERRENO: el corolario de la regla dura #13 dice
## que un guardia de accion no puede cancelar una transicion de terreno, y ahi
## vivio el "floating fall".
func intentar_cuerda() -> bool:
	var l: Spear = player.lanza
	if l == null or not is_instance_valid(l) or l.en_mano():
		return false
	if not buffer.consume(InputActions.ROPE):
		return false

	# Colgarse pide una lanza CLAVADA y no tener suelo debajo. De una lanza en
	# vuelo no cuelga nadie, y colgarse pisando el suelo no es colgarse.
	if l.clavada_en_algo() and not player.is_on_floor():
		fsm.cambiar(&"SpearSwing", {}, true)
		return true

	if not player.stamina.gastar(tuning.zip_stamina):
		return false
	fsm.cambiar(&"SpearZip", {}, true)
	return true


## Al entrar en cualquier hoja de este grupo.
func on_enter_hijo(_hoja: PlayerState) -> void:
	pass
