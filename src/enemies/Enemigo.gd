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
## Distancia a la que SUELTA la presa, en metros. 0 = no la suelta nunca, que es
## el defecto y el comportamiento historico. Ver `objetivo_valido()`: si se
## activa, tiene que ser mayor que `vista` o el enemigo parpadea.
@export_range(0.0, 120.0, 1.0) var radio_olvido: float = 0.0
## Distancia a la que se planta y ataca.
@export var alcance_ataque: float = 2.6
## Pausa entre ataques. Sin esto el Lancero es una picadora injusta.
@export_range(0.1, 5.0, 0.05) var cadencia: float = 1.4

@export_group("Patrulla")
## Puntos por los que ronda mientras no te ha visto, en coordenadas de MUNDO.
##
## Vacio = se queda quieto, que es lo que hacian los seis enemigos hasta ahora.
## Una lista con puntos lo pone a caminar entre ellos, y eso cambia mucho como se
## lee una sala: un enemigo parado es un obstaculo, uno que ronda es un habitante.
@export var ruta: PackedVector3Array = []
## Segundos que espera en cada punto antes de ir al siguiente. Cero da una ronda
## mecanica; una pausa la hace parecer una decision.
@export_range(0.0, 10.0, 0.1) var espera_en_punto: float = 1.2
## A que distancia de un punto se considera alcanzado.
@export_range(0.2, 5.0, 0.1) var radio_punto: float = 1.0
## Fraccion de `velocidad` a la que patrulla. Patrullar corriendo se lee como
## perseguir, y entonces ver al enemigo perseguirte de verdad deja de significar
## nada.
@export_range(0.1, 1.0, 0.05) var velocidad_patrulla: float = 0.45

@export_group("Agarre")
## ¿Se le puede clavar una daga y zarandearlo?
##
## **Falso por defecto, y el defecto es la regla.** El `ColosoMediano` y cualquier
## cosa grande se quedan fuera: zarandear algo de siete metros no es creíble, y el
## punto débil ya tiene su verbo contra ellos.
##
## Lo declara el ENEMIGO y no lo adivina la daga, igual que `WeakPoint.llave`:
## añadir un bicho agarrable es escribirle un `true` en su `.tscn`, sin abrir el
## arma.
@export var agarrable: bool = false
## Lo que pesa mientras cuelga de ti, en fracción de tu velocidad. 1 = no te frena;
## 0.5 = te deja a la mitad. Es lo que impide que llevar un cuerpo colgando salga
## gratis.
@export_range(0.1, 1.0, 0.05) var masa_agarre: float = 0.62
## Golpe en AREA que suelta al estamparse contra el suelo. Sin el, estampar solo
## empuja: el area es lo que convierte el zarandeo en una respuesta a un grupo.
@export var ataque_estampido: AttackData

@export_group("Navegacion")
## Cuanto tiene que moverse el destino para recalcular la ruta, en metros.
## Reescribirla cada frame hace trabajar al servidor 60 veces por segundo y por
## enemigo sin que el camino cambie.
@export_range(0.1, 10.0, 0.1) var nav_repath: float = 1.0

@onready var salud: HealthComponent = $Salud
@onready var poise: PoiseComponent = $Poise
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual: MeshInstance3D = $Visual/Cuerpo
@onready var marca: MeshInstance3D = $Visual/Marca
@onready var fsm: EnemyStateMachine = $FSM
## NAVEGACION, **opcional**. Si la escena trae un `NavigationAgent3D` llamado
## `Nav`, el enemigo rodea la geometria; si no, va en linea recta como siempre.
##
## Opcional y no obligatorio a proposito: los seis enemigos que ya existen no lo
## tienen y tienen que seguir funcionando igual. Un componente nuevo que obliga a
## tocar seis escenas para no romperlas no es una mejora, es una migracion.
@onready var nav: NavigationAgent3D = get_node_or_null("Nav") as NavigationAgent3D

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
## Ultimo destino que se le paso al agente de navegacion. Sirve para no repathear
## cada frame; ver `rumbo_hacia()`.
var _nav_destino: Vector3 = Vector3(9e9, 9e9, 9e9)
## Indice del punto de ruta al que va. Lo lleva `Patrulla`.
var punto_ruta: int = 0
## Velocidad con la que se lanzo este cuerpo al estamparlo. La escribe
## `StateWhirl` y la lee `EnemyEstampado` para escalar el dano del impacto: un
## cuerpo que llevabas quieto cae, y uno que llevabas lanzado revienta.
var impacto_estampido: float = 0.0


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
	# La gravedad NO se aplica agarrado: quien zarandea usa la suya, SIMETRICA
	# (regla dura #16). La del juego es asimetrica y un pendulo con ella gana
	# altura solo — medido, 6 m por pasada.
	var n := fsm.nombre_actual()
	if n != &"Muerto" and n != &"Agarrado":
		motor.aplicar_gravedad(delta)
	fsm.physics_update(delta)
	move_and_slide()
	_actualizar_color()
	_dibujar_gizmos()


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
	var direccion := frente()
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


