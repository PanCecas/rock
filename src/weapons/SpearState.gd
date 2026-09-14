class_name SpearState
extends Node
## Estado de la lanza. Mismo contrato que `EnemyState` y `PlayerState`: un nodo
## por estado, con `enter/exit/physics_update` y sus transiciones declaradas.

var lanza: Spear
var fsm: SpearStateMachine
var tuning: SpearTuning
## Segundos dentro de este estado.
var t: float = 0.0


func configurar(l: Spear, maquina: SpearStateMachine) -> void:
	lanza = l
	fsm = maquina
	tuning = l.tuning


func enter(_msg: Dictionary = {}) -> void:
	pass


func exit(_siguiente: StringName) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func debug_line() -> String:
	return name
