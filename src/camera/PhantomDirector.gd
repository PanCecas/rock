extends Node3D
## Puente entre la FSM del jugador y Phantom Camera.
##
## Phantom Camera funciona por PRIORIDADES: hay varias `PhantomCamera3D` en la
## escena y manda la de prioridad más alta, con el tween entre ellas resuelto por
## el plugin. Este nodo es lo único que decide cuál manda.
##
## La regla no cambia respecto al `CameraRig` propio: **el modo se deduce de la
## categoría del estado del jugador**, nunca se pide a mano. Esa decisión es buena
## y sobrevive a la migración; lo que se delega en el plugin es el trabajo sucio
## —el brazo con colisión, el tween entre encuadres, el ruido— que teníamos a
## medias y sin `dead zone`.
##
## Lo que aporta el plugin y no teníamos:
##   · `THIRD_PERSON` trae un `ShapeCast3D` de verdad: la cámara esquiva geometría
##     en vez de atravesarla, que es el problema que iba a aparecer en el primer
##     coloso.
##   · El tween entre cámaras es del plugin, con su curva. Antes era un `lerpf`
##     por parámetro y no se podía dibujar.
##   · `PhantomCameraNoise3D` da la vida sutil sin escribir un solo seno.
##
## Los parámetros viven en `CameraTuning.tres`, editable desde el inspector.

@export var tuning: CameraTuning
## NodePath y no Node: los exports tipados a Node no se resuelven al instanciar la
## escena y dejan la referencia en null sin avisar (regla dura #10).
@export var jugador_path: NodePath = ^"../Player"
@export var pcam_explorar_path: NodePath = ^"PCamExplorar"
@export var pcam_escalar_path: NodePath = ^"PCamEscalar"
@export var pcam_combate_path: NodePath = ^"PCamCombate"

## Prioridades. La activa sube; las demás se quedan abajo. No hace falta más
## resolución: son tres modos excluyentes, no una mezcla.
const PRIORIDAD_ACTIVA := 20
const PRIORIDAD_DORMIDA := 0

var _jugador: PlayerController
var _pcams: Dictionary = {}
var _modo: StringName = &"Explorar"
var _yaw: float = 0.0
var _pitch: float = -14.0
var _shake: float = 0.0
var _fov_suave: float = 0.0
var _dist_suave: float = 0.0
var _t_ruido: float = 0.0


func _ready() -> void:
	if tuning == null:
		tuning = CameraTuning.new()
	_jugador = get_node_or_null(jugador_path) as PlayerController
	_pcams = {
		&"Explorar": get_node_or_null(pcam_explorar_path),
		&"Escalar": get_node_or_null(pcam_escalar_path),
		&"Combate": get_node_or_null(pcam_combate_path),
	}
	# `follow_target` se asigna por codigo y no en la escena: el jugador es un nodo
	# hermano y una ruta guardada en el .tscn se rompe en cuanto alguien mueve el
	# arbol. Sin esto las PhantomCamera no siguen a nadie y se quedan en el origen.
	for clave in _pcams:
		var pcam := _pcams[clave] as Node3D
		if pcam != null and _jugador != null:
			pcam.set(&"follow_target", _jugador)

	EventBus.player_state_changed.connect(_on_estado_cambiado)
	EventBus.camara_shake.connect(_on_shake)
	EventBus.camara_realinear.connect(alinear_a)
	_aplicar_modo(&"Explorar")


func _process(delta: float) -> void:
	if _jugador == null:
		return

	_orbitar(delta)
	_reaccionar_a_velocidad(delta)
	_respirar(delta)
	_decaer_shake(delta)


## El stick derecho gira el nodo entero; las PhantomCamera cuelgan de él, así que
## orbitan con él sin que ninguna tenga que saber del input.
func _orbitar(delta: float) -> void:
	var stick := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if not stick.is_zero_approx():
		_yaw -= stick.x * 180.0 * delta
		_pitch -= stick.y * 130.0 * delta
	_pitch = clampf(_pitch, tuning.pitch_min, tuning.pitch_max)

	global_position = _jugador.global_position + Vector3.UP * (
		tuning.altura_objetivo * _altura_modo()
	)
	rotation_degrees = Vector3(_pitch + _shake, _yaw, 0.0)


