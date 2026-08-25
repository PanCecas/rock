class_name CameraRig
extends Node3D
## Cámara con modos apilables. Fase 1 implementa Explore y Climb; la Fase 2 añade
## Combat y la Fase 4 el modo Colossus con su FramingDirector.
##
## El modo no se elige a mano: se deduce de la categoría del estado del jugador.
## Ver docs/03_ARQUITECTURA_MECANICAS.md §7.

## NodePath y no Node: los exports tipados a Node no se resuelven al instanciar
## la escena, y el rig se quedaba clavado en el origen sin seguir a nadie.
@export var objetivo_path: NodePath = ^"../Player"
@export var tuning: PlayerTuning

## Parámetros por modo. Se interpolan, nunca se aplican de golpe.
const MODOS := {
	&"Explore": {"dist": 1.0, "altura": 1.0, "fov": 1.0, "suave": 1.0, "pitch_min": -65.0},
	# Escalando la cámara se acerca y se pega a la superficie: se necesita ver el
	# relieve inmediato, no el paisaje.
	&"Climb": {"dist": 0.62, "altura": 1.25, "fov": 0.92, "suave": 0.6, "pitch_min": -75.0},
	# Peleando la camara baja y se acerca: encuadra a los dos cuerpos y hace el
	# combate legible. Mas FOV para que no se pierda lo que entra por los lados.
	&"Combat": {"dist": 0.88, "altura": 1.15, "fov": 1.06, "suave": 0.75, "pitch_min": -55.0},
	# PRIMERA PERSONA: el brazo se recoge del todo y la camara sube a la altura de
	# los ojos. No hace falta una segunda camara ni una escena aparte —el modo ya
	# se interpola, asi que la entrada y la salida salen suavizadas gratis, que es
	# justo lo que pide una transicion a primera persona.
	&"Primera": {"dist": 0.0, "altura": 1.42, "fov": 1.22, "suave": 0.28, "pitch_min": -80.0},
}

var objetivo: Node3D
var modo: StringName = &"Explore"

@onready var brazo: SpringArm3D = $Brazo
@onready var camara: Camera3D = $Brazo/Camara

var _yaw: float = 0.0
var _pitch: float = -14.0
var _pos_suave: Vector3
var _p: Dictionary = {}
var _fov_extra: float = 0.0
var _jugador: PlayerController
var _yaw_objetivo: float = 0.0
var _realinea: float = 0.0
var _shake: float = 0.0
var _shake_decaimiento: float = 1.0


func _ready() -> void:
	objetivo = get_node_or_null(objetivo_path) as Node3D
	_jugador = objetivo as PlayerController
	if objetivo == null:
		push_warning("CameraRig sin objetivo en %s" % objetivo_path)
	if tuning == null:
		tuning = GameState.tuning
	EventBus.tuning_reloaded.connect(func() -> void: tuning = GameState.tuning)
	EventBus.player_state_changed.connect(_on_estado_cambiado)
	EventBus.camara_realinear.connect(alinear_a)
	EventBus.camara_shake.connect(sacudir)

	_p = (MODOS[&"Explore"] as Dictionary).duplicate()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	brazo.collision_mask = Layers.CAMARA
	brazo.margin = 0.35
	if objetivo != null:
		_pos_suave = objetivo.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * tuning.camara_sensibilidad
		_pitch -= mm.relative.y * tuning.camara_sensibilidad
		# Tocar el ratón cancela el realineado: la cámara nunca pelea con el jugador.
		if absf(mm.relative.x) > 1.0:
			_realinea = 0.0
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			Input.mouse_mode = (
				Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
				else Input.MOUSE_MODE_CAPTURED
			)


