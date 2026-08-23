class_name WaterSensor
extends Node
## ¿Estoy en el agua, y a qué profundidad?
##
## Consulta las `ZonaAgua` por proximidad en vez de por señales de Area3D: las
## señales llegan con un frame de retraso y la entrada al agua es justo el momento
## en que ese frame se nota —el clavado se dispara tarde y se ve mal—.

## Profundidad a partir de la cual se considera que el jugador está sumergido y
## deja de nadar en superficie.
@export_range(0.1, 3.0, 0.05) var umbral_sumergido: float = 1.15

var en_agua: bool = false
var zona: ZonaAgua = null
## Profundidad del centro del jugador. Negativa = por encima de la superficie.
var profundidad: float = -INF
var nivel: float = 0.0

var _p: PlayerController


func _ready() -> void:
	_p = get_parent() as PlayerController


func sondear() -> void:
	en_agua = false
	zona = null
	profundidad = -INF
	if _p == null:
		return

	var centro := _p.global_position + Vector3.UP * 0.9
	for n in _p.get_tree().get_nodes_in_group(&"agua"):
		var z := n as ZonaAgua
		if z == null or not is_instance_valid(z):
			continue
		var local := z.to_local(centro)
		var mitad := z.tamano * 0.5
		if absf(local.x) > mitad.x or absf(local.z) > mitad.z:
			continue
		var prof := z.profundidad(centro)
		if prof < 0.0 or prof > z.tamano.y:
			continue
		en_agua = true
		zona = z
		profundidad = prof
		nivel = z.superficie()
		return


## Sumergido de verdad: la cabeza está por debajo de la superficie.
func sumergido() -> bool:
	return en_agua and profundidad > umbral_sumergido


func debug_line() -> String:
	if not en_agua:
		return "—"
	return "%s  prof %.2f m" % ["BUCEO" if sumergido() else "superficie", profundidad]
