class_name PlayerController
extends CharacterBody3D
## El jugador. No contiene lógica de estados: solo orquesta componentes y expone
## los servicios que los estados usan.
##
## REGLA DURA (CLAUDE.md #2): la lógica de "qué puedo hacer ahora" vive en la FSM.
## Aquí solo hay recursos compartidos (cargas de dash, coyote, iframes) y utilidades.

@export var tuning: PlayerTuning
@export var visual_path: NodePath = ^"Visual"
@export var collider_path: NodePath = ^"Collider"

@onready var buffer: InputBuffer = $InputBuffer
@onready var stamina: StaminaComponent = $Stamina
@onready var suelo: GroundSensor = $GroundSensor
@onready var borde: LedgeSensor = $LedgeSensor
@onready var pared: WallSensor = $WallSensor
@onready var fsm: StateMachine = $StateMachine
@onready var visual: Node3D = get_node_or_null(visual_path)
@onready var _collider: CollisionShape3D = get_node_or_null(collider_path)

## El marco de referencia actual. Hoy es el mundo; en la Fase 4 será un coloso.
var superficie: SurfaceContext
var motor: LocomotionMotor

# --- Recursos compartidos entre estados --------------------------------------
var dash_cargas: int = 1
var saltos_aereos: int = 1
var wallrun_disponible: bool = true
var iframes: float = 0.0
## Bloqueo temporal del agarre de bordes, para poder soltarse sin reengancharse.
var tiempo_sin_borde: float = 0.0
var tiempo_en_aire: float = 0.0
## Velocidad vertical del último frame antes de tocar suelo, para el aterrizaje duro.
var impacto_ultimo: float = 0.0

var _coyote: float = 0.0
var _alabeo: float = 0.0
var _altura_base: float = 1.8
var _giro_objetivo: float = 0.0
var _tiene_giro: bool = false
var _bloqueo_control: float = 0.0
var _pos_anterior: Vector3 = Vector3.ZERO
var _atascado: float = 0.0


func _ready() -> void:
	if tuning == null:
		tuning = GameState.tuning
	EventBus.tuning_reloaded.connect(_on_tuning_reloaded)

	superficie = SurfaceContext.new()
	motor = LocomotionMotor.new(self)

	_configurar_cuerpo()
	stamina.configurar(tuning)

	# La forma se duplica: sin esto, encoger la cápsula al deslizarse escribía en
	# el Resource COMPARTIDO de la escena y la altura se quedaba pillada.
	if _collider != null and _collider.shape != null:
		_collider.shape = _collider.shape.duplicate()
		if _collider.shape is CapsuleShape3D:
			_altura_base = (_collider.shape as CapsuleShape3D).height
	_pos_anterior = global_position

	fsm.configurar(self)
	EventBus.player_spawned.emit(self)


func _physics_process(delta: float) -> void:
	if HitstopManager.global_activo():
		return

	_avanzar_relojes(delta)

	# 1) Heredar el movimiento del marco ANTES de decidir nada. Con suelo estático
	#    no hace nada; sobre un coloso es lo que impide salir volando.
	superficie.arrastrar(self)
	up_direction = superficie.up

	# 2) Sensores: la FSM decide sobre datos frescos, nunca sobre los del frame anterior.
	var frente := direccion_frontal()
	suelo.sondear()
	pared.sondear(frente)
	if tiempo_sin_borde <= 0.0:
		borde.sondear(frente)
	else:
		borde.hay_borde = false

	# 3) La FSM escribe en velocity.
	fsm.physics_update(delta)

	# 4) Un único move_and_slide por frame, aquí y en ningún otro sitio.
	var en_suelo_antes := is_on_floor()
	impacto_ultimo = absf(superficie.vertical(velocity))
	move_and_slide()
	if not en_suelo_antes and is_on_floor():
		EventBus.player_landed.emit(impacto_ultimo, impacto_ultimo > tuning.aterrizaje_duro)

	_antiatasco(delta)
	_actualizar_visual(delta)
	_reset_si_cae()
	_debug()


## Ajustes de CharacterBody3D que evitan que la cápsula se enganche.
##
## `floor_block_on_wall` es el culpable clásico: con él activado, la unión entre
## una pared y el suelo bloquea el deslizamiento y el personaje se queda clavado
## en cualquier esquina interior.
func _configurar_cuerpo() -> void:
	floor_max_angle = deg_to_rad(tuning.angulo_max_suelo)
	floor_snap_length = 0.4
	floor_block_on_wall = false
	floor_constant_speed = true
	floor_stop_on_slope = true
	slide_on_ceiling = true
	max_slides = 6
	wall_min_slide_angle = deg_to_rad(12.0)
	safe_margin = 0.02
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_UPWARD_VELOCITY
	up_direction = superficie.up


