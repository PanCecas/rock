class_name Enemigo
extends CharacterBody3D
## El CUERPO de un enemigo: componentes, dano, muerte y orquestacion. Nada de IA.
##
## Es el equivalente de `PlayerController` para el bando contrario, y tiene la
## misma regla: aqui no se decide "que hago ahora". Eso vive en la FSM.
##
## Antes esto y la IA y la fisica compartian un archivo de 372 lineas, y por eso
## escribir un enemigo volador significaba duplicarlo entero para cambiar tres
## lineas de gravedad. Ahora:
##
##   EnemyMotor   -> COMO se mueve   (suelo / vuelo)
##   states/      -> QUE hace        (un nodo por estado)
##   Enemigo      -> QUE es          (vida, postura, hitbox, muerte)
##
## `vuela = true` es todo lo que separa a un guardian de un volador.

@export var ataque: AttackData
@export var palette: Palette

@export_group("Locomocion")
## VUELO: apaga la gravedad y habilita el eje vertical. Un enemigo volador o
## acuatico no necesita ni una linea de IA distinta, solo esto.
@export var vuela: bool = false
@export var velocidad: float = 3.4
@export_range(1.0, 100.0, 1.0) var aceleracion: float = 24.0
## Grados por segundo que puede girar sobre si mismo. Es el valor de DISEÑO: un
## bicho pequeño gira como un bicho pequeño y uno de siete metros no deberia
## poder dar una vuelta por segundo.
@export_range(15.0, 720.0, 5.0) var velocidad_giro: float = 360.0
## RED DE SEGURIDAD, en m/s: lo mas rapido que el borde del cuerpo puede barrer
## el suelo al girar.
##
## Existe porque un cuerpo en la capa WORLD es una PLATAFORMA MOVIL para
## `move_and_slide`, y girar arrastra a quien tenga encima a velocidad ω·r sin
## tocarle la velocidad. Con el coloso —radio 2.2 y giro a 360°/s— eso eran
## **13.8 m/s**, mas rapido que correr: el jugador salia disparado en circulos.
##
## El tope se aplica sobre el RADIO REAL del cuerpo, asi que protege tambien a
## los enemigos que aun no existen. El valor por defecto es lo bastante alto como
## para no tocar a los Guardianes (radio 0.45 -> permite 509°/s, muy por encima
## de su giro de diseño): quien lo nota es el que es grande, que es quien debe.
@export_range(0.5, 20.0, 0.1) var arrastre_maximo: float = 4.0

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
## Pausa entre ataques. Sin esto el Lancero es una picadora injusta.
@export_range(0.1, 5.0, 0.05) var cadencia: float = 1.4

@onready var salud: HealthComponent = $Salud
@onready var poise: PoiseComponent = $Poise
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual: MeshInstance3D = $Visual/Cuerpo
@onready var marca: MeshInstance3D = $Visual/Marca
@onready var fsm: EnemyStateMachine = $FSM

var motor: EnemyMotor
var objetivo: Node3D = null
## Cuenta atras entre ataques. La arma `Recuperar` y la lee `Acercarse`.
var espera: float = 0.0
## Duracion del tambaleo y del derribo del ULTIMO golpe recibido. Las escribe
## `recibir_golpe` y las leen los estados correspondientes.
var stagger: float = 0.45
var derribo: float = 1.6
var frame_ataque: int = 0

var _mat: StandardMaterial3D
## El golpe que esta matando: lo necesita `_al_morir` para lanzar el cadaver.
var _golpe_mortal: Golpe = null

## Nombres de estado por valor del enum heredado. Existe SOLO por compatibilidad:
## las herramientas y los tests hablan en `Estado.DERRIBADO`, y romper eso no
## aportaba nada. La FSM manda; esto es un traductor de ida y vuelta.
const NOMBRES := [
	&"Dormido", &"Acercarse", &"Telegrafia", &"Atacar", &"Recuperar",
	&"Aturdido", &"Derribado", &"Quebrado", &"Muerto",
]


## Radio real del cuerpo, medido del collider. Lo usa el tope de giro.
var _radio: float = 0.0


func _ready() -> void:
	if palette == null:
		palette = GameState.palette
	add_to_group(&"enemigos")
	_radio = _medir_radio()
	motor = EnemyMotor.new(self)
	motor.vuela = vuela
	motor.aceleracion = aceleracion
	_preparar_material()
	salud.muerto.connect(_al_morir)
	poise.quebrada.connect(_al_quebrar)
	poise.restaurada.connect(func() -> void:
		if fsm.nombre_actual() == &"Quebrado":
			fsm.cambiar(&"Recuperar"))
	hitbox.impacto.connect(_al_impactar)
	configurar_tipo()
	fsm.configurar(self)


