extends Node
## SCREENSHOT TESTS: regresion visual contra imagenes de referencia.
##
##   godot --path . --resolution 960x540 tools/TestVisual.tscn
##   godot --path . --resolution 960x540 tools/TestVisual.tscn -- actualizar
##
## Es una ESCENA y no un `--script` a proposito: en modo script los autoloads no
## se registran, y aqui hace falta silenciar el DebugOverlay.
##
## Por que existe: los tests funcionales comprueban que la FSM llega a un estado,
## no que el personaje se VEA bien estando en el. Media docena de bugs de este
## proyecto —el cuerpo torcido al salir del agua, la capsula partida por la mitad
## junto a una rampa, el cuerpo sin inclinar al escalar una pendiente— eran todos
## visuales, y todos pasaron los tests funcionales sin despeinarse. Una imagen los
## habria cazado en el acto.
##
## Cada toma fuerza un estado concreto, espera a que la orientacion converja y
## fotografia. La comparacion es por pixel con tolerancia: no se busca igualdad
## exacta —el render nunca es identico bit a bit— sino que no haya cambiado nada
## perceptible.
##
## Las referencias viven en `tools/baseline/`. Si no existen, se crean y el test
## avisa. `-- actualizar` las regenera a proposito: hazlo solo cuando el cambio
## visual sea el que buscabas, y mira el diff antes.

## Cuanto puede variar un canal sin contar como diferencia (de 0 a 255).
const TOLERANCIA_CANAL := 10
## Fraccion de pixeles distintos que se tolera antes de fallar.
const TOLERANCIA_PCT := 0.004
## Centro del corral del Gym. Escrito aqui a proposito y no deducido: una toma de
## referencia FIJA una pose, asi que sus coordenadas son parte del contrato. Si
## `Gym._corral()` se mueve, esta constante y las referencias se actualizan juntas.
const CORRAL := Vector3(11.0, 0.0, -32.0)
## Frames de reposo antes de disparar. Da tiempo a que la fisica se asiente y a
## que las orientaciones interpoladas (nado, escalada) lleguen a su destino.
const REPOSO := 40

var _main: Node
var _p: Node3D
var _cam: Camera3D
var _tomas: Array = []
var _i: int = 0
var _f: int = 0
var _fallos: PackedStringArray = []
var _nuevas: PackedStringArray = []
var _actualizar: bool = false
## Frames que lleva sostenida una pose que hay que congelar. Ver `_ante_coloso`.
var _pose: int = 0


func _ready() -> void:
	_actualizar = OS.get_cmdline_user_args().has("actualizar")
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as Node3D

	# El panel de debug imprime velocidad y stamina en vivo: con el puesto, dos
	# capturas del mismo estado nunca serian iguales.
	DebugOverlay.visible_panel = false
	var panel: Variant = DebugOverlay.get("_panel")
	if panel != null and panel is CanvasItem:
		(panel as CanvasItem).visible = false

	# Camara propia y fija. El CameraRig suaviza e interpola, asi que encuadra
	# distinto segun por donde vengas: justo lo que no se quiere en una referencia.
	_cam = Camera3D.new()
	_cam.fov = 60.0
	add_child(_cam)
	_cam.make_current()

	_construir()
	DirAccess.make_dir_recursive_absolute("res://tools/baseline")
	DirAccess.make_dir_recursive_absolute("user://visual")
	RenderingServer.frame_post_draw.connect(_tick)


