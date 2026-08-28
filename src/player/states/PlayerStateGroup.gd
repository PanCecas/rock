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
	# HACE FALTA QUE LA LANZA ESTE AHI FUERA, no solo que no la lleves en la mano.
	# Aqui ponia `l.en_mano()`, que solo es cierto en `Wielded`: con la lanza
	# GUARDADA la negacion daba true y la cuerda tiraba de ti hacia una lanza
	# invisible parada en el punto de spawn. Ver `Spear.esta_fuera()`.
	if l == null or not is_instance_valid(l) or not l.esta_fuera():
		return false
	if not buffer.consume(InputActions.ROPE):
		return false

	# DOS PUNTOS MANDAN SOBRE UNO. Con la lanza y el anclaje puestos, el mismo
	# boton da la resortera en vez del balanceo, y no hay que aprender nada nuevo:
	# el numero de cuerdas que hay puestas se VE, y decide.
	#
	#   un punto  -> pendulo. Caes en arco y bombeas.
	#   dos puntos-> elastico. Tiras hacia atras y sales disparado.
	#
	# Que no haya un tercer boton es la mitad del diseño: quien quiera balancearse
	# teniendo los dos puestos recupera uno, y eso ya es una decision de posicion.
	# CARNE ANTES QUE MUNDO. Una daga clavada en un bicho agarrable no admite otra
	# lectura: lo que quieres es zarandearlo. Va delante de la resortera y del
	# balanceo porque los dos son verbos de traversal y este es de combate, y
	# porque el enemigo se te escapa mientras dudas.
	if player.daga_en_carne() != null:
		fsm.cambiar(&"Whirl", {}, true)
		return true

	if _resortera_lista():
		fsm.cambiar(&"Slingshot", {}, true)
		return true

	if l.clavada_en_algo():
		fsm.cambiar(&"SpearSwing", {}, true)
		return true

	if not player.stamina.gastar(tuning.zip_stamina):
		return false
	fsm.cambiar(&"SpearZip", {}, true)
	return true


## ¿Estan los DOS puntos puestos? Es lo unico que separa la resortera del
## balanceo, y por eso se pregunta en un solo sitio.
func _resortera_lista() -> bool:
	var l: Spear = player.lanza
	if l == null or not is_instance_valid(l) or not l.clavada_en_algo():
		return false
	# LA DAGA TIENE QUE ESTAR EN MUNDO, no en carne. Un enemigo se mueve, y un
	# ancla que anda rompe la conservacion de energia del elastico: la resortera
	# ALMACENA energia y la devuelve, asi que sus dos puntos tienen que ser fijos.
	return player.daga_en_mundo() != null


## Al entrar en cualquier hoja de este grupo.
func on_enter_hijo(_hoja: PlayerState) -> void:
	pass
