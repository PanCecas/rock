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
## El ANCLAJE: la segunda cuerda. Mismo boton para tirarlo y para recogerlo, igual
## que la lanza y por la misma razon: o lo tienes o no lo tienes, y eso se ve.
const THROW_ANCHOR := &"throw_anchor"

# Sistema
const INTERACT := &"interact"
const LOCK_ON := &"lock_on"
const DEBUG_TOGGLE := &"debug_toggle"
const DEBUG_RESET := &"debug_reset"

## Acciones que el InputBuffer vigila cada physics frame.
const BUFFERED: Array[StringName] = [
	JUMP, DASH, GLIDE, GRAB, ROPE,
	ATTACK_LIGHT, ATTACK_HEAVY, PARRY, DODGE,
	THROW_SPEAR, RECALL_SPEAR, SWAP_WEAPON, THROW_ANCHOR,
	INTERACT, LOCK_ON, CROUCH,
]

## Acciones cuyo estado mantenido consulta el jugador.
##
## ROPE esta en las dos listas, y no es un descuido: se CONSUME para engancharse
## —un pulso— y se CONSULTA mantenida para tensar la resortera —un gesto que dura
## mientras aguantas—. Son las dos mitades del mismo boton, igual que mantener el
## planeo despues de haberlo desplegado.
const HELD: Array[StringName] = [
	MOVE_FORWARD, MOVE_BACK, MOVE_LEFT, MOVE_RIGHT,
	SPRINT, CROUCH, JUMP, GLIDE, AIM, GRAB, PARRY, ROPE,
]

## Acciones que COMPARTEN TECLA. Consumir una invalida a su hermana si vino de la
## misma pulsación, o los dos estados se pelean por ella.
##
## JUMP/GLIDE ya NO está aquí: el planeo se mudó a Ctrl y Mouse 4 precisamente
## porque compartir tecla con el salto resultaba incómodo. Quedan dash y esquiva,
## que siguen en el mismo botón por diseño.
##
## Sprint queda fuera a propósito: se consulta con is_held(), no se consume, así
## que mantener Shift tras un dash sigue corriendo.
const EXCLUSIVAS := {
	DASH: [DODGE],
	DODGE: [DASH],
}