func _construir() -> void:
	_tomas = [
		_toma("gym_general", Vector3(14, 9, 22), Vector3(0, 1, 0),
			func() -> void: _situar(Vector3(0, 0.05, 4))),

		# POSTURA. Las dos alturas de capsula en el mismo encuadre: buena parte de
		# los bugs de la 2.03 fueron el personaje encogiendose cuando no tocaba.
		_toma("postura_de_pie", Vector3(3.2, 1.6, 3.2), Vector3(0, 0.9, 0),
			func() -> void: _situar(Vector3(0, 0.05, 0))),
		_toma("postura_agachada", Vector3(3.2, 1.6, 3.2), Vector3(0, 0.9, 0),
			func() -> void:
				_situar(Vector3(0, 0.05, 0))
				_estado(&"Crouch"),
			func() -> void: _estado(&"Crouch")),

		# ESCALADA. El cuerpo tiene que inclinarse CON la pendiente: un muro de 90
		# lo deja vertical, una rampa de 60 lo tumba treinta grados.
		_toma("escalada_muro_90", Vector3.ZERO, Vector3.ZERO,
			func() -> void: _ante_rampa(90.0),
			func() -> void: _ante_rampa(90.0),
			func() -> void: _encuadrar_jugador()),
		_toma("escalada_rampa_60", Vector3.ZERO, Vector3.ZERO,
			func() -> void: _ante_rampa(60.0),
			func() -> void: _ante_rampa(60.0),
			func() -> void: _encuadrar_jugador()),

		# DOMO DE CALIBRACION: el anillo dorado marca el slope limit. Si alguien
		# mueve el numero y el anillo no se mueve con el, aqui se ve.
		_toma("domo_umbral", Vector3(28, 8, 44), Vector3(28, 3, 30),
			func() -> void: _situar(Vector3(28, 0.05, 38))),

		# ARENA: los tres Guardianes, para vigilar silueta y color.
		_toma("arena", Vector3(45, 7, -30), Vector3(45, 1, -45),
			func() -> void: _situar(Vector3(45, 0.5, -34))),

		# EL CORDON. Es lo UNICO que puede cubrirlo: el cordon no colisiona, no
		# restringe nada y no cambia ningun estado —es adorno a proposito—, asi que
		# ningun test funcional puede afirmar nada sobre el. O se mira, o no se
		# comprueba.
		_toma("cordon", Vector3.ZERO, Vector3.ZERO,
			func() -> void: _tender_cordon(),
			func() -> void: _sostener_cordon(),
			func() -> void: _encuadrar_cordon()),

		# --- CORRAL DEL 3.03 -------------------------------------------------
		# `TestEnemigos` comprueba que la rafaga sale, que la carga no persigue y
		# que `pared.hay_pared` se pone a true sobre el coloso. Ninguna de esas
		# nueve comprobaciones mira si los tres se VEN como lo que son: un
		# embestidor bajo y ancho, un volador pequeno en el aire y un coloso de
		# siete metros. Escala relativa, silueta y color solo los caza una imagen.
		_toma("corral_enemigos", Vector3.ZERO, Vector3.ZERO,
			func() -> void:
				_montar_corral()
				# En la fila, no delante: sirve de REGLA. Sin un cuerpo conocido
				# al lado, "el coloso es grande" no es una medida de nada.
				_situar(CORRAL + Vector3(-3.0, 0.05, 0.0)),
			func() -> void: _montar_corral(),
			func() -> void: _encuadrar_corral()),

		# EL COLOSO ESCALADO. La toma que mas falta hacia de las tres: el funcional
		# se conforma con un booleano del sensor de pared, y ese booleano vale
		# igual con el cuerpo pegado al torso que con la capsula metida dentro de
		# la del coloso o el personaje colgando en horizontal. Aqui se ve.
		_toma("coloso_escalada", Vector3.ZERO, Vector3.ZERO,
			func() -> void:
				_montar_corral()
				_ante_coloso(),
			func() -> void:
				_montar_corral()
				_ante_coloso(),
			func() -> void: _encuadrar_coloso()),

		# LA ALTURA DEL VOLADOR, con el jugador en el suelo y en el mismo encuadre.
		# Es una toma de MEDIDA: fija en una imagen la distancia vertical que hoy
		# lo hace inalcanzable. El dia que se toque `altura_vuelo` o el punto al
		# que se ancla, esta referencia lo va a ensenar en rojo, que es justo lo
		# que se quiere de un cambio asi.
		_toma("volador_alcance", Vector3.ZERO, Vector3.ZERO,
			func() -> void: _montar_alcance(),
			func() -> void: _montar_alcance(),
			func() -> void: _encuadrar_volador()),
	]


