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


## ¿Y la CUERDA? Tercer miembro de la misma familia, y el que faltaba.
##
## Los cuatro verbos de cuerda —balanceo, zip, resortera y zarandeo— viven en
## `Attached`, o sea que el grupo que resuelve la Z es el mismo al que pertenecen.
## Sin este guardia, colgarse de la lanza y volver a pulsar Z reentraria en el
## estado en el que ya estas: la resortera, que TENSA mientras mantienes y
## dispara al SOLTAR, se rearmaria cada frame y no dispararia nunca.
func maneja_cuerda() -> bool:
	return false


## ¿Se arma el agarre AUTOMATICO de pared desde este estado?
##
## `PlayerTuning.escalada_auto_tiempo` lo dice en su propia descripcion:
## *"CAMINAR contra una pared perpendicular durante este tiempo engancha solo"*.
## Caminar. Llegar a un muro a 15 m/s surfeando no es insistir contra el, es
## chocar, y el codigo no distinguia las dos cosas: medido, **4 de las 5
## adherencias automaticas de 60 s de juego salieron directamente de `Surf`**, y
## la salida del surf acababa pegada a la geometria con la velocidad a cero. Eso
## es el "al salir del surf no puedo direccionar al personaje" que se reporto: el
## surf salia limpio —ocho caminos de salida medidos en pista libre, los ocho
## obedeciendo— y lo que bloqueaba era la pared que habia delante.
##
## Se apaga desde los verbos rapidos y no desde el sensor: el agarre a mano
## (`GRAB`) sigue funcionando igual desde todos ellos, asi que la mecanica no se
## pierde — deja de ocurrir SOLA.
func adherencia_automatica() -> bool:
	return true


## ¿Este estado sobrevive a quedarse sin stamina?
##
## `GroupAttached` te suelta en cuanto la stamina llega a cero, y esta bien: sin
## fuerzas te resbalas de una pared. Pero eso vale para lo que se SOSTIENE —
## escalar, colgarse—, no para un gesto que ya se pago entero al empezar. El zip
## a la lanza cuesta 12 de golpe; con 12 justos arrancaba y se cancelaba solo al
## frame siguiente, que se lee como que el juego ignoro la pulsacion.
func resiste_agotamiento() -> bool:
	return false


## Techo de velocidad HORIZONTAL para este estado, en m/s. Negativo = el global.
##
## La regla dura #12 dice que la velocidad se limita en UN SOLO SITIO, y se sigue
## cumpliendo: `_limitar_velocidad()` sigue siendo ese sitio. Lo que esto permite
## es que un estado DECLARE su techo ahi, en vez de recortar por su cuenta.
##
## Existe por el balanceo, y con una medicion detras. La gravedad de caida de este
## juego es -38 m/s², asi que un pendulo alcanza `sqrt(2*38*L)` abajo del arco:
## con cuerda de mas de 6.4 m ya pasa de 22. El clamp global no le hacia de techo,
## le hacia de IMPUESTO —le quitaba energia justo en el punto mas rapido, que es
## donde el arco es horizontal— y el columpio perdia altura en cada pasada por
## una razon que no era fisica.
##
## Se le da techo propio y no barra libre porque el motivo del clamp global sigue
## siendo bueno: encadenar sin techo saca al jugador del mapa. Pero un pendulo no
## es momentum encadenado; es un sistema cerrado cuyo pico lo fija la altura de
## caida, y esa la pone el nivel.
func techo_velocidad() -> float:
	return -1.0


## Texto para el DebugOverlay. Se sobrescribe si el estado tiene algo que contar.
func debug_line() -> String:
	return ""
