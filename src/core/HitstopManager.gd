extends Node
## Autoload. Congela la animación de atacante y receptor durante unos frames.
##
## REGLA DURA (CLAUDE.md #5): NUNCA Engine.time_scale. Ralentizar el motor entero
## se siente como lag, no como impacto. Aquí se congela solo lo que participa en
## el golpe, más una micro-pausa global de 1–3 frames que el gameplay consulta.
##
## Escala de referencia (docs/03_ARQUITECTURA_MECANICAS.md §3.2):
##   ligero 50 ms · pesado 90 ms · parry 160 ms · punto débil de coloso 250 ms

## Tope de la pausa global, en frames. 10 a 60 Hz son 167 ms: por encima deja de
## leerse como un impacto y pasa a leerse como que el juego se ha colgado.
const PAUSA_MAX_FRAMES := 10

var _congelados: Dictionary = {}   # Node -> segundos restantes
## FRAME DE FISICA EN EL QUE SE REANUDA, no un contador que se descuenta.
##
## **Con un contador la pausa duraba cero.** Se pedia desde el
## `_physics_process` del jugador y se descontaba en el del autoload, que corre
## ANTES: la pausa de un frame se apagaba antes de que nadie llegara a leerla.
## Medido con `MedirPatada`: `PAUSA 0 frames` al conectar una patada.
##
## Contra un numero de frame absoluto eso no puede pasar — no hay orden que
## respetar, solo una comparacion.
var _pausa_hasta: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
	if _congelados.is_empty():
		return
	var terminados: Array = []
	for nodo in _congelados:
		if not is_instance_valid(nodo):
			terminados.append(nodo)
			continue
		_congelados[nodo] = float(_congelados[nodo]) - delta
		if _congelados[nodo] <= 0.0:
			terminados.append(nodo)
			_descongelar(nodo)
	for nodo in terminados:
		_congelados.erase(nodo)


## Petición estándar: congela a los participantes y dispara la micro-pausa global.
func golpe(duracion: float, participantes: Array[Node] = []) -> void:
	for nodo in participantes:
		congelar(nodo, duracion)
	var frames: int = clampi(roundi(duracion * 60.0), 1, PAUSA_MAX_FRAMES)
	_pausa_hasta = maxi(_pausa_hasta, Engine.get_physics_frames() + frames)
	EventBus.hitstop_requested.emit(duracion)


## Congela la animación de un nodo (o de su AnimationTree/AnimationPlayer hijo).
func congelar(nodo: Node, duracion: float) -> void:
	if not is_instance_valid(nodo) or duracion <= 0.0:
		return
	var restante: float = maxf(float(_congelados.get(nodo, 0.0)), duracion)
	if not _congelados.has(nodo):
		_aplicar(nodo, true)
	_congelados[nodo] = restante


## ¿Estamos en la micro-pausa global? El gameplay la consulta para no avanzar.
##
## **Y LA PAUSA ES LA UNICA PARTE DEL HITSTOP QUE HOY SE VE.** `congelar()` para
## `AnimationTree`s, y este juego todavia se prueba con capsulas grises (regla
## dura #7): no hay animacion que parar. Hasta que existan, el impacto se
## comunica parando el mundo y moviendo a la victima, y nada mas.
func global_activo() -> bool:
	return Engine.get_physics_frames() < _pausa_hasta


func esta_congelado(nodo: Node) -> bool:
	return _congelados.has(nodo)


func limpiar() -> void:
	for nodo in _congelados:
		_descongelar(nodo)
	_congelados.clear()
	_pausa_hasta = 0


func _descongelar(nodo: Node) -> void:
	_aplicar(nodo, false)


func _aplicar(nodo: Node, congelar_flag: bool) -> void:
	if not is_instance_valid(nodo):
		return
	var tree := _buscar(nodo, "AnimationTree") as AnimationTree
	if tree != null:
		tree.active = not congelar_flag
		return
	var player := _buscar(nodo, "AnimationPlayer") as AnimationPlayer
	if player != null:
		player.speed_scale = 0.0 if congelar_flag else 1.0


func _buscar(raiz: Node, clase: String) -> Node:
	if raiz.is_class(clase):
		return raiz
	for hijo in raiz.get_children():
		var r := _buscar(hijo, clase)
		if r != null:
			return r
	return null

