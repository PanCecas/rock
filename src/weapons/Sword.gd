class_name Sword
extends Node3D
## LA ESPADA. El arma de mano, y el unico proyectil que VUELVE.
##
## Mismo patron que `Spear` + `SpearStateMachine`: cuerpo y orquestador aqui, una
## regla por estado alla.
##
##   Wielded -> Swing -> Wielded
##   Wielded -> InFlight -> Returning -> Wielded
##   InFlight | Returning -> Homing -> Returning
##
## **Tres verbos, y cada uno resuelve un hueco distinto del moveset del 4.00:**
##
## 1. **CORTAR** (click izq.) es el ataque que la patada dejo libre al mudarse al
##    Espacio. Se pidio asi —*«que la patada sea en el espacio, no en el ataque,
##    ya que vamos es a atacar con la espada»*— y ademas separa dos cosas que
##    estaban pegadas sin querer: hasta ahora la patada era a la vez el salto
##    aereo y el unico ataque, o sea que moverse por el aire y pegar eran el
##    mismo boton y no habia forma de hacer uno sin el otro.
## 2. **LANZARLA** (click der.) la saca de la mano. Mientras esta fuera no hay
##    corte, y ese es el precio: se ve, se entiende y no hay que explicarlo.
## 3. **PATEARLA EN VUELO** la manda **al enemigo mas cercano**, que es la frase
##    literal del encargo. El resto del bucle ya existia: la patada es la que
##    tiene momentum, la espada es algo que sobrevive al golpe, y de ahi sale el
##    pogo.
##
## **Y SIEMPRE VUELVE.** Ahi esta la diferencia con la lanza, y es de trabajo, no
## de numeros: la lanza SE QUEDA donde la clavas —plataforma, ancla, punto fijo—
## y la espada es un bumeran. Una se tira para dejarla puesta; la otra se tira
## para recogerla. Sin esa separacion serian la misma arma con dos mallas, y la
## segunda sobraria.
##
## Efecto secundario de que vuelva: **cada tirada da DOS pasadas pateables**, la
## de ida y la de vuelta, sin que el jugador tenga que ir a recoger nada al suelo.

signal lanzada(direccion: Vector3)
signal recuperada
signal corte
signal estado_cambiado(nombre: StringName)

## Grupo por el que busca enemigos. En un solo sitio, igual que `Ancla.GRUPO`.
const GRUPO_ENEMIGOS := &"enemigos"

@export var tuning: SwordTuning
## EL CORTE. Sus tiempos en frames son los que gobiernan el gesto: la duracion no
## esta escrita en codigo (regla dura #1).
@export var ataque: AttackData
## LA HOJA GIRANDO. Otro `.tres` y no el mismo, porque son dos cosas distintas:
## un corte tiene un arco delante de ti y una espada que gira sobre si misma
## corta todo lo que roza. Compartir el `.tres` obligaria a elegir un arco que
## miente en uno de los dos casos.
@export var ataque_vuelo: AttackData
@export var palette: Palette
## Quien la empuña. Decide el equipo de la hitbox y donde esta la mano.
@export var dueno_path: NodePath

## Superficies contra las que da la vuelta. **No se clava en ninguna**: eso es de
## la lanza. Chocar solo adelanta el retorno.
@export_flags_3d_physics var capas_rebote: int = Layers.WORLD | Layers.COLOSSUS_SURFACE

@onready var fsm: SwordStateMachine = $FSM
@onready var hitbox: Hitbox = $Hitbox
## LA CARA QUE SE DEJA PATEAR. Apagada salvo mientras esta fuera de la mano.
##
## Del bando ENEMIGO (`equipo = 1`) por el mismo truco que la lanza: con 1 la
## alcanza la patada del jugador y la ignoran los enemigos. Lo que impide que se
## golpee a si misma no es el equipo —ahi se contradice— sino el filtro de DUEÑO
## de `Hitbox`, que existe justo porque la lanza rompio esa suposicion.
@onready var hurtbox: Hurtbox = get_node_or_null(^"Hurtbox")
@onready var visual: Node3D = $Visual

var dueno: Node3D = null
## VELOCIDAD DE VUELO, en mundo. La escriben los estados y la reescribe la patada.
var vuelo: Vector3 = Vector3.ZERO
## Direccion de vuelo, normalizada. Es el "adelante" que usa la hitbox.
var direccion: Vector3 = Vector3.FORWARD
## A QUIEN PERSIGUE. Lo pone la patada y lo consume `Homing`.
var objetivo: Enemigo = null

var _mat_hoja: StandardMaterial3D
var _mat_guarda: StandardMaterial3D


func _ready() -> void:
	if tuning == null:
		tuning = SwordTuning.new()
	if palette == null:
		palette = GameState.palette
	dueno = get_node_or_null(dueno_path) as Node3D
	_preparar_visual()
	if hitbox != null:
		hitbox.dueno = self
		hitbox.equipo = 0
	armar_hurtbox(false)
	fsm.configurar(self)


func _physics_process(delta: float) -> void:
	if HitstopManager.global_activo():
		return
	fsm.physics_update(delta)


