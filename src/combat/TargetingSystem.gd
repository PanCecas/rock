class_name TargetingSystem
extends Node
## Soft-lock: la cámara SUGIERE, no encadena.
##
## Un hard-lock convierte el combate en un carrusel y se pelea con la movilidad,
## que es el pilar del juego. Aquí el objetivo solo sirve para dos cosas: encarar
## los ataques y corregir el dash. La cámara sigue siendo tuya.
##
## En la Fase 4, contra un coloso el objetivo será un WeakPoint, no el bicho entero.

@export var alcance: float = 14.0
## Semiángulo del cono de búsqueda desde la dirección de la cámara.
@export_range(10.0, 180.0, 1.0) var cono_grados: float = 80.0
## Peso relativo del ángulo frente a la distancia al puntuar candidatos.
@export_range(0.0, 1.0, 0.05) var peso_angulo: float = 0.65
@export var equipo: int = 0
## Altura desde la que se apunta, sobre el origen del jugador.
@export_range(0.0, 3.0, 0.05) var altura_ojos: float = 1.0
## Altura del punto al que se apunta, sobre el origen del enemigo.
@export_range(0.0, 4.0, 0.05) var altura_objetivo: float = 0.9

## Objetivo bloqueado a mano con `lock_on`. Null = solo hay sugerencia.
var fijado: Node3D = null
var sugerido: Node3D = null

var _dueno: Node3D


func _ready() -> void:
	_dueno = get_parent() as Node3D


## Recalcula la sugerencia. Se llama una vez por frame desde el controlador.
func actualizar(direccion_referencia: Vector3) -> void:
	if fijado != null and not _valido(fijado):
		fijado = null
	sugerido = _buscar(direccion_referencia)


## Alterna el fijado manual sobre lo que haya sugerido ahora mismo.
func alternar_fijado() -> void:
	fijado = null if fijado != null else sugerido


## El objetivo efectivo: el fijado si lo hay, si no la sugerencia.
func objetivo() -> Node3D:
	if fijado != null and _valido(fijado):
		return fijado
	return sugerido


## Dirección hacia el objetivo, PLANA. ZERO si no hay ninguno.
##
## Se queda plana a propósito, y no es un descuido: sus tres consumidores
## —`StateAttack`, `StateAirAttack` y `StateParry`— la usan para ENCARAR y para
## `motor.impulso()`. Darles componente vertical lanzaría al jugador hacia arriba
## al pegarle a algo que vuela, que no es apuntar: es despegar.
##
## Para apuntar de verdad en tres dimensiones está `direccion_3d()`.
func direccion_a_objetivo() -> Vector3:
	var o := objetivo()
	if o == null or _dueno == null:
		return Vector3.ZERO
	var d := o.global_position - _dueno.global_position
	d.y = 0.0
	return d.normalized() if not d.is_zero_approx() else Vector3.ZERO


## Dirección hacia el objetivo SIN aplastar la Y: la que hace falta para
## perseguir a algo por el aire.
##
## Sale del pecho y no de los pies, que es de donde salen los golpes. Contra un
## enemigo a 4.5 m de altura y 2 de distancia, medir desde los pies mete casi
## nueve grados de error hacia arriba.
func direccion_3d() -> Vector3:
	var o := objetivo()
	if o == null or _dueno == null:
		return Vector3.ZERO
	var d := _punto_de_mira(o) - (_dueno.global_position + Vector3.UP * altura_ojos)
	return d.normalized() if not d.is_zero_approx() else Vector3.ZERO


## Distancia real al objetivo, en 3D. ZERO si no hay.
func distancia_3d() -> float:
	var o := objetivo()
	if o == null or _dueno == null:
		return 0.0
	return (_punto_de_mira(o) - (_dueno.global_position + Vector3.UP * altura_ojos)).length()


## A dónde se apunta de un cuerpo: a su centro, no a sus pies. El origen de un
## `CharacterBody3D` está en el suelo, así que apuntar a `global_position` es
## apuntarle a los tobillos.
func _punto_de_mira(o: Node3D) -> Vector3:
	return o.global_position + Vector3.UP * altura_objetivo


## Corrige una dirección hacia el objetivo si está dentro de `grados`.
## Es la asistencia que hace que un dash de combate no se vaya por la tangente.
func corregir(direccion: Vector3, grados: float) -> Vector3:
	var hacia := direccion_a_objetivo()
	if hacia.is_zero_approx() or direccion.is_zero_approx():
		return direccion
	if rad_to_deg(direccion.angle_to(hacia)) > grados:
		return direccion
	return hacia


func _buscar(referencia: Vector3) -> Node3D:
	if _dueno == null:
		return null
	var espacio := _dueno.get_world_3d().direct_space_state
	var forma := SphereShape3D.new()
	forma.radius = alcance

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = forma
	params.transform = Transform3D(Basis.IDENTITY, _dueno.global_position + Vector3.UP)
	params.collision_mask = Layers.HURTBOX
	params.collide_with_areas = true
	params.collide_with_bodies = false

	# La referencia llega ya en 3D —es el frente de la camara— y se usa TAL CUAL.
	# Antes se aplastaba a la horizontal aqui mismo, tirando informacion que el
	# llamante ya daba, y eso tenia una consecuencia peor que perder precision:
	# un enemigo justo encima daba vector plano CERO, caia en el `continue` de
	# abajo y era literalmente INSELECCIONABLE. El volador vive ahi.
	var ref := referencia
	if ref.is_zero_approx():
		ref = -_dueno.global_basis.z
	ref = ref.normalized()

	var ojos := _dueno.global_position + Vector3.UP * altura_ojos
	var mejor: Node3D = null
	var mejor_puntos := -INF

	for r in espacio.intersect_shape(params, 16):
		var hb := r.collider as Hurtbox
		if hb == null or hb.equipo == equipo or not _valido(hb.dueno as Node3D):
			continue
		var duenyo := hb.dueno as Node3D
		var hacia := _punto_de_mira(duenyo) - ojos
		var dist := hacia.length()
		if hacia.is_zero_approx():
			continue
		# El cono se mide en 3D contra el frente de la camara. En juego normal
		# —camara horizontal, enemigos a ras de suelo— el angulo sale igual que
		# antes; la diferencia solo aparece cuando miras hacia arriba, que es
		# justo cuando hace falta.
		var angulo := rad_to_deg(ref.angle_to(hacia.normalized()))
		if angulo > cono_grados:
			continue
		# Puntuación 0..1: cuanto más centrado y más cerca, mejor.
		var p_ang := 1.0 - angulo / cono_grados
		var p_dist := 1.0 - clampf(dist / alcance, 0.0, 1.0)
		var puntos := p_ang * peso_angulo + p_dist * (1.0 - peso_angulo)
		if puntos > mejor_puntos:
			mejor_puntos = puntos
			mejor = duenyo

	return mejor


func _valido(n: Node3D) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n.has_method("esta_vivo"):
		return n.esta_vivo()
	return true


func debug_line() -> String:
	var o := objetivo()
	if o == null:
		return "—"
	return "%s%s" % [o.name, "  [FIJADO]" if fijado != null else ""]
