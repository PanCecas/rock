class_name ColosoMediano
extends Enemigo
## COLOSO MEDIANO: grande, lento, y **su cuerpo se escala**.
##
## Por ahora NO ATACA, y es deliberado. Su único trabajo en esta fase es que
## agarrarse a algo que se mueve resulte cómodo. Meterle un ataque ahora
## convertiría cada prueba de escalada en una pelea, y no sabríamos si el problema
## está en el agarre o en que te están pegando.
##
## Es el **puente pedagógico** hacia el coloso de la Fase 4 (`project.md §3.2`): el
## jugador aprende a escalar algo que camina en un enemigo que cabe en pantalla,
## antes de tener que hacerlo a sesenta metros del suelo.
##
## Cómo se hace escalable, que es lo único técnicamente interesante:
##
##   · Su collider está en la capa **CLIMBABLE** además de la de mundo. El
##     `WallSensor` del jugador ya busca esa capa desde la Fase 1, así que no hace
##     falta tocar una línea del jugador.
##   · Camina **muy despacio** (1.1 m/s). No es un rasgo de personalidad: la
##     escalada del jugador mueve la posición a mano contra la superficie, y si el
##     cuerpo se moviera rápido lo dejaría atrás. La velocidad es el parámetro que
##     hace la escalada cómoda o imposible.
##   · No se sacude. El `ShakeDirector` es de la Fase 4; aquí sobra.
##
## Lo que este enemigo NO resuelve todavía, y hay que saberlo: el `SurfaceContext`
## sigue tratando el mundo como estático. Escalar un cuerpo en movimiento pide que
## el marco de referencia se mueva con él, y ese es el trabajo de la Fase 4. Aquí
## se puede escalar mientras camina porque va despacio, no porque el sistema lo
## soporte de verdad.

## Capa CLIMBABLE del proyecto (`Layers.gd`). El `WallSensor` la busca desde la
## Fase 1: marcar el collider es todo lo que hace falta para que se pueda trepar.
const CAPA_CLIMBABLE := 4


func _ready() -> void:
	super()
	add_to_group(&"colosos_medianos")
	_marcar_escalable()


func configurar_tipo() -> void:
	salud.maxima = 400.0
	poise.maxima = 200.0
	velocidad = 1.1
	# GIRO DE GIGANTE. Con los 360°/s por defecto, su borde —radio 2.2— barria el
	# suelo a 13.8 m/s, mas rapido que correr (9.4), y como esta en la capa WORLD
	# eso es una PLATAFORMA MOVIL: `move_and_slide` arrastraba al jugador en
	# circulos sin tocarle la velocidad. Medido: 3.11 m de desplazamiento con
	# `velocity` a 0.00 en todo momento.
	#
	# A 45°/s el borde va a 1.7 m/s, por debajo de caminar (4.2), asi que siempre
	# se puede andar en contra. Y ademas tarda ocho segundos en darse la vuelta,
	# que es como debe moverse algo de siete metros.
	velocidad_giro = 45.0
	salud.actual = salud.maxima
	poise.actual = poise.maxima


## No ataca: nunca sale de perseguir. Sin `ataque` asignado, `Acercarse` se planta
## a distancia y ahí se queda, que es exactamente lo que se busca para practicar.
func estado_de_ataque() -> StringName:
	return &"Acercarse"


## Marca el collider como CLIMBABLE por código y no en la escena, porque es una
## propiedad del DISEÑO de este enemigo —«a este se le trepa»— y no un ajuste que
## deba poder olvidarse al duplicar la escena.
func _marcar_escalable() -> void:
	var col := get_node_or_null("Collider") as CollisionShape3D
	if col == null:
		return
	set_collision_layer_value(CAPA_CLIMBABLE, true)
	# También cuenta como mundo: si no, el jugador lo atraviesa al caminar.
	set_collision_layer_value(1, true)
