class_name Bandada
extends Node3D
## CRIATURAS VOLADORAS. Cintas de tela que planean en grupo, estilo *Journey*.
##
## **No traen modelo propio: usan el `Enjambre` que ya existe.** El sistema
## generativo de `src/generative/` es un modelo de Kuramoto medido y probado —31
## comprobaciones, sincroniza en 9.6 s y se deshace en 19.6— que no dibuja ni
## suena a proposito. Esto es otra MANIFESTACION del mismo modelo, igual que las
## Criaturas de Tela son una. Escribir un segundo Kuramoto aqui habria sido tener
## dos fisicas que se desincronizan en cuanto alguien toque una.
##
## QUE SE VE, y por que es esto y no boids:
##
##   r alto  -> la bandada va APRETADA en el mismo tramo del recorrido y bate las
##              alas al unisono. Es una sola cosa moviendose.
##   r bajo  -> se estira a lo largo del circuito, cada una a su ritmo, y el
##              aleteo se rompe en desorden.
##
## `docs/01_DIRECCION_ARTE.md §4.6` pedia "bandadas de pajaros blancos con boids
## simples". Los boids dan separacion, alineamiento y cohesion — tres fuerzas que
## hay que pelear entre si— y lo que se busca aqui es otra cosa: que el grupo
## RESPIRE, que se junte y se deshaga solo. Eso el Kuramoto lo da con una regla, y
## ademas se puede afirmar con un test. El color blanco de §4.6 se respeta:
## `blanco_tiza` es el unico blanco permitido de la paleta.
##
## **EL FRENTE ES −Z**, el convenio del bando enemigo (regla dura #21). No es un
## tercer criterio: la malla se construye aqui mismo, en `_malla_cinta()`, y se
## construye tumbada hacia −Z para que `Basis.looking_at()` la encare sin signos
## a mano. Quien la cambie, que cambie las dos cosas a la vez.

const SHADER := preload("res://src/art/shaders/bandada.gdshader")

@export var palette: Palette
## El modelo. Si se deja vacio se construye uno con los valores de abajo.
@export var tuning: EnjambreTuning
## Cuantas criaturas. Sobrescribe `tuning.agentes`: el numero de bichos es una
## decision de escena, no del modelo.
@export_range(2, 200, 1) var criaturas: int = 22

@export_group("El circuito")
## Cuanto tarda una criatura en dar una vuelta al circuito, en segundos.
##
## Se pide asi y no en rad/s porque es lo unico que se puede juzgar a ojo: con
## `radio = 26` y veinte segundos, la criatura vuela a unos 8 m/s, que es velocidad
## de planeo. `EnjambreTuning.a_ritmo()` traduce esto al reloj del modelo entero
## —frecuencias Y acoplamiento— para que la bandada sea el mismo sistema medido en
## el Jardin, a camara lenta, y no otro sin medir.
@export_range(2.0, 300.0, 0.5) var vuelta_segundos: float = 20.0
## Radio del bucle que recorren, en metros.
@export_range(2.0, 200.0, 0.5) var radio: float = 26.0
## Cuanto sube y baja el recorrido. La componente vertical va al DOBLE de
## frecuencia que la horizontal: eso convierte un anillo plano en un ocho
## tumbado, y es lo que hace que el vuelo se lea como planeo y no como carrusel.
@export_range(0.0, 60.0, 0.5) var vaiven: float = 7.0
## Radio del tubo por el que se reparten alrededor de la linea del circuito. A
## cero vuelan todas por el mismo hilo y se solapan.
@export_range(0.0, 20.0, 0.1) var dispersion_tubo: float = 3.4
## Inclinacion del plano del circuito, en grados. Un anillo perfectamente
## horizontal se lee como una decoracion; ladeado se lee como vuelo.
@export_range(-60.0, 60.0, 1.0) var ladeo: float = 14.0

