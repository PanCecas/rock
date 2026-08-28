class_name Cordon
extends Node3D
## EL CORDÓN entre la mano y la lanza. **Puramente visual.**
##
## No colisiona, no se corta, no se dobla en las esquinas y no restringe nada. Es
## una decisión, no una carencia: una cuerda que interactúa con el mundo es un
## agujero sin fondo —el propio roadmap aparca la "cuerda física real estilo
## Loader" para después de la Fase 4— y la mecánica no la necesita. Lo que ata al
## jugador a la lanza es una **restricción analítica** sobre su posición
## (`docs/03 §5`), un número; esto es lo que hace que ese número se vea.
##
## Verlet con restricción de distancia, que es el algoritmo más barato que da una
## cuerda creíble: integras posiciones, luego empujas cada par de puntos hasta su
## separación de reposo, y repites unas cuantas veces. Sin fuerzas, sin masas, sin
## joints.
##
## Corre en `_process` y no en `_physics_process` a propósito: es imagen, así que
## va al ritmo del render y no al de la física. A 60 Hz de física y 144 de render,
## simularla con la física haría que la cuerda diera tirones que nada más da.

## Puntos de la cuerda. Pocos: quince tramos ya se leen como cuerda y cada uno
## cuesta una raíz cuadrada por iteración de restricción.
@export_range(4, 64, 1) var nudos: int = 16
## Iteraciones de restricción por frame. Más = más tensa y más rígida.
@export_range(1, 20, 1) var rigidez: int = 12
## Cuánta cuerda sobra respecto a la distancia en línea recta. Es LA comba: a 0
## la cuerda es un palo, y a 0.1 cuelga lo justo para que se note que es cuerda.
@export_range(0.0, 0.6, 0.01) var comba: float = 0.06
## Gravedad que sienten los nudos. No es la del juego: es la que se ve bien.
@export_range(0.0, 60.0, 0.5) var peso: float = 14.0
## Amortiguación del movimiento de los nudos, por segundo.
@export_range(0.0, 1.0, 0.01) var rozamiento: float = 0.86
@export_range(0.005, 0.3, 0.005) var grosor: float = 0.055
@export var palette: Palette

var visible_cordon: bool = false

var _puntos: PackedVector3Array = []
var _previos: PackedVector3Array = []
var _malla: ImmediateMesh
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _sembrado: bool = false
var _acumulado: float = 0.0


func _ready() -> void:
	# EL CORDON SE QUEDA FUERA DE LA INTERPOLACION DE FISICA.
	#
	# Sus nudos viven en coordenadas de MUNDO y `_dibujar()` los pasa a local con
	# `to_local()`, que usa la transformada de fisica. Si ademas el nodo se
	# interpolara al dibujar, los vertices se calcularian contra una transformada
	# y se pintarian con otra: la cuerda entera se desplazaria el delta de la
	# interpolacion —hasta medio metro a 33 m/s— y se separaria de la mano.
	#
	# Quedandose fuera, `to_local()` y el render usan la MISMA transformada. La
	# suavidad del cordon no la da la interpolacion: la dan sus extremos, que se
	# tienden ya interpolados desde `Spear._process`.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	if palette == null:
		palette = GameState.palette
	_malla = ImmediateMesh.new()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _malla
	# Sin sombras: una cuerda de tres centímetros proyectando sombra cuesta más de
	# lo que aporta, y en la paleta de este juego no se vería.
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _color()
	_mat.roughness = 0.9
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_mesh.material_override = _mat

	_puntos.resize(nudos)
	_previos.resize(nudos)


## Lo llama la lanza cada frame con sus dos extremos. Si no hay cordón que
## dibujar, se pasa `false` y desaparece: la lanza en la mano no cuelga de nada.
func tender(desde: Vector3, hasta: Vector3, mostrar: bool) -> void:
	visible_cordon = mostrar
	_mesh.visible = mostrar
	if not mostrar:
		_sembrado = false
		return
	if not _sembrado:
		_sembrar(desde, hasta)
	_extremos(desde, hasta)


## PASO FIJO. La cuerda se simula siempre a 1/60, pase lo que pase con el render.
##
## No es purismo: verlet con delta variable da un resultado distinto segun el
## framerate, asi que la misma cuerda entre los mismos dos puntos colgaba distinto
## a 30 fps que a 144. Y en el screenshot test eso es un flake —la toma `cordon`
## salia 0.53% una pasada y 0.364% la siguiente, con el tope en 0.40—, que es
## exactamente el problema que se acaba de quitar de `TestFase2`.
const PASO := 1.0 / 60.0
## Techo de pasos por frame. Sin el, un tiron del sistema operativo se convierte
## en cien pasos de golpe y la cuerda pega un latigazo.
const PASOS_MAX := 4


