class_name PlayerState
extends Node
## Base de todos los estados. Cada estado es un Node hijo de la StateMachine.
##
## REGLA DURA (CLAUDE.md #2): prohibido `if estado == "x"` fuera de aquí. Si algún
## sistema necesita saber el estado, que pregunte `fsm.actual.categoria` o escuche
## `EventBus.player_state_changed`.

## Categoría del estado, para consultas y para el HFSM. La rellena el grupo padre.
var categoria: StringName = &"":
	get:
		return grupo.nombre if grupo != null else &""

var player: PlayerController
var fsm: StateMachine
var grupo: PlayerStateGroup
## Segundos dentro de este estado.
var t: float = 0.0

## Atajos: los estados escriben mucho contra estas tres cosas.
var tuning: PlayerTuning:
	get: return player.tuning
var buffer: InputBuffer:
	get: return player.buffer
var motor: LocomotionMotor:
	get: return player.motor
var sc: SurfaceContext:
	get: return player.superficie


func configurar(p: PlayerController, maquina: StateMachine, g: PlayerStateGroup) -> void:
	player = p
	fsm = maquina
	grupo = g


## `msg` transporta datos entre estados sin acoplarlos (velocidad de entrada,
## punto de borde, dirección de dash...).
func enter(_msg: Dictionary = {}) -> void:
	pass


## `siguiente` es el estado al que se va. Se pasa como parámetro porque la FSM
## llama a exit() ANTES de reasignar `fsm.actual`: preguntarle ahí por el destino
## devolvía el estado que se está abandonando, y las comprobaciones de "¿me voy al
## aire?" o "¿sigo agarrado?" nunca se cumplían.
func exit(_siguiente: StringName = &"") -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


## Texto para el DebugOverlay. Se sobrescribe si el estado tiene algo que contar.
func debug_line() -> String:
	return ""
