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


## ¿Este estado gestiona los botones de ataque por su cuenta?
##
## Los grupos corren ANTES que la hoja, así que sin esto GroupGrounded consumía la
## pulsación y lanzaba un ataque normal: atacar surfeando te sacaba del surf.
func maneja_ataques() -> bool:
	return false


## ¿Y el salto? Mismo motivo, y es el tercer sitio donde aparece el patrón: el
## salto alto de agachado y el long jump de surf nunca llegaban a ejecutarse
## porque el grupo se quedaba la pulsación y hacía un salto normal.
##
## Regla general: si una hoja tiene una versión PROPIA de una acción compartida,
## tiene que poder reclamarla, o el grupo se la come sin avisar.
func maneja_salto() -> bool:
	return false


## ¿Este estado sobrevive a quedarse sin stamina?
##
## `GroupAttached` te suelta en cuanto la stamina llega a cero, y esta bien: sin
## fuerzas te resbalas de una pared. Pero eso vale para lo que se SOSTIENE —
## escalar, colgarse—, no para un gesto que ya se pago entero al empezar. El zip
## a la lanza cuesta 12 de golpe; con 12 justos arrancaba y se cancelaba solo al
## frame siguiente, que se lee como que el juego ignoro la pulsacion.
func resiste_agotamiento() -> bool:
	return false


## Texto para el DebugOverlay. Se sobrescribe si el estado tiene algo que contar.
func debug_line() -> String:
	return ""
