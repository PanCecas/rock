@tool
class_name Ancla
extends Node3D
## UN PUNTO DEL QUE COLGARSE. Nada más.
##
## **Es el cambio de dueño de la cuerda.** Hasta el parche 3.16 la cuerda colgaba
## de la LANZA: para balancearte tenías que tirarla primero, acertar, y solo
## entonces existía un punto. Eso convertía un verbo de movimiento en una cadena
## de tres acciones, y es la mitad de por qué el balanceo se sentía lento — la
## otra mitad era que el arco no terminaba nunca.
##
## Ahora el punto lo pone el NIVEL. Está ahí, se ve, y engancharse es una sola
## pulsación sin tiempo de viaje. La lanza vuelve a ser lo que era: un arma que
## además es plataforma.
##
## **Se descubre por GRUPO, no por consulta de física.** Un `Area3D` por ancla
## costaría una capa de colisión, un tick de solapamiento y la latencia de un
## frame que la `Hitbox` ya documenta; y lo que hace falta aquí es recorrer una
## lista corta y puntuarla. Con veinte anclas en pantalla eso son veinte restas.
##
## **No tiene colisión.** Un ancla es un sitio al que apuntar, no un obstáculo:
## que el jugador choque contra su propio punto de enganche sería exactamente lo
## contrario de lo que se busca. Misma razón por la que la estación de jam es
## escenografía.

## Grupo por el que las encuentra el jugador. En un solo sitio: escribirlo a mano
## en el buscador y en el poblador es como se llega a dos grupos con un typo de
## diferencia y a un ancla que no engancha sin decir por qué.
const GRUPO := &"anclas"

## Radio del testigo visual, en metros. Solo presentación: el alcance real y el
## cono los pone `PlayerTuning`, no esto.
@export_range(0.05, 2.0, 0.05) var radio: float = 0.28:
	set(v):
		radio = v
		if is_inside_tree():
			_rehacer()

## ¿Se dibuja el testigo? Apagado para anclas que ya tienen su propio modelo
## colgando —una argolla, una rama—: el testigo es un marcador de blockout.
@export var visible_en_juego: bool = true:
	set(v):
		visible_en_juego = v
		if is_inside_tree():
			_rehacer()

var _visual: MeshInstance3D = null


func _ready() -> void:
	add_to_group(GRUPO)
	_rehacer()


## LA BÚSQUEDA, y vive aquí porque es asunto del ancla.
##
## Tres filtros y un criterio, en este orden porque cada uno es más caro que el
## anterior:
##
##   1. RANGO. Una resta de vectores.
##   2. CONO DE CÁMARA. Un producto escalar. El jugador engancha a lo que está
##      MIRANDO, no a lo que tiene detrás: sin esto, encadenar en una sala con
##      varias anclas te tira hacia la que acabas de soltar.
##   2bis. Y LA QUE ACABAS DE SOLTAR se salta del todo (`excluir_ancla`), porque
##      desde el 4.01 soltarse devuelve la cuerda. Ver `PlayerController
##      .soltar_de_ancla()`.
##   3. LÍNEA DE VISIÓN. Un rayo, y solo para las que ya pasaron los dos filtros.
##      Engancharse a través de una pared se lee como un bug aunque sea cómodo.
##
## Y el criterio es el ÁNGULO, no la distancia: entre dos anclas buenas, la que
## está más centrada en la pantalla es la que el jugador cree que ha elegido.
##
## **SON DOS ORÍGENES DISTINTOS, Y NO ES UN DETALLE.** El rango y la visión se
## miden desde el JUGADOR, porque la cuerda sale de él; el cono se mide desde la
## CÁMARA, porque "lo que estás mirando" es lo que hay en la pantalla. Medirlo
## todo desde la cámara —que es como estaba— le suma al alcance la distancia del
## brazo: `cuerda_rango` decía 12 y el jugador enganchaba a 20, y ese número es
## justo el que dibuja los niveles. Medido al cazarlo: 20.75 m.
static func mejor(
	arbol: SceneTree,
	origen: Vector3,
	ojo: Vector3,
	direccion: Vector3,
	rango: float,
	cos_cono: float,
	excluir: Array[RID] = [],
	excluir_ancla: Ancla = null
) -> Ancla:
	var mejor_ancla: Ancla = null
	var mejor_puntos := -1.0
	var rango2 := rango * rango
	var mundo: World3D = null

	for nodo in arbol.get_nodes_in_group(GRUPO):
		var a := nodo as Ancla
		if a == null or not a.is_inside_tree():
			continue
		# LA QUE ACABAS DE SOLTAR NO CUENTA. Es lo unico que separa «encadenar
		# anclas» de «bombear una sola»: soltarse devuelve la cuerda, asi que sin
		# este filtro el mismo punto se podria reenganchar en el aire una y otra
		# vez y el arco volveria a ser un MODO con pasos extra (regla dura #27).
		# Vuelve a valer en cuanto toques algo: `recargar_moveset()` la olvida.
		if a == excluir_ancla:
			continue
		var hacia := a.global_position - origen
		var d2 := hacia.length_squared()
		if d2 > rango2 or d2 < 0.01:
			continue
		var en_pantalla := a.global_position - ojo
		if en_pantalla.is_zero_approx():
			continue
		var alineacion := direccion.dot(en_pantalla.normalized())
		if alineacion < cos_cono:
			continue
		# Puntúa por alineación: el empate se rompe por cercanía, que es lo que
		# uno espera cuando dos anclas están igual de centradas.
		var puntos := alineacion - 0.02 * sqrt(d2) / maxf(rango, 0.001)
		if puntos <= mejor_puntos:
			continue
		if mundo == null:
			mundo = a.get_world_3d()
		if not _hay_vision(mundo, origen, a.global_position, excluir):
			continue
		mejor_puntos = puntos
		mejor_ancla = a

	return mejor_ancla


## ¿Se ve el ancla desde aquí? Se para en la geometría del mundo, que es lo único
## que tapa de verdad: los enemigos y las zonas de agua no son paredes.
static func _hay_vision(
	mundo: World3D, desde: Vector3, hasta: Vector3, excluir: Array[RID]
) -> bool:
	if mundo == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(desde, hasta, Layers.WORLD)
	q.exclude = excluir
	return mundo.direct_space_state.intersect_ray(q).is_empty()


func _rehacer() -> void:
	if _visual != null and is_instance_valid(_visual):
		_visual.queue_free()
		_visual = null
	if not visible_en_juego:
		return
	var malla := SphereMesh.new()
	malla.radius = radio
	malla.height = radio * 2.0
	malla.radial_segments = 10
	malla.rings = 5
	var mat := StandardMaterial3D.new()
	# Regla dura #9: el color sale de la Palette, nunca de un hex a mano.
	#
	# Y NO SE LE PREGUNTA A `GameState` DENTRO DEL EDITOR. Este script es `@tool`,
	# así que corre también durante el importado, y ahí el autoload todavía no
	# tiene la Palette resuelta: se llevaba un `Invalid access to property
	# 'palette'` por cada ancla de cada escena, en cada arranque. En el editor el
	# testigo sale blanco, que es lo correcto — ahí lo que importa es ver DÓNDE
	# está, no de qué color.
	var c := Color.WHITE
	if not Engine.is_editor_hint():
		var p: Palette = GameState.palette
		if p != null:
			c = p.oro_palido
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 0.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	malla.material = mat
	_visual = MeshInstance3D.new()
	_visual.mesh = malla
	# Un testigo no proyecta sombra: es un marcador, no un objeto del mundo.
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual)
