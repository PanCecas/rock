class_name EstacionJam
extends Node3D
## LA ESTACION DE JAM: ocho puestos en corro que tocan juntos, estilo *Sky*.
##
## **No trae modelo propio de sincronizacion: usa el `Enjambre` que ya existe.**
## Es la tercera manifestacion del mismo Kuramoto medido —la bandada y las
## luciernagas son las otras dos— y por la misma razon que ellas: un segundo
## modelo aqui serian dos fisicas que se desincronizan en cuanto alguien toque
## una. Aqui ademas cierra un encargo que llevaba dos parches abierto:
## `Enjambre` publica `pitch` y `amplitud` por agente y por frame desde el 3.11 y
## no habia nadie escuchando. Esto es ese alguien.
##
## QUE SE OYE, que es todo el sistema en dos lineas:
##
##   r bajo  -> ocho musicos a su aire. Notas sueltas, desordenadas, flojas.
##   r alto  -> los ocho caen en el mismo compas y tocan A LA VEZ: un acorde.
##
## Y respira sola, porque el acoplamiento se realimenta con histeresis: se junta,
## se cansa, se deshace y vuelve. Nadie programa esa estructura — son 9.6 s al
## orden, 19.6 al caos y 7.3 de vuelta, los mismos que mide `TestEnjambre`.
##
## CUATRO DECISIONES QUE LO HACEN FUNCIONAR:
##
## · **EL INSTRUMENTO ES EL PUESTO, NO EL AGENTE.** El agente trae el RITMO —su
##   fase— y el puesto trae el REGISTRO —su transposicion, fija—. Sin eso los
##   ocho tocarian la misma nota a la vez y el unisono seria una sola voz mas
##   fuerte, no un acorde. Con eso, el puesto 0 es el bajo y el 7 el agudo, y el
##   tono sube dando la vuelta al corro: se VE de donde sale cada nota.
##
## · **PENTATONICA, Y ESA ES LA REGLA ENTERA.** Es lo que hace que en *Sky* dos
##   desconocidos suenen bien sin haber hablado: una escala sin segundas menores
##   ni tritonos no tiene con que chocar. Cualquier combinacion de estas cinco
##   notas es consonante, asi que el sistema puede dejar que ocho voces elijan
##   POR SU CUENTA y no hace falta un director. Con una escala mayor de siete
##   grados, el mismo codigo sonaria a error la mitad del tiempo.
##
## · **NOTAS, NO UN ZUMBIDO.** Un puesto GOLPEA cuando su fase cruza un
##   subdivision del compas, y la nota decae sola. La fase del Kuramoto no
##   modula un tono continuo: ES el pulso. Por eso sincronizarse se OYE como que
##   se juntan los ataques, que es lo que se oye de verdad cuando una banda entra
##   a tiempo.
##
## · **UNA SOLA FUENTE DE AUDIO, no ocho.** Ocho `AudioStreamPlayer3D` son ocho
##   buffers que rellenar desde GDScript cada frame para una cosa que siempre se
##   escucha como un conjunto. La estacion es el instrumento; la mezcla ocurre
##   antes del altavoz. El ancho estereo se pone dentro, por el sitio del puesto
##   en el corro.
##
## EL JUGADOR ES EL MARCAPASOS. Acercarse tira de los puestos que PUEDEN seguirle
## el ritmo —`|ωᵢ − Ω| ≤ A`, la misma condicion que decide que criaturas de la
## bandada te escoltan— y los demas siguen a lo suyo. No hay boton de "unirse":
## te acercas y algunos te cogen el compas.

## GOLPE de un puesto: quien y en que nota. Se publica por la misma razon por la
## que `Enjambre` publica `pitch` y `amplitud` y no toca un altavoz: el que un
## puesto ataque es un HECHO del sistema, y quien quiera colgar de el un efecto,
## una vibracion o una luz no deberia tener que preguntarle al sintetizador.
signal golpe(indice: int, hz: float)


@export var palette: Palette
## El modelo. Vacio = se construye uno al compas de `compas_segundos`.
@export var tuning: EnjambreTuning
## Cuantos puestos. Ocho es el numero de la referencia y el que cabe en el corro
## sin que dos se tapen; sobrescribe `tuning.agentes`, porque cuantos musicos hay
## es una decision de escena y no del modelo.
@export_range(2, 16, 1) var asientos: int = 8

