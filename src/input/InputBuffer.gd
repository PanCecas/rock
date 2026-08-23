class_name InputBuffer
extends Node
## Ventana deslizante de las últimas pulsaciones con timestamp.
##
## REGLA DURA (CLAUDE.md #4): los estados NUNCA llaman a Input directamente.
## Este nodo es el único que lo hace. Todo lo demás pregunta aquí.
##
## Es lo que separa un plataformero que se siente bien de uno que se siente roto:
## el jugador pulsa salto 80 ms antes de aterrizar y el juego se lo respeta.

## Cuánto tiempo sobrevive una pulsación en el buffer.
@export_range(0.05, 1.0, 0.01) var ventana_default: float = 0.15
## Máximo de entradas guardadas. 20 sobra de largo.
@export var capacidad: int = 20

var _entradas: Array[Dictionary] = []
var _tiempo: float = 0.0
var _consumidas: Dictionary = {}


func _ready() -> void:
	process_priority = -100  # antes que cualquier consumidor


func _physics_process(delta: float) -> void:
	_tiempo += delta
	for accion in InputActions.BUFFERED:
		if Input.is_action_just_pressed(accion):
			_registrar(accion)
	_purgar()


func _registrar(accion: StringName) -> void:
	_entradas.append({"accion": accion, "t": _tiempo})
	_consumidas.erase(accion)
	if _entradas.size() > capacidad:
		_entradas.pop_front()


func _purgar() -> void:
	# La ventana más larga que alguien pueda pedir; con 1 s vamos sobrados.
	var limite := _tiempo - 1.0
	while not _entradas.is_empty() and _entradas[0]["t"] < limite:
		_entradas.pop_front()


## ¿Hay una pulsación reciente sin consumir? No la gasta.
func peek(accion: StringName, ventana: float = -1.0) -> bool:
	var w := ventana if ventana >= 0.0 else ventana_default
	var ultima := _ultima(accion)
	if ultima < 0.0:
		return false
	if _consumidas.get(accion, -1.0) == ultima:
		return false
	return (_tiempo - ultima) <= w


## Igual que peek() pero marca la pulsación como usada. Es lo que llaman los estados.
func consume(accion: StringName, ventana: float = -1.0) -> bool:
	if not peek(accion, ventana):
		return false
	_consumidas[accion] = _ultima(accion)
	return true


## Estado mantenido del botón, sin buffer. Para planear, apuntar, agarrarse.
func is_held(accion: StringName) -> bool:
	return Input.is_action_pressed(accion)


## Vector de movimiento en espacio de cámara, ya normalizado y con zona muerta.
func move_vector() -> Vector2:
	return Input.get_vector(
		InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
		InputActions.MOVE_FORWARD, InputActions.MOVE_BACK
	)


## Segundos desde la última pulsación de la acción. INF si nunca.
func time_since(accion: StringName) -> float:
	var ultima := _ultima(accion)
	return INF if ultima < 0.0 else _tiempo - ultima


## Vacía el buffer. Se llama al respawnear o al entrar en cinemática.
func clear() -> void:
	_entradas.clear()
	_consumidas.clear()


## Contenido actual, para el DebugOverlay.
func debug_line() -> String:
	if _entradas.is_empty():
		return "—"
	var partes := PackedStringArray()
	for i in range(maxi(0, _entradas.size() - 4), _entradas.size()):
		var e := _entradas[i]
		var edad: float = _tiempo - float(e["t"])
		var usada := "·" if _consumidas.get(e["accion"], -1.0) == e["t"] else "!"
		partes.append("%s%s%.0fms" % [e["accion"], usada, edad * 1000.0])
	return " ".join(partes)


func _ultima(accion: StringName) -> float:
	for i in range(_entradas.size() - 1, -1, -1):
		if _entradas[i]["accion"] == accion:
			return _entradas[i]["t"]
	return -1.0
