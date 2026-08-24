class_name SurfaceContext
extends RefCounted
## El corazón del proyecto. Define qué es "abajo" y qué es "el mundo" ahora mismo.
##
## En un plataformero normal `abajo` es Vector3.DOWN y el suelo está quieto. Aquí
## el jugador va a estar de pie sobre el hombro de un coloso que camina, gira y se
## sacude. Si esto se parchea en la Fase 4 hay que reescribir el controlador entero,
## así que existe desde el primer día aunque de momento `frame` sea casi siempre null.
##
## Ver docs/03_ARQUITECTURA_MECANICAS.md §1.
##
## REGLA: el jugador NUNCA se hace hijo del coloso en el árbol de escena. Eso rompe
## la física y la cámara. La reconciliación es por delta de transform.

## El nodo cuyo transform define el mundo local. null = mundo estático.
var frame: Node3D = null
## Dirección "arriba" en espacio de mundo.
var up: Vector3 = Vector3.UP
## Gravedad en espacio de mundo.
var gravedad: Vector3 = Vector3.DOWN

var _xform_anterior: Transform3D = Transform3D.IDENTITY
var _frame_valido: bool = false


## Cambia el marco de referencia. Devuelve true si de verdad cambió.
func set_frame(nuevo: Node3D) -> bool:
	if nuevo == frame:
		return false
	frame = nuevo
	_frame_valido = frame != null and is_instance_valid(frame)
	_xform_anterior = frame.global_transform if _frame_valido else Transform3D.IDENTITY
	EventBus.surface_frame_changed.emit(frame)
	return true


## Delta de transform del marco desde el tick anterior. Identidad si es estático.
## Se llama UNA vez por physics frame, antes de mover al jugador.
func consumir_delta() -> Transform3D:
	if not _frame_valido:
		return Transform3D.IDENTITY
	if not is_instance_valid(frame):
		set_frame(null)
		return Transform3D.IDENTITY
	var actual := frame.global_transform
	var delta := actual * _xform_anterior.affine_inverse()
	_xform_anterior = actual
	return delta


## Arrastra al cuerpo con el marco: traslación y rotación heredadas.
## La velocidad también se rota, o al girar el coloso el jugador saldría disparado
## en la dirección antigua.
func arrastrar(cuerpo: CharacterBody3D) -> void:
	if not _frame_valido:
		return
	var delta := consumir_delta()
	if delta.is_equal_approx(Transform3D.IDENTITY):
		return
	cuerpo.global_position = delta * cuerpo.global_position
	cuerpo.velocity = delta.basis * cuerpo.velocity
	up = (delta.basis * up).normalized()
	gravedad = delta.basis * gravedad


## Convierte el input de cámara a dirección de movimiento en el plano del marco.
## Es lo que hace que "adelante" siga significando lo mismo mientras el coloso gira.
func direccion_movimiento(entrada: Vector2, camara: Camera3D) -> Vector3:
	if entrada.is_zero_approx():
		return Vector3.ZERO
	if camara == null:
		return Vector3(entrada.x, 0.0, entrada.y)
	var adelante := -camara.global_basis.z
	var derecha := camara.global_basis.x
	# Proyectar sobre el plano perpendicular a `up`, no sobre el plano XZ del mundo.
	adelante = plano(adelante)
	derecha = plano(derecha)
	if adelante.is_zero_approx() or derecha.is_zero_approx():
		return Vector3.ZERO
	return (adelante.normalized() * -entrada.y + derecha.normalized() * entrada.x).limit_length(1.0)


## Componente de un vector en el plano del suelo actual.
func plano(v: Vector3) -> Vector3:
	return v - up * v.dot(up)


## Componente vertical (con signo) respecto al arriba actual.
func vertical(v: Vector3) -> float:
	return v.dot(up)


## Reemplaza la componente vertical de un vector conservando la horizontal.
func con_vertical(v: Vector3, valor: float) -> Vector3:
	return plano(v) + up * valor


func gravedad_actual(magnitud: float) -> Vector3:
	return gravedad.normalized() * absf(magnitud)


func es_estatico() -> bool:
	return not _frame_valido


func debug_line() -> String:
	return "estático" if es_estatico() else "frame: %s" % frame.name