@export_group("El corro")
## Radio del corro, en metros. A 3.4 caben ocho puestos con hueco para pasar
## entre ellos, que hace falta: al centro se entra andando.
@export_range(1.0, 20.0, 0.1) var radio: float = 3.4
## Altura del taburete.
@export_range(0.1, 3.0, 0.05) var alto_taburete: float = 0.55
## Cuanto SUBE Y BAJA el musico con su ciclo, en metros. Es la manifestacion
## visual del mismo numero que elige la nota: se ve quien va a tocar antes de
## oirlo, y eso es la mitad de que un corro se lea como una banda.
@export_range(0.0, 1.0, 0.01) var vaiven: float = 0.16
## Cuanto se ESTIRA el musico en el golpe, y cuanto tarda en volver. El golpe es
## un pulso, no un brillo sostenido: mismo criterio que el destello de las
## luciernagas.
@export_range(0.0, 1.0, 0.01) var golpe_estiron: float = 0.22
@export_range(0.5, 20.0, 0.5) var golpe_caida: float = 6.0

@export_group("La musica")
## Cuanto dura un compas de cada musico, en segundos. Es lo unico que se puede
## juzgar a oido, igual que `Bandada.vuelta_segundos` es lo unico que se puede
## juzgar a ojo. De aqui sale el reloj del modelo entero con `a_ritmo()`, asi que
## la estacion es el mismo sistema medido en el Jardin, a otra velocidad.
@export_range(0.2, 8.0, 0.05) var compas_segundos: float = 1.7
## Golpes por compas. A 1 el corro suena a campanas; a 2 o 3 empieza a sonar a
## banda tocando algo.
@export_range(1, 8, 1) var golpes_por_compas: int = 2
## La escala, en semitonos desde la tonica. Por defecto la PENTATONICA MAYOR
## —0, 2, 4, 7, 9—, que es la que no puede sonar mal consigo misma.
@export var escala: PackedInt32Array = PackedInt32Array([0, 2, 4, 7, 9])
## Tonica, en Hz. 174.61 es un fa3, el mismo `pitch_base` del `EnjambreTuning`.
@export_range(40.0, 900.0, 0.01) var tonica: float = 174.61
## Cuantos GRADOS DE LA ESCALA separan el puesto mas grave del mas agudo.
##
## En grados y no en semitonos, y eso no es una comodidad: es lo que hace que la
## pentatonica sea una invariante y no una intencion. Repartir 24 semitonos entre
## ocho puestos da saltos de 3.43, y redondeando salen 0, 3, 7, 10, 14, 17, 21, 24
## — que en clases de altura son 0, 3, 7, 10, 2, 5, 9, 0, y el 3, el 10 y el 5 no
## estan en la escala. Sumar un grado bueno a un registro malo da una nota mala:
## medido, **143 de 480 combinaciones caian fuera**.
##
## Contando en grados no hay forma de salirse. Diez grados son dos octavas justas
## en una escala de cinco notas.
@export_range(0, 40, 1) var registro_grados: int = 10
## Volumen de la estacion, en decibelios.
@export_range(-60.0, 12.0, 0.5) var volumen_db: float = -9.0
## A cuantos metros deja de oirse.
@export_range(2.0, 200.0, 1.0) var alcance: float = 26.0
## Cuanto tarda una nota en apagarse, en segundos.
@export_range(0.05, 6.0, 0.05) var nota_duracion: float = 1.1
## Mezcla del segundo y tercer armonico. A cero es un seno puro —una flauta sosa—;
## subirlo le pone madera. Es lo unico que separa esto de un pitido.
@export_range(0.0, 1.0, 0.01) var armonicos: float = 0.38
## Ancho estereo del corro. El puesto de la izquierda se oye a la izquierda.
@export_range(0.0, 1.0, 0.01) var ancho_estereo: float = 0.45
## Frecuencia de muestreo del sintetizador. 22050 es la mitad del estandar y se
## nota cero en un instrumento de madera —no hay nada por encima de 11 kHz que
## importe aqui— y cuesta exactamente la mitad de bucle en GDScript.
@export_range(8000.0, 48000.0, 50.0) var mix_rate: float = 22050.0

