class_name Hurtbox
extends Area3D
## Superficie que recibe golpes. No decide nada: reenvía el Golpe a su dueño, que
## es quien sabe si está parrieando, bloqueando o simplemente comiéndoselo.
##
## Separar "dónde me pueden dar" de "qué hago cuando me dan" es lo que permite que
## el jugador y los Guardianes compartan todo el pipeline de daño.

signal golpe_recibido(golpe: Golpe)

## Bando. Lo leen la Hitbox (para no golpear aliados) y el TargetingSystem (para
## no proponerte a ti mismo como objetivo). 0 = jugador, 1 = enemigos.
@export var equipo: int = 0
## Nodo que resuelve el golpe. Debe implementar `recibir_golpe(golpe) -> int`.
@export var dueno_path: NodePath = ^".."

var dueno: Node = null


func _ready() -> void:
	collision_layer = Layers.HURTBOX
	collision_mask = 0
	monitorable = true
	monitoring = false  # la hitbox es quien busca; la hurtbox solo espera
	dueno = get_node_or_null(dueno_path)
	if dueno == null:
		push_warning("Hurtbox sin dueño en %s" % dueno_path)


## Llamado por la Hitbox. Devuelve el Golpe.Resultado.
func recibir(golpe: Golpe) -> int:
	if dueno != null and dueno.has_method("recibir_golpe"):
		golpe.resultado = dueno.recibir_golpe(golpe)
	golpe_recibido.emit(golpe)
	return golpe.resultado
