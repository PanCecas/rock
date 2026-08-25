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

@export_group("Ataques")
## Primer golpe de la cadena ligera. Los demás cuelgan de `siguiente`.
@export var ataque_ligero: AttackData
@export var ataque_pesado: AttackData
@export var ataque_aereo: AttackData
@export var ataque_plunge: AttackData
## Ataques acuaticos: bajo el agua un golpe es un desplazamiento con hitbox.
@export var ataque_agua_ligero: AttackData
@export var ataque_agua_pesado: AttackData
## Patada deslizante: el salto de conejo. Su hitbox vive todo el trayecto.
@export var ataque_slide_kick: AttackData
## Clavado. Su hitbox vive todo el trayecto y lanza por los aires.
@export var ataque_dive: AttackData
## Clavado PESADO: mas dano y rebote sobre la cabeza del enemigo.
@export var ataque_dive_pesado: AttackData
## Patada baja desde agachado. Derriba en vez de tambalear.
@export var ataque_agachado: AttackData
## Ataque lanzado desde el dash: hereda el momentum y cierra distancia.
@export var ataque_dash: AttackData
## Shift + ataque ligero: estocada de esgrima que conserva la forma del surf.
@export var ataque_surf_ligero: AttackData
## Shift + ataque pesado: frenazo en seco y empujon fuerte.
@export var ataque_surf_pesado: AttackData
## Contraataque que solo se abre tras un parry perfecto.
@export var ataque_contra: AttackData

@onready var buffer: InputBuffer = $InputBuffer
@onready var stamina: StaminaComponent = $Stamina
@onready var suelo: GroundSensor = $GroundSensor
@onready var borde: LedgeSensor = $LedgeSensor
@onready var pared: WallSensor = $WallSensor
@onready var techo: CeilingSensor = $CeilingSensor
@onready var agua: WaterSensor = $WaterSensor
@onready var fsm: StateMachine = $StateMachine
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var salud: HealthComponent = $Salud
@onready var poise: PoiseComponent = $Poise
@onready var targeting: TargetingSystem = $Targeting
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
## Saltar desde el surf no lo cancela: al aterrizar se recupera si esto sigue vivo.
var surf_pendiente: float = 0.0
var surf_rapidez: float = 0.0

var _coyote: float = 0.0
var _alabeo: float = 0.0
var _altura_base: float = 1.8
var _altura_objetivo: float = 1.0
## Postura que PIDE el estado actual, en fraccion de altura. Se reinicia a 1.0
## cada frame: un estado que quiera ir agachado tiene que seguir pidiendolo.
var _postura_pedida: float = 1.0
## ¿Se esta agachado solo porque no se cabe de pie? Es la diferencia entre el
## agachado que pide el jugador y el que impone el mundo, y hace falta tenerla
## separada: el primero dura lo que dure el boton, el segundo se deshace solo.
var agachado_forzado: bool = false
var _altura_actual: float = 1.0
var _giro_objetivo: float = 0.0
var _tiene_giro: bool = false
var _bloqueo_control: float = 0.0
var _cooldown_salto: float = 0.0
var _pos_anterior: Vector3 = Vector3.ZERO
var _atascado: float = 0.0
var _giro_visual: float = 0.0
## Mientras dura, `_actualizar_visual` no toca la orientacion: manda el nado.
var _orientacion_3d: bool = false
## Segundos que le quedan a la recuperacion de verticalidad. > 0 = enderezandose.
var _recuperacion: float = 0.0
## Ventana del side jump: se abre al pedir la direccion contraria corriendo.
var ventana_sidejump: float = 0.0
## Tiempo empujando contra una pared. Al pasar del umbral, se escala solo.
var tiempo_contra_pared: float = 0.0
## Espera de la patada deslizante. Vive aqui y no en el estado porque tiene que
## sobrevivir a la patada: un cooldown que muere con el estado que lo pone no es
## un cooldown, es un adorno.
var cd_slide_kick: float = 0.0
## Espera entre clavados. Mismo motivo y mismo patron que la patada deslizante:
## un ataque de movilidad que se puede repetir sin pausa deja de ser una decision.
var cd_dive: float = 0.0
## HANG TIME: segundos con gravedad CERO. Lo arma el rebote del clavado pesado y lo
## consulta `LocomotionMotor.aplicar_gravedad`, asi que vale para Fall, Jump y
## Glide sin que ninguno tenga que saber que existe.
var hangtime: float = 0.0
## ¿La camara debe ir en primera persona? Lo pide el ataque pesado en carrera.
var primera_persona: bool = false
var _giro_visual_restante: float = 0.0


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
	_altura_objetivo = 1.0
	_altura_actual = 1.0
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
	var cam := camara()
	targeting.actualizar(-cam.global_basis.z if cam != null else frente)
	suelo.sondear()
	pared.sondear(frente)
	techo.sondear(_altura_base * _altura_actual, _altura_base)
	agua.sondear()
	if tiempo_sin_borde <= 0.0:
		borde.sondear(frente)
	else:
		borde.hay_borde = false

	# 3) La FSM escribe en velocity.
	fsm.physics_update(delta)

	_limitar_velocidad()

	# 4) Un único move_and_slide por frame, aquí y en ningún otro sitio.
	var en_suelo_antes := is_on_floor()
	impacto_ultimo = absf(superficie.vertical(velocity))
	move_and_slide()
	if not en_suelo_antes and is_on_floor():
		EventBus.player_landed.emit(impacto_ultimo, impacto_ultimo > tuning.aterrizaje_duro)

	_antiatasco(delta)
	_resolver_postura()
	_actualizar_altura(delta)
	_actualizar_visual(delta)
	_reset_si_cae()
	_debug()