@export_group("Marcapasos")
## Quien puede llevar el compas. Vacio = el jugador que anuncie
## `EventBus.player_spawned`. NodePath y no `Node3D` — regla dura #10.
@export var jugador_path: NodePath
## A que distancia del CORRO empieza a oirsele el compas. Se mide al corro y no a
## cada musico, por lo mismo que la escolta de la bandada: un musico enganchado no
## se mueve de su taburete, asi que su distancia no dice nada.
@export_range(0.0, 60.0, 0.5) var radio_llamada: float = 9.0
## Fuerza de la llamada, en fraccion de `k_max`. Es la `A` de `|ωᵢ − Ω| ≤ A`.
##
## **Y tiene que ser COMPARABLE A LA DISPERSION de frecuencias, o engancha todo el
## mundo.** A 1.1 salia A = 12.58 contra una dispersion de 2.38: la condicion se
## cumplia con holgura para los ocho y el corro se volvia un metronomo del
## jugador. Es el mismo fallo que tuvo la escolta de la bandada, y aqui se arregla
## por donde toca —el numero que la ecuacion compara— en vez de con un rasgo mas.
@export_range(0.0, 4.0, 0.01) var fuerza_llamada: float = 0.12
## Que fraccion del corro TE PRESTA ATENCION. Ver `_llamar()`: sin esto el
## acoplamiento del grupo arrastra a los demas detras de los primeros y acaban
## siguiendote los ocho.
@export_range(0.0, 1.0, 0.05) var fraccion_curiosa: float = 0.5

var enjambre: Enjambre

var _jugador: Node3D
var _reproductor: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
var _tabla: PackedFloat32Array = []
## Una voz por asiento: nota sonando, o apagada.
var _voces: Array[Dictionary] = []
## COPIA DE ESTE LADO de donde esta cada musico y cuanto brilla. Regla dura #23:
## al servidor de render no se le pregunta el estado del juego.
var _musicos: Array[MeshInstance3D] = []
var _brillos: PackedFloat32Array = []
var _subpaso: PackedInt32Array = []
var _ultima_nota: PackedFloat32Array = []
var _mat_musico: Array[StandardMaterial3D] = []
var _golpes_totales: int = 0


func _ready() -> void:
	if palette == null:
		palette = GameState.palette
	if tuning == null:
		var base := EnjambreTuning.new()
		tuning = base.a_ritmo((TAU / maxf(compas_segundos, 0.2)) / base.frecuencia_base)
	tuning.agentes = asientos

	_montar_corro()
	_montar_audio()

	enjambre = Enjambre.new()
	enjambre.name = "Enjambre"
	enjambre.tuning = tuning
	enjambre.palette = palette
	add_child(enjambre)
	# EL COMPAS QUE PROPONE EL JUGADOR es el del medio de la banda. Con Ω igual a
	# `frecuencia_base`, quien puede seguirle son los musicos de tempo medio: los
	# extremos —el mas lento y el mas rapido— siguen a lo suyo pase lo que pase.
	# Es la misma eleccion que la bandada, y por el mismo motivo: que "algunos, no
	# todos" salga de la ecuacion y no de un sorteo.
	enjambre.marcapasos_omega = tuning.frecuencia_base

	_subpaso.resize(asientos)
	_ultima_nota.resize(asientos)
	_brillos.resize(asientos)
	for i in asientos:
		_subpaso[i] = _paso_de(i)
		_ultima_nota[i] = 0.0
		_brillos[i] = 0.0

	if jugador_path.is_empty():
		EventBus.player_spawned.connect(_adoptar)
	else:
		_jugador = get_node_or_null(jugador_path) as Node3D


func _adoptar(p: Node3D) -> void:
	if _jugador == null:
		_jugador = p


## A quien escuchar, ya montado el nodo. Mismo motivo que `Pasto.seguir()`: el
## `NodePath` solo se resuelve si estaba puesto ANTES de `add_child`, y un sistema
## construido por codigo casi nunca lo esta.
func seguir(nodo: Node3D) -> void:
	_jugador = nodo


func _physics_process(delta: float) -> void:
	_llamar()
	_revisar_golpes()
	_animar(delta)


func _process(_delta: float) -> void:
	_rellenar_audio()


# --- El compas ----------------------------------------------------------------