@export_group("La criatura")
@export_range(0.3, 20.0, 0.1) var largo: float = 2.6
@export_range(0.05, 4.0, 0.05) var ancho: float = 0.42
## Segmentos de la cinta. Son los que permiten que ondule; con menos de seis la
## onda se ve como un codo.
@export_range(4, 24, 1) var segmentos: int = 10
## Grados de alabeo al girar. Es lo que vende que la criatura PILOTA la curva en
## vez de ser arrastrada por ella.
@export_range(0.0, 80.0, 1.0) var alabeo: float = 34.0
## Opacidad en el valle y en la cresta del ciclo. Propias y no las del
## `EnjambreTuning` (0.35–0.95): las Criaturas de Tela del Jardin viven contra un
## telon oscuro y pueden permitirse ser fantasmales; una bandada contra el cielo a
## treinta metros, no. A 0.35 se borraba entera.
@export_range(0.0, 1.0, 0.01) var opacidad_min: float = 0.62
@export_range(0.0, 1.0, 0.01) var opacidad_max: float = 1.0

@export_group("Escolta")
## A quien rodean. Vacio = el jugador que anuncie `EventBus.player_spawned`.
@export var jugador_path: NodePath
## Desde que distancia oye la bandada la llamada, en metros.
@export_range(2.0, 120.0, 0.5) var escolta_radio: float = 24.0
## QUE PARTE DE LA BANDADA ES DE LAS CURIOSAS, de 0 a 1.
##
## No elige a nadie: pone el corte sobre la `curiosidad`, que es un rasgo fijo de
## cada criatura. Las que quedan por debajo del corte oyen la llamada; las demas,
## no — y como el rasgo no cambia nunca, **siempre son las mismas las que vienen a
## verte**. Eso es mejor que un sorteo: se aprende a reconocerlas.
##
## Entre las curiosas todavia decide la ecuacion: engancha la que cumple
## `|ωᵢ − Ω| ≤ Aᵢ`, asi que una curiosa demasiado rapida tampoco te sigue.
##
## A 1.0 se van todas y deja de haber decision; a 0 no se va ninguna.
@export_range(0.0, 1.0, 0.01) var escolta_fraccion: float = 0.4
## Cuanto mas fuerte tira el jugador que la propia bandada.
##
## Por debajo de 1 el grupo gana siempre y no escolta nadie: el acoplamiento del
## enjambre llega a `k_max`, y una llamada mas floja que eso no despega a nadie de
## la formacion. Es el numero que decide si la escolta EXISTE, no cuantas.
@export_range(0.0, 4.0, 0.05) var escolta_fuerza: float = 1.3
## Radio y altura del circulo con el que rodean al jugador.
@export_range(1.0, 30.0, 0.1) var orbita_radio: float = 5.0
@export_range(0.0, 20.0, 0.1) var orbita_alto: float = 2.8
## Cuantas vueltas al jugador por cada vuelta al circuito. Es lo unico que separa
## un cortejo de un carrusel lento: la bandada da una vuelta al circuito en veinte
## segundos y eso, sin multiplicar, seria una orbita de veinte segundos.
@export_range(1.0, 12.0, 0.5) var orbita_vueltas: float = 4.0
## Cuanto sube y baja la orbita. Plana se lee como un anillo pintado.
@export_range(0.0, 6.0, 0.1) var orbita_onda: float = 0.9
## TU MALLA DE BLENDER, si la tienes. Vacio = la cinta procedural de aqui abajo.
##
## Dos cosas que el shader le pide: la criatura tiene que estar **tumbada hacia
## −Z** —es el convenio del bando enemigo, regla dura #21— y **`UV.y = 0` en la
## cabeza y `1` en la cola**, que es de donde sale la onda que recorre la tela.
##
## `largo`, `ancho` y `segmentos` dejan de usarse en cuanto pones una.
@export var malla: Mesh

var enjambre: Enjambre
var multimesh: MultiMeshInstance3D
var _mat: ShaderMaterial
## Desfase de cada criatura dentro del tubo, en el marco local del recorrido.
var _carriles: PackedVector2Array = PackedVector2Array()
var _jugador: Node3D
## El jugador en el espacio LOCAL de este nodo. Las poses del `MultiMesh` son
## locales, asi que la orbita tiene que calcularse en las mismas coordenadas.
var _jugador_local: Vector3 = Vector3.ZERO
var _hay_jugador: bool = false
## DONDE ESTA CADA CRIATURA, en local, tal y como se acaba de escribir.
##
## Es una copia de lo que va al `MultiMesh`, y no un lujo: **al servidor de render
## no se le pregunta el estado del juego.** `MultiMesh.get_instance_transform()`
## devuelve la identidad en headless —ahi el servidor es un maniqui que no guarda
## el buffer—, asi que cualquier logica que lo lea funciona en pantalla y falla en
## un test sin decir por que. Lo cazo `TestMundoVivo`: `perturbar_cerca()` medía
## contra doce criaturas todas en el origen y siempre elegia la primera.
var _poses: Array[Transform3D] = []


