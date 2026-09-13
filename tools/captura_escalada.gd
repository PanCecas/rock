extends Node
## CAPTURAS DEL CANDADO DE ESCALADA. Necesita GPU:
##
##   godot --path . --resolution 1280x720 tools/CapturaEscalada.tscn
##
## Fotografía el mismo gesto contra el mismo muro **con la habilidad puesta y sin
## ella**, que es la única forma de ver que el candado apaga algo. Con el panel de
## debug encendido, para leer el número y la imagen juntos.
##
## Y una tercera: rozar un muro a 26 m/s. Es la que vigila que nadie vuelva a
## escribir `motor.impulso()` en un estado de pared — esa llamada reemplaza el
## vector horizontal entero y convertía un roce en un frenazo.
##
## Los archivos van a `user://escalada/` y la ruta se imprime al terminar.

const CARPETA := "user://escalada"

var _main: Node
var _p: PlayerController
var _cam: Camera3D
var _mirar: Vector3 = Vector3.ZERO
var _hechas: PackedStringArray = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	await get_tree().physics_frame

	for n in get_tree().get_nodes_in_group(&"enemigos"):
		var e := n as Enemigo
		if e != null and is_instance_valid(e):
			e.vista = 0.0

	# El rig se apaga entero: persigue con amortiguación y recién teletransportado
	# apuntaría a donde estaba el jugador hace medio segundo.
	var rig := _main.get_node_or_null("CameraRig") as Node3D
	if rig != null:
		rig.process_mode = Node.PROCESS_MODE_DISABLED
	_cam = get_viewport().get_camera_3d()

	DebugOverlay.visible_panel = true
	await _correr()


func _correr() -> void:
	# ---- 1) CON LA HABILIDAD. El comportamiento de siempre: insistes y trepas.
	#         La pared escalable del Gym está en (24, 6, 20), con la cara en
	#         z = 19.5 y catorce metros de ancho.
	_situar(Vector3(24.0, 0.05, 21.2), true)
	_camara(Vector3(33.0, 6.5, 27.0), Vector3(24.0, 4.0, 20.0))
	Input.action_press(&"move_forward")
	await _frames(70)
	await _foto("01_con_habilidad_trepa")
	Input.action_release(&"move_forward")
	await _frames(10)

	# ---- 2) SIN LA HABILIDAD. Mismo muro, misma insistencia, mismo encuadre. La
	#         pared vuelve a ser un sitio del que rebotar en vez de un sitio donde
	#         se te acaba la línea.
	_situar(Vector3(24.0, 0.05, 21.2), false)
	_camara(Vector3(33.0, 6.5, 27.0), Vector3(24.0, 4.0, 20.0))
	Input.action_press(&"move_forward")
	await _frames(70)
	await _foto("02_sin_habilidad_no_trepa")
	Input.action_release(&"move_forward")
	await _frames(10)

	# ---- 3) EL ROCE. El corredor de wall-run: dos muros de 24 m a x = ±1.3, sin
	#         suelo cerca. Se llega casi paralelo, que es lo que hace un roce, y el
	#         panel tiene que seguir diciendo una rapidez alta.
	_situar(Vector3(0.0, 6.0, -24.0), false)
	_p.velocity = Vector3(0.28, 0.0, -0.96).normalized() * 26.0
	_p.momentum_libre = 4.0
	_p.momentum_techo = 40.0
	_p.call("orientar_a", _p.velocity.normalized())
	_camara(Vector3(11.0, 11.0, -28.0), Vector3(0.0, 5.0, -32.0))
	await _frames(4)
	await _foto("03_antes_del_roce")
	await _frames(9)
	await _foto("04_rozando")

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


func _situar(pos: Vector3, con_habilidad: bool) -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.stamina.llenar()
	_p.momentum_libre = 0.0
	_p.recargar_moveset()
	_p.puede_escalar = con_habilidad
	_p.fsm.cambiar(&"Idle" if pos.y < 1.0 else &"Fall")
	_p.reset_physics_interpolation()
	# La cámara del rig está apagada, así que el yaw de la cámara real es lo único
	# que decide hacia dónde empuja `move_forward`: la mecánica lee
	# `player.camara()`, no la rotación del cuerpo.


func _camara(desde: Vector3, hacia: Vector3) -> void:
	_mirar = hacia
	if _cam == null:
		return
	_cam.global_position = desde
	_cam.look_at(hacia, Vector3.UP)
	_cam.reset_physics_interpolation()


func _cerrar() -> void:
	print("\n=== CAPTURAS DEL CANDADO DE ESCALADA ===")
	for n in _hechas:
		print("  %s.png" % n)
	print("  en: %s" % ProjectSettings.globalize_path(CARPETA + "/"))
	get_tree().quit(0)
