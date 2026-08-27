class_name SpearStateMachine
extends Node
## FSM de la lanza. Plana, como la de los enemigos: seis estados sin jerarquia
## no necesitan grupos, y anadirlos "por si acaso" seria arquitectura por
## adelantado.
##
##   Holstered -> Wielded -> InFlight -> Embedded | Grounded -> Returning

@export var estado_inicial: StringName = &"Wielded"

var actual: SpearState
var anterior: StringName = &""

var _estados: Dictionary = {}
var _l: Spear


func configurar(l: Spear) -> void:
	_l = l
	for hijo in get_children():
		if hijo is SpearState:
			var s := hijo as SpearState
			s.configurar(l, self)
			_estados[s.name] = s
	if not _estados.has(estado_inicial):
		push_error("SpearStateMachine: no existe el estado inicial '%s'" % estado_inicial)
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
		push_error("SpearStateMachine: no existe el estado '%s'" % nombre)
		return
	if actual != null and actual.name == nombre and not reentrar:
		return
	if actual != null:
		actual.exit(nombre)
		anterior = actual.name
	actual = _estados[nombre]
	actual.t = 0.0
	actual.enter(msg)
	if _l != null:
		_l.estado_cambiado.emit(nombre)


func nombre_actual() -> StringName:
	return actual.name if actual != null else &""


func existe(nombre: StringName) -> bool:
	return _estados.has(nombre)