func _ready() -> void:
	if palette == null:
		palette = GameState.palette
	if tuning == null:
		var base := EnjambreTuning.new()
		tuning = base.a_ritmo((TAU / maxf(vuelta_segundos, 0.5)) / base.frecuencia_base)
	tuning.agentes = criaturas
	_repartir_carriles()
	_montar_malla()

	enjambre = Enjambre.new()
	enjambre.name = "Enjambre"
	enjambre.tuning = tuning
	enjambre.palette = palette
	add_child(enjambre)
	# EL MARCAPASOS LATE EN EL CENTRO DE LA BANDA. Con Ω = `frecuencia_base`, los
	# que pueden seguirle son los de frecuencia media: los bichos "normales" se van
	# con el jugador y los raros —el mas rapido y el mas lento— siguen a lo suyo.
	# Es una regla que se puede ver sin explicarla.
	enjambre.marcapasos_omega = tuning.frecuencia_base

	if jugador_path.is_empty():
		EventBus.player_spawned.connect(_adoptar)
	else:
		_jugador = get_node_or_null(jugador_path) as Node3D
	_colocar()


func _adoptar(p: Node3D) -> void:
	if _jugador == null:
		_jugador = p


## A quien rodear, ya montado el nodo. Mismo motivo que `Pasto.seguir()`.
func seguir(nodo: Node3D) -> void:
	_jugador = nodo


func _process(_delta: float) -> void:
	_colocar()


## Reparte a las criaturas por la SECCION del tubo con el angulo aureo.
##
## Mismo motivo que las fases iniciales del `Enjambre`: un reparto regular es
## simetrico, y en un anillo la simetria se ve como una formacion militar. El
## aureo llena el disco sin cerrarlo y sin repetir un patron.
func _repartir_carriles() -> void:
	const AUREO := PI * (3.0 - sqrt(5.0))
	_carriles.resize(criaturas)
	for i in criaturas:
		var a := float(i) * AUREO
		# sqrt para que el disco quede lleno de forma uniforme y no apelotonado
		# en el centro: repartir el radio linealmente concentra la mitad de las
		# criaturas en el cuarto interior.
		var r := sqrt(float(i) + 0.5) / sqrt(float(criaturas))
		_carriles[i] = Vector2(cos(a), sin(a)) * r * dispersion_tubo


## EL RECORRIDO. Un ocho tumbado: circulo en el plano, doble frecuencia en altura.
##
## El LADEO va aqui dentro, no aplicado despues a la transformada entera. Cuando
## la escolta entro en escena, ese ladeo de fuera inclinaba tambien la orbita
## alrededor del jugador —que tiene que ser horizontal— y ladeaba al propio
## jugador. Si el circuito esta inclinado, lo esta el circuito.
func _punto(u: float) -> Vector3:
	var p := Vector3(cos(u) * radio, sin(u * 2.0) * vaiven * 0.5, sin(u) * radio)
	return Basis(Vector3.FORWARD, deg_to_rad(ladeo)) * p


## La tangente ANALITICA, no una diferencia entre dos frames.
##
## Con diferencias, la direccion depende del framerate y ademas se queda un frame
## por detras: a 26 m de radio eso es medio metro de desfase entre donde mira la
## criatura y donde va. La derivada del recorrido no tiene ninguno de los dos
## problemas y cuesta lo mismo.
func _tangente(u: float) -> Vector3:
	var t := Vector3(-sin(u) * radio, cos(u * 2.0) * vaiven, cos(u) * radio)
	return (Basis(Vector3.FORWARD, deg_to_rad(ladeo)) * t).normalized()


