class_name SwordState
extends Node
## Estado de la espada. Mismo contrato que `SpearState`, `EnemyState` y
## `PlayerState`: un nodo por estado, con `enter/exit/physics_update`.
##
## **Es una copia del de la lanza, y es a proposito.** Son dos armas con cinco y
## seis comportamientos cada una, y unificar los dos contratos en un
## `WeaponState` generico ahora mismo significaria tocar la lanza —que acaba de
## entrar y esta medida— para ahorrar sesenta lineas. Cuando exista la tercera
## arma habra tres copias y entonces la refactorizacion se paga sola: hasta
## entonces esto es la regla de tres, no un descuido.

var espada: Sword
var fsm: SwordStateMachine
var tuning: SwordTuning
## Segundos dentro de este estado.
var t: float = 0.0


func configurar(e: Sword, maquina: SwordStateMachine) -> void:
	espada = e
	fsm = maquina
	tuning = e.tuning


func enter(_msg: Dictionary = {}) -> void:
	pass


func exit(_siguiente: StringName) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func debug_line() -> String:
	return name
