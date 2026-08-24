class_name Guardian
extends CharacterBody3D
## Guardián de Ruina: constructo de piedra. Existe para que el combate tenga con
## qué practicarse, no para poblar el mundo.
##
## Los tres arquetipos comparten este script y se diferencian por datos:
##   LANCERO — agresivo, presiona y castiga la pasividad
##   ESCUDO  — bloquea de frente; su ataque cargado es EL objetivo del parry
##   VIGIA   — a distancia, obliga a moverse
##
## FSM propia y minúscula a propósito: la IA no es el punto de la Fase 2. Lo que
## importa es que telegrafíe con claridad para que el parry se pueda entrenar.

enum Tipo { LANCERO, ESCUDO, VIGIA }
enum Estado { DORMIDO, ACERCARSE, TELEGRAFIA, ATACAR, RECUPERAR, ATURDIDO, DERRIBADO, QUEBRADO, MUERTO }

@export var tipo: Tipo = Tipo.LANCERO
@export var ataque: AttackData
@export var palette: Palette

@export_group("Muerte")
## Multiplicador local sobre la `fuerza_muerte` del ataque que remata. Permite que
## un enemigo pesado salga menos despedido que uno ligero con el mismo golpe.
@export_range(0.0, 3.0, 0.05) var ragdoll_mult: float = 1.0
@export_range(0.0, 30.0, 0.5) var ragdoll_torque: float = 6.0
@export_range(0.5, 30.0, 0.5) var ragdoll_vida: float = 6.0

@export_group("Comportamiento")
@export var vista: float = 18.0
## Distancia a la que se planta y ataca.
@export var alcance_ataque: float = 2.6
@export var velocidad: float = 3.4
## Pausa entre ataques. Sin esto el Lancero es una picadora injusta.
@export_range(0.1, 5.0, 0.05) var cadencia: float = 1.4
## El Escudo bloquea todo lo que llegue dentro de este semiángulo frontal.
@export_range(0.0, 180.0, 5.0) var arco_guardia: float = 70.0

@onready var salud: HealthComponent = $Salud
@onready var poise: PoiseComponent = $Poise
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual: MeshInstance3D = $Visual/Cuerpo
@onready var marca: MeshInstance3D = $Visual/Marca

var estado: int = Estado.DORMIDO
var objetivo: Node3D = null

var _t: float = 0.0
var _frame_ataque: int = 0
var _espera: float = 0.0
var _mat: StandardMaterial3D
## El golpe que está matando: lo necesita `_al_morir` para lanzar el cadáver.
var _golpe_mortal: Golpe = null
var _stagger: float = 0.45
var _derribo: float = 1.6


func _ready() -> void:
	if palette == null:
		palette = GameState.palette
	add_to_group(&"guardianes")
	_preparar_material()
	salud.muerto.connect(_al_morir)
	poise.quebrada.connect(_al_quebrar)
	poise.restaurada.connect(func() -> void: if estado == Estado.QUEBRADO: _ir_a(Estado.RECUPERAR))
	hitbox.impacto.connect(_al_impactar)
	_configurar_tipo()


func _physics_process(delta: float) -> void:
	if HitstopManager.global_activo() or HitstopManager.esta_congelado(self):
		return

	_t += delta
	_espera = maxf(0.0, _espera - delta)

	if estado != Estado.MUERTO and not is_on_floor():
		velocity.y -= 30.0 * delta
	else:
		velocity.y = -2.0

	match estado:
		Estado.DORMIDO: _dormido()
		Estado.ACERCARSE: _acercarse(delta)
		Estado.TELEGRAFIA: _telegrafia()
		Estado.ATACAR: _atacar()
		Estado.RECUPERAR: _recuperar()
		Estado.ATURDIDO, Estado.DERRIBADO, Estado.QUEBRADO: _quieto(delta)
		Estado.MUERTO: _quieto(delta)

	move_and_slide()
	_actualizar_color()


# --- Estados -----------------------------------------------------------------

func _dormido() -> void:
	_frenar()
	var j := _jugador()
	if j != null and global_position.distance_to(j.global_position) < vista:
		objetivo = j
		_ir_a(Estado.ACERCARSE)


func _acercarse(delta: float) -> void:
	if not _objetivo_valido():
		_ir_a(Estado.DORMIDO)
		return
	var hacia := objetivo.global_position - global_position
	hacia.y = 0.0
	var dist := hacia.length()
	_encarar(hacia)

	# El Vigía mantiene distancia; los otros dos van a por ti.
	var deseada := alcance_ataque
	if tipo == Tipo.VIGIA and dist < alcance_ataque * 0.6:
		_mover(-hacia.normalized(), delta)
		return

	if dist > deseada:
		_mover(hacia.normalized(), delta)
	else:
		_frenar()
		if _espera <= 0.0:
			_ir_a(Estado.TELEGRAFIA)


