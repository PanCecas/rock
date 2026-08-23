class_name CameraRig
extends Node3D
## FASE 0 — PROVISIONAL.
##
## Órbita con ratón/stick y resolución de colisión por SpringArm3D. Suficiente
## para recorrer el Gym. La FASE 1 lo amplía con los modos apilables
## (Explore / Combat / Climb / Colossus / Aim) de docs/03_ARQUITECTURA_MECANICAS.md §7.

## NodePath y no Node: los exports tipados a Node no se resuelven al instanciar
## la escena, y el rig se quedaba clavado en el origen sin seguir a nadie.
@export var objetivo_path: NodePath = ^"../Player"
@export var tuning: PlayerTuning

var objetivo: Node3D

@onready var brazo: SpringArm3D = $Brazo
@onready var camara: Camera3D = $Brazo/Camara

var _yaw: float = 0.0
var _pitch: float = -12.0
var _pos_suave: Vector3


func _ready() -> void:
	objetivo = get_node_or_null(objetivo_path) as Node3D
	if objetivo == null:
		push_warning("CameraRig sin objetivo en %s" % objetivo_path)
	if tuning == null:
		tuning = GameState.tuning
	EventBus.tuning_reloaded.connect(func() -> void: tuning = GameState.tuning)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	brazo.spring_length = tuning.camara_distancia
	brazo.collision_mask = Layers.CAMARA
	brazo.margin = 0.35
	camara.fov = tuning.camara_fov
	if objetivo != null:
		_pos_suave = objetivo.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * tuning.camara_sensibilidad
		_pitch -= mm.relative.y * tuning.camara_sensibilidad
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			Input.mouse_mode = (
				Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
				else Input.MOUSE_MODE_CAPTURED
			)


func _process(delta: float) -> void:
	if objetivo == null:
		return

	# Stick derecho del mando.
	var stick := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if not stick.is_zero_approx():
		_yaw -= stick.x * 180.0 * delta
		_pitch -= stick.y * 130.0 * delta

	_pitch = clampf(_pitch, tuning.camara_pitch_min, tuning.camara_pitch_max)

	# Seguimiento amortiguado, independiente del framerate.
	var deseado := objetivo.global_position + Vector3.UP * tuning.camara_altura_objetivo
	var factor := 1.0 - exp(-delta / maxf(tuning.camara_suavizado, 0.001))
	_pos_suave = _pos_suave.lerp(deseado, factor)

	global_position = _pos_suave
	rotation_degrees = Vector3(0.0, _yaw, 0.0)
	brazo.rotation_degrees = Vector3(_pitch, 0.0, 0.0)
	brazo.spring_length = tuning.camara_distancia
	camara.fov = tuning.camara_fov
