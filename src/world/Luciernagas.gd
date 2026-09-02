class_name Luciernagas
extends Node3D
## LUCIERNAGAS. Puntos de luz que derivan por el aire y parpadean al unisono.
##
## Tercera manifestacion del MISMO modelo (`src/generative/Enjambre.gd`), y la que
## mejor lo enseña: aqui el oscilador no mueve casi nada —el vuelo es una deriva
## lenta— y lo que se ve es puro PARPADEO. Cuando el enjambre se sincroniza, el
## claro entero late a la vez; cuando se deshace, se convierte en un centelleo
## desordenado. Y como el acoplamiento se realimenta solo, eso pasa una y otra vez
## sin que nadie lo dispare.
##
## Es lo que hace un bosque de *Breath of the Wild* de noche, y sale de una regla,
## no de un guion.
##
## POR QUE ESTO NO REIMPLEMENTA KURAMOTO: ver la cabecera de `Bandada`. El modelo
## esta medido y probado en `tools/TestEnjambre.tscn`; una segunda copia serian dos
## fisicas que se desincronizan a la primera que alguien toque una.
##
## Y por que el modelo puede con doscientas: `Enjambre._integrar()` resuelve el
## acoplamiento en CAMPO MEDIO —la identidad `(1/N)Σ sin(θⱼ−θᵢ) ≡ r·sin(ψ−θᵢ)`,
## exacta, no un promedio—, asi que el coste es O(N) y no O(N²). Con la suma doble
## esto costaria 32.400 senos por frame en GDScript; asi cuesta 180.

const SHADER := preload("res://src/art/shaders/luciernaga.gdshader")

@export var palette: Palette
## El modelo. Vacio = se construye uno con los valores de abajo.
@export var tuning: EnjambreTuning
@export_range(4, 400, 1) var cuantas: int = 180
## Semilla del reparto. Fija: un claro que cambia entre arranques rompe el
## screenshot test y no aporta nada.
@export var semilla: int = 90210

@export_group("El claro")
## Cada cuanto parpadea una luciernaga de ritmo medio, en segundos. Como en
## `Bandada`, se traduce al reloj del modelo con `EnjambreTuning.a_ritmo()`: mismo
## sistema medido, otra velocidad.
@export_range(0.3, 30.0, 0.1) var parpadeo_segundos: float = 3.0
## Caja en la que viven, centrada en el nodo.
@export var area: Vector3 = Vector3(28.0, 5.0, 28.0)
## Cuanto se aleja cada una de su sitio al derivar, en metros.
@export_range(0.0, 6.0, 0.05) var deriva: float = 0.85
## Ritmo de la deriva respecto al del oscilador. Por debajo de 1 la luciernaga se
## mueve mas despacio de lo que parpadea, que es lo que hace un bicho de verdad:
## flota, no corre.
@export_range(0.05, 3.0, 0.05) var deriva_ritmo: float = 0.35
## Dureza del destello. Alto = chispazo; bajo = respiracion. Se pasa al shader.
@export_range(1.0, 24.0, 0.5) var dureza: float = 7.0
@export_range(0.01, 1.0, 0.01) var tamano: float = 0.12
## CUANTO SE APRIETA EL CLARO AL SINCRONIZARSE, en fraccion de su tamaño.
##
## Es lo que convierte 180 bichos independientes en un ENJAMBRE. Con las
## luciernagas ancladas cada una a su sitio, la sincronizacion solo se ve en la
## luz; apretando la nube con el orden, la forma del grupo cuenta lo mismo que el
## parpadeo. Y no es un segundo sistema: sale del MISMO numero, `r`, que ya decide
## si parpadean juntas. Disperso el claro se abre, al unisono se junta.
##
## A 1.0 no se aprieta nada. A 0.4 la nube se encoge a menos de la mitad.
@export_range(0.2, 1.0, 0.01) var apretado: float = 0.58

@export_group("El jugador")
## Quien las desordena al pasar. Vacio = el que anuncie `EventBus.player_spawned`.
@export var jugador_path: NodePath
## Radio en el que cruzar las desordena, en metros.
@export_range(0.0, 12.0, 0.1) var dispersar_radio: float = 2.4
## Cuantas puede desordenar por segundo. Sin techo, correr entre ellas perturbaria
## una por frame y el enjambre no volveria a sincronizar nunca.
@export_range(0.0, 60.0, 0.5) var dispersar_cadencia: float = 7.0