## LOS DOS ARQUETIPOS, y no hacen falta dos clases para tenerlos.
##
##   CUERPO A CUERPO -> `distancia_minima() == 0`. Acorta distancia y pega. Es el
##     defecto: el Lancero, el Escudo, el Embestidor.
##   A DISTANCIA     -> `distancia_minima() > 0` y `necesita_linea_de_vision()`.
##     Mantiene el hueco y solo dispara si te ve. El Vigia y el Volador.
##
## Son dos NUMEROS y no dos jerarquias porque acercarse y alejarse son el mismo
## problema con el signo cambiado, y "disparar" y "pegar" son el mismo estado con
## otro `AttackData`. Una clase `EnemyRanged` aparte obligaria a duplicar la
## deteccion, el aturdido, la muerte y el ragdoll para cambiar dos condiciones.

## Distancia por debajo de la cual RETROCEDE. Cero = va a por ti sin mas.
func distancia_minima() -> float:
	return 0.0


## ¿Necesita VERTE para atacar? Falso por defecto: quien pega de cerca ya tiene
## que llegar hasta ti, y exigirle ademas un rayo limpio lo dejaria parado contra
## cualquier saliente. Cierto para el arquetipo a distancia, donde es justo lo que
## hace que la cobertura sirva de algo.
func necesita_linea_de_vision() -> bool:
	return false


## Ajustes por arquetipo. Se llama antes de arrancar la FSM.
func configurar_tipo() -> void:
	pass


# --- Utilidades que usan los estados -----------------------------------------

func jugador() -> Node3D:
	return GameState.player


## ¿Sigue habiendo presa?
##
## Con `radio_olvido` en 0 —el defecto— NO hay comprobacion de distancia: una vez
## te ha visto, te persigue. Fue deliberado, y sigue siendo lo correcto por
## defecto: un radio de olvido apretado hace que el enemigo suelte la presa a
## media persecucion y se lea como que se ha roto.
##
## Pero para un enemigo de carga tiene sentido poder decir "si te alejas tanto,
## deja de importarte": un toro no persigue tres pantallas. Por eso es un numero y
## no una regla, y por eso es MAYOR que `vista` en cuanto se activa —olvidar antes
## de dejar de ver seria un parpadeo constante entre perseguir y dormir—.
func objetivo_valido() -> bool:
	if objetivo == null or not is_instance_valid(objetivo):
		return false
	if radio_olvido <= 0.0:
		return true
	return global_position.distance_to(objetivo.global_position) <= radio_olvido


## Vector horizontal hacia el objetivo, o ZERO si no hay.
func hacia_objetivo() -> Vector3:
	if not objetivo_valido():
		return Vector3.ZERO
	var d := objetivo.global_position - global_position
	if not vuela:
		d.y = 0.0
	return d


## EL FRENTE DE UN CUERPO ES `-basis.z`. EN TODO EL PROYECTO.
##
## Aqui estuvo el bug del embestidor que se sentia "al reves y poco natural", y no
## era del embestidor: era de esta funcion. `atan2(d.x, d.z)` deja `+basis.z`
## apuntando al objetivo —medido: hacia=(0,0,1) da yaw 0 y `+basis.z`=(0,0,1)—
## mientras que TODAS las demas lineas del bando enemigo leen `-basis.z` como el
## morro. Encarar te daba la ESPALDA, y a partir de ahi:
##
##   · el cono de vision del embestidor miraba hacia atras: te detectaba solo si
##     estabas detras, que es justo lo contrario de lo que promete tener un cono.
##   · `Anticipar` fijaba `rumbo = -basis.z` y la carga salia HUYENDO de ti.
##   · `Atacar` golpeaba hacia atras: el empuje mandaba al jugador HACIA el
##     enemigo en vez de apartarlo.
##   · el volador "huia" acercandose, y el cadaver salia despedido al reves.
##
## Un solo `atan2` con el signo cambiado arregla los cinco, porque los cinco
## estaban bien: el unico que mentia era este. Y por eso la correccion va aqui y
## no en cada sitio —invertir los cinco lectores habria dejado el proyecto con dos
## convenios de "frente" conviviendo, que es como se volveria a romper—.
## HACIA DONDE MOVERSE para llegar a `destino`, rodeando la geometria si se puede.
##
## Es el unico sitio del bando enemigo que sabe que existe la navegacion, y por eso
## `Acercarse` y `Patrulla` no cambian: siguen pidiendo "llevame ahi" y reciben un
## vector. Si no hay agente, si no hay navmesh, o si el destino no es alcanzable,
## devuelve la linea recta —que es lo que el juego lleva haciendo desde la Fase 2 y
## funciona—. La navegacion es una MEJORA, no un requisito.
##
## Los que vuelan van siempre rectos: un navmesh es una superficie, y pedirle la
## ruta a un bicho que se mueve por el aire da un camino pegado al suelo.
func rumbo_hacia(destino: Vector3) -> Vector3:
	var recto := destino - global_position
	if not vuela:
		recto.y = 0.0
	if nav == null or vuela:
		return recto

	# Repath solo si el destino se ha movido de verdad. Reescribir `target_position`
	# cada frame obliga al servidor a recalcular la ruta 60 veces por segundo por
	# enemigo, y eso con una sala llena se nota antes que la propia IA.
	if destino.distance_squared_to(_nav_destino) > nav_repath * nav_repath:
		_nav_destino = destino
		nav.target_position = destino

	if nav.is_navigation_finished() or not nav.is_target_reachable():
		return recto
	var paso := nav.get_next_path_position() - global_position
	if not vuela:
		paso.y = 0.0
	# Sin navmesh util el agente devuelve su propia posicion. Sin este guardia el
	# enemigo se quedaria clavado en el sitio, que se lee como que se ha colgado.
	return recto if paso.length_squared() < 0.0001 else paso