func _tick() -> void:
	if _i >= _tomas.size():
		return
	_f += 1
	var t: Dictionary = _tomas[_i]
	if _f == 1:
		# Toda toma empieza con el jugador procesando: alguna lo congela al final
		# para fijar la pose, y ese congelado no puede sobrevivir a la siguiente.
		_p.set_physics_process(true)
		_pose = 0
		# La lanza vuelve a la mano al empezar CADA toma. La del cordon la deja
		# clavada, y con ella clavada el cordon cruza el resto de encuadres de
		# punta a punta: el jugador se teletransporta al corral y la cuerda le
		# sigue desde treinta metros.
		var l: Spear = _p.get("lanza")
		if l != null and is_instance_valid(l):
			l.fsm.cambiar(&"Wielded")
		(t["preparar"] as Callable).call()
		if t.has("encuadre"):
			(t["encuadre"] as Callable).call()
		else:
			_cam.global_position = t["cam"]
			_cam.look_at(t["mira"], Vector3.UP)
		return
	if _f < REPOSO:
		# Reafirmar el estado cada frame: la FSM puede sacarnos de el por su cuenta
		# —caerse, soltarse del muro— y la referencia dejaria de significar nada.
		if t.has("sostener"):
			(t["sostener"] as Callable).call()
		return
	_procesar(t)
	_i += 1
	_f = 0
	if _i >= _tomas.size():
		_informe()


func _procesar(t: Dictionary) -> void:
	var img := get_viewport().get_texture().get_image()
	var nombre: String = t["nombre"]
	var ruta := "res://tools/baseline/%s.png" % nombre

	if _actualizar or not FileAccess.file_exists(ruta):
		img.save_png(ruta)
		_nuevas.append(nombre)
		return

	var base := Image.load_from_file(ruta)
	if base == null:
		_fallos.append("%-22s no se pudo leer la referencia" % nombre)
		return
	if base.get_width() != img.get_width() or base.get_height() != img.get_height():
		_fallos.append("%-22s la referencia mide %dx%d y la captura %dx%d. Corre siempre con la misma --resolution." % [
			nombre, base.get_width(), base.get_height(), img.get_width(), img.get_height()])
		return

	var distintos := _comparar(base, img, nombre)
	var total := img.get_width() * img.get_height()
	var pct := float(distintos) / float(total)
	if pct > TOLERANCIA_PCT:
		img.save_png("user://visual/%s_actual.png" % nombre)
		_fallos.append("%-22s %.2f%% de pixeles distintos (tope %.2f%%)" % [
			nombre, pct * 100.0, TOLERANCIA_PCT * 100.0])
	else:
		print("  OK    %-22s %.3f%% distinto" % [nombre, pct * 100.0])


## Cuenta pixeles distintos y deja un mapa del diff: el numero dice CUANTO ha
## cambiado, pero solo la imagen dice DONDE.
func _comparar(base: Image, actual: Image, nombre: String) -> int:
	var w := actual.get_width()
	var h := actual.get_height()
	var diff := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	var n := 0
	for y in h:
		for x in w:
			var a := base.get_pixel(x, y)
			var b := actual.get_pixel(x, y)
			var d: float = maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))
			if d * 255.0 > float(TOLERANCIA_CANAL):
				n += 1
				diff.set_pixel(x, y, Color.RED)
			else:
				diff.set_pixel(x, y, Color(a.r * 0.25, a.g * 0.25, a.b * 0.25))
	if n > 0:
		diff.save_png("user://visual/%s_diff.png" % nombre)
	return n


func _informe() -> void:
	if not _nuevas.is_empty():
		print("\n--- REFERENCIAS %s ---" % ("REGENERADAS" if _actualizar else "CREADAS"))
		for n in _nuevas:
			print("  +  tools/baseline/%s.png" % n)
		print("  Miralas antes de commitearlas: son el contrato visual del proyecto.")
	print("\nRESULTADO VISUAL: %d/%d tomas." % [_tomas.size() - _fallos.size(), _tomas.size()])
	if not _fallos.is_empty():
		print("--- FALLOS ---")
		for f in _fallos:
			print("  " + f)
		print("  Mapas de diff en: %s" % ProjectSettings.globalize_path("user://visual/"))
	get_tree().quit(1 if not _fallos.is_empty() else 0)