var enjambre: Enjambre
var multimesh: MultiMeshInstance3D
var _mat: ShaderMaterial
## Donde vive cada una, en local. La deriva se cuenta desde aqui.
var _hogares: PackedVector3Array = PackedVector3Array()
## Desfase de la deriva de cada una. Sin el, sincronizadas irian TODAS al mismo
## sitio y el claro se convertiria en un solo punto.
var _desfases: PackedVector3Array = PackedVector3Array()
## Donde esta cada una, en local. Copia de lo que va al `MultiMesh`: al servidor
## de render no se le pregunta el estado del juego. Ver `Bandada._poses`.
var _poses: PackedVector3Array = PackedVector3Array()
var _jugador: Node3D
var _cd_dispersar: float = 0.0


func _ready() -> void:
	if palette == null:
		palette = GameState.palette
	if tuning == null:
		var base := EnjambreTuning.new()
		tuning = base.a_ritmo((TAU / maxf(parpadeo_segundos, 0.1)) / base.frecuencia_base)
	tuning.agentes = cuantas
	_repartir()
	_montar()

	enjambre = Enjambre.new()
	enjambre.name = "Enjambre"
	enjambre.tuning = tuning
	enjambre.palette = palette
	add_child(enjambre)
	if jugador_path.is_empty():
		EventBus.player_spawned.connect(_adoptar)
	else:
		_jugador = get_node_or_null(jugador_path) as Node3D
	_colocar()


func _adoptar(p: Node3D) -> void:
	if _jugador == null:
		_jugador = p


## A quien reaccionar, ya montado el nodo. Mismo motivo que `Pasto.seguir()`.
func seguir(nodo: Node3D) -> void:
	_jugador = nodo


func _process(delta: float) -> void:
	_dispersar(delta)
	_colocar()


## CRUZAR EL CLARO LO DESORDENA, y luego se recompone solo.
##
## No hay un estado "asustadas" ni una huida: se le perturba la fase a la que
## tengas al lado —lo mismo que hace un clic en el Jardin— y el acoplamiento se
## encarga del resto. Lo que se ve es que abres un hueco de centelleo desordenado
## por donde pasas, y que se cierra detras de ti.
##
## Con cadencia porque si no, correr entre ellas perturbaria una por frame: el
## enjambre no volveria a sincronizar nunca y el efecto —que es la VUELTA— no
## llegaria a existir.
func _dispersar(delta: float) -> void:
	_cd_dispersar = maxf(0.0, _cd_dispersar - delta)
	if _cd_dispersar > 0.0 or dispersar_radio <= 0.0:
		return
	if _jugador == null or not is_instance_valid(_jugador):
		return
	if perturbar_cerca(_jugador.global_position, dispersar_radio) >= 0:
		_cd_dispersar = 1.0 / maxf(dispersar_cadencia, 0.01)


func _repartir() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	_hogares.resize(cuantas)
	_desfases.resize(cuantas)
	for i in cuantas:
		_hogares[i] = Vector3(
			rng.randf_range(-area.x, area.x) * 0.5,
			rng.randf_range(0.0, area.y),
			rng.randf_range(-area.z, area.z) * 0.5)
		_desfases[i] = Vector3(
			rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU))


func _colocar() -> void:
	if enjambre == null or multimesh == null:
		return
	var mm := multimesh.multimesh
	var n := mini(cuantas, enjambre.fases.size())
	if _poses.size() != n:
		_poses.resize(n)
	# EL APRETON. Ver `apretado`: la nube se encoge hacia su centro a medida que el
	# enjambre se ordena, asi que la sincronizacion se ve en la FORMA del grupo y
	# no solo en la luz. Mismo numero, dos canales.
	var centro := Vector3(0.0, area.y * 0.5, 0.0)
	var apreton: float = lerpf(1.0, apretado, enjambre.orden)
	for i in n:
		var f := enjambre.fase_de(i) * deriva_ritmo
		var d: Vector3 = _desfases[i]
		# Deriva: tres senos desfasados. Los tres salen de la MISMA fase, asi que
		# al sincronizarse el claro entero se mece a la vez —desplazado bicho a
		# bicho por `_desfases`, que es lo que impide que colapsen en un punto—.
		var vuelo := Vector3(
			sin(f + d.x), sin(f * 0.7 + d.y) * 0.55, cos(f * 0.86 + d.z)) * deriva
		_poses[i] = centro + (_hogares[i] - centro) * apreton + vuelo
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, _poses[i]))
		# x = ciclo · y = desvio. El shader hace el resto.
		mm.set_instance_custom_data(i, Color(
			enjambre.ciclo_de(i), enjambre.desvio_de(i), 0.0, 0.0))


