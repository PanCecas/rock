extends Node
## BANCO DE LA CADENA: ¿sobrevive la velocidad al tocar el mundo?
##
##   godot --headless --path . tools/MedirCadena.tscn
##
## El moveset del parche 4.00 se sostiene sobre una sola promesa —«encadenar
## limpio acumula velocidad»— y esa promesa la rompe cualquier estado que
## escriba `velocity = Vector3.ZERO` al recibirte. Este banco va a buscarlos por
## el camino real: llegar lanzado a un muro, a un canto, a una rampa.
##
## **Mide DOS cosas por transición, y las dos hacen falta:**
##
##   · a qué estado te manda el contacto —porque un estado que no querías es un
##     problema aunque conserve la velocidad—, y
##   · qué queda de la rapidez que traías.
##
## Se imprime en una tabla para poder pegarla al lado de la de la pasada
## anterior, igual que `MedirPatada`.

var _main: Node
var _p: PlayerController

var _paso: int = 0
var _t: float = 0.0
var _guion: Array = []
var _lineas: PackedStringArray = []

# --- Latches del contacto.
var _v_lanzado: float = 0.0
var _v_min_tras: float = 9999.0
var _v_final: float = 0.0
var _estados: PackedStringArray = []
var _estado_prev: StringName = &""
var _cargas_min: int = 99
var _cargas_max: int = -1
var _pared_frames: int = 0
## Rapidez EN EL CONTACTO y unos frames DESPUES. Leerla al final de la ventana no
## vale: el jugador ya ha caido al suelo y lo que se mide es la friccion del
## suelo, no lo que hizo el muro.
var _v_al_tocar: float = -1.0
var _v_tras_tocar: float = -1.0
var _frames_desde_toque: int = -1
var _recargas: int = 0
var _cargas_prev: int = -1
var _v_plano_prev: float = 0.0
var _tocaba_prev: bool = false
## Rapidez en el PRIMER frame dentro de `_espiar`. Es donde se ve si el estado te
## recibe conservando o borrando.
var _espiar: StringName = &""
var _v_estado: float = -1.0
## Curva de la rapidez frame a frame, para ver si el tope corta o decae.
var _curva: PackedFloat32Array = PackedFloat32Array()
var _midiendo_curva: bool = false
## Salto medido desde donde sea: la vertical justo antes de pulsar y la de cuatro
## frames despues, que es cuando el impulso ya esta puesto y la gravedad apenas lo
## ha tocado.
var _cuerda_fija: bool = false
var _cuerda_suelta: bool = true
var _saltar_tras: int = -1
var _vy_antes_salto: float = 0.0
var _vy_tras_salto: float = -99.0
var _contando_salto: int = -1
## En que estado estaba el jugador al pulsar Espacio. Sin esto, "saltar desde el
## arco" puede estar midiendo un doble salto en el aire y no enterarse: la medida
## imprimiria un impulso correcto de un sitio que no era el que se preguntaba.
var _estado_al_saltar: StringName = &"?"

# --- LA CADENA DE CUERDAS.
## La camara se conduce a mano y el rig se apaga. El cono de camara es PARTE de
## la mecanica de la cuerda —`Ancla.mejor()` lo mide desde el ojo—, asi que
## dejarlo al azar de a donde mirase el rig convertiria una medida de la cuerda
## en una medida del rig.
var _cam: Camera3D = null
var _mirar_obj: Vector3 = Vector3.ZERO
var _mirar_activo: bool = false
## Guion por FRAMES dentro de una medida. `_medida` solo tiene un "hacer", y una
## cadena son tres gestos en tres momentos distintos: engancharse, soltar y
## volver a engancharse.
var _agenda: Array = []
var _fr: int = 0
var _enganches: int = 0
var _ancla_a: Ancla = null
## Lo que habia en el instante del SEGUNDO intento. Si falla, estas dos lineas
## dicen por cual de las tres puertas —carga, alcance o cono— y no hay que
## adivinarlo.
var _cuerda_al_2o: String = "?"
var _candidata_2o: String = "?"
## En que estado estaba el jugador unos frames DESPUES de pulsar. Un intento que
## falla con la carga puesta y el ancla en el cono solo puede estar fallando por
## el estado, asi que hay que imprimirlo.
var _estado_2o: StringName = &"?"
## Flancos de contacto dentro de la medida. Es la condicion literal que recarga
## el moveset, y contarla es lo unico que distingue «el segundo enganche salio de
## la nada» de «lo pago un roce con un pilar». `_recargas` no vale para esto:
## cuenta SUBIDAS de `patada_cargas`, y estando ya al maximo una recarga no sube.
var _toques: int = 0
## Los mismos, congelados en el instante del segundo intento. Es el numero que
## prueba la cadena: si al pulsar la Z sobre la siguiente ancla el jugador no
## habia tocado NADA y aun asi engancha, la cuerda se encadena de verdad.
var _toques_al_2o: int = 0


