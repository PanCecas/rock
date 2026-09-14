class_name Volador
extends Enemigo
## VOLADOR: ráfaga de tres, recarga, y se reposiciona en zigzag mientras recarga.
##
## Todo su diseño gira alrededor de una idea: **la recarga es su ventana de
## vulnerabilidad, y tiene que verse desde lejos.** Por eso no recarga quieto ni
## escondido: recarga huyendo en zigzag, que es un movimiento tan raro que el
## jugador aprende a leerlo en dos encuentros. «Está haciendo el zigzag» pasa a
## significar «ahora puedo alcanzarlo».
##
## Un enemigo a distancia que recarga sin avisar es un francotirador: solo enseña
## a buscar cobertura. Este enseña a perseguir.
##
## Técnicamente **no comparte una línea de IA con el guardián terrestre**: la única
## diferencia de física es `vuela = true`, que apaga la gravedad y habilita el eje
## vertical en el `EnemyMotor`. Ese era el criterio de terminado del P0.

@export_group("Ráfaga")
@export var proyectil: PackedScene
## Disparos por ráfaga.
@export_range(1, 8, 1) var disparos: int = 3
## Separación entre disparos de la misma ráfaga. Corta: es una ráfaga, no tres
## ataques seguidos.
@export_range(0.02, 1.0, 0.01) var separacion: float = 0.14
@export_range(1.0, 60.0, 0.5) var velocidad_proyectil: float = 22.0

@export_group("Recarga y reposicionamiento")
@export_range(0.2, 6.0, 0.05) var recarga: float = 1.8
## Cuántos tramos tiene el zigzag. Tres es el mínimo que se lee como zigzag: con
## dos parece que ha cambiado de idea.
@export_range(1, 6, 1) var tramos_zigzag: int = 3
@export_range(1.0, 20.0, 0.5) var distancia_tramo: float = 5.0
## Cuánto se abre cada tramo respecto a la huida en línea recta.
@export_range(0.0, 90.0, 5.0) var apertura_zigzag: float = 55.0
## Altura de vuelo sobre el objetivo. Se mantiene aunque el suelo suba o baje.
@export_range(0.0, 20.0, 0.5) var altura_vuelo: float = 4.5
## Hasta donde busca el suelo bajo el jugador para medir su altura de vuelo.
@export_range(2.0, 120.0, 1.0) var sondeo_suelo: float = 60.0


func _ready() -> void:
	super()
	add_to_group(&"voladores")


func configurar_tipo() -> void:
	salud.maxima = 35.0
	poise.maxima = 18.0
	salud.actual = salud.maxima
	poise.actual = poise.maxima


## Vuela por encima de ti, no a tu altura. Sin esto se pega al suelo y deja de ser
## un enemigo aéreo.
func distancia_minima() -> float:
	return alcance_ataque * 0.75


## Dispara proyectiles: sin linea de vision no tira. Volando, ademas, es el que
## mas facil la tiene —basta con subir— asi que la restriccion le sale barata.
func necesita_linea_de_vision() -> bool:
	return true


func estado_de_ataque() -> StringName:
	return &"Rafaga"


## Punto al que quiere estar: sobre el objetivo, a su altura de vuelo.
func punto_de_vuelo() -> Vector3:
	if not objetivo_valido():
		return global_position
	var p := objetivo.global_position
	# Sobre el SUELO, no sobre el jugador. Anclarlo a la Y del objetivo lo hacia
	# literalmente inalcanzable: saltabas y subia contigo manteniendo el hueco,
	# asi que perseguirlo en vertical era imposible por definicion. Ahora saltar
	# recorta distancia, que es lo unico que hace que valga la pena saltar.
	return Vector3(p.x, _altura_del_suelo(p) + altura_vuelo, p.z)


## Y del suelo bajo un punto. Si no encuentra nada —hueco, borde del mapa— se
## queda con la del propio objetivo: quedarse quieto es mejor que desplomarse.
func _altura_del_suelo(punto: Vector3) -> float:
	var espacio := get_world_3d().direct_space_state
	var desde := punto + Vector3.UP * 2.0
	var q := PhysicsRayQueryParameters3D.create(
		desde, desde + Vector3.DOWN * sondeo_suelo, Layers.WORLD)
	q.exclude = [get_rid()]
	var r := espacio.intersect_ray(q)
	return (r.position as Vector3).y if not r.is_empty() else punto.y


## Dispara UNO. Lo llama el estado de ráfaga, una vez por disparo.
func disparar() -> void:
	if proyectil == null or not objetivo_valido():
		return
	var p := proyectil.instantiate()
	# Al padre y no a sí mismo: un proyectil hijo del que dispara se mueve con él
	# y desaparece cuando muere, que es justo cuando más falta hace que siga.
	get_parent().add_child(p)
	var origen := global_position + Vector3.UP * 0.5
	var hacia := (objetivo.global_position + Vector3.UP * 0.9 - origen).normalized()
	p.global_position = origen
	if p.has_method("lanzar"):
		p.lanzar(hacia, velocidad_proyectil, ataque, self)
	EventBus.camara_shake.emit(0.1, 0.06)
