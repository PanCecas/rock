class_name SwordStateMachine
extends Node
## FSM de la espada. Plana, como la de la lanza y la de los enemigos.
##
##   Wielded -> Swing -> Wielded
##   Wielded -> InFlight -> Returning -> Wielded
##   InFlight | Returning -> Homing -> Returning
##
## **`Swing` vive AQUI y no en la FSM del jugador, y esa es la decision de diseño
## mas importante de toda la espada.** Un corte no te mueve —te mueve la patada,
## que es el otro boton— asi que no es una transicion del jugador: es un gesto
## que corre ENCIMA de lo que estuvieras haciendo. Cortar corriendo, deslizando,
## colgado del arco o a media patada funciona sin que ningun grupo tenga que
## enterarse, y de paso desaparece entero el problema de la regla dura #13: no
## hay accion compartida que repartir entre tres grupos ni guardia que olvidar.

@export var estado_inicial: StringName = &"Wielded"

var actual: SwordState
var anterior: StringName = &""

var _estados: Dictionary = {}
var _e: Sword


func configurar(e: Sword) -> void:
	_e = e
	for hijo in get_children():
		if hijo is SwordState:
			var s := hijo as SwordState
			s.configurar(e, self)
			_estados[s.name] = s
	if not _estados.has(estado_inicial):
		push_error("SwordStateMachine: no existe el estado inicial '%s'" % estado_inicial)
		return
	actual = _estados[estado_inicial]
	actual.t = 0.0
	actual.enter()


func physics_update(delta: float) -> void:
	if actual == null:
		return
	actual.t += delta
	actual.physics_update(delta)


func cambiar(nombre: StringName, msg: Dictionary = {}, reentrar: bool = false) -> void:
	if not _estados.has(nombre):
		push_error("SwordStateMachine: no existe el estado '%s'" % nombre)
		return
	if actual != null and actual.name == nombre and not reentrar:
		return
	if actual != null:
		actual.exit(nombre)
		anterior = actual.name
	actual = _estados[nombre]
	actual.t = 0.0
	actual.enter(msg)
	if _e != null:
		_e.estado_cambiado.emit(nombre)


func nombre_actual() -> StringName:
	return actual.name if actual != null else &""


func existe(nombre: StringName) -> bool:
	return _estados.has(nombre)