## Enciende o apaga la cara pateable. Lo piden los estados de vuelo al entrar y
## al salir: en la mano la espada no es un blanco, y una hurtbox olvidada
## encendida convertiria el arma empuñada en algo a lo que patear a distancia
## cero — que es exactamente el bug que tuvo la lanza en el 4.02.
##
## **Se apaga por CAPA, no por `monitorable`.** `Hitbox` no monitoriza: pregunta
## una forma al espacio, y `intersect_shape` encuentra cualquier area por su capa
## sin mirar `monitorable` en absoluto.
func armar_hurtbox(armada: bool) -> void:
	if hurtbox == null:
		return
	hurtbox.collision_layer = Layers.HURTBOX if armada else 0
	hurtbox.monitorable = armada
	hurtbox.dueno = self


# --- LOS TRES VERBOS ----------------------------------------------------------

## ¿PUEDE CORTAR AHORA MISMO?
##
## Existe separada de `cortar()` para que quien lee el boton pueda preguntar
## ANTES de consumir la pulsacion. Es el patron de `intentar_cuerda()`: si la
## accion no va a ocurrir, la pulsacion se queda viva en el buffer y sale sola en
## cuanto se pueda. Sin esto, pulsar durante los 10 frames de recuperacion se
## tragaba el corte siguiente — medido: 2 cortes por segundo donde el `.tres`
## permite 3.8.
func puede_cortar() -> bool:
	return ataque != null and fsm.nombre_actual() == &"Wielded"


## CORTAR. Devuelve false si la espada no esta en la mano, que es el unico motivo
## por el que este boton puede no contestar — y se ve, porque el arma no esta.
##
## `hacia` viene de la CAMARA y no del cuerpo, igual que el tiro de la lanza: en
## tercera persona uno corta hacia donde mira. **Y el jugador NO se gira**: un
## corte es un tajo, no una embestida, asi que no pelea con el estado de
## movimiento que lo lleve ni con el unico escritor de la orientacion visual
## (regla dura #17).
func cortar(hacia: Vector3) -> bool:
	if not puede_cortar():
		return false
	var d := hacia
	if d.is_zero_approx():
		d = -global_basis.z
	fsm.cambiar(&"Swing", {"direccion": d.normalized()})
	return true


## ¿SE PUEDE TIRAR AHORA MISMO? Misma pareja que `puede_cortar()`, y existe por
## el mismo motivo: para que quien lee el boton pregunte ANTES de consumir.
func puede_lanzar() -> bool:
	return fsm.nombre_actual() == &"Wielded"


## LANZARLA. Solo desde la mano: no hay dos espadas.
func lanzar(desde: Vector3, hacia: Vector3) -> bool:
	if not puede_lanzar():
		return false
	global_position = desde
	# Un teletransporte no se interpola: sin esto la espada se dibuja barriendo
	# desde donde estuviera hasta la mano en un solo frame (regla dura #21bis).
	reset_physics_interpolation()
	fsm.cambiar(&"InFlight", {"direccion": hacia})
	return true


## LLAMARLA DE VUELTA antes de tiempo. Es la otra mitad del mismo boton, igual
## que en la lanza: si la llevas la tiras, si no, vuelve.
func recuperar() -> bool:
	if not esta_fuera():
		return false
	fsm.cambiar(&"Returning")
	return true


## LA PATADA LA MANDA AL ENEMIGO MAS CERCANO.
##
## Es el verbo que se pidio con esas palabras, y lo que lo separa de patear la
## lanza —que solo REDIRIGE hacia donde pateaste— es que aqui la espada ELIGE: tu
## decides cuando, ella decide a quien. Con eso el gesto se puede hacer mirando a
## cualquier sitio, que es justo lo que hace falta cuando lo estas encadenando en
## el aire y la camara la tienes puesta en el siguiente ancla.
##
## **Sin nadie a quien ir no se queda callada**: se comporta como la lanza y sale
## disparada hacia donde pateaste. Un boton que a veces no hace nada es un boton
## que se deja de pulsar.
##
## Devuelve IMPACTO porque el golpe SI ha ocurrido y el jugador tiene que rebotar.
## Lo que NO da es recarga del moveset: eso lo decide `StateKick`, y la razon esta
## escrita alli — tocar tus propias cosas no es tocar el mundo.
func recibir_golpe(golpe: Golpe) -> int:
	if fsm == null or not esta_fuera():
		return Golpe.Resultado.INMUNE

	var presa := enemigo_mas_cercano()
	if presa != null:
		fsm.cambiar(&"Homing", {"objetivo": presa}, true)
	else:
		var hacia := golpe.direccion
		if hacia.is_zero_approx():
			hacia = direccion
		fsm.cambiar(&"InFlight", {
			"direccion": hacia.normalized(),
			"velocidad": tuning.patada_empuje,
		}, true)

	CombatFX.impacto(get_parent(), global_position, color_de(&"oro_palido"), 1.8)
	EventBus.camara_shake.emit(0.3, 0.12)
	return Golpe.Resultado.IMPACTO


# --- Servicios para los estados -----------------------------------------------