# --- Utilidades ---------------------------------------------------------------

func _toma(nombre: String, cam: Vector3, mira: Vector3, preparar: Callable,
		sostener: Callable = Callable(), encuadre: Callable = Callable()) -> Dictionary:
	var d := {"nombre": nombre, "cam": cam, "mira": mira, "preparar": preparar}
	if sostener.is_valid():
		d["sostener"] = sostener
	if encuadre.is_valid():
		d["encuadre"] = encuadre
	return d


## Camara de frente y por debajo del jugador, mirando hacia arriba. Es el unico
## angulo que sirve para las rampas: estan a 3.4 m unas de otras y miden 2.6 de
## ancho, asi que una camara lateral acaba dentro de la rampa vecina. Y de frente
## la inclinacion del cuerpo se lee contra el cielo, que es lo que se quiere ver.
func _encuadrar_jugador() -> void:
	var pos := _p.global_position
	_cam.global_position = pos + Vector3(0.0, -0.5, -4.0)
	_cam.look_at(pos + Vector3(0.0, 0.9, 0.0), Vector3.UP)


func _situar(pos: Vector3) -> void:
	_p.global_position = pos
	_p.set("velocity", Vector3.ZERO)
	_estado(&"Idle")


func _estado(nombre: StringName) -> void:
	var fsm: Variant = _p.get("fsm")
	if fsm != null:
		fsm.cambiar(nombre)


## Coloca al jugador apoyado contra la rampa de `angulo` del Gym y lo engancha.
## Misma geometria deducida que usa `test_fase2.gd`: contra una pendiente los pies
## quedan por delante del pecho, y colocarse "a ojo" no vale.
func _ante_rampa(angulo: float) -> void:
	var angulos := PackedFloat32Array([30.0, 40.0, 44.0, 45.0, 50.0, 60.0, 75.0, 90.0, 110.0])
	var i := 0
	for j in angulos.size():
		if is_equal_approx(angulos[j], angulo):
			i = j
			break
	var a := deg_to_rad(angulo)
	var radio := 0.35
	var centro_y := 3.0
	var z := -30.0 - radio * sin(a)
	if absf(angulo - 90.0) > 0.1:
		z += (centro_y - radio * cos(a)) / tan(a)
	_p.global_position = Vector3(-33.0 + 3.4 * float(i), centro_y - radio, z)
	_p.set("velocity", Vector3.ZERO)
	_estado(&"Climb")


# --- El corral del 3.03 -------------------------------------------------------

## Planta a los tres enemigos en reposo y los CONGELA.
##
## Congelarlos no es comodidad, es la unica forma de que la toma signifique algo:
## con su FSM viva el embestidor te ve y carga, el volador se coloca sobre tu
## cabeza y dispara, y el coloso camina. Dos capturas del mismo encuadre no
## coincidirian nunca y la referencia seria ruido.
##
## Y se PLANTAN en una posicion explicita en vez de fotografiarlos donde nacen,
## porque donde nacen no es donde reposan: el coloso aparece con los pies 1.1 m
## por encima del suelo y cae durante los primeros frames. Fotografiarlo "tal
## cual sale" daria una imagen distinta segun cuando dispares.
func _montar_corral() -> void:
	# EN FILA, y no donde los pone el Gym. En el corral real el coloso esta
	# adelantado y tapa a los otros dos desde cualquier angulo util —el rincon
	# esta encajonado entre los muros de 9 m de la piscina y los del wall-run—.
	# Puestos en linea, la toma hace lo unico que se le pide: comparar las tres
	# siluetas de un vistazo. La disposicion REAL del corral ya la fotografia
	# `gym_general`.
	#
	# La Y esta calculada, no puesta a ojo: el collider de cada enemigo cuelga a
	# +1 de su origen, asi que el origen que deja los pies en el suelo es
	# `altura / 2 - 1`.
	_plantar("Embestidor", CORRAL + Vector3(-6.0, 0.1, 0.0))
	_plantar("ColosoMediano", CORRAL + Vector3(0.0, 2.5, 0.0))
	_plantar("Volador", CORRAL + Vector3(5.5, 4.0, 0.0))