func _process(delta: float) -> void:
	if objetivo == null:
		return

	var stick := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if not stick.is_zero_approx():
		_yaw -= stick.x * 180.0 * delta
		_pitch -= stick.y * 130.0 * delta
		if absf(stick.x) > 0.3:
			_realinea = 0.0

	_aplicar_realineado(delta)
	_interpolar_modo(delta)
	_pitch = clampf(_pitch, float(_p["pitch_min"]), tuning.camara_pitch_max)

	# Seguimiento amortiguado e independiente del framerate.
	var deseado := objetivo.global_position + Vector3.UP * (tuning.camara_altura_objetivo * float(_p["altura"]))
	var suavizado: float = maxf(tuning.camara_suavizado * float(_p["suave"]), 0.001)
	_pos_suave = _pos_suave.lerp(deseado, 1.0 - exp(-delta / suavizado))

	global_position = _pos_suave
	rotation_degrees = Vector3(0.0, _yaw, 0.0)
	# La sacudida se suma DESPUES del encuadre y solo a la rotacion: mover la
	# posicion de la camara atraviesa geometria y marea mas de lo que aporta.
	var s_x := 0.0
	var s_y := 0.0
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - _shake_decaimiento * delta)
		var a := randf() * TAU
		s_x = cos(a) * _shake
		s_y = sin(a) * _shake
	brazo.rotation_degrees = Vector3(_pitch + s_x, s_y, 0.0)
	brazo.spring_length = tuning.camara_distancia * float(_p["dist"])

	# Un punto de FOV por cada 4 m/s por encima de la carrera. Es sutil a propósito:
	# el objetivo es notar la velocidad, no marear.
	var exceso := 0.0
	if _jugador != null and _jugador.motor != null:
		exceso = maxf(0.0, _jugador.motor.rapidez_plana() - tuning.velocidad_correr)
	_fov_extra = lerpf(_fov_extra, minf(exceso * 0.25, 9.0), 1.0 - exp(-3.0 * delta))
	camara.fov = tuning.camara_fov * float(_p["fov"]) + _fov_extra


## Pide que la cámara se coloque detrás de una dirección de mundo.
## Lo usa el wall-jump: sin esto acabas volando de espaldas a donde miras y
## encadenar el siguiente muro es a ciegas.
func alinear_a(direccion: Vector3, fuerza: float) -> void:
	var d := Vector3(direccion.x, 0.0, direccion.z)
	if d.length_squared() < 0.04 or fuerza <= 0.0:
		return
	d = d.normalized()
	# La cámara mira a lo largo de -Z del rig, así que este es el yaw que la deja
	# apuntando hacia `d`.
	_yaw_objetivo = rad_to_deg(atan2(-d.x, -d.z))
	_realinea = clampf(fuerza, 0.0, 1.0)


func _aplicar_realineado(delta: float) -> void:
	if _realinea <= 0.0:
		return
	# Por el camino corto: girar 350° cuando bastan 10 marea.
	var diferencia := wrapf(_yaw_objetivo - _yaw, -180.0, 180.0)
	if absf(diferencia) < 0.5:
		_realinea = 0.0
		return
	_yaw += diferencia * minf(1.0, _realinea * 6.0 * delta)
	# Se agota sola: es un empujón, no un bloqueo de cámara.
	_realinea = maxf(0.0, _realinea - delta * 1.4)


## Sacudida aditiva. `intensidad` en grados.
func sacudir(intensidad: float, duracion: float) -> void:
	_shake = maxf(_shake, intensidad)
	_shake_decaimiento = intensidad / maxf(duracion, 0.01)


func _interpolar_modo(delta: float) -> void:
	var destino: Dictionary = MODOS.get(modo, MODOS[&"Explore"])
	var f := 1.0 - exp(-4.5 * delta)
	for clave in destino:
		_p[clave] = lerpf(float(_p.get(clave, destino[clave])), float(destino[clave]), f)


func _on_estado_cambiado(_anterior: StringName, _nuevo: StringName) -> void:
	if _jugador == null or _jugador.fsm == null:
		return
	# La primera persona manda sobre la categoria: es un modo que pide un ataque
	# concreto, no una consecuencia de en que grupo esta la FSM.
	if _jugador.primera_persona:
		modo = &"Primera"
		DebugOverlay.set_line("cámara", modo)
		return
	var cat: StringName = _jugador.fsm.actual.categoria
	if cat == &"Attached":
		modo = &"Climb"
	elif cat == &"Combat" or _jugador.targeting.objetivo() != null:
		modo = &"Combat"
	else:
		modo = &"Explore"
	DebugOverlay.set_line("cámara", modo)
