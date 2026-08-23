class_name StateMachine
extends Node
## FSM jerárquica del jugador.
##
## Estructura esperada en la escena:
##   StateMachine
##     Grounded (PlayerStateGroup)
##       Idle · Move · Slide · Landing
##     Airborne (PlayerStateGroup)
##       Jump · Fall · Glide · WallSlide · WallRun
##     Attached (PlayerStateGroup)
##       LedgeHang · LedgeClimb · Climb
##     Dash (PlayerState suelto: se entra desde suelo y desde aire)

@export var estado_inicial: StringName = &"Fall"

var actual: PlayerState
var anterior: StringName = &""

var _estados: Dictionary = {}
var _grupos: Array[PlayerStateGroup] = []
var _p: PlayerController
var _cambio_pendiente: bool = false


func configurar(p: PlayerController) -> void:
	_p = p
	_registrar(self, null)
	if not _estados.has(estado_inicial):
		push_error("StateMachine: no existe el estado inicial '%s'" % estado_inicial)
		return
	actual = _estados[estado_inicial]
	actual.t = 0.0
	actual.enter()


func _registrar(nodo: Node, grupo: PlayerStateGroup) -> void:
	for hijo in nodo.get_children():
		if hijo is PlayerStateGroup:
			var g := hijo as PlayerStateGroup
			g.configurar(_p, self, null)
			_grupos.append(g)
			_registrar(g, g)
		elif hijo is PlayerState:
			var s := hijo as PlayerState
			s.configurar(_p, self, grupo)
			_estados[s.name] = s


func physics_update(delta: float) -> void:
	if actual == null:
		return
	actual.t += delta
	_cambio_pendiente = false

	# 1) El grupo resuelve las transiciones compartidas.
	if actual.grupo != null:
		actual.grupo.shared_update(delta)

	# 2) Si el grupo no cambió de estado, corre la hoja.
	if not _cambio_pendiente and actual != null:
		actual.physics_update(delta)


## Cambia de estado. `msg` pasa datos sin acoplar los estados entre sí.
##
## `reentrar` permite volver a entrar en el estado en el que ya estamos. Existe
## por las cadenas de combate: encadenar el segundo golpe es entrar OTRA VEZ en
## Attack con otro AttackData, y el guardia contra auto-transiciones se lo comía
## en silencio. Se pide explícitamente para que un bucle accidental siga siendo
## imposible por defecto.
func cambiar(nombre: StringName, msg: Dictionary = {}, reentrar: bool = false) -> void:
	if not _estados.has(nombre):
		push_error("StateMachine: estado desconocido '%s'" % nombre)
		return
	if actual != null and actual.name == nombre and not reentrar:
		return

	var siguiente: PlayerState = _estados[nombre]
	anterior = actual.name if actual != null else &""
	if actual != null:
		actual.exit()
	actual = siguiente
	actual.t = 0.0
	_cambio_pendiente = true
	actual.enter(msg)
	if actual.grupo != null:
		actual.grupo.on_enter_hijo(actual)
	EventBus.player_state_changed.emit(anterior, nombre)


func en_categoria(cat: StringName) -> bool:
	return actual != null and actual.categoria == cat


func nombre_actual() -> StringName:
	return actual.name if actual != null else &"—"


func debug_line() -> String:
	if actual == null:
		return "—"
	var extra := actual.debug_line()
	var cat := str(actual.categoria)
	return "%s%s / %s  %.2fs%s" % [
		cat, "" if cat.is_empty() else " ›", actual.name, actual.t,
		"   " + extra if not extra.is_empty() else ""
	]