func _physics_process(delta: float) -> void:
	if HitstopManager.global_activo() or HitstopManager.esta_congelado(self):
		return

	espera = maxf(0.0, espera - delta)
	if fsm.nombre_actual() != &"Muerto":
		motor.aplicar_gravedad(delta)
	fsm.physics_update(delta)
	move_and_slide()
	_actualizar_color()


# --- Estado, con traductor al enum viejo -------------------------------------

## El valor del enum que corresponde al estado actual de la FSM. Se puede leer y
## asignar: asignarlo cambia de estado de verdad.
var estado: int:
	get:
		return NOMBRES.find(fsm.nombre_actual()) if fsm != null else 0
	set(valor):
		if fsm != null and valor >= 0 and valor < NOMBRES.size():
			fsm.cambiar(NOMBRES[valor])


# --- Dano ---------------------------------------------------------------------

## Punto de entrada del dano. Lo llama la Hurtbox.
func recibir_golpe(golpe: Golpe) -> int:
	if fsm.nombre_actual() == &"Muerto":
		return Golpe.Resultado.INMUNE

	if bloquea(golpe):
		CombatFX.impacto(get_parent(), golpe.punto + Vector3.UP, color_de(&"lavanda_gris"), 0.8)
		EventBus.camara_shake.emit(0.3, 0.1)
		# Bloquear igualmente cuesta postura: la guardia se puede romper a golpes.
		poise.aplicar(golpe.poise() * 0.5)
		return Golpe.Resultado.BLOQUEADO

	# Se guarda ANTES de aplicar el dano: si este golpe mata, `_al_morir` se dispara
	# dentro de `salud.aplicar()` y necesita saber quien y con que.
	_golpe_mortal = golpe
	salud.aplicar(golpe.dano())
	var quiebre := poise.aplicar(golpe.poise())
	CombatFX.impacto(get_parent(), golpe.punto + Vector3.UP, color_de(&"carmesi"), 1.0)
	EventBus.hit_landed.emit(golpe.atacante, self, golpe.dano())

	if not salud.vivo:
		return Golpe.Resultado.IMPACTO

	var empuje := golpe.empuje_mundo()
	velocity = Vector3(empuje.x, maxf(empuje.y, 0.0), empuje.z)

	# DERRIBO: la patada baja no tambalea, tumba.
	if golpe.datos != null and golpe.datos.derribo:
		derribo = golpe.datos.derribo_duracion
		CombatFX.onda(get_parent(), global_position + Vector3.UP * 0.2, color_de(&"oro_palido"), 2.0)
		fsm.cambiar(&"Derribado")
		return Golpe.Resultado.IMPACTO

	if not quiebre and fsm.nombre_actual() != &"Quebrado":
		# El stagger lo dicta el ataque: es el castigo terrestre, la alternativa a
		# mandar al enemigo por los aires.
		stagger = golpe.datos.stagger if golpe.datos != null and golpe.datos.stagger > 0.0 else 0.45
		fsm.cambiar(&"Aturdido")
	return Golpe.Resultado.IMPACTO


## Si nos parrean, el golpe se cancela y quedamos abiertos. Es el premio del parry.
func _al_impactar(golpe: Golpe) -> void:
	if golpe.resultado == Golpe.Resultado.PARRY or golpe.resultado == Golpe.Resultado.PARRY_PERFECTO:
		poise.actual = 0.0
		_al_quebrar()
		poise.rota = true


func _al_quebrar() -> void:
	if fsm.nombre_actual() == &"Muerto":
		return
	fsm.cambiar(&"Quebrado")
	CombatFX.onda(get_parent(), global_position + Vector3.UP, color_de(&"oro_palido"), 2.6)
	EventBus.guard_broken.emit(self)


## Muerte con cadaver fisico. Si el golpe que remata trae `fuerza_muerte`, el
## cuerpo sale despedido por donde venia el golpe.
func _al_morir() -> void:
	fsm.cambiar(&"Muerto")
	CombatFX.onda(get_parent(), global_position + Vector3.UP, color_de(&"crema_bruma"), 3.4)
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


# --- Ganchos que las subclases redefinen -------------------------------------

## ¿Este enemigo bloquea este golpe? Por defecto nadie bloquea: es del Escudo.
func bloquea(_golpe: Golpe) -> bool:
	return false


