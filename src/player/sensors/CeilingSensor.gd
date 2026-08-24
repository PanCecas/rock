class_name CeilingSensor
extends Node
## ¿Hay techo justo encima? Decide si el jugador PUEDE levantarse.
##
## Es lo que convierte un túnel bajo en un obstáculo de verdad: agacharse deja de
## ser un botón que pulsas y se convierte en un estado en el que te quedas
## atrapado hasta salir. Sin esto, soltar el botón dentro del túnel devolvería la
## cápsula a su altura completa y el jugador atravesaría la geometría o se
## quedaría clavado.
##
## Usa un shapecast y no un rayo: un rayo central deja pasar al jugador por debajo
## del canto de una viga y luego lo empotra al estirarse.

## Margen extra sobre la altura completa. Un pelo de holgura evita levantarse
## justo debajo de un techo y quedarse rozando.
@export_range(0.0, 0.5, 0.01) var margen: float = 0.08
@export_range(0.05, 1.0, 0.05) var radio: float = 0.3

var bloqueado: bool = false
var distancia_libre: float = INF

var _p: PlayerController


func _ready() -> void:
	_p = get_parent() as PlayerController


## Sondea SOLO el hueco que falta: desde la coronilla actual hasta donde estaría
## la coronilla de pie.
##
## Ese "solo" es todo el arreglo. La sonda barría desde los pies y con el alto
## completo, asi que su cabeza llegaba 0.68 m POR ENCIMA de la del personaje: casi
## cualquier saliente, rampa o viga a metro y medio contaba como techo, el suelo
## forzaba agachado y la capsula se partia por la mitad de golpe. Eso era el
## "cambio brusco de altura al acercarse a una pared inclinada".
##
## `altura_actual` y `altura_necesaria` van en METROS de altura de capsula.
func sondear(altura_actual: float, altura_necesaria: float) -> void:
	bloqueado = false
	distancia_libre = INF
	if _p == null:
		return

	var hueco := altura_necesaria - altura_actual + margen
	if hueco <= 0.0:
		return

	var sc := _p.superficie
	var espacio := _p.get_world_3d().direct_space_state

	var forma := SphereShape3D.new()
	forma.radius = radio

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = forma
	params.collision_mask = Layers.SUELO_JUGADOR
	params.exclude = [_p.get_rid()]
	params.motion = sc.up * hueco
	# Arranca en el centro de la semiesfera superior de la capsula ACTUAL: asi el
	# barrido cubre exactamente el volumen nuevo y ni un centimetro mas.
	var desde: float = maxf(altura_actual - radio, radio)
	params.transform = Transform3D(Basis.IDENTITY, _p.global_position + sc.up * desde)

	var r := espacio.cast_motion(params)
	# cast_motion devuelve [inicio_seguro, fin_inseguro] en fracción del motion.
	if r.size() == 2 and r[0] < 1.0:
		bloqueado = true
		distancia_libre = float(r[0]) * hueco


func debug_line() -> String:
	if not bloqueado:
		return "libre"
	return "TECHO  %.2f m" % distancia_libre
