extends Node
## Autoload. Congela la animación de atacante y receptor durante unos frames.
##
## REGLA DURA (CLAUDE.md #5): NUNCA Engine.time_scale. Ralentizar el motor entero
## se siente como lag, no como impacto. Aquí se congela solo lo que participa en
## el golpe, más una micro-pausa global de 1–3 frames que el gameplay consulta.
##
## Escala de referencia (docs/03_ARQUITECTURA_MECANICAS.md §3.2):
##   ligero 50 ms · pesado 90 ms · parry 160 ms · punto débil de coloso 250 ms

## Frames de micro-pausa global según la duración pedida.
const FRAMES_GLOBALES := {0.05: 1, 0.09: 2, 0.16: 2, 0.25: 3}

var _congelados: Dictionary = {}   # Node -> segundos restantes
var _pausa_global: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
	if _pausa_global > 0.0:
		_pausa_global = maxf(0.0, _pausa_global - delta)

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
	_pausa_global = maxf(_pausa_global, _frames_a_segundos(duracion))
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
func global_activo() -> bool:
	return _pausa_global > 0.0


func esta_congelado(nodo: Node) -> bool:
	return _congelados.has(nodo)


func limpiar() -> void:
	for nodo in _congelados:
		_descongelar(nodo)
	_congelados.clear()
	_pausa_global = 0.0


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


func _frames_a_segundos(duracion: float) -> float:
	var frames := 1
	for umbral in FRAMES_GLOBALES:
		if duracion >= float(umbral):
			frames = maxi(frames, int(FRAMES_GLOBALES[umbral]))
	return float(frames) / 60.0
