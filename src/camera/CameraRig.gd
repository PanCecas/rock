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
## Reloj del ruido de sacudida. Avanza con `camara_shake_frecuencia`, no con el
## frame: asi la sacudida se siente igual a 60 fps que a 144.
var _shake_t: float = 0.0
var _ruido := FastNoiseLite.new()
## Look ahead ya suavizado. Se guarda entre frames porque su gracia es ir por
## DETRAS de la velocidad, no seguirla.
var _adelanto_suave: Vector3 = Vector3.ZERO
## Cuanto se esta levantando el rig para no hundir la camara en el agua. Se guarda
## entre frames para que suba y baje suave en vez de dar un salto al entrar.
var _alza_agua: float = 0.0


func _ready() -> void:
	# LA CAMARA SE QUEDA FUERA DE LA INTERPOLACION DE FISICA, y es obligatorio.
	#
	# El proyecto la tiene activada globalmente (`physics/common/physics_interpolation`)
	# porque la fisica va a 60 Hz y la pantalla a 144: sin ella, dos de cada tres
	# frames repetian la posicion del personaje. Pero la interpolacion es para lo
	# que mueve la FISICA, y este rig se mueve por CODIGO en `_process`, a ritmo de
	# render. Dejarlo dentro lo interpolaria una segunda vez —suavizado sobre
	# suavizado— y el resultado es una camara que va medio frame por detras de si
	# misma: exactamente el mareo que se intentaba quitar.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

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
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_ruido.frequency = 0.08
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
	#
	# Se sigue la posicion INTERPOLADA, no `global_position`. Con la interpolacion
	# de fisica activada, `global_position` sigue siendo la del ultimo tick de 60 Hz
	# —o sea, un valor escalonado— mientras que lo que se DIBUJA del personaje ya
	# va interpolado. Perseguir el valor escalonado dejaria a la camara persiguiendo
	# una cosa distinta de la que se ve, y el personaje volveria a temblar en
	# pantalla aunque el cuerpo fuera suave.
	var deseado := _punto_objetivo() + Vector3.UP * (tuning.camara_altura_objetivo * float(_p["altura"]))
	deseado += _adelanto(delta)
	var suavizado: float = maxf(tuning.camara_suavizado * float(_p["suave"]), 0.001)
	_pos_suave = _pos_suave.lerp(deseado, 1.0 - exp(-delta / suavizado))

	global_position = _pos_suave
	rotation_degrees = Vector3(0.0, _yaw, 0.0)
	_sacudir_encuadre(delta)
	brazo.spring_length = tuning.camara_distancia * float(_p["dist"])

	_sacar_del_agua(delta)
	_actualizar_fov(delta)


## DÓNDE ESTÁ EL OBJETIVO **ESTE FRAME**, no en el último tick de física.
##
## Con `physics/common/physics_interpolation` activado, `global_position` sigue
## dando la posición del último tick de 60 Hz —un valor escalonado— mientras que
## lo que se DIBUJA del personaje ya va interpolado a ritmo de render. Perseguir
## el valor escalonado dejaría a la cámara siguiendo una cosa distinta de la que
## se ve, y el personaje seguiría temblando en pantalla aunque su cuerpo fuera
## perfectamente suave. `get_global_transform_interpolated()` da lo que se dibuja.
func _punto_objetivo() -> Vector3:
	return objetivo.get_global_transform_interpolated().origin


## LOOK AHEAD: la cámara se adelanta hacia donde vas.
##
## Es lo que hace que un disparo de resortera se vea venir en vez de descubrirse
## al llegar: encuadras el destino, no la nuca del personaje.
##
## Dos decisiones que lo hacen usable:
##
##   · **desplaza el PUNTO SEGUIDO, nunca el yaw.** Girar la cámara sola le quita
##     el control al jugador y es la forma más rápida de que un look-ahead se
##     sienta mal. Aquí el ratón sigue mandando en la dirección; el adelanto solo
##     mueve el centro del encuadre.
##   · **va deliberadamente LENTO** (`camara_adelanto_respuesta`). Un adelanto que
##     se pega a la velocidad instantánea oscila con cada corrección del stick.
##     Arrastrándose por detrás, acompaña el movimiento sostenido e ignora el
##     temblor.
func _adelanto(delta: float) -> Vector3:
	var destino := Vector3.ZERO
	if _jugador != null and tuning.camara_adelanto > 0.0:
		var v := _jugador.velocity
		var plana := Vector3(v.x, 0.0, v.z)
		var f: float = clampf(plana.length() / maxf(tuning.camara_adelanto_ref, 0.001), 0.0, 1.0)
		if not plana.is_zero_approx():
			destino = plana.normalized() * (tuning.camara_adelanto * f)
		# La componente vertical va aparte: la resortera te sube y te baja
		# disparado, y eso no lo encuadra un adelanto horizontal.
		var fv: float = clampf(v.y / maxf(tuning.camara_adelanto_ref, 0.001), -1.0, 1.0)
		destino += Vector3.UP * (tuning.camara_adelanto * tuning.camara_adelanto_vertical * fv)
	_adelanto_suave = _adelanto_suave.lerp(
		destino, 1.0 - exp(-tuning.camara_adelanto_respuesta * delta))
	return _adelanto_suave