## En que subdivision del compas va el musico `i`. Un entero que solo sube: el
## golpe es que CAMBIE, no que la fase cruce un valor.
##
## Comparar contra un umbral —"toca cuando el ciclo pase de 0.5"— parece lo mismo
## y no lo es: con un ciclo que sube y baja hay que acordarse del valor anterior
## para saber en que sentido lo cruzo, y si un frame se salta el umbral entero la
## nota no suena. Contando escalones no se pierde ninguno.
func _paso_de(i: int) -> int:
	if enjambre == null:
		return 0
	return int(floorf(enjambre.fase_de(i) / TAU * float(golpes_por_compas)))


func _revisar_golpes() -> void:
	for i in asientos:
		var p := _paso_de(i)
		if p != _subpaso[i]:
			_subpaso[i] = p
			tocar(i)


## GOLPEA el puesto `i`. Publico: sirve para que algo de fuera —un test, un
## enemigo, el jugador— haga sonar un puesto sin esperar a su compas.
func tocar(i: int) -> void:
	if i < 0 or i >= asientos or enjambre == null:
		return
	var hz := nota_de(i)
	_ultima_nota[i] = hz
	_brillos[i] = 1.0
	_golpes_totales += 1
	golpe.emit(i, hz)
	# El volumen sale del enjambre, no de aqui: `amplitud_de()` ya baja a los
	# desviados —"las desviadas cantan mas flojo"— y eso es lo que convierte el
	# orden en volumen. Disperso se oye un murmullo; al unisono, un acorde.
	var vol: float = 0.25 + enjambre.amplitud_de(i) * 0.75
	var pan: float = 0.0
	if asientos > 1:
		pan = sin(TAU * float(i) / float(asientos)) * ancho_estereo
	_voces[i] = {
		"paso": hz * float(_tabla.size()) / maxf(mix_rate, 1.0),
		"cursor": 0.0,
		"amp": vol,
		"caida": pow(0.001, 1.0 / maxf(nota_duracion * mix_rate, 1.0)),
		"izq": clampf(0.5 - pan * 0.5, 0.0, 1.0),
		"der": clampf(0.5 + pan * 0.5, 0.0, 1.0),
	}


## LA NOTA del puesto `i`, en Hz.
##
## Dos sumandos y cada uno viene de un sitio distinto, que es la idea entera:
##
##   el PUESTO pone el registro  -> fijo, reparte dos octavas por el corro
##   el AGENTE pone el grado     -> su ciclo elige uno de los cinco de la escala
##
## Al sincronizarse, los ocho eligen el MISMO grado a la vez y suena un acorde
## repartido en dos octavas. Desincronizados, cinco grados distintos sonando a
## destiempo — y como la escala es pentatonica, eso tampoco puede sonar mal.
func nota_de(i: int) -> float:
	if escala.is_empty() or enjambre == null:
		return tonica
	var n := escala.size()
	var grado: int = clampi(int(enjambre.ciclo_de(i) * float(n)), 0, n - 1)
	# TODO EN GRADOS, y la conversion a semitonos se hace UNA vez al final. El
	# indice de escala se lleva la octava consigo: dividir da la octava y el resto
	# da la nota, asi que sumar registro y grado no puede sacar de la escala.
	var paso: int = 0
	if asientos > 1:
		paso = int(roundf(float(registro_grados) * float(i) / float(asientos - 1)))
	var idx := paso + grado
	var semis: int = escala[posmod(idx, n)] + 12 * (idx / n)
	return tonica * pow(2.0, float(semis) / 12.0)


## Cuantos musicos llevan TU compas ahora mismo.
func enganchados(umbral: float = 0.6) -> int:
	return enjambre.enganchados(umbral) if enjambre != null else 0


## Golpes dados desde que existe la estacion. Para tests: un sistema que suena se
## afirma contando ataques, no leyendo el altavoz.
func golpes() -> int:
	return _golpes_totales


## Ultima nota que sono en el puesto `i`, en Hz. 0 si no ha tocado aun.
func nota_sonando(i: int) -> float:
	return _ultima_nota[i] if i >= 0 and i < _ultima_nota.size() else 0.0


## Sitio del puesto `i` en el mundo.
func sitio(i: int) -> Vector3:
	if i < 0 or i >= _musicos.size() or not is_instance_valid(_musicos[i]):
		return global_position
	return _musicos[i].global_position