func _process(delta: float) -> void:
	if not visible_cordon or not _sembrado:
		return
	_acumulado += delta
	var pasos := 0
	while _acumulado >= PASO and pasos < PASOS_MAX:
		_acumulado -= PASO
		_integrar(PASO)
		for i in rigidez:
			_restringir()
		pasos += 1
	if _acumulado > PASO * float(PASOS_MAX):
		_acumulado = 0.0
	_dibujar()


## Lleva la cuerda a su reposo AHORA, sin esperar a que el tiempo la asiente.
##
## Lo usa el screenshot test. Con los dos extremos quietos la cuerda converge a
## una catenaria unica, pero cuantos pasos hagan falta depende de cuanto tiempo
## real haya pasado, y eso varia con la maquina: la toma salia 0.54% una pasada y
## 0.360% la siguiente. Llamar a esto la deja en el mismo sitio siempre.
##
## Es idempotente: una vez en reposo, volver a llamarlo no la mueve.
func asentar(pasos: int = 90) -> void:
	if not _sembrado:
		return
	for i in pasos:
		_integrar(PASO)
		for j in rigidez:
			_restringir()
	_acumulado = 0.0
	_dibujar()


## Coloca todos los nudos en línea recta entre los dos extremos. Sin esto, la
## primera vez que aparece la cuerda lo hace desde donde estuviera antes y se ve
## un latigazo que no significa nada.
func _sembrar(desde: Vector3, hasta: Vector3) -> void:
	_acumulado = 0.0
	for i in nudos:
		var u := float(i) / float(nudos - 1)
		_puntos[i] = desde.lerp(hasta, u)
		_previos[i] = _puntos[i]
	_sembrado = true


func _extremos(desde: Vector3, hasta: Vector3) -> void:
	_puntos[0] = desde
	_puntos[nudos - 1] = hasta


## Verlet: la velocidad es implícita —la diferencia con la posición anterior— así
## que amortiguar es acercar esas dos posiciones, no tocar ninguna velocidad.
func _integrar(delta: float) -> void:
	# El paso es fijo, asi que la amortiguacion es una constante y no hay que
	# corregirla por delta.
	var amort := rozamiento
	for i in range(1, nudos - 1):
		var actual := _puntos[i]
		var vel := (actual - _previos[i]) * amort
		_previos[i] = actual
		_puntos[i] = actual + vel + Vector3.DOWN * peso * delta * delta


## Empuja cada par de nudos a su separación de reposo. Los dos extremos están
## clavados, así que la corrección se reparte solo entre los que se pueden mover.
func _restringir() -> void:
	var recto := _puntos[0].distance_to(_puntos[nudos - 1])
	var reposo: float = (recto / float(nudos - 1)) * (1.0 + comba)
	for i in nudos - 1:
		var a := _puntos[i]
		var b := _puntos[i + 1]
		var d := b - a
		var largo := d.length()
		if largo < 0.00001:
			continue
		var error := d * ((largo - reposo) / largo)
		# Los extremos NO se mueven: son la mano y la lanza. Y cuando uno del par
		# esta clavado, el otro se lleva la correccion ENTERA, no la mitad.
		# Repartirla a medias con un punto que no se puede mover deja la mitad del
		# error sin corregir en cada iteracion, y eso es lo que hacia que la cuerda
		# saliera quebrada en zigzag en vez de colgando: el solver oscilaba.
		var fija_a := i == 0
		var fija_b := i + 1 == nudos - 1
		if fija_a and fija_b:
			continue
		if fija_a:
			_puntos[i + 1] = b - error
		elif fija_b:
			_puntos[i] = a + error
		else:
			_puntos[i] = a + error * 0.5
			_puntos[i + 1] = b - error * 0.5


## Cinta orientada a la cámara. Una cuerda dibujada con líneas mide un píxel
## mires donde mires; una cinta que gira hacia el ojo se lee siempre igual de
## gruesa, que es lo que se quiere de algo que a veces está a treinta metros.
func _dibujar() -> void:
	_malla.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var ojo := cam.global_position

	_malla.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	for i in nudos:
		var p := _puntos[i]
		var siguiente: Vector3 = _puntos[mini(i + 1, nudos - 1)]
		var anterior: Vector3 = _puntos[maxi(i - 1, 0)]
		var eje := (siguiente - anterior)
		if eje.is_zero_approx():
			eje = Vector3.UP
		var lado := eje.normalized().cross((ojo - p).normalized())
		if lado.is_zero_approx():
			lado = Vector3.RIGHT
		lado = lado.normalized() * grosor * 0.5
		# Local, no global: el nodo puede no estar en el origen.
		_malla.surface_add_vertex(to_local(p - lado))
		_malla.surface_add_vertex(to_local(p + lado))
	_malla.surface_end()


func _color() -> Color:
	if palette == null:
		return Color.WHITE
	var v: Variant = palette.get(&"crema_medio")
	return v if v is Color else Color.WHITE
