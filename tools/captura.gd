extends SceneTree
## Carga Main.tscn, deja que se asiente y guarda una captura. Para revisar el
## look sin abrir el editor:  godot --path . --script tools/captura.gd

const DESTINO := "user://captura_fase0.png"
var _f := 0

func _initialize() -> void:
	root.add_child(load("res://content/levels/Main.tscn").instantiate())
	RenderingServer.frame_post_draw.connect(_tick)

func _tick() -> void:
	_f += 1
	if _f != 60:
		return
	var img := root.get_texture().get_image()
	img.save_png(DESTINO)
	print("captura -> %s (%dx%d)" % [ProjectSettings.globalize_path(DESTINO), img.get_width(), img.get_height()])
	quit()