## La anticipación es lo único que hace entrenable el parry: si el ataque no se
## ve venir, acertar es lotería y el jugador deja de intentarlo.
func _telegrafia() -> void:
	_frenar()
	if _objetivo_valido():
		var hacia := objetivo.global_position - global_position
		hacia.y = 0.0
		_encarar(hacia)
	if _t >= ataque.frames_a_seg(ataque.frames_windup):
		hitbox.nuevo_swing()
		_frame_ataque = ataque.frames_windup
		_ir_a(Estado.ATACAR)


func _atacar() -> void:
	_frame_ataque += 1
	if ataque.activo_en(_frame_ataque):
		# El Lancero avanza al golpear: castiga quedarse quieto justo fuera de rango.
		if tipo == Tipo.LANCERO:
			var adelante := -global_basis.z
			velocity.x = adelante.x * 5.0
			velocity.z = adelante.z * 5.0
		hitbox.golpear(ataque, -global_basis.z)
	else:
		_frenar()
	if _frame_ataque >= ataque.frames_windup + ataque.frames_activo:
		_ir_a(Estado.RECUPERAR)


func _recuperar() -> void:
	_frenar()
	if _t >= ataque.frames_a_seg(ataque.frames_recuperacion):
		_espera = cadencia
		_ir_a(Estado.ACERCARSE)


func _quieto(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	if estado == Estado.ATURDIDO and _t >= _stagger:
		_ir_a(Estado.ACERCARSE)
	elif estado == Estado.DERRIBADO and _t >= _derribo:
		_ir_a(Estado.ACERCARSE)


# --- Daño --------------------------------------------------------------------

## Punto de entrada del daño. Lo llama la Hurtbox.
func recibir_golpe(golpe: Golpe) -> int:
	if estado == Estado.MUERTO:
		return Golpe.Resultado.INMUNE

	# El Escudo bloquea de frente salvo que el ataque rompa guardia o esté quebrado.
	if _bloquea(golpe):
		CombatFX.impacto(get_parent(), golpe.punto + Vector3.UP, _color(&"lavanda_gris"), 0.8)
		EventBus.camara_shake.emit(0.3, 0.1)
		# Bloquear igualmente cuesta postura: la guardia se puede romper a golpes.
		if poise.aplicar(golpe.poise() * 0.5):
			pass
		return Golpe.Resultado.BLOQUEADO

	# Se guarda ANTES de aplicar el daño: si este golpe mata, `_al_morir` se dispara
	# dentro de `salud.aplicar()` y necesita saber quién y con qué.
	_golpe_mortal = golpe
	salud.aplicar(golpe.dano())
	var quiebre := poise.aplicar(golpe.poise())
	CombatFX.impacto(get_parent(), golpe.punto + Vector3.UP, _color(&"carmesi"), 1.0)
	EventBus.hit_landed.emit(golpe.atacante, self, golpe.dano())

	if not salud.vivo:
		return Golpe.Resultado.IMPACTO

	var empuje := golpe.empuje_mundo()
	velocity = Vector3(empuje.x, maxf(empuje.y, 0.0), empuje.z)

	# DERRIBO: la patada baja no tambalea, tumba. La ventana es larga a proposito:
	# es lo que le da una razon ofensiva a agacharse.
	if golpe.datos != null and golpe.datos.derribo:
		_derribo = golpe.datos.derribo_duracion
		CombatFX.onda(get_parent(), global_position + Vector3.UP * 0.2, _color(&"oro_palido"), 2.0)
		_ir_a(Estado.DERRIBADO)
		return Golpe.Resultado.IMPACTO

	if not quiebre and estado != Estado.QUEBRADO:
		# El stagger lo dicta el ataque: es el castigo terrestre, la alternativa a
		# mandar al enemigo por los aires.
		_stagger = golpe.datos.stagger if golpe.datos != null and golpe.datos.stagger > 0.0 else 0.45
		_ir_a(Estado.ATURDIDO)
	return Golpe.Resultado.IMPACTO


## Si nos parrean, el golpe se cancela y quedamos abiertos. Es el premio del parry.
func _al_impactar(golpe: Golpe) -> void:
	if golpe.resultado == Golpe.Resultado.PARRY or golpe.resultado == Golpe.Resultado.PARRY_PERFECTO:
		poise.actual = 0.0
		_al_quebrar()
		poise.rota = true


func _al_quebrar() -> void:
	if estado == Estado.MUERTO:
		return
	_ir_a(Estado.QUEBRADO)
	CombatFX.onda(get_parent(), global_position + Vector3.UP, _color(&"oro_palido"), 2.6)
	EventBus.guard_broken.emit(self)


## Muerte con cadáver físico. Si el golpe que remata trae `fuerza_muerte`, el
## cuerpo sale despedido por donde venía el golpe (muerte estilo Overwatch).
## Es el único sitio donde un golpe pesado manda a alguien por los aires: en vida,
## solo tambalea.
func _al_morir() -> void:
	_ir_a(Estado.MUERTO)
	CombatFX.onda(get_parent(), global_position + Vector3.UP, _color(&"crema_bruma"), 3.4)
	hurtbox.monitorable = false

	var fuerza := 0.0
	var direccion := -global_basis.z
	if _golpe_mortal != null and _golpe_mortal.datos != null:
		fuerza = _golpe_mortal.datos.fuerza_muerte * ragdoll_mult
		if not _golpe_mortal.direccion.is_zero_approx():
			direccion = _golpe_mortal.direccion

	if fuerza > 0.01:
		var torque: float = (_golpe_mortal.datos.torque_muerte if _golpe_mortal != null else 0.0)
		Ragdoll.lanzar(self, visual.mesh, _mat, direccion, fuerza, maxf(torque, ragdoll_torque), ragdoll_vida)
		queue_free()
		return

	# Sin fuerza declarada, se desploma en el sitio.
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(1.0, 0.05, 1.0), 0.5).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


