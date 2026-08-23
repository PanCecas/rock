class_name WallSensor
extends Node
## Detecta paredes a los lados y al frente: wall-run, wall-slide, wall-jump y
## superficies escalables a mano.

@export_range(0.1, 3.0, 0.05) var altura: float = 1.05
@export_range(0.1, 3.0, 0.05) var alcance: float = 0.6
## Inclinación máxima para que cuente como pared vertical.
@export_range(0.0, 45.0, 1.0) var tolerancia_grados: float = 25.0

var hay_pared: bool = false
## -1 izquierda, 1 derecha, 0 al frente.
var lado: int = 0
var normal: Vector3 = Vector3.ZERO
var punto: Vector3 = Vector3.ZERO
var colisionador: Node3D = null
var escalable: bool = false

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
	if _p == null:
		return

	var sc := _p.superficie
	var espacio := _p.get_world_3d().direct_space_state
	var origen := _p.global_position + sc.up * altura
	var b := _p.global_basis
	var frente := sc.plano(direccion_avance)
	frente = frente.normalized() if not frente.is_zero_approx() else sc.plano(-b.z).normalized()
	var derecha := sc.up.cross(frente).normalized()

	var candidatos := [
		{"dir": frente, "lado": 0},
		{"dir": derecha, "lado": 1},
		{"dir": -derecha, "lado": -1},
	]

	for c in candidatos:
		var dir: Vector3 = c["dir"]
		var q := PhysicsRayQueryParameters3D.create(origen, origen + dir * alcance, Layers.SUELO_JUGADOR | Layers.CLIMBABLE)
		q.exclude = [_p.get_rid()]
		var r := espacio.intersect_ray(q)
		if r.is_empty():
			continue
		var col := r.collider as Node3D
		if col == _pared_bloqueada:
			continue
		var n := r.normal as Vector3
		# Solo cuenta si es una pared razonablemente vertical.
		if absf(rad_to_deg(asin(clampf(n.dot(sc.up), -1.0, 1.0)))) > tolerancia_grados:
			continue
		hay_pared = true
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
	return "%s%s" % [donde, "  escalable" if escalable else ""]