## Red de seguridad: si el jugador QUIERE moverse y no avanza durante un rato,
## se le empuja fuera. Es un parche a propósito — los atascos de cápsula contra
## geometría de cajas son inevitables y frustran más que cualquier bug de física.
func _antiatasco(delta: float) -> void:
	var deseada := superficie.plano(velocity).length()
	var real := global_position.distance_to(_pos_anterior) / maxf(delta, 0.0001)
	if deseada > 2.0 and real < deseada * 0.15:
		_atascado += delta
	else:
		_atascado = 0.0

	if _atascado > 0.18:
		var salida := get_wall_normal() if is_on_wall() else superficie.up
		if salida.is_zero_approx():
			salida = superficie.up
		global_position += salida * 0.15
		_atascado = 0.0
		DebugOverlay.set_line("atasco", "desatascado hacia %.1f,%.1f,%.1f" % [salida.x, salida.y, salida.z])

	_pos_anterior = global_position


func _avanzar_relojes(delta: float) -> void:
	iframes = maxf(0.0, iframes - delta)
	tiempo_sin_borde = maxf(0.0, tiempo_sin_borde - delta)
	_bloqueo_control = maxf(0.0, _bloqueo_control - delta)
	if is_on_floor():
		_coyote = tuning.coyote_time
		tiempo_en_aire = 0.0
	else:
		_coyote = maxf(0.0, _coyote - delta)
		tiempo_en_aire += delta


# --- Servicios para los estados ----------------------------------------------

## Recarga lo que se recupera al tocar suelo o al hacer wall-jump.
func recargar_aire() -> void:
	dash_cargas = tuning.dash_cargas_aire
	saltos_aereos = tuning.saltos_aereos


func puede_dashear() -> bool:
	if not stamina.alcanza(tuning.stamina_dash):
		return false
	return is_on_floor() or dash_cargas > 0


func hay_coyote() -> bool:
	return _coyote > 0.0


func consumir_coyote() -> void:
	_coyote = 0.0


## Control aéreo: menos autoridad que en suelo, pero nunca cero. Un salto sin
## corrección se siente como un compromiso injusto.
##
## Durante `_bloqueo_control` la autoridad baja mucho: es lo que permite que un
## wall-jump despegue de verdad aunque el jugador siga apuntando a la pared.
func control_aereo(delta: float) -> void:
	var entrada := buffer.move_vector()
	if entrada.is_zero_approx():
		motor.acelerar(Vector3.ZERO, tuning.frenado_aire, delta)
		return
	var escala := tuning.control_bloqueado_mult if _bloqueo_control > 0.0 else 1.0
	var dir := superficie.direccion_movimiento(entrada, camara())
	var objetivo: float = maxf(tuning.velocidad_correr, motor.rapidez_plana())
	motor.acelerar(dir * objetivo, tuning.aceleracion_aire * escala, delta)


## Baja la autoridad del control aéreo durante unos instantes.
func bloquear_control_aereo(segundos: float) -> void:
	_bloqueo_control = maxf(_bloqueo_control, segundos)


## Salto de pared estilo Mario 3D. Lo comparten WallSlide, WallRun y el coyote
## de pared desde Fall o Glide, así que rebotar es siempre la misma maniobra.
##
## Tres cosas lo hacen fluido en vez de rígido:
##   · el impulso VERTICAL es absoluto y fuerte — en Mario el salto de pared sube
##     de verdad, no es un empujón lateral con propina;
##   · se conserva el momentum A LO LARGO del muro, así que importa cómo llegaste;
##   · la intención del jugador (stick + cámara) inclina el rebote, pero se le
##     recorta la componente que apunta a la pared: nunca puedes saltar hacia ella.
func saltar_de_pared(fuerza: float = 1.0) -> void:
	var normal := superficie.plano(pared.normal_de_salto()).normalized()
	if normal.is_zero_approx():
		normal = -direccion_frontal()

	# Velocidad paralela al muro: la parte que hay que respetar.
	var a_lo_largo := superficie.plano(velocity)
	a_lo_largo -= normal * a_lo_largo.dot(normal)

	# Hacia dónde pide ir el jugador, sin dejarle volver contra la pared.
	var intencion := superficie.direccion_movimiento(buffer.move_vector(), camara())
	var hacia_dentro := intencion.dot(normal)
	if hacia_dentro < 0.0:
		intencion -= normal * hacia_dentro

	pared.bloquear_actual()
	var salida := (
		normal * tuning.walljump_lateral * fuerza
		+ intencion * tuning.walljump_lateral * tuning.walljump_intencion
		+ a_lo_largo * tuning.walljump_conserva
	)
	velocity = superficie.con_vertical(salida, tuning.walljump_vertical * fuerza)

	bloquear_control_aereo(tuning.walljump_bloqueo)
	orientar_a(salida)
	recargar_aire()
	wallrun_disponible = true
	# La cámara se pone detrás del rebote: sin esto acabas volando de espaldas a
	# donde miras y encadenar el siguiente muro es a ciegas.
	EventBus.camara_realinear.emit(salida, tuning.camara_realinea_walljump)