func _ready() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	await get_tree().physics_frame
	for n in get_tree().get_nodes_in_group(&"enemigos"):
		var e := n as Enemigo
		if e != null and is_instance_valid(e):
			e.vista = 0.0
	var rig := _main.get_node_or_null("CameraRig") as Node3D
	if rig != null:
		rig.process_mode = Node.PROCESS_MODE_DISABLED
	_cam = get_viewport().get_camera_3d()
	_construir()


func _construir() -> void:
	_guion = [
		# LA PARED ESCALABLE DEL GYM, en (24, 6, 20) con la cara en z = 19.5.
		# Se llega lanzado y EMPUJANDO, que es el caso real: encadenas hacia un muro
		# y sigues pidiendo esa dirección porque quieres seguir por ahí.
		_medida("llegar a un muro a 30 m/s, empujando", 1.4,
			func() -> void:
				_lanzar(Vector3(24.0, 3.0, 27.0), Vector3.FORWARD * 30.0, true),
			func() -> String:
				return "v %.1f -> %.1f   estados: %s" % [
					_v_lanzado, _v_final, _traza()]),

		# EL MISMO MURO Y EL MISMO GESTO, pero SIN LA HABILIDAD DE TREPAR. Es la
		# comparacion que decide si el candado sirve: con ella te agarra y te pone a
		# cero, sin ella la pared vuelve a ser un sitio del que rebotar.
		_medida("el mismo muro SIN la habilidad", 1.4,
			func() -> void:
				_lanzar(Vector3(24.0, 3.0, 27.0), Vector3.FORWARD * 30.0, true)
				_p.puede_escalar = false,
			func() -> String:
				return "v %.1f -> %.1f   estados: %s" % [
					_v_lanzado, _v_final, _traza()]),

		# EL MISMO MURO, sin pedir la dirección. Es la fila de control: separa lo
		# que hace el CONTACTO de lo que hace la ADHERENCIA AUTOMÁTICA, que solo se
		# arma si el stick insiste.
		_medida("el mismo muro, SIN empujar — control", 1.4,
			func() -> void:
				_lanzar(Vector3(24.0, 3.0, 27.0), Vector3.FORWARD * 30.0, false),
			func() -> String:
				return "v %.1f -> %.1f   estados: %s" % [
					_v_lanzado, _v_final, _traza()]),

		# ESCALANDO: ¿el flanco de recarga se dispara solo? Si `is_on_wall()`
		# parpadea mientras se trepa, las cargas se rellenan sin tocar nada nuevo y
		# el presupuesto aéreo deja de ser un presupuesto.
		_medida("escalando: ¿se rellenan las cargas solas?", 2.0,
			func() -> void:
				_lanzar(Vector3(24.0, 3.0, 27.0), Vector3.FORWARD * 30.0, true)
				_p.patada_cargas = 0
				_p.cuerda_disponible = false
				_recargas = 0
				_cargas_prev = 0,
			func() -> String:
				return "%d recargas en 2 s   pared %d/%d frames   cargas %d..%d" % [
					_recargas, _pared_frames, int(2.0 * 60.0),
					_cargas_min if _cargas_min < 99 else 0, _cargas_max]),

		# ROZANDO, que es el caso que de verdad importa. De frente perder toda la
		# velocidad es FISICAMENTE CORRECTO —te has estrellado— y medir solo eso no
		# dice nada. Lo que tiene que sobrevivir es la componente que va A LO LARGO
		# del muro.
		#
		# En el corredor de wall-run del Gym: dos muros de 24 m de largo a x = ±1.3,
		# sin suelo cerca. Y se lee EN EL CONTACTO, no al final de la ventana: al
		# final el jugador ya ha aterrizado y lo que se mediria es la friccion del
		# suelo echandole la culpa al muro.
		_medida("ROZAR un muro a 16 grados, a 30 m/s", 0.7,
			func() -> void:
				var dir := Vector3(0.28, 0.0, -0.96).normalized()
				_lanzar(Vector3(0.0, 6.0, -24.0), dir * 30.0, false),
			func() -> String: return _linea_roce()),

		_medida("y el mismo roce a 35 grados", 0.7,
			func() -> void:
				var dir := Vector3(0.57, 0.0, -0.82).normalized()
				_lanzar(Vector3(-0.4, 6.0, -24.0), dir * 30.0, false),
			func() -> String: return _linea_roce()),

		# --- LOS ESTADOS QUE TE RECIBEN ---------------------------------------
		# La regla del genero, escrita en el propio documento: "nunca reinicies la
		# velocidad horizontal al entrar a un estado; convierte, escala o proyecta".
		# Aqui se va a buscar quien la incumple, llegando lanzado a cada uno.
		_medida("DASHEAR viniendo a 36 m/s", 0.5,
			func() -> void:
				_lanzar(Vector3(0.0, 10.0, 6.0), Vector3.RIGHT * 36.0, false)
				_v_estado = -1.0
				_espiar = &"Dash"
				_p.fsm.cambiar(&"Dash"),
			func() -> String:
				return "entra %.1f -> primer frame dentro %.1f" % [_v_lanzado, _v_estado]),

		_medida("PARRY viniendo a 15 m/s", 0.5,
			func() -> void:
				_lanzar(Vector3(0.0, 0.3, 6.0), Vector3.RIGHT * 15.0, false)
				_v_estado = -1.0
				_espiar = &"Parry"
				_p.fsm.cambiar(&"Parry"),
			func() -> String:
				return "entra %.1f -> primer frame dentro %.1f" % [_v_lanzado, _v_estado]),

		# EL TOPE. Con un clamp duro, pasar de 34 a 22 ocurre en UN frame y el
		# momentum ganado no se siente ganado. Con un soft cap decae, y lo que se mide
		# es cuanto tarda.
		_medida("de 34 m/s al tope: ¿corte o caida?", 1.2,
			func() -> void:
				_lanzar(Vector3(0.0, 30.0, 6.0), Vector3.RIGHT * 34.0, false)
				_curva = PackedFloat32Array()
				_midiendo_curva = true,
			func() -> String:
				_midiendo_curva = false
				var t := PackedStringArray()
				for i in [0, 3, 6, 12, 24, 48]:
					if i < _curva.size():
						t.append("%dfr %.1f" % [i, _curva[i]])
				return " · ".join(t)),

		# --- LA CUERDA: ALCANCE Y SALIDA -------------------------------------
		# ¿Se pueden encadenar las anclas que hay PUESTAS? El alcance no es un numero
		# de gusto: es la distancia entre dos anclas vecinas. Si es menor, no hay
		# cadena que dar y la cuerda se siente corta con razon.
		_medida("¿llega el alcance de un ancla a la siguiente?", 0.1,
			func() -> void: pass,
			func() -> String: return _cuerdas_entre_anclas()),

		# **Se monta entre el par de anclas MAS JUNTO del Gym** (la 2 y la 3, a
		# 9.7 m), no entre dos cualesquiera. El primer encuadre puso la siguiente a
		# 18.5 m de un alcance de 19 y la medida se volvio ilegible: el ancla se
		# salia del alcance sola mientras el jugador caia, asi que el fallo podia
		# ser del alcance o de la carga y la linea no distinguia cual.
		#
		# ENCADENAR CUERDA -> CUERDA, que es el criterio de exito del rediseño
		# entero: «cuerda -> patada -> pared -> cuerda sin tocar el suelo».
		#
		# Se mide por el camino REAL —la tecla, el cono y el buffer— y la camara
		# apunta sola al ancla que toca en cada momento, asi que el cono siempre
		# pasa. Lo que queda medido son las otras dos puertas: el alcance y la
		# carga. Si el segundo enganche no sale, la linea dice por cual.
		_medida("encadenar ancla -> ancla sin tocar nada", 2.2,
			func() -> void:
				_lanzar(Vector3(-10.5, 10.0, 34.0), Vector3.ZERO, false)
				_ancla_a = _ancla_por_nombre("Ancla_2")
				if _ancla_a != null:
					_mirar_a(_ancla_a.global_position)
				_agenda = _guion_de_cadena(false),
			func() -> String:
				return "%d enganches   2o (tras %d toques): cuerda %s, ancla %s   %s" % [
					_enganches, _toques_al_2o, _cuerda_al_2o, _candidata_2o, _traza()]),

		# LA MISMA CADENA, recargando a mano en el hueco. FILA DE CONTROL: si con
		# la carga puesta el segundo enganche SI sale, el que falla es el
		# presupuesto y no el cono ni el alcance. Sin esta fila, la de arriba no
		# distingue "no queda cuerda" de "no hay ancla".
		_medida("la misma cadena, recargando a mano — control", 2.2,
			func() -> void:
				_lanzar(Vector3(-10.5, 10.0, 34.0), Vector3.ZERO, false)
				_ancla_a = _ancla_por_nombre("Ancla_2")
				if _ancla_a != null:
					_mirar_a(_ancla_a.global_position)
				_agenda = _guion_de_cadena(true),
			func() -> String:
				return "%d enganches   2o (tras %d toques): cuerda %s, ancla %s   %s" % [
					_enganches, _toques_al_2o, _cuerda_al_2o, _candidata_2o, _traza()]),

		# LA Z ESTANDO PEGADO A UNA PARED. Rozar un muro RECARGA la cuerda —tocar
		# algo la devuelve—, asi que el wall-slide es justo el sitio desde el que
		# uno intenta encadenar. Si el boton no responde ahi, encadenar sale «a
		# veces si y a veces no» segun si rozaste algo por el camino.
		#
		# Sin empujar a proposito: `move_forward` sale de la camara, y la camara
		# aqui mira al ancla —o sea en direccion contraria al muro—. Con la
		# velocidad basta: `wallslide_entrada_min` mide lo que va CONTRA la pared.
		_medida("pegado a una pared: ¿responde la Z?", 1.4,
			func() -> void:
				_lanzar(Vector3(24.0, 8.0, 21.6), Vector3.FORWARD * 6.0, false)
				_p.puede_escalar = false
				var a := _ancla_por_nombre("Ancla_0")
				if a != null:
					_mirar_a(a.global_position)
				_agenda = [
					{"fr": 30, "que": func() -> void:
						_cuerda_al_2o = "lista" if _p.cuerda_disponible else "GASTADA"
						var c := _p.buscar_ancla()
						_candidata_2o = "ninguna en el cono"
						if c != null:
							_candidata_2o = "%s a %.1f m" % [c.name,
								c.global_position.distance_to(_p.global_position)]
						_estado_2o = _p.fsm.nombre_actual()
						_cuerda_fija = true},
					{"fr": 45, "que": func() -> void: _cuerda_fija = false},
				],
			func() -> String:
				return "%d enganches   al pulsar: cuerda %s, ancla %s, en %s   %s" % [
					_enganches, _cuerda_al_2o, _candidata_2o, _estado_2o, _traza()]),

		# SALTAR DESDE EL ARCO. Lo que se mide es la vertical DESPUES, comparada con
		# la que traias: si salen iguales, el boton no esta dando ningun impulso.
		#
		# **Y se imprime el ESTADO en el que se pulso.** La pasada anterior dio
		# «-15.2 -> +10.7» y se leyo como que el arco saltaba bien; sin el nombre
		# del estado al lado, esa linea no distingue un salto desde el arco de un
		# doble salto en el aire, que es lo que estaba midiendo.
		_medida("saltar desde el arco: ¿da impulso?", 1.0,
			func() -> void:
				_lanzar(Vector3(16.0, 8.0, 26.0), Vector3.ZERO, false)
				_ancla_a = _ancla_por_nombre("Ancla_0")
				if _ancla_a != null:
					_mirar_a(_ancla_a.global_position)
				_vy_antes_salto = 0.0
				_vy_tras_salto = -99.0
				_agenda = [{"fr": 3, "que": func() -> void: _cuerda_fija = true}]
				_saltar_tras = 34,
			func() -> String:
				return "en %s: vy %.1f -> tras pulsar Espacio %.1f" % [
					_estado_al_saltar, _vy_antes_salto, _vy_tras_salto]),

		# EL DOBLE SALTO a secas, como fila de control: si este da impulso y el de la
		# cuerda no, el problema es de la cuerda y no del salto.
		_medida("doble salto en el aire — control", 0.5,
			func() -> void:
				_lanzar(Vector3(0.0, 14.0, 6.0), Vector3.ZERO, false)
				_vy_antes_salto = 0.0
				_vy_tras_salto = -99.0
				_saltar_tras = 8,
			func() -> String:
				return "vy cayendo %.1f -> tras pulsar Espacio %.1f" % [
					_vy_antes_salto, _vy_tras_salto]),

		# EL CANTO. Otro receptor de momentum, y el que más se cruza en un arco:
		# la repisa del Gym, a media altura de la pared.
		_medida("llegar a un canto a 25 m/s", 1.4,
			func() -> void:
				_lanzar(Vector3(24.0, 6.6, 27.0), Vector3.FORWARD * 25.0, true),
			func() -> String:
				return "v %.1f -> %.1f   estados: %s" % [
					_v_lanzado, _v_final, _traza()]),
	]


