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
## EL CORTE DE ESPADA. Desde el 4.06 este boton es de la ESPADA y de nada mas.
##
## Durante el 4.00 aqui vivia la patada, y a la vez el Espacio tambien la
## lanzaba: el mismo verbo en dos teclas, o sea que moverse por el aire y pegar
## eran lo mismo y no habia forma de hacer uno sin el otro. Se pidio separarlos
## —*«que la patada sea en el espacio, no en el ataque, ya que vamos es a atacar
## con la espada»*— y eso es exactamente lo que este nombre significa ahora.
##
## `attack_heavy` se retiro en el 4.00 con los once verbos que lo usaban: un
## boton que no hace nada es peor que un boton que no existe, porque se prueba y
## no contesta.
const ATTACK_LIGHT := &"attack_light"
const PARRY := &"parry"
const DODGE := &"dodge"

# Armas
const AIM := &"aim"
const THROW_SPEAR := &"throw_spear"
## TIRAR Y LLAMAR LA ESPADA. Un boton, las dos mitades: si la llevas la tiras, si
## esta fuera vuelve. Mismo trato que la lanza, y por el mismo motivo escrito
## alli — no son dos verbos peleandose por una tecla, son las dos mitades del
## mismo, y cual toca SE VE porque el arma esta o no esta en la mano.
const THROW_SWORD := &"throw_sword"
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
	ATTACK_LIGHT, PARRY, DODGE,
	THROW_SPEAR, THROW_SWORD, RECALL_SPEAR, SWAP_WEAPON,
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