## DONDE VUELA LA CRIATURA `i` cuando NO escolta: su carril dentro del tubo.
func _en_circuito(u: float, i: int) -> Vector3:
	var frente := _tangente(u)
	# Marco local del recorrido: `lateral` y `arriba` son los dos ejes de la
	# seccion del tubo. Salen de la tangente, asi que el tubo acompaña a la curva
	# en vez de quedarse fijo en el mundo.
	var lateral := frente.cross(Vector3.UP)
	lateral = lateral.normalized() if not lateral.is_zero_approx() else Vector3.RIGHT
	var arriba := lateral.cross(frente).normalized()
	var carril: Vector2 = _carriles[i]
	return _punto(u) + lateral * carril.x + arriba * carril.y


## Y DONDE VUELA CUANDO ESCOLTA: rodeando al jugador.
##
## El angulo sale de su PROPIA fase, multiplicada, mas un reparto fijo por indice.
## Las dos mitades hacen falta:
##
##   · la fase, porque enganchadas todas comparten fase y el anillo gira ENTERO al
##     ritmo del marcapasos. Es lo que hace que la escolta se lea como formacion y
##     no como tres bichos dando vueltas cada uno por su lado.
##   · el reparto por indice, porque sin el —al ir todas en fase— se apilarian en
##     el MISMO punto del circulo. El anillo tiene huecos donde estan las que no
##     enganchan, y eso es correcto: se ve quien vino y quien no.
func _en_orbita(u: float, i: int) -> Vector3:
	var a := u * orbita_vueltas + TAU * float(i) / float(maxi(criaturas, 1))
	return (_jugador_local + Vector3.UP * orbita_alto
		+ Vector3(cos(a), 0.0, sin(a)) * orbita_radio
		+ Vector3.UP * (sin(a * 2.0) * orbita_onda))


## La mezcla. `e` es el enganche: 0 vuela el circuito, 1 rodea al jugador.
##
## Se mezclan las POSICIONES y no dos estados. Una criatura no "entra en modo
## escolta": su sitio se desplaza de una curva a la otra mientras su fase sigue
## corriendo sin enterarse. Por eso no hay transicion que programar, ni un
## chasquido al entrar, ni una vuelta a casa que coreografiar — cuando el jugador
## se va, el enganche decae y la misma mezcla la devuelve al circuito.
func _punto_mezclado(u: float, i: int, e: float) -> Vector3:
	if e <= 0.001 or not _hay_jugador:
		return _en_circuito(u, i)
	return _en_circuito(u, i).lerp(_en_orbita(u, i), e)


## LA LLAMADA. Le pide al marcapasos que tire de quien tenga cerca.
##
## Solo pone la FUERZA; quien engancha lo decide la ecuacion (ver la cabecera del
## marcapasos en `Enjambre`). Y se pide cada frame: en cuanto el jugador se aleja
## deja de pedirse, el enganche decae solo y la bandada vuelve.
func _llamar() -> void:
	_hay_jugador = _jugador != null and is_instance_valid(_jugador)
	if not _hay_jugador:
		return
	_jugador_local = to_local(_jugador.global_position)

	# LA DISTANCIA SE MIDE AL TERRITORIO, no a cada criatura.
	#
	# Medirla criatura a criatura parece lo natural y es una trampa: una escolta
	# esta ORBITANDO al jugador, o sea a cinco metros de el por definicion, asi que
	# su propia distancia nunca sube y la llamada no se apaga jamas. Medido: el
	# jugador se iba a noventa metros y dos criaturas se iban con el, orbitandole
	# para siempre. La bandada tiene un sitio, y la llamada solo se oye ahi.
	var d := _jugador_local.length()
	var cerca: float = 1.0 - smoothstep(escolta_radio * 0.45, escolta_radio, d)
	if cerca <= 0.001:
		return
	# LA FUERZA SE MIDE CONTRA EL ACOPLAMIENTO DEL GRUPO, no en abstracto: lo que
	# tiene que vencer una llamada es a la bandada tirando de los suyos.
	var fuerza := tuning.k_max * escolta_fuerza * cerca
	for i in _poses.size():
		# Y SOLO LAS CURIOSAS LA OYEN. El borde es blando para que el corte no se
		# lea como una lista: con `escolta_fraccion` a la mitad, una criatura justo
		# en el limite duda.
		var c := tuning.curiosidad(i, criaturas)
		var oye: float = 1.0 - smoothstep(
			escolta_fraccion - 0.06, escolta_fraccion + 0.06, c)
		if oye > 0.001:
			enjambre.pedir_tiron(i, fuerza * oye)


