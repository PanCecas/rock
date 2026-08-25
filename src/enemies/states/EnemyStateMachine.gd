class_name EnemyStateMachine
extends Node
## FSM del enemigo. Plana, sin grupos: la IA de un saco de boxeo no los necesita,
## y anadirlos "por si acaso" seria arquitectura por adelantado.
##
## Estructura esperada en la escena:
##   FSM
##     Dormido · Acercarse · Telegrafia · Atacar · Recuperar
##     Aturdido · Derribado · Quebrado · Muerto

@export var estado_inicial: StringName = &"Dormido"

var actual: EnemyState
var anterior: StringName = &""

var _estados: Dictionary = {}
var _e: Enemigo


func configurar(e: Enemigo) -> void:
	_e = e
	for hijo in get_children():
		if hijo is EnemyState:
			var s := hijo as EnemyState
			s.configurar(e, self)
			_estados[s.name] = s
	if not _estados.has(estado_inicial):
		push_error("EnemyStateMachine: no existe el estado inicial '%s'" % estado_inicial)
		return
	actual = _estados[estado_inicial]
	actual.t = 0.0
	actual.enter()


func physics_update(delta: float) -> void:
	if actual == null:
		return
	actual.t += delta
	actual.physics_update(delta)


## `reentrar` permite volver a entrar al mismo estado. Hace falta para el ataque
## encadenado, igual que en la FSM del jugador.
func cambiar(nombre: StringName, msg: Dictionary = {}, reentrar: bool = false) -> void:
	if not _estados.has(nombre):
		push_error("EnemyStateMachine: no existe el estado '%s'" % nombre)
		return
	if actual != null and actual.name == nombre and not reentrar:
		return
	if actual != null:
		actual.exit(nombre)
		anterior = actual.name
	actual = _estados[nombre]
	actual.t = 0.0
	actual.enter(msg)


func nombre_actual() -> StringName:
	return actual.name if actual != null else &""


func existe(nombre: StringName) -> bool:
	return _estados.has(nombre)