## Ajustes de CharacterBody3D que evitan que la cápsula se enganche.
##
## `floor_block_on_wall` es el culpable clásico: con él activado, la unión entre
## una pared y el suelo bloquea el deslizamiento y el personaje se queda clavado
## en cualquier esquina interior.
func _configurar_cuerpo() -> void:
	floor_max_angle = deg_to_rad(tuning.angulo_max_suelo())
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
	ventana_sidejump = maxf(0.0, ventana_sidejump - delta)
	cd_slide_kick = maxf(0.0, cd_slide_kick - delta)
	cd_dive = maxf(0.0, cd_dive - delta)
	hangtime = maxf(0.0, hangtime - delta)
	_actualizar_sidejump(delta)
	_actualizar_adherencia(delta)
	_cooldown_salto = maxf(0.0, _cooldown_salto - delta)
	surf_pendiente = maxf(0.0, surf_pendiente - delta)
	if is_on_floor():
		_coyote = tuning.coyote_time
		tiempo_en_aire = 0.0
	else:
		_coyote = maxf(0.0, _coyote - delta)
		tiempo_en_aire += delta


# --- Servicios para los estados ----------------------------------------------

## CLAMP DURO de la velocidad horizontal, en el último punto antes de mover.
##
## El juego premia encadenar momentum, pero encadenar sin techo termina sacando al
## jugador del mapa. El límite va aquí y no en cada estado: un solo sitio, imposible
## de olvidar al añadir el siguiente verbo.
func _limitar_velocidad() -> void:
	var plano := superficie.plano(velocity)
	var rapidez := plano.length()
	if rapidez > tuning.velocidad_maxima:
		velocity = plano * (tuning.velocidad_maxima / rapidez) + superficie.up * superficie.vertical(velocity)


## PUERTA ÚNICA DEL SALTO. Todos los saltos pasan por aquí, sin excepción.
##
## Garantiza "1 pulsación = 1 salto": al consumir la pulsación se invalida
## cualquier otra que siguiera viva en la ventana, y un cooldown corto impide que
## machacar el botón produzca más saltos que intenciones. Antes cada estado
## consumía por su cuenta y el spam encadenaba saltos que no se habían pedido.
func consumir_salto() -> bool:
	if _cooldown_salto > 0.0:
		return false
	if not buffer.consume(InputActions.JUMP, tuning.jump_buffer):
		return false
	buffer.invalidar(InputActions.JUMP)
	_cooldown_salto = tuning.salto_intervalo_min
	return true


## Recarga lo que se recupera al tocar suelo o al hacer wall-jump.
## Suspende la gravedad unos instantes. La usa el rebote del clavado pesado.
func iniciar_hangtime(segundos: float) -> void:
	hangtime = maxf(hangtime, segundos)


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
	# El techo del aire es la velocidad con la que DESPEGASTE, no la de correr. Con
	# `velocidad_correr` como suelo, un salto desde parado alcanzaba la velocidad
	# maxima de carrera sin tocar el suelo: el salto no pesaba nada porque la
	# carrerilla no servia para nada.
	var objetivo: float = maxf(tuning.control_aereo_techo, motor.rapidez_plana())
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


