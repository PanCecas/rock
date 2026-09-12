class_name StaminaComponent
extends Node
## Barra única que gobierna escalar, planear, correr, dashear y aguantar sacudidas.
## Los ataques NO gastan stamina: esto no es un souls.
##
## Es el balanceador maestro del juego. Cada upgrade será +stamina o +eficiencia de
## un verbo, nunca +daño. Ver docs/03_ARQUITECTURA_MECANICAS.md §8.

signal agotada()
signal recuperada()

var actual: float = 100.0
var maxima: float = 100.0

var _retardo: float = 0.0
var _agotada: bool = false
var _tuning: PlayerTuning


func configurar(tuning: PlayerTuning) -> void:
	_tuning = tuning
	maxima = tuning.stamina_max
	actual = minf(actual, maxima) if actual > 0.0 else maxima


## Solo corre el reloj del retardo. Quién regenera y a qué ritmo lo decide el
## estado activo llamando a regenerar(): colgado de un borde no se recupera igual
## que de pie en el suelo.
func _physics_process(delta: float) -> void:
	if _retardo > 0.0:
		_retardo -= delta


## Gasto continuo, en unidades por segundo. Devuelve false si no queda.
func drenar(por_segundo: float, delta: float) -> bool:
	return gastar(por_segundo * delta)


## Gasto puntual (un dash, un salto de escalada). Devuelve false si no alcanza.
func gastar(cantidad: float) -> bool:
	if cantidad <= 0.0:
		return true
	if actual <= 0.0:
		return false
	actual = maxf(0.0, actual - cantidad)
	_retardo = _tuning.stamina_retardo_regen
	EventBus.stamina_changed.emit(actual, maxima)
	if actual <= 0.0 and not _agotada:
		_agotada = true
		agotada.emit()
	return actual > 0.0


## ¿Alcanza para un gasto puntual? No lo gasta.
func alcanza(cantidad: float) -> bool:
	return actual >= cantidad


func regenerar(por_segundo: float, delta: float) -> void:
	if _retardo > 0.0:
		return
	if actual >= maxima:
		return
	actual = minf(maxima, actual + por_segundo * delta)
	EventBus.stamina_changed.emit(actual, maxima)
	if _agotada and actual > maxima * 0.15:
		_agotada = false
		recuperada.emit()


## Regeneración instantánea al pisar suelo seguro.
func llenar() -> void:
	if is_equal_approx(actual, maxima):
		return
	actual = maxima
	_retardo = 0.0
	_agotada = false
	EventBus.stamina_changed.emit(actual, maxima)


func vacia() -> bool:
	return actual <= 0.0


func fraccion() -> float:
	return actual / maxf(maxima, 0.001)
