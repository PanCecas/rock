class_name WallSensor
extends Node
## Detecta paredes a los lados y al frente: wall-run, wall-slide, wall-jump y
## superficies escalables a mano.

@export_range(0.1, 3.0, 0.05) var altura: float = 1.05
## SONDA BAJA, a la altura de las rodillas. Existe por pura geometria: apoyado
## contra una pendiente de 60 grados, el pecho del personaje YA ESTA POR ENCIMA
## de la superficie —la pared se aleja 0.6 m por cada metro que subes—, asi que un
## solo rayo a la altura del pecho no puede ver una rampa por mucho que se amplie
## la horquilla de angulos. Abajo si la ve.
@export_range(0.1, 3.0, 0.05) var altura_baja: float = 0.45
@export_range(0.1, 3.0, 0.05) var alcance: float = 0.6

## LÍMITE DE ÁNGULO DE ESCALADA. Una superficie cuenta como pared —y por tanto es
## escalable, corrible y rebotable— cuando el ángulo entre su normal y el "arriba"
## del marco cae en esta horquilla. 0° sería suelo plano; 90°, un muro vertical.
##
## El mínimo estaba de hecho en 65° (la tolerancia era ±25° alrededor de la
## vertical) y por eso una rampa de 60° se rechazaba: el sistema la leía como
## "suelo inclinado" en vez de como "muro". Bajarlo a 60 es lo que abre las
## rampas empinadas a la escalada.
@export_range(0.0, 90.0, 1.0) var angulo_min: float = 60.0
## El techo no es 90 exacto a propósito: la normal que devuelve un raycast contra
## un muro "vertical" ronda los 90.0 ± unas décimas, y cortar justo ahí hace que
## la pared parpadee. Los grados de más también dejan pasar desplomes suaves.
@export_range(0.0, 180.0, 1.0) var angulo_max: float = 95.0
## Techo SOLO para la sonda baja, y mucho mas estricto. Un muro vertical ya lo ve
## el rayo de pecho; aceptarlo tambien abajo convertiria cada escalon de medio
## metro en una pared que se puede escalar. La sonda baja es para pendientes.
@export_range(0.0, 180.0, 1.0) var angulo_max_bajo: float = 75.0

## Medio grado de margen para que la horquilla sea inclusiva DE VERDAD. La normal
## que devuelve un raycast contra una cara construida a 60.0 grados exactos vuelve
## como 59.997, y cortar en el numero redondo dejaria fuera justo el caso limite
## que el sistema promete aceptar.
const HOLGURA := 0.5

var hay_pared: bool = false
## -1 izquierda, 1 derecha, 0 al frente.
var lado: int = 0
var normal: Vector3 = Vector3.ZERO
var punto: Vector3 = Vector3.ZERO
var colisionador: Node3D = null
var escalable: bool = false
## Ángulo real de la superficie tocada, en grados. Lo usa la escalada para
## inclinar el cuerpo: una rampa de 60° no se trepa como un muro de 90°.
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
	escalable = false
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

	# Pecho primero y rodillas despues, para cada direccion: en un muro vertical
	# los dos ven lo mismo y gana el de arriba, asi que el wall-run y el wall-jump
	# de siempre se comportan exactamente igual que antes.
	var sondas := [
		{"y": altura, "techo": angulo_max},
		{"y": altura_baja, "techo": angulo_max_bajo},
	]

	for c in candidatos:
		var dir: Vector3 = c["dir"]
		for sonda in sondas:
			var origen: Vector3 = _p.global_position + sc.up * float(sonda["y"])
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
			if grados < angulo_min - HOLGURA or grados > float(sonda["techo"]) + HOLGURA:
				continue
			hay_pared = true
			angulo = grados
			lado = int(c["lado"])
			normal = n
			ultima_normal = n
			punto = r.position
			colisionador = col
			escalable = _es_escalable(col)
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


func _es_escalable(col: Node3D) -> bool:
	if col is CollisionObject3D:
		return (col as CollisionObject3D).get_collision_layer_value(4)  # CLIMBABLE
	return false


func debug_line() -> String:
	if not hay_pared:
		return "—"
	var donde := "frente" if lado == 0 else ("dcha" if lado > 0 else "izda")
	return "%s %.0f°%s" % [donde, angulo, "  escalable" if escalable else ""]