## Lanza al jugador desde `pos` con `vel`, opcionalmente manteniendo la dirección
## de avance pulsada. El permiso de momentum se abre a mano: sin él el clamp
## global (22) recorta los 30 antes de que nada del mundo los toque, y la medida
## culparía al muro de lo que hace el clamp.
func _lanzar(pos: Vector3, vel: Vector3, empujando: bool) -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
	_p.global_position = pos
	_p.velocity = vel
	_p.stamina.llenar()
	_p.recargar_moveset()
	# Y LOS SALTOS AEREOS, que son otra cuenta. `recargar_moveset()` repone la
	# cuerda y la patada; el doble salto y el dash los repone `recargar_aire()`, y
	# olvidarlo hacia que la fila de control del doble salto midiera a un jugador
	# que ya no le quedaba —"no salta" en vez de "no le queda"—.
	_p.recargar_aire()
	# La habilidad vuelve a estar puesta en cada medida: el Gym la da, y una medida
	# no puede heredar el estado de la anterior.
	_p.puede_escalar = true
	_p.call("orientar_a", vel.normalized())
	_p.fsm.cambiar(&"Fall")
	_p.reset_physics_interpolation()
	if empujando:
		Input.action_press(&"move_forward")
	_v_lanzado = _p.superficie.plano(vel).length()
	_v_min_tras = 9999.0
	_v_final = 0.0
	_estados = PackedStringArray([str(_p.fsm.nombre_actual())])
	_pared_frames = 0
	_espiar = &""
	_midiendo_curva = false
	_cuerda_fija = false
	_saltar_tras = -1
	_contando_salto = -1
	_v_al_tocar = -1.0
	_v_tras_tocar = -1.0
	_frames_desde_toque = -1
	_cargas_min = 99
	_cargas_max = -1
	_toques = 0
	_toques_al_2o = 0
	_agenda = []
	_fr = 0
	_enganches = 0
	_mirar_activo = false
	_ancla_a = null
	_cuerda_al_2o = "?"
	_candidata_2o = "?"
	_estado_2o = &"?"
	_estado_al_saltar = &"?"


