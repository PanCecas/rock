class_name Embestidor
extends Enemigo
## EMBESTIDOR: te ve, se planta, y carga en línea recta hasta chocar.
##
## Su mecánica entera es **esquivable por diseño**, y eso descansa en dos
## decisiones que van juntas:
##
##   1. **La dirección se BLOQUEA al terminar la anticipación.** Si persiguiera
##      mientras carga no habría esquiva posible: sería un misil teledirigido y el
##      jugador solo podría correr. Al fijar el rumbo, el gesto correcto pasa a ser
##      quedarse quieto y apartarse en el último momento, que es mucho más
##      satisfactorio que huir.
##   2. **Contra la pared queda aturdido y abierto.** Esa es la recompensa por
##      esquivar bien, y lo que convierte al enemigo en un puzle de posicionamiento
##      en vez de en un saco con más vida.
##
## El cono de visión es la otra mitad: se le puede flanquear. Un enemigo que te ve
## a 360 grados no premia acercarse por detrás.

## Semiángulo del cono de visión, en grados. 45 = un cono frontal de 90.
@export_range(5.0, 180.0, 1.0) var cono_grados: float = 45.0
## Altura desde la que sale el rayo que confirma la visión.
@export_range(0.0, 3.0, 0.05) var altura_ojos: float = 1.2

@export_group("Carga")
## Lo que dura la anticipación. Es la ventana en la que el jugador decide, así que
## es el número más importante de este enemigo: corto, es injusto; largo, es
## inofensivo.
@export_range(0.1, 3.0, 0.05) var anticipacion: float = 0.75
@export_range(1.0, 40.0, 0.5) var velocidad_carga: float = 15.0
## Tope de la carga. Sin él, un fallo en campo abierto lo manda al horizonte.
@export_range(0.5, 10.0, 0.1) var duracion_carga: float = 1.6
## Lo que queda abierto tras estrellarse. Largo a propósito: es el premio.
@export_range(0.5, 8.0, 0.1) var aturdido_muro: float = 2.4


func _ready() -> void:
	super()
	add_to_group(&"embestidores")


func configurar_tipo() -> void:
	salud.maxima = 80.0
	poise.maxima = 45.0
	velocidad = 2.2
	salud.actual = salud.maxima
	poise.actual = poise.maxima


## CONO DE VISIÓN: producto escalar contra el frente, MÁS un raycast que confirme
## que no hay pared en medio.
##
## El dot solo no basta y es el error clásico: te detecta a través del suelo, de
## una columna o del otro lado de un muro, y el jugador no entiende por qué le han
## visto. Las dos comprobaciones juntas son las que hacen que esconderse funcione.
func detecta(j: Node3D) -> bool:
	if j == null:
		return false
	var hacia := j.global_position - global_position
	hacia.y = 0.0
	var dist := hacia.length()
	if dist > vista or dist < 0.01:
		return false

	var frente := -global_basis.z
	frente.y = 0.0
	if frente.is_zero_approx():
		return false
	if rad_to_deg(frente.normalized().angle_to(hacia.normalized())) > cono_grados:
		return false

	# Línea de visión de verdad: sin esto ve a través de las paredes.
	var espacio := get_world_3d().direct_space_state
	var desde := global_position + Vector3.UP * altura_ojos
	var hasta := j.global_position + Vector3.UP * altura_ojos
	var q := PhysicsRayQueryParameters3D.create(desde, hasta, Layers.WORLD)
	q.exclude = [get_rid()]
	return espacio.intersect_ray(q).is_empty()


func estado_al_despertar() -> StringName:
	return &"Anticipar"


func estado_de_ataque() -> StringName:
	return &"Anticipar"
