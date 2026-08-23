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


## `altura_necesaria` es la altura de cápsula a la que se quiere volver.
func sondear(altura_necesaria: float) -> void:
	bloqueado = false
	distancia_libre = INF
	if _p == null:
		return

	var sc := _p.superficie
	var espacio := _p.get_world_3d().direct_space_state

	var forma := SphereShape3D.new()
	forma.radius = radio

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = forma
	params.collision_mask = Layers.SUELO_JUGADOR
	params.exclude = [_p.get_rid()]
	params.motion = sc.up * (altura_necesaria + margen)
	# Desde justo encima de la cápsula agachada hacia arriba.
	params.transform = Transform3D(Basis.IDENTITY, _p.global_position + sc.up * radio)

	var r := espacio.cast_motion(params)
	# cast_motion devuelve [inicio_seguro, fin_inseguro] en fracción del motion.
	if r.size() == 2 and r[0] < 1.0:
		bloqueado = true
		distancia_libre = float(r[0]) * (altura_necesaria + margen)


func debug_line() -> String:
	if not bloqueado:
		return "libre"
	return "TECHO  %.2f m" % distancia_libre