## Orienta el cuerpo en 3D hacia `dir`, con pitch y yaw reales. Es lo que hace
## que nadar hacia el fondo INCLINE al personaje en vez de dejarlo horizontal, y
## lo que inclina el cuerpo contra una rampa de 60 grados al escalarla.
##
## Interpola la BASE, no los angulos de Euler: rotar por Euler cruza el gimbal al
## apuntar recto arriba o abajo, que es justo lo que se pide bajo el agua.
##
## `arriba_ref` permite imponer el "arriba" del cuerpo —la escalada le pasa la
## pendiente de la pared—. Sin el, la referencia se transporta desde el arriba
## actual segun cuanto se acerque `dir` a la vertical: elegir entre UP y FORWARD
## con un umbral duro hacia saltar el roll de golpe justo al picar al fondo.
func orientar_a_3d(dir: Vector3, delta: float, arriba_ref: Vector3 = Vector3.ZERO) -> void:
	if visual == null or dir.length_squared() < 0.04:
		return
	_orientacion_3d = true
	_recuperacion = 0.0
	var d := dir.normalized()
	var arriba := arriba_ref
	if arriba.is_zero_approx():
		# Cuanto mas vertical es `d`, mas se confia en el arriba que ya tenia el
		# cuerpo. Es continuo, asi que no hay chasquido de balanceo en el cenit.
		var verticalidad: float = smoothstep(0.7, 0.98, absf(d.dot(superficie.up)))
		arriba = superficie.up.lerp(visual.global_basis.y, verticalidad)
	arriba -= d * arriba.dot(d)
	if arriba.length_squared() < 0.0001:
		arriba = visual.global_basis.x
	# `looking_at` mira por -Z, y el visual apunta con +Z, de ahi el signo.
	var objetivo := Basis.looking_at(-d, arriba.normalized())
	var peso: float = clampf(deg_to_rad(tuning.giro_3d_grados_seg) * delta, 0.0, 1.0)
	# Por `quaternion` y no por `basis`: asignar la base pisaria el `scale.y` con
	# el que el agachado encoge al personaje.
	visual.quaternion = visual.quaternion.slerp(objetivo.get_rotation_quaternion(), peso)


## UPRIGHT ORIENTATION RECOVERY. Arranca la vuelta a la vertical: se conserva el
## yaw —hacia donde mira— y se van a cero el pitch y el roll.
##
## Existe porque el nado y la escalada escriben los tres ejes, mientras que la
## logica de tierra solo escribe el yaw: sin esto, salir del agua o soltarse de
## una rampa dejaba al personaje torcido para siempre.
##
## Es una TRANSICION, no un guardia por frame: lo llaman los estados al salir del
## medio que inclinaba, y se apaga solo. Por eso no puede pelearse con el dash, el
## agachado ni el movimiento aereo, que nunca lo encienden.
func enderezar(duracion: float = -1.0) -> void:
	if visual == null:
		return
	_orientacion_3d = false
	# El yaw actual se preserva leyendolo del cuerpo, no del ultimo `_giro_objetivo`:
	# bajo el agua el cuerpo ha estado girando por su cuenta.
	var frente := superficie.plano(visual.global_basis.z)
	if frente.is_zero_approx():
		# Mirando recto arriba o abajo no hay rumbo horizontal en el frente; el
		# vientre del personaje sí lo tiene.
		frente = superficie.plano(-visual.global_basis.y)
	if not frente.is_zero_approx():
		_giro_objetivo = atan2(frente.x, frente.z)
		_tiene_giro = true
	_recuperacion = duracion if duracion > 0.0 else tuning.enderezar_duracion


## Balanceo lento al derivar: el cuerpo cabecea suavemente sin ir a ningun sitio.
func derivar_visual(onda: float, grados: float, delta: float) -> void:
	if visual == null:
		return
	_orientacion_3d = true
	_recuperacion = 0.0
	visual.rotate_object_local(Vector3.RIGHT, deg_to_rad(onda * grados * delta))


## Hacia donde apunta el nado: la velocidad si se mueve, la camara si no. Es la
## direccion que usan los ataques acuaticos.
func direccion_nado() -> Vector3:
	if velocity.length_squared() > 1.0:
		return velocity.normalized()
	var cam := camara()
	if cam != null:
		return -cam.global_basis.z
	return -global_basis.z