## Una linea de roce, leida en el contacto. Si no llego a tocar el muro se dice,
## en vez de imprimir un porcentaje de una cosa que no paso.
func _linea_roce() -> String:
	if _v_al_tocar < 0.0:
		return "NO llego a tocar el muro   estados: %s" % _traza()
	var tras: float = _v_tras_tocar if _v_tras_tocar >= 0.0 else _v_final
	return "al tocar %.1f -> 10 frames despues %.1f   (%.0f%% conservado)   %s" % [
		_v_al_tocar, tras, 100.0 * tras / maxf(_v_al_tocar, 0.001), _traza()]


## EL GUION DE UNA CADENA, en frames: engancharse, soltar, mirar a la siguiente y
## volver a pulsar. `con_recarga` es la fila de control — le devuelve la carga a
## mano en el hueco, que es lo que haria tocar una pared.
func _guion_de_cadena(con_recarga: bool) -> Array:
	return [
		{"fr": 3, "que": func() -> void: _cuerda_fija = true},
		{"fr": 45, "que": func() -> void: _cuerda_fija = false},
		{"fr": 48, "que": func() -> void:
			if con_recarga:
				_p.recargar_moveset()
			var b := _ancla_vecina(_ancla_a)
			if b != null:
				_mirar_a(b.global_position)},
		{"fr": 53, "que": func() -> void:
			_toques_al_2o = _toques
			_cuerda_al_2o = "lista" if _p.cuerda_disponible else "GASTADA"
			var c := _p.buscar_ancla()
			_candidata_2o = "ninguna en el cono"
			if c != null:
				_candidata_2o = "%s a %.1f m" % [
					c.name, c.global_position.distance_to(_p.global_position)]
			_cuerda_fija = true},
		{"fr": 61, "que": func() -> void: _estado_2o = _p.fsm.nombre_actual()},
	]