func _colocar() -> void:
	if enjambre == null or multimesh == null:
		return
	var mm := multimesh.multimesh
	var n := mini(criaturas, enjambre.fases.size())
	if _poses.size() != n:
		_poses.resize(n)
	_llamar()
	for i in n:
		var u := enjambre.fase_de(i)
		var e := escolta_de(i)
		var pos := _punto_mezclado(u, i, e)

		# EL FRENTE, por diferencia sobre la MISMA mezcla y no sobre el circuito.
		# Una criatura escoltando vuela por la orbita: si mirase la tangente del
		# circuito, iria de lado. Es analitica igual —dos evaluaciones de la misma
		# funcion con la misma `e`—, no una diferencia entre frames.
		var adelante := _punto_mezclado(u + 0.05, i, e)
		var frente := adelante - pos
		frente = frente.normalized() if not frente.is_zero_approx() else Vector3.FORWARD
		var lateral := frente.cross(Vector3.UP)
		lateral = lateral.normalized() if not lateral.is_zero_approx() else Vector3.RIGHT
		var arriba := lateral.cross(frente).normalized()

		# ALABEO: se inclina HACIA la curva. El signo sale de cuanto gira el
		# frente un poco mas adelante — es la curvatura del camino que realmente
		# esta volando, orbita incluida.
		var mas := _punto_mezclado(u + 0.1, i, e) - adelante
		var giro := 0.0
		if not mas.is_zero_approx():
			giro = mas.normalized().cross(frente).dot(arriba)
		var base := Basis.looking_at(frente, arriba).rotated(
			frente, deg_to_rad(alabeo) * clampf(giro * 6.0, -1.0, 1.0))

		var pose := Transform3D(base, pos)
		_poses[i] = pose
		mm.set_instance_transform(i, pose)
		var ciclo := enjambre.ciclo_de(i)
		# CUSTOM: lo que el shader necesita y no cabe en el color.
		#   x = ciclo (0..1)   y = desvio (0..1)   z = opacidad   w = fase cruda
		# La fase CRUDA y no el ciclo para la onda de la cinta: el ciclo sube y
		# baja dos veces por vuelta y la onda saldria simetrica, sin recorrido.
		mm.set_instance_custom_data(i, Color(
			ciclo, enjambre.desvio_de(i),
			lerpf(opacidad_min, opacidad_max, ciclo),
			enjambre.fase_de(i)))


## Cuantas escoltan ahora mismo. La medida honesta de "algunas, no todas".
func escoltando(umbral: float = 0.6) -> int:
	return enjambre.enganchados(umbral) if enjambre != null else 0


## Cuanto escolta la criatura `i`, de 0 a 1. **Recortado por los dos extremos.**
##
## El enganche crudo es una media movil y decae de forma asintotica: nunca llega a
## cero del todo. Eso, mezclando POSICIONES, es un problema real y no un decimal:
## con el jugador a noventa metros, un residuo del 1% arrastra a la criatura casi
## un metro fuera de su circuito, y a doscientos metros la arrastra dos. El
## `smoothstep` le da un cero de verdad por abajo y un uno de verdad por arriba.
func escolta_de(i: int) -> float:
	if enjambre == null:
		return 0.0
	return smoothstep(0.2, 0.85, enjambre.enganche_de(i))