func esta_vivo() -> bool:
	return salud.vivo


# --- Utilidades ---------------------------------------------------------------

func _bloquea(golpe: Golpe) -> bool:
	if tipo != Tipo.ESCUDO or poise.rota or estado == Estado.QUEBRADO:
		return false
	if golpe.datos != null and golpe.datos.rompe_guardia:
		return false
	var frente := -global_basis.z
	var desde := -golpe.direccion
	desde.y = 0.0
	if desde.is_zero_approx():
		return false
	return rad_to_deg(frente.angle_to(desde.normalized())) <= arco_guardia


func _configurar_tipo() -> void:
	match tipo:
		Tipo.LANCERO:
			salud.maxima = 60.0
			poise.maxima = 30.0
			cadencia = 1.1
			velocidad = 4.2
		Tipo.ESCUDO:
			salud.maxima = 110.0
			poise.maxima = 55.0
			cadencia = 2.0
			velocidad = 2.6
			alcance_ataque = 2.2
		Tipo.VIGIA:
			salud.maxima = 45.0
			poise.maxima = 20.0
			cadencia = 2.4
			velocidad = 3.0
			alcance_ataque = 9.0
	salud.actual = salud.maxima
	poise.actual = poise.maxima


func _ir_a(nuevo: int) -> void:
	estado = nuevo
	_t = 0.0


func _mover(dir: Vector3, delta: float) -> void:
	var deseada := dir * velocidad
	velocity.x = move_toward(velocity.x, deseada.x, 24.0 * delta)
	velocity.z = move_toward(velocity.z, deseada.z, 24.0 * delta)


func _frenar() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1.2)
	velocity.z = move_toward(velocity.z, 0.0, 1.2)


func _encarar(hacia: Vector3) -> void:
	if hacia.length_squared() < 0.01:
		return
	rotation.y = rotate_toward(rotation.y, atan2(hacia.x, hacia.z), 6.0 * get_physics_process_delta_time() * 60.0 * 0.06)


func _objetivo_valido() -> bool:
	return objetivo != null and is_instance_valid(objetivo)


func _jugador() -> Node3D:
	return GameState.player


func _preparar_material() -> void:
	_mat = StandardMaterial3D.new()
	_mat.roughness = 0.9
	visual.material_override = _mat
	var m2 := StandardMaterial3D.new()
	m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marca.material_override = m2


## El color comunica el estado sin necesidad de UI: es la regla del 10% aplicada
## al combate. Piedra desaturada en reposo, acento saturado cuando importa.
func _actualizar_color() -> void:
	if _mat == null:
		return
	var base := _color(&"piedra_media")
	match estado:
		Estado.TELEGRAFIA:
			base = _color(&"carmesi")
		Estado.QUEBRADO, Estado.DERRIBADO:
			base = _color(&"oro_palido")
		Estado.ATURDIDO:
			base = _color(&"lavanda_gris")
		Estado.DORMIDO:
			base = _color(&"piedra_sombra")
	_mat.albedo_color = _mat.albedo_color.lerp(base, 0.35)

	var m2 := marca.material_override as StandardMaterial3D
	if m2 != null:
		m2.albedo_color = _color(&"carmesi") if tipo == Tipo.LANCERO else (
			_color(&"azul_claro") if tipo == Tipo.ESCUDO else _color(&"oro_palido"))
	marca.visible = estado != Estado.MUERTO


func _color(nombre: StringName) -> Color:
	if palette == null:
		return Color.WHITE
	var v: Variant = palette.get(nombre)
	return v if v is Color else Color.WHITE
