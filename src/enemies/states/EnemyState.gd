class_name EnemyState
extends Node
## Base de los estados de enemigo. Misma forma que `PlayerState` a proposito:
## duplicar un patron que ya funciona cuesta menos que inventar otro, y quien sepa
## leer la FSM del jugador sabe leer esta.

var enemigo: Enemigo
var fsm: EnemyStateMachine
## Segundos dentro de este estado.
var t: float = 0.0


func configurar(e: Enemigo, maquina: EnemyStateMachine) -> void:
	enemigo = e
	fsm = maquina


func enter(_msg: Dictionary = {}) -> void:
	pass


func exit(_siguiente: StringName = &"") -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


## Texto para el DebugOverlay.
func debug_line() -> String:
	return ""