## ¿Esta en la mano, lista para cortar o para tirar?
func en_mano() -> bool:
	var n := fsm.nombre_actual()
	return n == &"Wielded" or n == &"Swing"


## ¿Esta AHI FUERA? Es la pregunta que decide si el boton tira o recupera, y si
## la patada tiene algo a lo que llegar.
func esta_fuera() -> bool:
	var n := fsm.nombre_actual()
	return n == &"InFlight" or n == &"Returning" or n == &"Homing"


## EL ENEMIGO MAS CERCANO A LA ESPADA, vivo y dentro de rango.
##
## **Se mide desde el arma y no desde el jugador**, y a efectos practicos da igual:
## para patearla hay que alcanzarla, asi que en el frame de la patada los dos
## estan a menos de tres metros. Desde el arma es ademas lo que se puede explicar
## mirando la pantalla — la curva sale de donde esta la espada.
##
## Por GRUPO y no por consulta de fisica, igual que `Ancla.mejor()`: con una
## docena de enemigos son doce restas, y una consulta de forma costaria una capa
## de colision y un frame de latencia para contestar lo mismo.
func enemigo_mas_cercano() -> Enemigo:
	var arbol := get_tree()
	if arbol == null:
		return null
	var mejor: Enemigo = null
	var mejor_d2: float = tuning.busqueda_rango * tuning.busqueda_rango
	for nodo in arbol.get_nodes_in_group(GRUPO_ENEMIGOS):
		var e := nodo as Enemigo
		if e == null or not is_instance_valid(e) or not e.is_inside_tree():
			continue
		if not e.esta_vivo():
			continue
		var d2 := global_position.distance_squared_to(e.global_position)
		if d2 > mejor_d2:
			continue
		mejor_d2 = d2
		mejor = e
	return mejor


## Donde queda la espada cuando la llevas encima. Al costado CONTRARIO que la
## lanza: las dos en la misma mano se dibujaban una dentro de otra.
func punto_de_mano() -> Vector3:
	if dueno == null or not is_instance_valid(dueno):
		return global_position
	return dueno.global_position + Vector3.UP * 0.95 - dueno.global_basis.x * 0.45


## La mano TAL Y COMO SE DIBUJA este frame. Misma razon que en `Spear`: con la
## interpolacion de fisica encendida, `global_position` va escalonada a 60 Hz y
## perseguirla deja al arma siguiendo algo distinto de lo que se ve.
func mano_dibujada() -> Vector3:
	if dueno == null or not is_instance_valid(dueno):
		return global_position
	var tr := dueno.get_global_transform_interpolated()
	return tr.origin + Vector3.UP * 0.95 - tr.basis.x * 0.45


## Orienta la hoja a lo largo de una direccion.
func apuntar_a(dir: Vector3) -> void:
	if dir.is_zero_approx() or visual == null:
		return
	var arriba := Vector3.UP
	if absf(dir.normalized().dot(arriba)) > 0.99:
		arriba = Vector3.FORWARD
	visual.global_basis = Basis.looking_at(dir.normalized(), arriba)


## EL GIRO DE VUELO. Solo presentacion, y hace falta: sin el, una espada que
## viaja recta y sin animacion se lee como un objeto colgado del aire. Es la
## misma queja que se hizo de la lanza suspendida, evitada antes de que pase.
func girar_en_vuelo(delta: float) -> void:
	if visual == null or tuning.giro_vuelo <= 0.0:
		return
	visual.rotate_object_local(Vector3.RIGHT, TAU * tuning.giro_vuelo * delta)


func color_de(nombre: StringName) -> Color:
	if palette == null:
		return Color.WHITE
	var v: Variant = palette.get(nombre)
	return v if v is Color else Color.WHITE


func _preparar_visual() -> void:
	var hoja := get_node_or_null("Visual/Hoja") as MeshInstance3D
	if hoja != null:
		var caja := BoxMesh.new()
		caja.size = Vector3(tuning.grosor, tuning.ancho, tuning.largo)
		hoja.mesh = caja
		hoja.position = Vector3(0, 0, -tuning.largo * 0.2)
		_mat_hoja = StandardMaterial3D.new()
		_mat_hoja.albedo_color = color_de(&"caliza_sol")
		_mat_hoja.metallic = 0.5
		_mat_hoja.roughness = 0.28
		hoja.material_override = _mat_hoja

	var guarda := get_node_or_null("Visual/Guarda") as MeshInstance3D
	if guarda != null:
		var g := BoxMesh.new()
		g.size = Vector3(tuning.grosor * 1.4, tuning.ancho * 3.2, tuning.ancho * 0.9)
		guarda.mesh = g
		guarda.position = Vector3(0, 0, tuning.largo * 0.32)
		_mat_guarda = StandardMaterial3D.new()
		_mat_guarda.albedo_color = color_de(&"oro_palido")
		_mat_guarda.metallic = 0.7
		_mat_guarda.roughness = 0.35
		guarda.material_override = _mat_guarda


func debug_line() -> String:
	var extra := ""
	if objetivo != null and is_instance_valid(objetivo):
		extra = "  -> %s" % objetivo.name
	return "%s%s" % [fsm.nombre_actual(), extra]