func _montar_malla() -> void:
	multimesh = MultiMeshInstance3D.new()
	multimesh.name = "Cintas"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = malla if malla != null else _malla_cinta()
	mm.instance_count = criaturas
	multimesh.multimesh = mm
	multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# FUERA DE LA INTERPOLACION DE FISICA (regla dura #21bis): las instancias se
	# mueven por CODIGO en `_process`, asi que dentro se interpolarian dos veces.
	multimesh.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# La AABB a mano por lo mismo que en `Pasto`: el shader ondula los vertices
	# fuera de lo que el MultiMesh deduce de las transformadas.
	var r := radio + dispersion_tubo + largo * 2.0
	multimesh.custom_aabb = AABB(
		Vector3(-r, -vaiven - dispersion_tubo - largo, -r),
		Vector3(r * 2.0, (vaiven + dispersion_tubo + largo) * 2.0, r * 2.0))

	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	# SILUETA OSCURA CONTRA EL CIELO, y esto contradice a `01_DIRECCION_ARTE §4.6`
	# a proposito.
	#
	# §4.6 pide "pajaros blancos (#F2F0E6)". Medido en el juego: la niebla es
	# `crema_bruma` #EFE8D8 y `blanco_tiza` es #F2F0E6 — **el mismo color**. Con
	# eso la bandada existe, vuela y no se ve: el usuario la reporto como "cosas
	# con cola que aparecen en el debug y no en pantalla", y tenia razon.
	#
	# El blanco de la referencia funciona porque alli los pajaros cruzan por
	# delante de los arcos casi negros. Contra cielo abierto hace falta lo
	# contrario: la silueta tiene que ser MAS OSCURA que el fondo. Se queda en la
	# familia del aire —el 30% de la paleta—, que es donde le toca a la fauna
	# atmosferica, y no gasta acento.
	_mat.set_shader_parameter(&"color_calma", _color(&"lavanda_profundo"))
	_mat.set_shader_parameter(&"color_pico", _color(&"lavanda_gris"))
	_mat.set_shader_parameter(&"color_perdida", _color(&"piedra_sombra"))
	multimesh.material_override = _mat
	add_child(multimesh)


## LA CINTA: una tira tumbada hacia −Z que se estrecha hacia la cola.
##
## `UV.y` va de 0 en la cabeza a 1 en la cola, y de ahi sale la onda: la cabeza
## queda quieta y la cola ondea, que es lo que hace que se lea como tela empujada
## por el aire y no como un objeto rigido que vibra.
func _malla_cinta() -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var nor := PackedVector3Array()
	var idx := PackedInt32Array()

	for s in segmentos + 1:
		var t := float(s) / float(segmentos)
		# Ancha en el tercio delantero y afilada al final: es la silueta de manta
		# que hace que se lea como criatura y no como bufanda.
		var w := ancho * (0.35 + 0.65 * sin(clampf(t * 1.35, 0.0, 1.0) * PI))
		var z := -largo * t
		v.append(Vector3(-w, 0.0, z))
		v.append(Vector3(w, 0.0, z))
		uv.append(Vector2(0.0, t))
		uv.append(Vector2(1.0, t))
		nor.append(Vector3.UP)
		nor.append(Vector3.UP)

	for s in segmentos:
		var a := s * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_NORMAL] = nor
	arrays[Mesh.ARRAY_INDEX] = idx
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malla


## Perturba a la criatura mas cercana a un punto. El jugador que las cruza las
## desordena, y el grupo se recompone solo: es la misma interaccion que en el
## Jardin, y aqui es lo que hace que la bandada REACCIONE a que pases.
func perturbar_cerca(punto: Vector3, radio_alcance: float = 6.0) -> int:
	if enjambre == null:
		return -1
	var mejor := -1
	var mejor_d := radio_alcance * radio_alcance
	for i in _poses.size():
		var d := posicion_de(i).distance_squared_to(punto)
		if d < mejor_d:
			mejor_d = d
			mejor = i
	if mejor >= 0:
		enjambre.perturbar(mejor)
	return mejor


## Posicion de mundo de la criatura `i`.
func posicion_de(i: int) -> Vector3:
	if i < 0 or i >= _poses.size():
		return global_position
	return global_transform * _poses[i].origin


## Hacia donde MIRA la criatura `i`, en mundo.
##
## Con signo y por una funcion, no leyendo `-basis.z` por ahi suelto: es el mismo
## criterio de la regla dura #21 —el frente se escribe en UN sitio— y de la #22
## —un sentido se mide con signo, nunca con un modulo—.
func frente_de(i: int) -> Vector3:
	if i < 0 or i >= _poses.size():
		return -global_basis.z
	return (global_basis * -_poses[i].basis.z).normalized()


func _color(nombre: StringName) -> Color:
	if palette == null:
		return Color.WHITE
	var v: Variant = palette.get(nombre)
	return v if v is Color else Color.WHITE


func debug_line() -> String:
	if enjambre == null:
		return "—"
	return "%d criaturas · %d escoltando · %s" % [
		criaturas, escoltando(), enjambre.debug_line()]
