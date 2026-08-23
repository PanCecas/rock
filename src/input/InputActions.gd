class_name InputActions
extends RefCounted
## Nombres de las acciones del input map, en un solo sitio.
## Nadie escribe un string de acción a mano.

# Movimiento
const MOVE_FORWARD := &"move_forward"
const MOVE_BACK := &"move_back"
const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const SPRINT := &"sprint"
const CROUCH := &"crouch"

# Traversal
const JUMP := &"jump"
const DASH := &"dash"
const GLIDE := &"glide"
const GRAB := &"grab"
const ROPE := &"rope"

# Combate
const ATTACK_LIGHT := &"attack_light"
const ATTACK_HEAVY := &"attack_heavy"
const PARRY := &"parry"
const DODGE := &"dodge"

# Armas
const AIM := &"aim"
const THROW_SPEAR := &"throw_spear"
const RECALL_SPEAR := &"recall_spear"
const SWAP_WEAPON := &"swap_weapon"

# Sistema
const INTERACT := &"interact"
const LOCK_ON := &"lock_on"
const DEBUG_TOGGLE := &"debug_toggle"
const DEBUG_RESET := &"debug_reset"

## Acciones que el InputBuffer vigila cada physics frame.
const BUFFERED: Array[StringName] = [
	JUMP, DASH, GLIDE, GRAB, ROPE,
	ATTACK_LIGHT, ATTACK_HEAVY, PARRY, DODGE,
	THROW_SPEAR, RECALL_SPEAR, SWAP_WEAPON,
	INTERACT, LOCK_ON, CROUCH,
]

## Acciones cuyo estado mantenido consulta el jugador.
const HELD: Array[StringName] = [
	MOVE_FORWARD, MOVE_BACK, MOVE_LEFT, MOVE_RIGHT,
	SPRINT, CROUCH, JUMP, GLIDE, AIM, GRAB, PARRY,
]

## Acciones que COMPARTEN TECLA. Una sola pulsación de Espacio registra `jump` y
## `glide` a la vez, así que consumir una tiene que invalidar a la otra o los dos
## estados se pelean por la misma pulsación: doble salto y planeo se disparaban
## juntos y el jugador gastaba el salto aéreo sin querer.
##
## Sprint queda fuera a propósito: se consulta con is_held(), no se consume, así
## que mantener Shift tras un dash sigue corriendo.
const EXCLUSIVAS := {
	JUMP: [GLIDE],
	GLIDE: [JUMP],
	DASH: [DODGE],
	DODGE: [DASH],
}