## LA LLAMADA, y se mide AL CORRO. Copiada de `Bandada._llamar()` a proposito: es
## el mismo problema y ya se resolvio mal una vez alli. Medir la distancia a cada
## musico no sirve —esta sentado, no se acerca ni se aleja—, asi que lo que decide
## es lo cerca que estas del sitio.
func _llamar() -> void:
	if _jugador == null or not is_instance_valid(_jugador) or enjambre == null:
		return
	var d := (_jugador.global_position - global_position).length()
	var cerca: float = 1.0 - smoothstep(radio_llamada * 0.45, radio_llamada, d)
	if cerca <= 0.001:
		return
	var fuerza := tuning.k_max * fuerza_llamada * cerca
	for i in asientos:
		# NO TODOS TE OYEN, y hace falta decirlo aparte de la ecuacion.
		#
		# Con la llamada igual para todos, el marcapasos engancha a unos cuantos y
		# **el acoplamiento del grupo arrastra al resto detras**: medido, 5 de 8
		# enganchados y 2 de ellos sin cumplir `|ωᵢ − Ω| ≤ A`. Es fisica correcta
		# —un corro acoplado se mueve como una cosa— y es lo contrario de lo que se
		# busca. Le paso lo mismo a la escolta de la bandada y se arreglo igual: con
		# un SEGUNDO rasgo fijo, la `curiosidad`, que decide quien presta atencion.
		#
		# Que sea fijo es lo que lo hace bueno: son siempre los mismos, asi que se
		# aprende a reconocerlos, y eso es mejor que un sorteo.
		var c := tuning.curiosidad(i, asientos)
		var oye: float = 1.0 - smoothstep(fraccion_curiosa - 0.06, fraccion_curiosa + 0.06, c)
		if oye > 0.001:
			enjambre.pedir_tiron(i, fuerza * oye)


# --- Manifestacion visual -----------------------------------------------------

func _animar(delta: float) -> void:
	if enjambre == null:
		return
	for i in _musicos.size():
		var m := _musicos[i]
		if not is_instance_valid(m):
			continue
		_brillos[i] = maxf(0.0, _brillos[i] - golpe_caida * delta)
		var ciclo := enjambre.ciclo_de(i)
		var base := _sitio_local(i)
		m.position = base + Vector3.UP * (ciclo * vaiven + _brillos[i] * golpe_estiron)
		# NO SE ROTA. Ni aqui ni en el Jardin: un cuerpo que solo puede decir donde
		# esta, cuanto ocupa y de que color es se lee de un vistazo, y ocho girando
		# a la vez no.
		var e: float = 1.0 + _brillos[i] * golpe_estiron
		m.scale = Vector3(1.0, e, 1.0)
		if i < _mat_musico.size() and _mat_musico[i] != null:
			# EL DESVIO DESATURA, igual que en las Criaturas de Tela: el que va a su
			# aire se apaga y el que va con el grupo se enciende. Cuando los ocho
			# convergen, el corro entero es un solo color latiendo — y eso es ver la
			# sincronizacion sin que nadie ponga un numero en pantalla.
			var junto: float = 1.0 - enjambre.desvio_de(i)
			var c: Color = palette.piedra_sombra.lerp(palette.lavanda_gris, junto)
			_mat_musico[i].albedo_color = c.lerp(palette.oro_palido, _brillos[i])
			_mat_musico[i].emission_energy_multiplier = _brillos[i] * 1.6


func _sitio_local(i: int) -> Vector3:
	var a := TAU * float(i) / float(maxi(asientos, 1))
	return Vector3(cos(a) * radio, alto_taburete, sin(a) * radio)


