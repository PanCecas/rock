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
## SILENCIADO: el jugador no recibe input, y el mundo sigue corriendo.
##
## Vive AQUI y no en la FSM ni en el controlador porque la regla dura #4 ya
## garantiza que este es el unico nodo que habla con `Input`: cortarlo aqui apaga
## el movimiento, los ataques, el salto, la lanza y la cuerda de una vez y para
## siempre. Cualquier otro sitio seria una lista que hay que acordarse de
## ampliar cada vez que nazca un verbo.
var silenciado: bool = false


func _ready() -> void:
	process_priority = -100  # antes que cualquier consumidor
	EventBus.interfaz_modal.connect(silenciar)


## Corta o devuelve el input del jugador. Al cortar se VACIA el buffer: una
## pulsacion guardada justo antes de abrir la interfaz se ejecutaria al cerrarla,
## y eso se siente como un fantasma.
func silenciar(si: bool) -> void:
	silenciado = si
	if si:
		clear()


func _physics_process(delta: float) -> void:
	_tiempo += delta
	if silenciado:
		return
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
##
## Consumir también invalida las acciones que comparten tecla (InputActions.EXCLUSIVAS):
## si Espacio dispara `jump` y `glide`, quien llegue primero se queda la pulsación.
func consume(accion: StringName, ventana: float = -1.0) -> bool:
	if not peek(accion, ventana):
		return false
	var cuando := _ultima(accion)
	_consumidas[accion] = cuando
	for hermana in InputActions.EXCLUSIVAS.get(accion, []):
		var suya := _ultima(hermana)
		# Solo si vino de la MISMA pulsación: dos teclas distintas pulsadas casi a
		# la vez siguen siendo dos intenciones distintas.
		if suya >= 0.0 and absf(suya - cuando) < 0.03:
			_consumidas[hermana] = suya
	return true


## Estado mantenido del botón, sin buffer. Para planear, apuntar, agarrarse.
func is_held(accion: StringName) -> bool:
	return not silenciado and Input.is_action_pressed(accion)


## Vector de movimiento en espacio de cámara, ya normalizado y con zona muerta.
func move_vector() -> Vector2:
	if silenciado:
		return Vector2.ZERO
	return Input.get_vector(
		InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
		InputActions.MOVE_FORWARD, InputActions.MOVE_BACK
	)


## Cuánto lleva MANTENIDA la acción. 0 si no está pulsada ahora mismo.
## Es lo que distingue un toque de un mantener sin duplicar acciones en el mapa.
func held_time(accion: StringName) -> float:
	if silenciado or not Input.is_action_pressed(accion):
		return 0.0
	var ultima := _ultima(accion)
	return 0.0 if ultima < 0.0 else _tiempo - ultima


## Segundos desde la última pulsación de la acción. INF si nunca.
func time_since(accion: StringName) -> float:
	var ultima := _ultima(accion)
	return INF if ultima < 0.0 else _tiempo - ultima


## Tira TODAS las pulsaciones pendientes de una acción.
##
## Es lo que garantiza "1 pulsación = 1 salto": tras saltar, cualquier pulsación
## que siguiera viva en la ventana deja de contar. Sin esto, machacar el botón
## acumulaba saltos que salían solos al aterrizar.
func invalidar(accion: StringName) -> void:
	var ultima := _ultima(accion)
	if ultima >= 0.0:
		_consumidas[accion] = ultima


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
