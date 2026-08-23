class_name PoiseComponent
extends Node
## Postura. Es lo que decide si un golpe interrumpe o rebota, y es la diferencia
## entre un combate que se siente como un puñetazo y uno que se siente como pegarle
## a un saco que no se entera.
##
## Se agota golpeando y se recupera sola tras un respiro. Al llegar a cero:
## GUARD BREAK, una ventana larga y vulnerable. Es el premio por presionar.

signal quebrada()
signal restaurada()

@export var maxima: float = 40.0
## Cuánto tarda en empezar a recuperarse tras el último golpe.
@export_range(0.0, 5.0, 0.05) var retardo_regen: float = 1.1
@export_range(0.0, 200.0, 1.0) var regen: float = 25.0
## Duración del GuardBreak. Larga a propósito: tiene que dar tiempo a un combo.
@export_range(0.1, 8.0, 0.1) var duracion_quiebre: float = 2.2

var actual: float = 0.0
var rota: bool = false

var _retardo: float = 0.0
var _quiebre: float = 0.0


func _ready() -> void:
	actual = maxima


func _physics_process(delta: float) -> void:
	if rota:
		_quiebre -= delta
		if _quiebre <= 0.0:
			rota = false
			actual = maxima
			restaurada.emit()
		return

	if _retardo > 0.0:
		_retardo -= delta
		return
	if actual < maxima:
		actual = minf(maxima, actual + regen * delta)


## Devuelve true si este golpe ha quebrado la postura.
func aplicar(cantidad: float) -> bool:
	if rota or cantidad <= 0.0:
		return false
	actual = maxf(0.0, actual - cantidad)
	_retardo = retardo_regen
	if actual <= 0.0:
		rota = true
		_quiebre = duracion_quiebre
		quebrada.emit()
		return true
	return false


func fraccion() -> float:
	return actual / maxf(maxima, 0.001)