## ¿HAY LINEA DE VISION hasta ese punto? Un rayo a la altura de los ojos.
##
## Vivia dentro de `Embestidor.detecta()` y se ha subido aqui porque hacen falta
## dos cosas distintas con ella: detectar (el cono del embestidor) y DISPARAR (el
## arquetipo a distancia no debe tirar a traves de una columna). Dos copias del
## mismo rayo es como se llega a que una vea la pared y la otra no.
func hay_linea_de_vision(hacia: Node3D, altura: float = 1.2) -> bool:
	if hacia == null or not is_instance_valid(hacia):
		return false
	var espacio := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * altura,
		hacia.global_position + Vector3.UP * altura,
		Layers.WORLD)
	q.exclude = [get_rid()]
	return espacio.intersect_ray(q).is_empty()


func encarar(hacia: Vector3) -> void:
	var d := hacia
	d.y = 0.0
	if d.length_squared() < 0.01:
		return
	var objetivo_yaw := atan2(-d.x, -d.z)
	rotation.y = rotate_toward(rotation.y, objetivo_yaw, giro_maximo() * get_physics_process_delta_time())


## El frente REAL de este cuerpo, ya normalizado y sin componente vertical.
##
## Existe para que nadie vuelva a escribir el signo a mano: cinco copias de
## `-global_basis.z` repartidas por los estados son cinco sitios donde el convenio
## puede volver a divergir, y ya divergio una vez.
func frente() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized() if not f.is_zero_approx() else Vector3.FORWARD


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


## GIZMOS (F7). Lo que un enemigo "decide" es invisible, y por eso depurarlo a
## ciegas cuesta tanto: un bicho que no reacciona puede estar dormido, puede
## tenerte fuera del cono, puede tener una columna en medio, o puede estar roto.
## Los cuatro casos se leen igual mirándolo.
func _dibujar_gizmos() -> void:
	if not DebugDraw.activo or palette == null:
		return

	# EL CONO DE VISION, con el alcance real. Es el gizmo que convierte "no me ve"
	# en una respuesta y no en una sospecha.
	var semiangulo: float = get("cono_grados") if get("cono_grados") != null else 180.0
	DebugDraw.cono(global_position + Vector3.UP * 1.2, frente(),
		minf(semiangulo, 88.0), vista, palette.lavanda_gris)

	# LINEA DE VISION al jugador: verde si hay, roja si algo la corta. Junto al
	# cono, las dos mitades de "por que no reacciona" quedan a la vista.
	var j := jugador()
	if j != null and is_instance_valid(j):
		var hay := hay_linea_de_vision(j)
		DebugDraw.linea(global_position + Vector3.UP * 1.2,
			j.global_position + Vector3.UP * 1.2,
			palette.pasto_sol if hay else palette.carmesi)

	# ALCANCE DE ATAQUE y distancia minima: los dos anillos entre los que el
	# enemigo se queda quieto. Ver por que "no se acerca mas" es media depuracion.
	DebugDraw.esfera(global_position, alcance_ataque, palette.oro_palido)
	var minima := distancia_minima()
	if minima > 0.0:
		DebugDraw.esfera(global_position, minima, palette.carmesi)

	# LA RUTA DE PATRULLA, con el punto al que va marcado. Sin esto, una ronda mal
	# puesta —un punto dentro de un muro— es indistinguible de una IA rota.
	if not ruta.is_empty():
		for i in ruta.size():
			var a: Vector3 = ruta[i]
			var b: Vector3 = ruta[(i + 1) % ruta.size()]
			DebugDraw.linea(a, b, palette.crema_medio)
			DebugDraw.punto(a, 0.4, palette.crema_medio)
		DebugDraw.punto(ruta[punto_ruta % ruta.size()], 0.9, palette.oro_palido)
