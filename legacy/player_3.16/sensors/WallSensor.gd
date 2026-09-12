class_name WallSensor
extends Node
## Detecta paredes a los lados y al frente: wall-run, wall-slide, wall-jump y
## superficies escalables a mano.

@export_range(0.1, 3.0, 0.05) var altura: float = 1.05
## SONDA ALTA, a la altura de los hombros. Existe por la misma razon geometrica
## que la de pecho, pero al reves: contra un DESPLOME la pared se te viene encima,
## asi que a la altura del pecho puede quedar mas lejos que a la de la cabeza. Sin
## esta sonda, los angulos por encima de 90 no se detectan nunca.
@export_range(0.1, 3.0, 0.05) var altura_alta: float = 1.55
## SONDA BAJA, a la altura de las rodillas. Es la unica que puede ver una rampa
## tumbada: contra una pendiente cercana al slope limit, el pecho queda por encima
## de la superficie y su rayo nace dentro del collider.
@export_range(0.1, 3.0, 0.05) var altura_baja: float = 0.45
## Techo de angulo SOLO para la sonda baja. Un muro vertical ya lo ven las otras
## dos; aceptarlo tambien a la altura de las rodillas convertiria cada escalon de
## medio metro en una pared escalable. La sonda baja existe para las pendientes.
@export_range(0.0, 180.0, 1.0) var angulo_max_bajo: float = 80.0
@export_range(0.1, 3.0, 0.05) var alcance: float = 0.6

var hay_pared: bool = false
## -1 izquierda, 1 derecha, 0 al frente.
var lado: int = 0
var normal: Vector3 = Vector3.ZERO
var punto: Vector3 = Vector3.ZERO
var colisionador: Node3D = null
## ¿Es un asidero marcado a mano (capa CLIMBABLE)? Es un coste de stamina, no
## un permiso: la horquilla de angulos ya decide si se puede escalar o no.
var asidero: bool = false
## Ángulo real de la superficie tocada, en grados. Lo usa la escalada para
## inclinar el cuerpo: una rampa de 75° no se trepa como un muro de 90°.
var angulo: float = 0.0

## Memoria de la última pared tocada, para el coyote del wall-jump.
var _t_sin_pared: float = INF
var ultima_normal: Vector3 = Vector3.ZERO

## Pared desde la que se acaba de saltar. Se ignora un instante para poder alternar.
var _pared_bloqueada: Node3D = null
var _bloqueo: float = 0.0

var _p: PlayerController


func _ready() -> void:
	_p = get_parent() as PlayerController


func _physics_process(delta: float) -> void:
	if _bloqueo > 0.0:
		_bloqueo -= delta
		if _bloqueo <= 0.0:
			_pared_bloqueada = null
	if not hay_pared:
		_t_sin_pared += delta


## ¿Había pared hace menos de `ventana` segundos? Es el coyote time del wall-jump:
## rebotar entre dos muros deja de exigir precisión de frame.
func reciente(ventana: float) -> bool:
	return hay_pared or _t_sin_pared <= ventana


## Normal a usar para saltar, incluso si el contacto ya se perdió.
func normal_de_salto() -> Vector3:
	return normal if hay_pared else ultima_normal


func sondear(direccion_avance: Vector3) -> void:
	hay_pared = false
	asidero = false
	lado = 0
	angulo = 0.0
	if _p == null:
		return

	var sc := _p.superficie
	var espacio := _p.get_world_3d().direct_space_state
	var b := _p.global_basis
	var frente := sc.plano(direccion_avance)
	frente = frente.normalized() if not frente.is_zero_approx() else sc.plano(-b.z).normalized()
	var derecha := sc.up.cross(frente).normalized()

	var candidatos := [
		{"dir": frente, "lado": 0},
		{"dir": derecha, "lado": 1},
		{"dir": -derecha, "lado": -1},
	]

	# Pecho primero y hombros despues, para cada direccion. En un muro vertical las
	# dos ven lo mismo y gana la de abajo, asi que el wall-run y el wall-jump de
	# siempre se comportan exactamente igual que antes; la alta solo aporta en los
	# desplomes, donde el pecho se queda corto.
	# Pecho, hombros y rodillas, en ese orden. En un muro vertical las tres ven lo
	# mismo y gana la de pecho, asi que el wall-run y el wall-jump se comportan
	# igual que siempre. Las otras dos solo aportan en los extremos: la alta en los
	# desplomes, la baja en las pendientes tumbadas.
	var sondas := [altura, altura_alta, altura_baja]

	for c in candidatos:
		var dir: Vector3 = c["dir"]
		for sonda in sondas:
			var origen: Vector3 = _p.global_position + sc.up * float(sonda)
			var q := PhysicsRayQueryParameters3D.create(origen, origen + dir * alcance, Layers.SUELO_JUGADOR | Layers.CLIMBABLE)
			q.exclude = [_p.get_rid()]
			var r := espacio.intersect_ray(q)
			if r.is_empty():
				continue
			var col := r.collider as Node3D
			if col == _pared_bloqueada:
				continue
			var n := r.normal as Vector3
			# Ángulo REAL de la superficie: el que separa su normal del "arriba" del
			# marco. Es el mismo cálculo que `Vector3.Angle(Vector3.up, hit.normal)`,
			# solo que contra `sc.up` y no contra el eje Y del mundo, porque sobre un
			# coloso "arriba" no es (0,1,0).
			var grados := rad_to_deg(sc.up.angle_to(n))
			# LA clasificacion, la misma que usa el suelo y la misma que alimenta el
			# `floor_max_angle` del cuerpo. Un sensor con su propio criterio es como
			# se llega a que una rampa sea "pared" para uno y "suelo" para otro.
			if _p.tuning.clasificar(grados) != PlayerTuning.Superficie.ESCALABLE:
				continue
			if is_equal_approx(float(sonda), altura_baja) and grados > angulo_max_bajo:
				continue
			hay_pared = true
			angulo = grados
			lado = int(c["lado"])
			normal = n
			ultima_normal = n
			punto = r.position
			colisionador = col
			asidero = _es_asidero(col)
			_t_sin_pared = 0.0
			return


## Marca la pared actual como recién saltada para poder alternar entre dos muros.
func bloquear_actual() -> void:
	_pared_bloqueada = colisionador
	_bloqueo = _p.tuning.pared_bloqueo


## Dirección de carrera a lo largo de la pared, la más alineada con el avance.
func direccion_carrera(avance: Vector3) -> Vector3:
	var sc := _p.superficie
	var a_lo_largo := sc.up.cross(normal).normalized()
	if a_lo_largo.dot(sc.plano(avance)) < 0.0:
		a_lo_largo = -a_lo_largo
	return a_lo_largo


func _es_asidero(col: Node3D) -> bool:
	if col is CollisionObject3D:
		return (col as CollisionObject3D).get_collision_layer_value(4)  # CLIMBABLE
	return false


func debug_line() -> String:
	if not hay_pared:
		return "—"
	var donde := "frente" if lado == 0 else ("dcha" if lado > 0 else "izda")
	return "%s %.0f°%s" % [donde, angulo, "  asidero" if asidero else ""]
