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
	]


func _tick() -> void:
	if _i >= _tomas.size():
		return
	_f += 1
	var t: Dictionary = _tomas[_i]
	if _f == 1:
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