## Pone la camara DETRAS del jugador y mirando al objetivo, cada frame. Asi el
## ancla cae siempre centrada en el cono y lo que se mide es la otra mitad.
func _mirar_a(objetivo: Vector3) -> void:
	_mirar_obj = objetivo
	_mirar_activo = true


func _colocar_camara() -> void:
	if not _mirar_activo or _cam == null or _p == null:
		return
	var dir := _mirar_obj - _p.global_position
	if dir.length() < 0.5:
		return
	dir = dir.normalized()
	_cam.global_position = _p.global_position - dir * 6.0 + Vector3.UP * 2.0
	_cam.look_at(_mirar_obj, Vector3.UP)


func _ancla_por_nombre(nombre: String) -> Ancla:
	for n in get_tree().get_nodes_in_group(Ancla.GRUPO):
		if n.name == nombre:
			return n as Ancla
	return null


## El ancla mas cercana al jugador, saltandose una. Se busca en el mundo y no se
## escribe a mano: los pilares del Gym se generan por codigo y una tabla no se
## entera de que se han movido.
func _ancla_vecina(excepto: Ancla) -> Ancla:
	var mejor: Ancla = null
	var mejor_d := INF
	for n in get_tree().get_nodes_in_group(Ancla.GRUPO):
		var a := n as Ancla
		if a == null or a == excepto:
			continue
		var d := a.global_position.distance_to(_p.global_position)
		if d < mejor_d:
			mejor_d = d
			mejor = a
	return mejor


