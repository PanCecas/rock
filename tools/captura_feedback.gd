extends Node
## LAS FOTOS DEL FEEDBACK. Necesita GPU:
##
##   godot --path . --resolution 1280x720 tools/CapturaFeedback.tscn
##
## Esto no se puede medir con un número. El moveset entero de este proyecto está
## cronometrado al frame y aun así se reportó que «no se siente que conecte»:
## **el 40% del feel no está en la física**, y esa parte solo se comprueba
## mirándola.
##
## Los momentos que deciden si esto funciona, y cada uno con su contraste al lado
## —cayendo contra aplastado, aplastado contra recuperado— porque una foto sola no
## dice si algo cambió: dice cómo se ve.
##
## **Aquí se cayó el viento.** Tenía sus dos fotos y las dos salieron vacías; ver
## eso es lo que hizo que se retirara en vez de quedarse puesto dando el problema
## por resuelto. Un banco que solo enseña lo que funciona no sirve de nada.
##
## Los archivos van a `user://feedback/` y la ruta se imprime al terminar.

const CARPETA := "user://feedback"

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
	var rig := _main.get_node_or_null("CameraRig") as Node3D
	if rig != null:
		rig.process_mode = Node.PROCESS_MODE_DISABLED
	_cam = get_viewport().get_camera_3d()
	await _correr()


func _correr() -> void:
	# ---- 1) EL APLASTADO. La foto tiene que pillar el frame del golpe: con
	#         `feedback_squash_duracion` en 0.12 s, a los 8 frames ya se ha ido
	#         media deformacion y la foto diria que no pasa nada.
	_situar(Vector3(-6.0, 6.0, 8.0), Vector3.ZERO)
	_camara(Vector3(-1.0, 2.2, 8.0), Vector3(-6.0, 1.0, 8.0))
	await _frames(4)
	await _foto("01_cayendo")
	await _caer_hasta_pisar(60)
	await _frames(2)
	await _foto("02_aplastado_al_aterrizar")
	await _frames(20)
	await _foto("03_recuperado")

	# ---- 2) LA ESTELA de la patada, que es lo que enseña la TRAYECTORIA.
	_situar(Vector3(-10.0, 3.0, 14.0), Vector3.RIGHT * 24.0)
	_p.call("orientar_a", Vector3.RIGHT)
	_camara(Vector3(-4.0, 6.5, 24.0), Vector3(-4.0, 2.5, 14.0))
	_pulsar(&"attack_light", 4)
	await _frames(11)
	await _foto("04_estela_de_la_patada")

	# ---- 3) EL POLVO DEL SLIDE, que es el verbo que mas raspa el suelo.
	_situar(Vector3(-16.0, 0.6, 0.0), Vector3.RIGHT * 14.0)
	_p.call("orientar_a", Vector3.RIGHT)
	_camara(Vector3(-11.0, 3.0, 8.0), Vector3(-12.0, 1.0, 0.0))
	await _frames(6)
	_pulsar(&"crouch", 20)
	await _frames(6)
	await _foto("05_polvo_del_slide")

	_cerrar()


# --- Utilidades ---------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		if _cam != null:
			_cam.look_at(_mirar, Vector3.UP)
		await get_tree().physics_frame


## Deja caer hasta que pise, con tope. Un `await` de N frames fijos aterrizaria en
## un frame distinto cada vez que alguien toque la gravedad.
func _caer_hasta_pisar(tope: int) -> void:
	for i in tope:
		if _cam != null:
			_cam.look_at(_mirar, Vector3.UP)
		await get_tree().physics_frame
		if _p.is_on_floor():
			return


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [CARPETA, nombre])
	_hechas.append(nombre)


func _situar(pos: Vector3, vel: Vector3) -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
	_p.global_position = pos
	_p.velocity = vel
	_p.stamina.llenar()
	_p.recargar_moveset()
	_p.recargar_aire()
	_p.fsm.cambiar(&"Fall")
	_p.reset_physics_interpolation()


func _camara(desde: Vector3, hacia: Vector3) -> void:
	_mirar = hacia
	if _cam == null:
		return
	_cam.global_position = desde
	_cam.look_at(hacia, Vector3.UP)
	_cam.reset_physics_interpolation()


func _pulsar(accion: StringName, frames: int) -> void:
	Input.action_press(accion)
	get_tree().create_timer(frames / 60.0).timeout.connect(
		func() -> void: Input.action_release(accion))


func _cerrar() -> void:
	print("\n=== LAS FOTOS DEL FEEDBACK ===")
	for n in _hechas:
		print("  %s.png" % n)
	print("  en: %s" % ProjectSettings.globalize_path(CARPETA + "/"))
	get_tree().quit(0)