## FOV DINÁMICO, y **asimétrico a propósito**.
##
## Abre rápido y cierra despacio. Un FOV que hace las dos cosas al mismo ritmo se
## lee como un parpadeo; abriendo de golpe con el impulso y cerrando con calma, el
## disparo deja resaca y se siente potente. Es el mismo truco que la gravedad
## asimétrica del salto, aplicado a la lente.
func _actualizar_fov(delta: float) -> void:
	var exceso := 0.0
	if _jugador != null and _jugador.motor != null:
		# La rapidez TOTAL, no la plana: la resortera te dispara en diagonal y con
		# solo la plana el tiro más vertical —que es el más espectacular— no abría
		# nada de FOV.
		exceso = maxf(0.0, _jugador.velocity.length() - tuning.velocidad_correr)
	var objetivo_fov: float = minf(exceso * tuning.camara_fov_por_ms, tuning.camara_fov_extra_max)
	var tasa: float = (tuning.camara_fov_abre if objetivo_fov > _fov_extra
		else tuning.camara_fov_cierra)
	_fov_extra = lerpf(_fov_extra, objetivo_fov, 1.0 - exp(-tasa * delta))
	camara.fov = tuning.camara_fov * float(_p["fov"]) + _fov_extra


## SACUDIDA por ruido, en el ENCUADRE y no en la posición.
##
## `h_offset`/`v_offset` desplazan el frustum de la cámara sin moverla de sitio:
## la imagen se sacude y la cámara no atraviesa geometría ni orbita alrededor del
## jugador. Rotar el brazo —que es lo que hacía antes— hace las dos cosas malas.
##
## El ruido va con `FastNoiseLite` y no con `randf()` porque un valor aleatorio
## por frame da vibración blanca, que a 144 Hz se ve como un borrón sucio. El
## ruido es continuo: sacude, pero la imagen sigue siendo legible.
func _sacudir_encuadre(delta: float) -> void:
	if _shake <= 0.0:
		camara.h_offset = 0.0
		camara.v_offset = 0.0
		brazo.rotation_degrees = Vector3(_pitch, 0.0, 0.0)
		return

	_shake = maxf(0.0, _shake - _shake_decaimiento * delta)
	_shake_t += delta * tuning.camara_shake_frecuencia
	# Dos cortes del mismo ruido bien separados en Y: usar el mismo eje para las
	# dos componentes daría una sacudida en diagonal perfecta, que se lee a ojo.
	var nx := _ruido.get_noise_2d(_shake_t, 0.0)
	var ny := _ruido.get_noise_2d(0.0, _shake_t + 137.0)
	camara.h_offset = nx * _shake * tuning.camara_shake_offset
	camara.v_offset = ny * _shake * tuning.camara_shake_offset
	# Un pelín de giro además del desplazamiento: vende el impacto sin marear.
	var g := tuning.camara_shake_giro * _shake
	brazo.rotation_degrees = Vector3(_pitch + ny * g, nx * g, 0.0)


## NADANDO EN SUPERFICIE, LA CAMARA NO SE METE EN EL AGUA.
##
## El brazo esquiva geometria —`Layers.CAMARA`— pero una `ZonaAgua` es un `Area3D`
## y para el brazo no existe: nadando, el brazo baja por detras y la lente acaba
## por debajo de la superficie. Y la superficie tiene `cull_disabled`, asi que
## desde abajo tapa la pantalla entera con un plano de color: parece un error de
## render y es solo la camara donde no debia estar.
##
## Se levanta el RIG entero y no se recorta el pitch: recortar el pitch le quita
## al jugador el control de la vista justo cuando esta intentando mirar, que es
## peor que subir la camara un palmo.
##
## BUCEANDO NO SE TOCA: ahi la camara TIENE que estar debajo. La condicion es
## nadar en superficie, no estar mojado.
func _sacar_del_agua(delta: float) -> void:
	# LA ALTURA DE LA LENTE SE CALCULA EN LOCAL, NO SE PREGUNTA EN MUNDO.
	#
	# `camara.global_position` ya trae el alza del frame anterior, asi que usarla
	# para decidir cuanto hay que alzar es un controlador persiguiendo su propio
	# error: sube, la medida mejora, deja de subir, y se estabiliza justo donde
	# todavia falta. Medido: 25 cm por debajo del agua mirando hacia arriba, y
	# cualquier intento de compensarlo sumando el alza lo volvia inestable.
	#
	# La composicion local del brazo y la lente NO depende de donde este el rig, y
	# es exactamente lo que hace falta: cuanto cuelga la lente por debajo de el.
	var objetivo := 0.0
	if _jugador != null and _jugador.agua != null:
		var s: WaterSensor = _jugador.agua
		if s.en_agua and not s.sumergido():
			var cuelga: float = (brazo.transform * camara.transform).origin.y
			objetivo = maxf(0.0,
				(s.nivel + tuning.camara_margen_agua) - (_pos_suave.y + cuelga))
	_alza_agua = lerpf(_alza_agua, objetivo, 1.0 - exp(-12.0 * delta))
	if _alza_agua > 0.001:
		global_position.y += _alza_agua


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
	var cat: StringName = _jugador.fsm.actual.categoria
	if cat == &"Attached":
		modo = &"Climb"
	elif cat == &"Combat" or _jugador.targeting.objetivo() != null:
		modo = &"Combat"
	else:
		modo = &"Explore"
	DebugOverlay.set_line("cámara", modo)