func _montar_corro() -> void:
	var suelo := MeshInstance3D.new()
	suelo.name = "Tarima"
	var disco := CylinderMesh.new()
	disco.top_radius = radio + 1.2
	disco.bottom_radius = radio + 1.2
	disco.height = 0.12
	suelo.mesh = disco
	suelo.material_override = _mat(palette.caliza_sol, 0.9)
	suelo.position = Vector3(0.0, 0.06, 0.0)
	add_child(suelo)

	for i in asientos:
		var p := _sitio_local(i)

		var taburete := MeshInstance3D.new()
		taburete.name = "Taburete%d" % i
		var cil := CylinderMesh.new()
		cil.top_radius = 0.28
		cil.bottom_radius = 0.32
		cil.height = alto_taburete
		taburete.mesh = cil
		taburete.material_override = _mat(palette.piedra_media, 0.85)
		taburete.position = Vector3(p.x, alto_taburete * 0.5, p.z)
		add_child(taburete)

		# CAPSULA GRIS, regla dura #7: el feel se prueba sin una sola animacion.
		# Cuando haya musicos de Blender, esta malla es lo unico que se cambia.
		var musico := MeshInstance3D.new()
		musico.name = "Musico%d" % i
		var caps := CapsuleMesh.new()
		caps.radius = 0.26
		caps.height = 1.05
		musico.mesh = caps
		var mat := _mat(palette.lavanda_gris, 0.8)
		mat.emission_enabled = true
		mat.emission = palette.oro_palido
		mat.emission_energy_multiplier = 0.0
		musico.material_override = mat
		musico.position = p + Vector3.UP * 0.52
		add_child(musico)
		_musicos.append(musico)
		_mat_musico.append(mat)
		_voces.append({})


func _mat(color: Color, rugosidad: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugosidad
	return m


# --- El sintetizador ----------------------------------------------------------

## LA TABLA DE ONDA. Un ciclo, precalculado.
##
## Se hace asi y no con `sin()` por muestra porque el bucle de mezcla corre en
## GDScript: a 22050 Hz y 60 fps son ~368 muestras por frame y por voz, y ocho
## voces son ~2.900 vueltas. Un `sin()` en cada una es el triple de coste que un
## indice en un array, y el resultado es identico.
func _montar_tabla() -> void:
	const N := 1024
	_tabla.resize(N)
	for i in N:
		var f := TAU * float(i) / float(N)
		# Segundo y tercer armonico. Un seno puro es una flauta de juguete; con
		# esto suena a algo golpeado.
		var v := sin(f) + armonicos * 0.5 * sin(f * 2.0) + armonicos * 0.25 * sin(f * 3.0)
		_tabla[i] = v / (1.0 + armonicos * 0.75)


func _montar_audio() -> void:
	_montar_tabla()
	_reproductor = AudioStreamPlayer3D.new()
	_reproductor.name = "Altavoz"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = mix_rate
	# Buffer corto: es lo que separa el golpe de cuando se ve al musico estirarse.
	gen.buffer_length = 0.12
	_reproductor.stream = gen
	_reproductor.volume_db = volumen_db
	_reproductor.max_distance = alcance
	_reproductor.unit_size = alcance * 0.35
	add_child(_reproductor)
	_reproductor.play()
	# EN HEADLESS EL DRIVER ES UN MANIQUI y esto puede volver nulo. Se guarda y se
	# comprueba, en vez de preguntarlo cada frame: es la misma leccion que la regla
	# dura #23 —un test no puede depender de que exista el aparato que dibuja o
	# suena—, y por eso lo que se AFIRMA de la musica se cuenta con `golpes()`.
	_playback = _reproductor.get_stream_playback() as AudioStreamGeneratorPlayback


func _rellenar_audio() -> void:
	if _playback == null:
		return
	var libres := _playback.get_frames_available()
	if libres <= 0:
		return
	var n := _tabla.size()
	var buf := PackedVector2Array()
	buf.resize(libres)
	for s in libres:
		var izq := 0.0
		var der := 0.0
		for i in _voces.size():
			var v: Dictionary = _voces[i]
			if v.is_empty():
				continue
			var amp: float = v["amp"]
			if amp < 0.0008:
				_voces[i] = {}
				continue
			var cur: float = v["cursor"]
			var m: float = _tabla[int(cur) % n] * amp
			izq += m * float(v["izq"])
			der += m * float(v["der"])
			v["cursor"] = fposmod(cur + float(v["paso"]), float(n))
			v["amp"] = amp * float(v["caida"])
		# Techo blando: ocho voces al unisono se pasan de 1.0 y eso recorta feo.
		buf[s] = Vector2(clampf(izq, -1.0, 1.0), clampf(der, -1.0, 1.0))
	_playback.push_buffer(buf)


func debug_line() -> String:
	return "jam  r=%.2f  %d/%d contigo  %d golpes" % [
		enjambre.orden if enjambre != null else 0.0,
		enganchados(), asientos, _golpes_totales]