## Giro de cortesía sobre el eje lateral: el backflip. No afecta a la física, solo
## cuenta lo que ha pasado. Se consume solo.
func girar_visual(grados_seg: float) -> void:
	_giro_visual = grados_seg
	_giro_visual_restante = 360.0


## Encara el visual hacia donde se mueve. Devuelve true si ha girado.
func orientar_si_se_mueve() -> bool:
	var plano := superficie.plano(velocity)
	if plano.length_squared() < 0.25:
		return false
	orientar_a(plano)
	return true


## Pide una altura de cápsula para ESTE frame (fracción de la normal).
##
## Es una peticion, no una orden, y caduca: cada frame se vuelve a 1.0. Antes cada
## estado escribia la altura en `enter()` y la restauraba en `exit()`, y eso hacia
## que la postura fuese un efecto de borde de las transiciones: saltar desde
## dentro de un tunel te dejaba a media altura para siempre, porque ningun estado
## aereo restauraba nada. Ahora la postura es una CONSECUENCIA del estado actual,
## y si nadie pide agacharse, el personaje se levanta solo.
##
## No se aplica de golpe: `_actualizar_altura()` interpola.
func pedir_postura(fraccion: float) -> void:
	_postura_pedida = minf(_postura_pedida, clampf(fraccion, 0.2, 1.0))


## Resuelve la postura del frame: lo que se pide, y lo que el mundo permite.
##
##     quiere agachado  +  puede levantarse  ->  postura final
##
## Es el unico sitio donde se decide la altura de la capsula. La deteccion de
## paredes, pendientes o superficies escalables NO entra aqui: una rampa no es
## una razon para agacharse.
func _resolver_postura() -> void:
	var objetivo := _postura_pedida
	# "Forzado" = no lo pides Y no puedes levantarte. Es el `wants + canStand` del
	# modelo: sin separar las dos cosas, un agachado impuesto por un tunel y uno
	# pedido con el boton son indistinguibles, y el primero no debe durar ni un
	# frame mas que la obstruccion.
	agachado_forzado = techo.bloqueado and not buffer.is_held(InputActions.CROUCH)
	# Si no cabes de pie te quedas agachado aunque no lo pidas, y en cuanto el
	# hueco aparece subes solo. Nadie tiene que acordarse de nada.
	if objetivo >= 1.0 and techo.bloqueado:
		objetivo = tuning.agachado_altura
	_altura_objetivo = objetivo
	_postura_pedida = 1.0


## Shift, en cualquiera de sus formas. Lo consultan la locomocion y el agua.
func quiere_sprint() -> bool:
	return buffer.is_held(InputActions.SPRINT) or buffer.is_held(InputActions.DASH)


## SIDE JUMP de Mario 64: correr y pedir la direccion CONTRARIA abre una ventana
## corta. Saltar dentro de ella da el salto lateral alto.
##
## Se detecta aqui y no en un estado porque el giro brusco ocurre ANTES de que
## haya nada que llamar "estado de girar": es una lectura del input contra el
## momentum, y ese par solo lo tiene el controlador.
func _actualizar_sidejump(_delta: float) -> void:
	if not is_on_floor():
		return
	var v := superficie.plano(velocity)
	if v.length() < tuning.sidejump_velocidad_min:
		return
	var entrada := buffer.move_vector()
	if entrada.length() < 0.6:
		return
	var deseada := superficie.direccion_movimiento(entrada, camara())
	if deseada.is_zero_approx():
		return
	if deseada.dot(v.normalized()) <= tuning.sidejump_umbral:
		ventana_sidejump = tuning.sidejump_ventana


## ADHERENCIA AUTOMATICA a la pared. Caminar contra una superficie perpendicular
## durante `escalada_auto_tiempo` engancha solo, sin pulsar nada.
##
## Escalar deja de ser un boton que hay que saber y pasa a ser lo que ocurre si
## insistes contra un muro, que es como se descubre en Breath of the Wild.
func _actualizar_adherencia(delta: float) -> void:
	if not pared.hay_pared or stamina.vacia():
		tiempo_contra_pared = 0.0
		return
	var entrada := buffer.move_vector()
	if entrada.length() < 0.5:
		tiempo_contra_pared = 0.0
		return
	var deseada := superficie.direccion_movimiento(entrada, camara())
	var normal := superficie.plano(pared.normal).normalized()
	# Empujar CONTRA la pared, no pasar rozando.
	if deseada.dot(-normal) < 0.65:
		tiempo_contra_pared = 0.0
		return
	tiempo_contra_pared += delta