func _montar() -> void:
	multimesh = MultiMeshInstance3D.new()
	multimesh.name = "Chispas"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	# El tamaño real lo pone el shader, que ademas lo hace latir. Aqui basta un
	# quad unitario: escalarlo tambien desde la malla seria un segundo sitio donde
	# cambiar lo mismo.
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = cuantas
	multimesh.multimesh = mm
	multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# FUERA DE LA INTERPOLACION DE FISICA (regla dura #21bis): las instancias se
	# mueven por CODIGO en `_process`, asi que dentro se interpolarian dos veces.
	multimesh.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# El billboard del shader mueve los vertices fuera de lo que el MultiMesh
	# deduce, y el halo crece con el destello: la AABB se pone a mano.
	var margen := deriva + tamano * 8.0 + 1.0
	multimesh.custom_aabb = AABB(
		Vector3(-area.x * 0.5 - margen, -margen, -area.z * 0.5 - margen),
		Vector3(area.x + margen * 2.0, area.y + margen * 2.0, area.z + margen * 2.0))

	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter(&"color_frio", _color(&"musgo_medio"))
	_mat.set_shader_parameter(&"color_calido", _color(&"oro_palido"))
	_mat.set_shader_parameter(&"dureza", dureza)
	_mat.set_shader_parameter(&"tamano", tamano)
	multimesh.material_override = _mat
	add_child(multimesh)


## Brillo de la luciernaga `i`, tal y como lo calcula el shader. Existe para el
## test: comprobar que el parpadeo se sincroniza hay que hacerlo sobre el numero
## que se dibuja, no sobre el ciclo crudo — la potencia es media mecanica.
func brillo_de(i: int) -> float:
	if enjambre == null:
		return 0.0
	return pow(clampf(enjambre.ciclo_de(i), 0.0, 1.0), dureza)


## Fraccion de luciernagas encendidas ahora mismo. Es la medida honesta del
## parpadeo colectivo: sincronizadas, esto va de casi 0 a casi 1 y vuelve;
## dispersas, se queda plano alrededor de su media.
func encendidas(umbral: float = 0.5) -> float:
	if enjambre == null or cuantas == 0:
		return 0.0
	var n := 0
	for i in mini(cuantas, enjambre.fases.size()):
		if brillo_de(i) >= umbral:
			n += 1
	return float(n) / float(cuantas)


func posicion_de(i: int) -> Vector3:
	if i < 0 or i >= _poses.size():
		return global_position
	return global_transform * _poses[i]


## Perturba a la mas cercana a un punto: pasar entre ellas las desordena y luego
## se recomponen. Es la misma interaccion del Jardin, en el mundo.
func perturbar_cerca(punto: Vector3, radio: float = 2.0) -> int:
	if enjambre == null:
		return -1
	var mejor := -1
	var mejor_d := radio * radio
	for i in _poses.size():
		var d := posicion_de(i).distance_squared_to(punto)
		if d < mejor_d:
			mejor_d = d
			mejor = i
	if mejor >= 0:
		enjambre.perturbar(mejor)
	return mejor


func _color(nombre: StringName) -> Color:
	if palette == null:
		return Color.WHITE
	var v: Variant = palette.get(nombre)
	return v if v is Color else Color.WHITE


func debug_line() -> String:
	if enjambre == null:
		return "—"
	return "%d luciernagas · %.0f%% encendidas · %s" % [
		cuantas, encendidas() * 100.0, enjambre.debug_line()]


## Radio medio de la nube, en metros. Es la medida de cuanto se ha apretado, y la
## que usa el test: la contraccion tiene que poder afirmarse con un numero.
func radio_nube() -> float:
	if _poses.is_empty():
		return 0.0
	var centro := Vector3(0.0, area.y * 0.5, 0.0)
	var suma := 0.0
	for p in _poses:
		suma += Vector2(p.x - centro.x, p.z - centro.z).length()
	return suma / float(_poses.size())
