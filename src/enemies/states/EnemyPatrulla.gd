extends EnemyState
## PATRULLA: ronda entre sus puntos mientras no te ha visto.
##
## Es el estado que le faltaba al bestiario. Hasta ahora todo enemigo esperaba
## clavado en el sitio hasta entrar en su radio de visión, y eso tiene un coste de
## lectura que no se nota hasta que se quita: un enemigo parado es un obstáculo, y
## uno que ronda es un habitante. La sala pasa de ser un decorado con torretas a
## ser un sitio donde vive algo.
##
## **Sigue vigilando mientras camina.** Patrullar sin detectar sería un salvapantallas:
## la mitad del valor de una ronda es que te obliga a cronometrar por dónde pasas.
##
## **Camina, no corre** (`velocidad_patrulla`). Si patrullara a su velocidad de
## persecución, verlo venir a por ti dejaría de significar nada: el cambio de ritmo
## ES la señal de que te ha visto.
##
## Va por `rumbo_hacia()`, así que rodea la geometría si el enemigo trae un
## `NavigationAgent3D` y va recto si no. La ruta no sabe cuál de las dos cosas
## pasa, y ese es el punto.

var _esperando: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_esperando = 0.0
	# Al punto MÁS CERCANO, no al primero de la lista. Volver de una persecución
	# y echar a andar hacia el otro extremo de la ronda se lee como un bug.
	_ir_al_mas_cercano()


func physics_update(delta: float) -> void:
	# 1) VIGILAR. Va antes que andar: ver al jugador manda sobre la ronda.
	var j := enemigo.jugador()
	if j != null and enemigo.detecta(j):
		enemigo.objetivo = j
		fsm.cambiar(enemigo.estado_al_despertar())
		return

	if enemigo.ruta.is_empty():
		# Se le ha quitado la ruta en caliente. Sin esto se quedaría andando hacia
		# un punto que ya no existe.
		fsm.cambiar(&"Dormido")
		return

	# 2) LA PAUSA EN CADA PUNTO. Una ronda sin pausas es un carrusel; con ellas
	#    parece que el bicho mira alrededor antes de seguir.
	if _esperando > 0.0:
		_esperando -= delta
		enemigo.motor.frenar(delta)
		return

	var destino := _punto_actual()
	var hacia := enemigo.rumbo_hacia(destino)
	var plano := Vector3(hacia.x, 0.0, hacia.z)

	# La distancia se mide contra el DESTINO REAL, no contra el siguiente nodo de
	# la ruta: el camino puede dar un rodeo y el nodo intermedio estar a un metro
	# mientras el punto sigue a diez.
	var falta := Vector3(destino.x - enemigo.global_position.x, 0.0,
		destino.z - enemigo.global_position.z)
	if falta.length() <= enemigo.radio_punto:
		_esperando = enemigo.espera_en_punto
		enemigo.punto_ruta = (enemigo.punto_ruta + 1) % enemigo.ruta.size()
		return

	if plano.is_zero_approx():
		return
	enemigo.encarar(plano)
	enemigo.motor.mover(plano.normalized(),
		enemigo.velocidad * enemigo.velocidad_patrulla, delta)


func _punto_actual() -> Vector3:
	if enemigo.ruta.is_empty():
		return enemigo.global_position
	return enemigo.ruta[enemigo.punto_ruta % enemigo.ruta.size()]


func _ir_al_mas_cercano() -> void:
	var mejor := 0
	var mejor_d := INF
	for i in enemigo.ruta.size():
		var d: float = enemigo.global_position.distance_squared_to(enemigo.ruta[i])
		if d < mejor_d:
			mejor_d = d
			mejor = i
	enemigo.punto_ruta = mejor


func debug_line() -> String:
	if enemigo.ruta.is_empty():
		return "PATRULLA sin ruta"
	if _esperando > 0.0:
		return "PATRULLA  espera %.1f s" % _esperando
	return "PATRULLA  -> punto %d/%d" % [enemigo.punto_ruta + 1, enemigo.ruta.size()]