func adherencia_lista() -> bool:
	return tiempo_contra_pared >= tuning.escalada_auto_tiempo


## ¿Hay techo que impida volver a la altura completa?
##
## Es lo que atrapa al jugador dentro de un túnel bajo: soltar el botón no basta,
## hace falta que haya sitio.
func techo_bloquea() -> bool:
	return techo.bloqueado


## ¿La cápsula está encogida ahora mismo? Lo consultan los ataques para saber si
## toca patada baja.
func esta_agachado() -> bool:
	return _altura_actual < 0.85


func _actualizar_altura(delta: float) -> void:
	if _collider == null or not _collider.shape is CapsuleShape3D:
		return
	if is_equal_approx(_altura_actual, _altura_objetivo):
		return
	_altura_actual = lerpf(
		_altura_actual, _altura_objetivo,
		1.0 - exp(-delta / maxf(tuning.agachado_transicion, 0.001))
	)
	if absf(_altura_actual - _altura_objetivo) < 0.01:
		_altura_actual = _altura_objetivo

	var alto := _altura_base * _altura_actual
	var forma := _collider.shape as CapsuleShape3D
	forma.height = alto
	_collider.position.y = alto * 0.5
	if visual != null:
		visual.scale.y = _altura_actual


func camara() -> Camera3D:
	return get_viewport().get_camera_3d()


# --- Combate ------------------------------------------------------------------

## Punto de entrada de TODO el daño que recibe el jugador. Lo llama la Hurtbox.
##
## El orden importa: i-frames primero (un dash bien medido lo esquiva todo), luego
## el estado activo por si está parrieando, y solo entonces el daño.
func recibir_golpe(golpe: Golpe) -> int:
	if not salud.vivo:
		return Golpe.Resultado.INMUNE
	if iframes > 0.0:
		return Golpe.Resultado.INMUNE

	if fsm.actual != null and fsm.actual.has_method("interceptar"):
		var r: int = fsm.actual.interceptar(golpe)
		if r != Golpe.Resultado.IMPACTO:
			return r

	salud.aplicar(golpe.dano())
	var quiebre := poise.aplicar(golpe.poise())

	HitstopManager.golpe(golpe.datos.hitstop if golpe.datos else 0.05, [self, golpe.atacante])
	EventBus.camara_shake.emit(0.9, 0.16)
	CombatFX.impacto(get_parent(), golpe.punto + Vector3.UP * 0.9, color_de(&"carmesi"), 1.1)
	EventBus.hit_landed.emit(golpe.atacante, self, golpe.dano())

	if not salud.vivo:
		EventBus.player_died.emit(&"combate")
		_revivir()
		return Golpe.Resultado.IMPACTO

	fsm.cambiar(&"Hitstun", {
		"empuje": golpe.empuje_mundo() * (1.6 if quiebre else 1.0),
		"duracion": 0.4 if quiebre else 0.22,
		"desde": golpe.direccion,
	})
	return Golpe.Resultado.IMPACTO


func esta_vivo() -> bool:
	return salud.vivo


## Resuelve un nombre de color de la Palette. Ningún hex a mano (CLAUDE.md #9).
func color_de(nombre: StringName) -> Color:
	var p := GameState.palette
	if p == null:
		return Color.WHITE
	var v: Variant = p.get(nombre)
	return v if v is Color else Color.WHITE


## En el Gym morir no tiene consecuencias: vuelves entero. La muerte de verdad
## llega con los colosos.
func _revivir() -> void:
	salud.actual = salud.maxima
	salud.vivo = true
	stamina.llenar()
	global_position = Vector3(0.0, 2.0, 4.0)
	velocity = Vector3.ZERO
	fsm.cambiar(&"Fall")


# --- Interno ------------------------------------------------------------------