func _plantar(nombre: String, pos: Vector3) -> void:
	var e := _enemigo(nombre)
	if e == null:
		return
	e.set_physics_process(false)
	e.global_position = pos
	# El yaw tambien: `encarar()` los gira hacia el jugador, y una capsula girada
	# se fotografia distinta por la marca del frente.
	e.rotation = Vector3.ZERO
	e.set("velocity", Vector3.ZERO)


## `owned = false` es obligatorio: el Gym los instancia por codigo, asi que no
## tienen owner y la busqueda por defecto no los encuentra.
func _enemigo(nombre: String) -> Node3D:
	return _main.find_child(nombre, true, false) as Node3D


## Pega al jugador al torso del coloso y lo engancha. El desfase es el mismo que
## usa `test_enemigos.gd` para su comprobacion de agarre, y sale del cuerpo y no
## de coordenadas escritas a mano: media altura y algo mas que el radio de su
## capsula, por la cara +Z.
func _ante_coloso() -> void:
	var c := _enemigo("ColosoMediano")
	if c == null:
		return
	# A la altura del CENTRO de la capsula (origen +1), que es donde su pared es
	# un cilindro y la normal sale horizontal. Mas abajo se entra en el casquete
	# inferior, donde la normal apunta hacia abajo y el cuerpo se inclina como si
	# estuviera colgando del techo: una pose real, pero no la que se quiere fijar
	# como referencia de "escalar un torso".
	# Se deja correr un rato y DESPUES se congela. Inclinar el cuerpo contra la
	# normal es trabajo de la FSM, no del test —calcularlo aqui a mano seria
	# duplicar el juego y la referencia dejaria de comprobar nada—; pero una vez
	# resuelta la pose hay que fijarla, porque `escalada_adherencia` empuja contra
	# la superficie en CADA paso de fisica y cuantos pasos caben entre dos frames
	# de render no es determinista. Sin congelar, la toma bailaba al 0.38% con el
	# tope en 0.40: habria acabado dando rojos que no son bugs.
	_pose += 1
	_p.global_position = c.global_position + Vector3(0.0, 1.0, 2.5)
	_p.set("velocity", Vector3.ZERO)
	if _pose > 30:
		# Recolocar y congelar EN EL MISMO frame, en este orden. Congelar antes de
		# recolocar dejaba la pose donde la hubiera dejado el ultimo paso de
		# fisica, y la toma salia bimodal: 0.000% o 0.360% segun la pasada.
		_p.set_physics_process(false)
		return
	# ENCARARLO, y no es un detalle cosmetico: el `WallSensor` sondea hacia
	# `direccion_frontal()`, que sin velocidad devuelve la Z del visual. Colocado
	# sin girar, el jugador sondeaba en direccion CONTRARIA al coloso, no
	# encontraba pared y se quedaba en `Climb` arrastrando la normal de la toma
	# anterior —la rampa de 60—. La foto salia con una pose inclinada creible y
	# completamente falsa: el peor resultado posible en un test de referencia.
	_p.call("orientar_a", c.global_position - _p.global_position)
	_estado(&"Climb")


## Pone al jugador en el suelo y al volador a su altura de vuelo REAL encima,
## leyendo `altura_vuelo` del propio nodo en vez de escribir un numero. Asi la
## toma documenta el valor que este configurado: el dia que se toque, o que se
## deje de anclar a la Y del jugador, la referencia sale en rojo. Que es
## exactamente lo que se quiere de un cambio asi.
func _montar_alcance() -> void:
	_montar_corral()
	var v := _enemigo("Volador")
	if v == null:
		return
	var suelo := CORRAL + Vector3(5.5, 0.05, 0.0)
	_p.global_position = suelo
	_p.set("velocity", Vector3.ZERO)
	_estado(&"Idle")
	var alt: Variant = v.get("altura_vuelo")
	v.global_position = suelo + Vector3.UP * (alt if alt is float else 4.5)


