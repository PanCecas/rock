extends SceneTree
## Capturas sin abrir el editor:
##   godot --path . --resolution 1600x900 --script tools/captura.gd

const TOMAS := [
	{"nombre": "gym", "pos": Vector3(0, 2, 4), "yaw": 0.0},
	{"nombre": "circuito", "pos": Vector3(-70, 2, -20), "yaw": 180.0},
	{"nombre": "arena", "pos": Vector3(45, 0.5, -40), "yaw": 0.0},
]

var _main: Node
var _f := 0
var _toma := 0

func _initialize() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	root.add_child(_main)
	RenderingServer.frame_post_draw.connect(_tick)

func _tick() -> void:
	_f += 1
	if _f < 30:
		return
	if _f == 30:
		_colocar()
		return
	if _f < 50:
		return
	_guardar()
	_toma += 1
	_f = 0
	if _toma >= TOMAS.size():
		quit()

func _colocar() -> void:
	var t: Dictionary = TOMAS[_toma]
	var p := _main.get_node("Player") as Node3D
	p.global_position = t["pos"]
	p.velocity = Vector3.ZERO
	var rig := _main.get_node("CameraRig")
	rig.set("_yaw", float(t["yaw"]))
	rig.global_position = t["pos"]

func _guardar() -> void:
	var destino: String = "user://cap_%s.png" % TOMAS[_toma]["nombre"]
	root.get_texture().get_image().save_png(destino)
	print("-> %s" % ProjectSettings.globalize_path(destino))