## FOV y distancia responden a la velocidad, y la FORMA de esa respuesta la dibuja
## una `Curve` del tuning. Con la curva vacía es una rampa lineal, que es lo que
## había antes: dejarla sin tocar no cambia nada.
func _reaccionar_a_velocidad(delta: float) -> void:
	var t := 0.0
	if _jugador.motor != null:
		t = tuning.fraccion_velocidad(_jugador.motor.rapidez_plana())
	var inf := tuning.influencia_velocidad

	var fov_obj := tuning.muestrear(tuning.curva_fov, t) * tuning.fov_extra_max * inf
	var dist_obj := tuning.muestrear(tuning.curva_distancia, t) * tuning.distancia_extra_max * inf
	var f := 1.0 - exp(-3.0 * delta)
	_fov_suave = lerpf(_fov_suave, fov_obj, f)
	_dist_suave = lerpf(_dist_suave, dist_obj, f)

	var activa := _pcams.get(_modo) as Node3D
	if activa == null:
		return
	activa.set(&"fov", tuning.fov * _fov_modo() + _fov_suave)
	activa.set(&"spring_length", tuning.distancia * _dist_modo() + _dist_suave)


## VIDA. Un cabeceo lento y muy pequeño que crece con la velocidad. No usa el
## `PhantomCameraNoise3D` del plugin a propósito: aquí hace falta que la amplitud
## dependa de lo rápido que vayas, y el recurso de ruido es de amplitud fija.
##
## El listón de "sutil": si al mirarlo piensas "se mueve la cámara", sobra. Tiene
## que notarse solo al apagarlo.
func _respirar(delta: float) -> void:
	if tuning.ruido_influencia <= 0.0:
		return
	_t_ruido += delta * tuning.ruido_frecuencia * TAU

	var t := 0.0
	if _jugador.motor != null:
		t = tuning.fraccion_velocidad(_jugador.motor.rapidez_plana())
	# A `ruido_por_velocidad` = 0 el ruido es constante; a 1 la camara se agita al
	# correr y se calma al pararse, que es lo que la hace sentir viva y no solo
	# temblorosa.
	var escala: float = lerpf(1.0, 0.35 + t, tuning.ruido_por_velocidad)
	var amplitud := tuning.ruido_grados * tuning.ruido_influencia * escala

	# Dos senos de periodo distinto: uno solo se lee como un péndulo mecánico.
	var activa := _pcams.get(_modo) as Node3D
	if activa == null:
		return
	activa.rotation_degrees = Vector3(
		sin(_t_ruido) * amplitud,
		sin(_t_ruido * 0.73) * amplitud * 1.3,
		sin(_t_ruido * 0.41) * amplitud * 0.5
	)


func _decaer_shake(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - tuning.shake_decaimiento * delta)


func _on_shake(intensidad: float, _duracion: float) -> void:
	_shake = maxf(_shake, intensidad * tuning.shake_influencia)


## El modo se DEDUCE del estado, no se pide. Misma regla que el rig anterior.
func _on_estado_cambiado(_anterior: StringName, _nuevo: StringName) -> void:
	if _jugador == null or _jugador.fsm == null or _jugador.fsm.actual == null:
		return
	var cat: StringName = _jugador.fsm.actual.categoria
	if cat == &"Attached":
		_aplicar_modo(&"Escalar")
	elif cat == &"Combat" or (_jugador.targeting != null and _jugador.targeting.objetivo() != null):
		_aplicar_modo(&"Combate")
	else:
		_aplicar_modo(&"Explorar")


## Subir la prioridad de una y bajar las otras. El tween entre encuadres lo hace
## Phantom Camera con la curva de su `PhantomCameraTween`.
func _aplicar_modo(nuevo: StringName) -> void:
	if _modo == nuevo:
		return
	_modo = nuevo
	for clave in _pcams:
		var pcam := _pcams[clave] as Node3D
		if pcam == null:
			continue
		pcam.set(&"priority", PRIORIDAD_ACTIVA if clave == nuevo else PRIORIDAD_DORMIDA)
	DebugOverlay.set_line("cámara", _modo)


func _dist_modo() -> float:
	match _modo:
		&"Escalar": return tuning.escalar_dist
		&"Combate": return tuning.combate_dist
		_: return tuning.explorar_dist


func _altura_modo() -> float:
	match _modo:
		&"Escalar": return tuning.escalar_altura
		&"Combate": return tuning.combate_altura
		_: return tuning.explorar_altura


func _fov_modo() -> float:
	return tuning.combate_fov if _modo == &"Combate" else 1.0


## Pide que la cámara se coloque detrás de una dirección de mundo. Lo usa el
## wall-jump: sin esto acabas volando de espaldas a donde miras.
func alinear_a(direccion: Vector3, fuerza: float) -> void:
	var d := direccion
	d.y = 0.0
	if d.is_zero_approx() or fuerza <= 0.0:
		return
	var objetivo := rad_to_deg(atan2(d.x, d.z)) + 180.0
	_yaw = lerp_angle(deg_to_rad(_yaw), deg_to_rad(objetivo), clampf(fuerza, 0.0, 1.0))
	_yaw = rad_to_deg(_yaw)