## La distancia entre cada ancla del Gym y la siguiente, contra el alcance
## configurado. Se lee del mundo, no de una tabla escrita a mano: el dia que se
## muevan las anclas, esto sigue diciendo la verdad.
func _cuerdas_entre_anclas() -> String:
	var anclas: Array = get_tree().get_nodes_in_group(Ancla.GRUPO)
	if anclas.size() < 2:
		return "no hay anclas en el mundo"
	var partes := PackedStringArray()
	var alcanzables := 0
	for i in anclas.size():
		var a := anclas[i] as Ancla
		var b := anclas[(i + 1) % anclas.size()] as Ancla
		if a == null or b == null:
			continue
		var d := a.global_position.distance_to(b.global_position)
		if d <= _p.tuning.cuerda_rango:
			alcanzables += 1
		partes.append("%.1f" % d)
	return "%d de %d vecinas dentro de %.0f m   [%s]" % [
		alcanzables, partes.size(), _p.tuning.cuerda_rango, " ".join(partes)]


func _traza() -> String:
	return " > ".join(_estados)


func _physics_process(delta: float) -> void:
	if _p == null or _guion.is_empty():
		return
	if _paso >= _guion.size():
		_informe()
		return
	# La camara va PRIMERO: el jugador la lee dentro de su propio tick, y este nodo
	# es la raiz, asi que su `_physics_process` corre antes que el de sus hijos.
	_colocar_camara()
	_t += delta

	# La Z mantenida necesita el FLANCO al soltar: dejar de llamar a `action_press`
	# no suelta nada, la accion se queda pulsada para siempre.
	if _cuerda_fija:
		Input.action_press(&"rope")
		_cuerda_suelta = false
	elif not _cuerda_suelta:
		Input.action_release(&"rope")
		_cuerda_suelta = true
	if _saltar_tras > 0:
		_saltar_tras -= 1
		if _saltar_tras == 0:
			_vy_antes_salto = _p.superficie.vertical(_p.velocity)
			_estado_al_saltar = _p.fsm.nombre_actual()
			Input.action_press(&"jump")
			_contando_salto = 0
	elif _saltar_tras == 0:
		Input.action_release(&"jump")
		_saltar_tras = -1
	if _contando_salto >= 0:
		_contando_salto += 1
		if _contando_salto == 4:
			_vy_tras_salto = _p.superficie.vertical(_p.velocity)

	var estado := _p.fsm.nombre_actual()
	if estado != _estado_prev:
		if estado == &"Grapple":
			_enganches += 1
		if _estados.size() < 8:
			_estados.append(str(estado))
		_estado_prev = estado
	var plano := _p.superficie.plano(_p.velocity).length()
	_v_final = plano
	_v_min_tras = minf(_v_min_tras, plano)
	var tocando := _p.is_on_floor() or _p.is_on_wall()
	if tocando and not _tocaba_prev:
		_toques += 1
	_tocaba_prev = tocando
	if _p.is_on_wall():
		_pared_frames += 1
		if _v_al_tocar < 0.0:
			_v_al_tocar = _v_plano_prev
			_frames_desde_toque = 0
	if _frames_desde_toque >= 0:
		_frames_desde_toque += 1
		if _frames_desde_toque == 10:
			_v_tras_tocar = plano
	_v_plano_prev = plano
	if _espiar != &"" and estado == _espiar and _v_estado < 0.0:
		_v_estado = plano
	if _midiendo_curva and _curva.size() < 64:
		_curva.append(plano)
	_cargas_min = mini(_cargas_min, _p.patada_cargas)
	_cargas_max = maxi(_cargas_max, _p.patada_cargas)
	if _p.patada_cargas > _cargas_prev:
		_recargas += 1
	_cargas_prev = _p.patada_cargas

	var actual: Dictionary = _guion[_paso]
	if is_zero_approx(_t - delta):
		(actual["hacer"] as Callable).call()
	_fr += 1
	for e in _agenda:
		if int(e["fr"]) == _fr:
			(e["que"] as Callable).call()
	if _t >= float(actual["dur"]):
		_lineas.append("  %-38s %s" % [
			actual["nombre"], (actual["leer"] as Callable).call()])
		_paso += 1
		_t = 0.0


func _informe() -> void:
	set_physics_process(false)
	print("\n=== LA CADENA CONTRA EL MUNDO ===\n")
	for l in _lineas:
		print(l)
	print("\n--- QUIEN PUEDE COMERSE LA VELOCIDAD ---")
	print("  velocidad_maxima      %.1f m/s   (el clamp global)" % _p.tuning.velocidad_maxima)
	print("  escalada_auto_tiempo  %.2f s     (lo que tarda la adherencia en armarse)" % _p.tuning.escalada_auto_tiempo)
	get_tree().quit(0)


func _medida(nombre: String, dur: float, hacer: Callable, leer: Callable) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "leer": leer}
