class_name PlayerController
extends CharacterBody3D
## FASE 0 — PROVISIONAL.
##
## Locomoción mínima para verificar que el proyecto arranca y para poder recorrer
## el Gym. La FASE 1 sustituye este archivo por la FSM jerárquica
## (Grounded / Airborne / Attached) descrita en docs/03_ARQUITECTURA_MECANICAS.md §2.
##
## Lo que YA respeta y hay que conservar al reescribirlo:
##   · todos los números salen de PlayerTuning (CLAUDE.md #1)
##   · el input pasa solo por InputBuffer (CLAUDE.md #4)
##   · gravedad asimétrica, coyote time, jump buffer y jump cut

@export var tuning: PlayerTuning
## NodePath y no Node: ver el mismo comentario en CameraRig.gd.
@export var visual_path: NodePath = ^"Visual"

@onready var buffer: InputBuffer = $InputBuffer
@onready var visual: Node3D = get_node_or_null(visual_path)

var _coyote: float = 0.0
var _saltos_restantes: int = 0
var _saltando: bool = false


func _ready() -> void:
	if tuning == null:
		tuning = GameState.tuning
	EventBus.tuning_reloaded.connect(func() -> void: tuning = GameState.tuning)
	floor_max_angle = deg_to_rad(tuning.angulo_max_suelo)
	EventBus.player_spawned.emit(self)


func _physics_process(delta: float) -> void:
	if HitstopManager.global_activo():
		return

	var en_suelo := is_on_floor()
	_actualizar_perdones(delta, en_suelo)
	_horizontal(delta, en_suelo)
	_vertical(delta, en_suelo)

	var impacto := absf(velocity.y)
	move_and_slide()
	if not en_suelo and is_on_floor():
		EventBus.player_landed.emit(impacto, impacto > 18.0)

	_orientar(delta)
	_reset_si_cae()
	_debug(en_suelo)


## En el Gym caerse no mata: te devuelve al spawn. En el juego real la caída
## larga es LA muerte (docs/00_VISION.md P2).
func _reset_si_cae() -> void:
	if global_position.y < -30.0:
		global_position = Vector3(0.0, 2.0, 4.0)
		velocity = Vector3.ZERO
		buffer.clear()


## Coyote time y saltos aéreos: el perdón es la mitad del game feel.
func _actualizar_perdones(delta: float, en_suelo: bool) -> void:
	if en_suelo:
		_coyote = tuning.coyote_time
		_saltos_restantes = tuning.saltos_aereos
		_saltando = false
	else:
		_coyote = maxf(0.0, _coyote - delta)


func _horizontal(delta: float, en_suelo: bool) -> void:
	var entrada := buffer.move_vector()
	var dir := _direccion_camara(entrada)

	var objetivo := tuning.velocidad_correr
	if buffer.is_held(InputActions.SPRINT):
		objetivo = tuning.velocidad_sprint
	elif entrada.length() < 0.6:
		objetivo = tuning.velocidad_caminar

	var plano := Vector3(velocity.x, 0.0, velocity.z)
	var deseado := dir * objetivo

	var tasa: float
	if dir.is_zero_approx():
		tasa = tuning.frenado_suelo if en_suelo else tuning.frenado_aire
	else:
		tasa = tuning.aceleracion_suelo if en_suelo else tuning.aceleracion_aire

	plano = plano.move_toward(deseado, tasa * delta)
	velocity.x = plano.x
	velocity.z = plano.z


func _vertical(delta: float, en_suelo: bool) -> void:
	# Gravedad asimétrica: subir flotante, caer contundente.
	var g := tuning.gravedad_subida if velocity.y > 0.0 else tuning.gravedad_caida
	if not en_suelo:
		velocity.y = maxf(velocity.y + g * delta, tuning.velocidad_terminal)

	# Jump buffer: la pulsación sobrevive hasta tocar suelo.
	if buffer.peek(InputActions.JUMP, tuning.jump_buffer):
		if _coyote > 0.0:
			buffer.consume(InputActions.JUMP, tuning.jump_buffer)
			_saltar(1)
		elif _saltos_restantes > 0:
			buffer.consume(InputActions.JUMP, tuning.jump_buffer)
			_saltos_restantes -= 1
			_saltar(2)

	# Jump cut: soltar el botón durante la subida acorta el salto.
	if _saltando and velocity.y > 0.0 and not buffer.is_held(InputActions.JUMP):
		velocity.y *= tuning.jump_cut
		_saltando = false


func _saltar(numero: int) -> void:
	velocity.y = tuning.velocidad_salto()
	_coyote = 0.0
	_saltando = true
	EventBus.player_jumped.emit(numero)


## Convierte el input 2D a dirección de mundo usando la cámara activa.
## En la Fase 4 esto pasará por el SurfaceContext para funcionar sobre un coloso.
func _direccion_camara(entrada: Vector2) -> Vector3:
	if entrada.is_zero_approx():
		return Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3(entrada.x, 0.0, entrada.y)
	var adelante := -cam.global_basis.z
	var derecha := cam.global_basis.x
	adelante.y = 0.0
	derecha.y = 0.0
	return (adelante.normalized() * -entrada.y + derecha.normalized() * entrada.x).limit_length(1.0)


func _orientar(delta: float) -> void:
	if visual == null:
		return
	var plano := Vector3(velocity.x, 0.0, velocity.z)
	if plano.length_squared() < 0.25:
		return
	var objetivo := atan2(plano.x, plano.z)
	visual.rotation.y = rotate_toward(
		visual.rotation.y, objetivo, deg_to_rad(tuning.giro_grados_seg) * delta
	)


func _debug(en_suelo: bool) -> void:
	DebugOverlay.set_line("estado", "PROVISIONAL · %s" % ("suelo" if en_suelo else "aire"))
	DebugOverlay.set_line("vel", "%.1f m/s  (y %.1f)" % [Vector2(velocity.x, velocity.z).length(), velocity.y])
	DebugOverlay.set_line("coyote", "%.0f ms" % (_coyote * 1000.0))
	DebugOverlay.set_line("saltos", "%d aéreos" % _saltos_restantes)
	DebugOverlay.set_line("buffer", buffer.debug_line())
	DebugOverlay.set_line("pos", "%.1f, %.1f, %.1f" % [global_position.x, global_position.y, global_position.z])