func _actualizar_visual(delta: float) -> void:
	if visual == null:
		return
	_seguir_velocidad()

	# La recuperacion de verticalidad manda mientras dure: es el unico momento en
	# que el cuerpo tiene que ignorar su propia rotacion anterior y volver a cero.
	if _recuperacion > 0.0:
		_enderezar_paso(delta)
		return
	if _orientacion_3d:
		return

	if _tiene_giro:
		visual.rotation.y = rotate_toward(
			visual.rotation.y, _giro_objetivo, deg_to_rad(tuning.giro_grados_seg) * delta
		)
	visual.rotation.z = lerpf(visual.rotation.z, deg_to_rad(_alabeo), 1.0 - exp(-9.0 * delta))

	# Voltereta del backflip: gira sobre su eje lateral y se apaga sola.
	if _giro_visual_restante > 0.0:
		var paso: float = minf(_giro_visual * delta, _giro_visual_restante)
		visual.rotate_object_local(Vector3.RIGHT, deg_to_rad(-paso))
		_giro_visual_restante -= paso
		if _giro_visual_restante <= 0.0:
			visual.rotation.x = 0.0


## El rumbo lo sigue marcando la velocidad, tambien mientras el cuerpo se endereza:
## salir del agua nadando no deberia congelar el giro durante la recuperacion.
func _seguir_velocidad() -> void:
	var plano := superficie.plano(velocity)
	if plano.length_squared() > 0.25:
		_giro_objetivo = atan2(plano.x, plano.z)
		_tiene_giro = true


## Un paso de la vuelta a la vertical. El destino es exactamente la postura que
## produce la logica de tierra —yaw + alabeo, pitch a cero—, asi que cuando acaba
## el relevo es invisible.
func _enderezar_paso(delta: float) -> void:
	_recuperacion = maxf(_recuperacion - delta, 0.0)
	var objetivo := Quaternion.from_euler(
		Vector3(0.0, _giro_objetivo, deg_to_rad(_alabeo))
	)
	var peso: float = clampf(deg_to_rad(tuning.enderezar_grados_seg) * delta, 0.0, 1.0)
	visual.quaternion = visual.quaternion.slerp(objetivo, peso)

	# Se cierra por tiempo o por cercania, lo que llegue antes. Sin el corte por
	# cercania una recuperacion corta acabaria a medias; sin el corte por tiempo,
	# un slerp asintotico no terminaria nunca.
	if _recuperacion <= 0.0 or visual.quaternion.angle_to(objetivo) < deg_to_rad(1.0):
		visual.rotation = Vector3(0.0, _giro_objetivo, deg_to_rad(_alabeo))
		_recuperacion = 0.0


## ¿Sigue el cuerpo volviendo a la vertical? Lo consulta el DebugOverlay.
func enderezando() -> bool:
	return _recuperacion > 0.0


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
	floor_max_angle = deg_to_rad(tuning.angulo_max_suelo())


func _debug() -> void:
	DebugOverlay.set_line("estado", fsm.debug_line())
	DebugOverlay.set_line("vel", "%.1f m/s   vy %.1f" % [motor.rapidez_plana(), motor.get_vertical()])
	DebugOverlay.set_line("stamina", "%s %.0f%%" % ["█".repeat(int(stamina.fraccion() * 12.0)).rpad(12, "░"), stamina.fraccion() * 100.0])
	DebugOverlay.set_line("aire", "coyote %.0fms · dash %d · saltos %d%s" % [
		_coyote * 1000.0, dash_cargas, saltos_aereos, " · wallrun" if wallrun_disponible else ""
	])
	DebugOverlay.set_line("suelo", suelo.debug_line())
	DebugOverlay.set_line("pared", pared.debug_line())
	DebugOverlay.set_line("techo", "%s   capsula %.0f%%" % [techo.debug_line(), _altura_actual * 100.0])
	DebugOverlay.set_line("agua", agua.debug_line())
	if ventana_sidejump > 0.0 or tiempo_contra_pared > 0.05:
		DebugOverlay.set_line("intencion", "sidejump %.0fms · pared %.0fms" % [
			ventana_sidejump * 1000.0, tiempo_contra_pared * 1000.0])
	DebugOverlay.set_line("borde", borde.debug_line())
	DebugOverlay.set_line("superficie", superficie.debug_line())
	DebugOverlay.set_line("vida", "%s %.0f%%   poise %.0f%%%s" % [
		"█".repeat(int(salud.fraccion() * 10.0)).rpad(10, "░"),
		salud.fraccion() * 100.0, poise.fraccion() * 100.0,
		"  QUEBRADA" if poise.rota else ""])
	DebugOverlay.set_line("objetivo", targeting.debug_line())
	DebugOverlay.set_line("buffer", buffer.debug_line())
	DebugOverlay.set_line("pos", "%.1f, %.1f, %.1f" % [global_position.x, global_position.y, global_position.z])
