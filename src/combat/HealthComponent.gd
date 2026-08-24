class_name HealthComponent
extends Node
## Vida. Deliberadamente tonto: no decide reacciones, solo lleva la cuenta.

signal dano_recibido(cantidad: float, restante: float)
signal muerto()

@export var maxima: float = 100.0
@export var invulnerable: bool = false

var actual: float = 0.0
var vivo: bool = true


func _ready() -> void:
	actual = maxima


func aplicar(cantidad: float) -> void:
	if not vivo or invulnerable or cantidad <= 0.0:
		return
	actual = maxf(0.0, actual - cantidad)
	dano_recibido.emit(cantidad, actual)
	if actual <= 0.0:
		vivo = false
		muerto.emit()


func curar(cantidad: float) -> void:
	if not vivo:
		return
	actual = minf(maxima, actual + cantidad)


func fraccion() -> float:
	return actual / maxf(maxima, 0.001)
