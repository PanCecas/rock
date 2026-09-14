extends Node
## CAPTURAS DE LA PATADA. Necesita GPU:
##
##   godot --path . --resolution 1280x720 tools/CapturaPatada.tscn
##
## Fotografía los momentos que deciden si el gesto se siente bien, con el panel de
## debug puesto para que el número y la imagen se lean juntos. Los archivos van a
## `user://patada/` y la ruta se imprime al terminar.
##
## No sustituye a `MedirPatada` —los números son los que afirman— pero un número
## no dice si el personaje sale por donde parecía que iba a salir, y eso solo se
## ve mirando.
##
## **El guion es una corrutina, no una máquina de pasos en `_physics_process`.**
## La primera versión guardaba el PNG con un `await` suelto dentro del tick, así
## que el archivo se escribía UN PASO TARDE: la foto llamada "durante la patada"
## salía con el jugador ya colocado para la toma siguiente. Con `await` en línea,
## cada foto es del frame que dice su nombre.

const CARPETA := "user://patada"

var _main: Node
var _p: PlayerController
var _victima: Enemigo
var _cam: Camera3D
var _mirar: Vector3 = Vector3.ZERO
var _hechas: PackedStringArray = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	await get_tree().physics_frame

	# Enemigos ciegos: lo que se fotografía es el gesto del jugador, no una pelea.
	for n in get_tree().get_nodes_in_group(&"enemigos"):
		var e := n as Enemigo
		if e != null and is_instance_valid(e):
			e.vista = 0.0

	# El rig se apaga entero. Persigue con amortiguación, así que recién
	# teletransportado apuntaría a donde estaba el jugador hace medio segundo.
	var rig := _main.get_node_or_null("CameraRig") as Node3D
	if rig != null:
		rig.process_mode = Node.PROCESS_MODE_DISABLED
	_cam = get_viewport().get_camera_3d()

	DebugOverlay.visible_panel = true
	await _correr()


func _correr() -> void:
	# ---- 1) LANZADO. La foto que importa: el panel tiene que decir una rapidez
	#         MAYOR que `patada_velocidad`, porque la patada es un suelo y no un
	#         valor. Antes del arreglo aquí ponía 18.0 viniera como viniera.
	_situar(Vector3(-8.0, 3.4, 6.0), 30.0)
	_camara(Vector3(-1.0, 10.0, 20.0), Vector3(-1.0, 3.2, 6.0))
	await _frames(6)
	await _foto("01_lanzado_antes")
	_patear()
	await _frames(8)
	await _foto("02_lanzado_durante")
	await _frames(30)

	# ---- 2) CONTRA UN ENEMIGO: el impacto y el rebote, que es lo que convierte
	#         al enemigo en plataforma. Antes del arreglo, conectar te dejaba a
	#         vertical cero y de largo.
	_plantar_victima(Vector3(5.5, 0.3, 6.0))
	_situar(Vector3(0.0, 1.1, 6.0), 6.0)
	_p.call("orientar_a", Vector3.RIGHT)
	_camara(Vector3(3.0, 7.0, 19.0), Vector3(3.0, 2.0, 6.0))
	await _frames(6)
	await _foto("03_hacia_el_enemigo")
	_patear()
	await _frames(8)
	await _foto("04_impacto")
	# EL PICO DEL REBOTE, no un rato despues. Con `patada_rebote` a 10 m/s y
	# `patada_hangtime` a 0.14 s, el punto alto cae sobre el frame 24: 1.4 m de
	# hangtime mas 1.3 m de subida. Fotografiarlo a los 13 pillaba al jugador ya
	# aterrizado y la foto decia justo lo contrario de lo que pasa.
	await _frames(20)
	await _foto("05_rebote")
	await _frames(20)

	# ---- 3) LA CADENA, que es el criterio de exito: colgado del ancla y con los
	#         gizmos puestos —el radio del arco y el ancla candidata— para que se
	#         vea de dónde cuelga.
	DebugDraw.activo = true
	if _victima != null and is_instance_valid(_victima):
		_victima.queue_free()
	_situar(Vector3(16.0, 5.0, 26.0), 0.0)
	# Desde detrás y por debajo: el cono de cámara es parte de la mecánica, así que
	# la foto tiene que estar MIRANDO el ancla o no engancharía.
	_camara(Vector3(25.0, 8.5, 14.0), Vector3(16.0, 11.2, 34.0))
	await _frames(6)
	await _foto("06_antes_de_engancharse")
	_pulsar(&"rope", 4)
	await _frames(26)
	await _foto("07_en_el_arco")
	_patear()
	await _frames(8)
	await _foto("08_patada_desde_el_arco")

	_cerrar()


# --- Utilidades ---------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		if _cam != null:
			_cam.look_at(_mirar, Vector3.UP)
		await get_tree().physics_frame


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [CARPETA, nombre])
	_hechas.append(nombre)


func _situar(pos: Vector3, rapidez: float) -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
	_p.global_position = pos
	_p.velocity = Vector3.RIGHT * rapidez
	_p.stamina.llenar()
	# El permiso de momentum abierto a mano: sin él el clamp global (22) recortaría
	# los 30 antes de que la patada pudiera heredarlos, y la foto mentiría.
	_p.recargar_moveset()
	_p.fsm.cambiar(&"Fall")
	_p.reset_physics_interpolation()


func _camara(desde: Vector3, hacia: Vector3) -> void:
	_mirar = hacia
	if _cam == null:
		return
	_cam.global_position = desde
	_cam.look_at(hacia, Vector3.UP)
	_cam.reset_physics_interpolation()


func _patear() -> void:
	# EL ESPACIO, no el click: desde el 4.06 la patada solo cuelga del salto
	# y `attack_light` es de la espada.
	_pulsar(&"jump", 4)


## Mantiene una acción pulsada unos frames y la suelta sola. El buffer es el único
## camino del input (regla dura #4), así que aquí se pulsa la TECLA.
func _pulsar(accion: StringName, frames: int) -> void:
	Input.action_press(accion)
	get_tree().create_timer(frames / 60.0).timeout.connect(
		func() -> void: Input.action_release(accion))


func _plantar_victima(pos: Vector3) -> void:
	if _victima != null and is_instance_valid(_victima):
		_victima.queue_free()
	_victima = load("res://src/enemies/Guardian.tscn").instantiate() as Enemigo
	_main.add_child(_victima)
	_victima.global_position = pos
	_victima.vista = 0.0
	_victima.ataque = null


func _cerrar() -> void:
	print("\n=== CAPTURAS DE LA PATADA ===")
	for n in _hechas:
		print("  %s.png" % n)
	print("  en: %s" % ProjectSettings.globalize_path(CARPETA + "/"))
	get_tree().quit(0)