## Empuje hacia delante en el frame activo del ataque. Cero salvo que la subclase
## quiera castigar quedarse justo fuera de rango.
func avance_al_golpear() -> float:
	return 0.0


## ¿Este enemigo ve al jugador? Por defecto, un radio: te ve venir desde
## cualquier lado. El embestidor lo redefine con un cono de vision, que es lo que
## hace que se le pueda flanquear.
func detecta(j: Node3D) -> bool:
	return j != null and global_position.distance_to(j.global_position) < vista


## Estado con el que este enemigo ataca. El guardian telegrafia y golpea; el
## embestidor anticipa y carga. La aproximacion es la misma para los dos.
func estado_de_ataque() -> StringName:
	return &"Telegrafia"


## Estado al que se pasa al ver al jugador.
func estado_al_despertar() -> StringName:
	return &"Acercarse"


## Distancia por debajo de la cual RETROCEDE. Cero = va a por ti sin mas.
func distancia_minima() -> float:
	return 0.0


## Ajustes por arquetipo. Se llama antes de arrancar la FSM.
func configurar_tipo() -> void:
	pass


# --- Utilidades que usan los estados -----------------------------------------

func jugador() -> Node3D:
	return GameState.player


## Sin comprobacion de distancia a proposito: una vez te ha visto, te persigue.
## Anadir un radio de "olvido" aqui hacia que soltara la presa a media persecucion.
func objetivo_valido() -> bool:
	return objetivo != null and is_instance_valid(objetivo)


## Vector horizontal hacia el objetivo, o ZERO si no hay.
func hacia_objetivo() -> Vector3:
	if not objetivo_valido():
		return Vector3.ZERO
	var d := objetivo.global_position - global_position
	if not vuela:
		d.y = 0.0
	return d


func encarar(hacia: Vector3) -> void:
	var d := hacia
	d.y = 0.0
	if d.length_squared() < 0.01:
		return
	var objetivo_yaw := atan2(d.x, d.z)
	rotation.y = rotate_toward(rotation.y, objetivo_yaw, giro_maximo() * get_physics_process_delta_time())


## Velocidad angular efectiva, en rad/s: la de diseño, recortada por el arrastre
## que el borde del cuerpo puede hacer sobre quien tenga encima.
func giro_maximo() -> float:
	var tope := deg_to_rad(velocidad_giro)
	if _radio > 0.01:
		tope = minf(tope, arrastre_maximo / _radio)
	return tope


## A que velocidad barre el suelo el borde de este cuerpo al girar al tope, en
## m/s. Es EL numero del bug del coloso, y por eso es publico: se puede afirmar
## sobre el en un test en vez de tener que reproducir el mareo a mano.
func arrastre_en_el_borde() -> float:
	return giro_maximo() * _radio


## Radio real de la capsula del cuerpo. Se mide, no se declara: declararlo a mano
## en cada escena es como se llega a que un enemigo mienta sobre su tamaño.
func _medir_radio() -> float:
	var col := get_node_or_null("Collider") as CollisionShape3D
	if col == null:
		return 0.0
	var f := col.shape
	if f is CapsuleShape3D:
		return (f as CapsuleShape3D).radius
	if f is SphereShape3D:
		return (f as SphereShape3D).radius
	if f is CylinderShape3D:
		return (f as CylinderShape3D).radius
	if f is BoxShape3D:
		var s := (f as BoxShape3D).size
		return maxf(s.x, s.z) * 0.5
	return 0.0


func color_de(nombre: StringName) -> Color:
	if palette == null:
		return Color.WHITE
	var v: Variant = palette.get(nombre)
	return v if v is Color else Color.WHITE


func _preparar_material() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color_de(&"piedra_media")
	_mat.roughness = 0.9
	if visual != null:
		visual.material_override = _mat


## El color dice en que estado esta sin necesidad de leer el panel de debug. Es la
## unica telegrafia que tiene una capsula gris.
func _actualizar_color() -> void:
	if _mat == null:
		return
	var destino := color_de(&"piedra_media")
	match fsm.nombre_actual():
		&"Telegrafia": destino = color_de(&"oro_palido")
		&"Atacar": destino = color_de(&"carmesi")
		&"Aturdido", &"Derribado": destino = color_de(&"lavanda_gris")
		&"Quebrado": destino = color_de(&"blanco_tiza")
	_mat.albedo_color = _mat.albedo_color.lerp(destino, 0.2)
	if marca != null:
		marca.visible = fsm.nombre_actual() == &"Quebrado"