## Dirección hacia la que "mira" el jugador para los sensores: la de movimiento si
## se mueve, la del visual si está quieto.
func direccion_frontal() -> Vector3:
	var v := motor.direccion_plana()
	if not v.is_zero_approx():
		return v
	if visual != null:
		return superficie.plano(visual.global_basis.z).normalized()
	return superficie.plano(global_basis.z).normalized()


## Encara el visual a una dirección de golpe (dash, agarre).
func orientar_a(dir: Vector3) -> void:
	var d := superficie.plano(dir)
	if d.is_zero_approx():
		return
	_giro_objetivo = atan2(d.x, d.z)
	_tiene_giro = true
	if visual != null:
		visual.rotation.y = _giro_objetivo


## Alabeo del cuerpo en grados. Lo usan el planeo y el wall-run: a 50 metros es lo
## único que comunica que estás girando.
func set_alabeo(grados: float) -> void:
	_alabeo = grados


## Encoge o restaura la cápsula (deslizamiento).
func set_altura_colision(fraccion: float) -> void:
	if _collider == null or not _collider.shape is CapsuleShape3D:
		return
	var forma := _collider.shape as CapsuleShape3D
	forma.height = _altura_base * fraccion
	_collider.position.y = (_altura_base * fraccion) * 0.5


func camara() -> Camera3D:
	return get_viewport().get_camera_3d()


# --- Interno ------------------------------------------------------------------

func _actualizar_visual(delta: float) -> void:
	if visual == null:
		return
	var plano := superficie.plano(velocity)
	if plano.length_squared() > 0.25:
		_giro_objetivo = atan2(plano.x, plano.z)
		_tiene_giro = true
	if _tiene_giro:
		visual.rotation.y = rotate_toward(
			visual.rotation.y, _giro_objetivo, deg_to_rad(tuning.giro_grados_seg) * delta
		)
	visual.rotation.z = lerpf(visual.rotation.z, deg_to_rad(_alabeo), 1.0 - exp(-9.0 * delta))


## En el Gym caerse no mata: te devuelve al spawn. En el juego real la caída larga
## es LA muerte (docs/00_VISION.md P2).
func _reset_si_cae() -> void:
	if global_position.y > -30.0:
		return
	global_position = Vector3(0.0, 2.0, 4.0)
	velocity = Vector3.ZERO
	superficie.set_frame(null)
	stamina.llenar()
	buffer.clear()
	fsm.cambiar(&"Fall")


func _on_tuning_reloaded() -> void:
	tuning = GameState.tuning
	stamina.configurar(tuning)
	floor_max_angle = deg_to_rad(tuning.angulo_max_suelo)


func _debug() -> void:
	DebugOverlay.set_line("estado", fsm.debug_line())
	DebugOverlay.set_line("vel", "%.1f m/s   vy %.1f" % [motor.rapidez_plana(), motor.get_vertical()])
	DebugOverlay.set_line("stamina", "%s %.0f%%" % ["█".repeat(int(stamina.fraccion() * 12.0)).rpad(12, "░"), stamina.fraccion() * 100.0])
	DebugOverlay.set_line("aire", "coyote %.0fms · dash %d · saltos %d%s" % [
		_coyote * 1000.0, dash_cargas, saltos_aereos, " · wallrun" if wallrun_disponible else ""
	])
	DebugOverlay.set_line("suelo", suelo.debug_line())
	DebugOverlay.set_line("pared", pared.debug_line())
	DebugOverlay.set_line("borde", borde.debug_line())
	DebugOverlay.set_line("superficie", superficie.debug_line())
	DebugOverlay.set_line("buffer", buffer.debug_line())
	DebugOverlay.set_line("pos", "%.1f, %.1f, %.1f" % [global_position.x, global_position.y, global_position.z])