## Tres cuartos desde arriba: es el unico angulo en el que los tres caben sin
## taparse entre ellos y en el que la diferencia de tamano se lee de un vistazo.
func _encuadrar_corral() -> void:
	# De frente y desde el sur, que es el unico eje despejado: al este estan los
	# muros de 9 m de la piscina (x ~18.5) y al oeste los del wall-run (x ~2).
	_cam.global_position = CORRAL + Vector3(0.0, 6.0, 11.0)
	_cam.look_at(CORRAL + Vector3(0.0, 3.0, 0.5), Vector3.UP)


## Desde delante y por fuera del coloso. La camara NO puede ir donde la pone
## `_encuadrar_jugador()` —cuatro metros por detras— porque ahi estaria dentro de
## la capsula de 2.2 m de radio y la toma saldria negra.
func _encuadrar_coloso() -> void:
	var c := _enemigo("ColosoMediano")
	if c == null:
		return
	_cam.global_position = c.global_position + Vector3(4.2, 1.4, 7.6)
	_cam.look_at(_p.global_position + Vector3(0.0, 0.7, 0.0), Vector3.UP)


## De perfil y a media altura entre los dos, para que lo que se lea sea la
## SEPARACION vertical y no cada uno por su lado.
func _encuadrar_volador() -> void:
	var v := _enemigo("Volador")
	if v == null:
		return
	var medio := (v.global_position + _p.global_position) * 0.5
	# Por el sur y algo escorada. Hacia el este no se puede: a x ~18.5 empiezan
	# los muros de 9 m de la piscina y la camara acaba DENTRO, mirando su pared.
	_cam.global_position = medio + Vector3(-3.5, 0.5, 9.0)
	_cam.look_at(medio, Vector3.UP)


# --- El cordon ----------------------------------------------------------------

## Punto desde el que se tira, delante del muro de la lanza del Gym.
const ANTE_MURO := Vector3(0.0, 0.05, 33.0)


func _tender_cordon() -> void:
	_situar(ANTE_MURO)
	var l: Spear = _p.get("lanza")
	if l == null:
		return
	# Un poco hacia arriba, para que se clave a media altura del muro y el cordon
	# tenga caida que ensenar. Clavada a ras de suelo la cuerda seria una recta.
	l.fsm.cambiar(&"Wielded")
	l.lanzar(l.punto_de_mano(), Vector3(0.0, 0.30, -1.0).normalized())


## El jugador se queda quieto: los DOS extremos tienen que estar parados para que
## el verlet llegue a su reposo. Con uno moviendose la cuerda nunca se asienta y
## la referencia baila.
func _sostener_cordon() -> void:
	_p.global_position = ANTE_MURO
	_p.set("velocity", Vector3.ZERO)
	# Al reposo a mano en cuanto se clava. Dejar que se asiente sola depende de
	# cuanto tiempo real pase, y eso cambia con la maquina: la toma bailaba entre
	# 0.36% y 0.54% con el tope en 0.40.
	var l: Spear = _p.get("lanza")
	if l != null and is_instance_valid(l) and l.clavada_en_algo():
		l.cordon.asentar()


func _encuadrar_cordon() -> void:
	var l: Spear = _p.get("lanza")
	if l == null:
		_cam.global_position = ANTE_MURO + Vector3(7.0, 3.0, 6.0)
		_cam.look_at(ANTE_MURO, Vector3.UP)
		return
	# De lado y con los dos extremos dentro: lo que se fotografia es la CURVA.
	var medio := (_p.global_position + l.global_position) * 0.5
	_cam.global_position = medio + Vector3(6.5, 1.6, 3.2)
	_cam.look_at(medio, Vector3.UP)
