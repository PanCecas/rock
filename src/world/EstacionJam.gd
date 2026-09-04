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

## El teclado del instrumento: 5 columnas x 3 filas, como en la referencia.
const TECLAS_COL := 5
const TECLAS_FIL := 3
const TECLAS := TECLAS_COL * TECLAS_FIL

## LAS TRES FAMILIAS del corro. El orden importa: es el mismo que usan la silueta
## del instrumento y el color, porque los tres salen de `grado_de()`.
enum Familia {PIANO, GUITARRA, VIENTO}
const NOMBRE_FAMILIA := ["PIANO", "GUIT", "VIENTO"]

## EL ESPECTRO DE CADA FAMILIA: amplitud de cada armonico, del 1 en adelante.
##
## Es media identidad del instrumento. La otra media —y la que mas se oye— es la
## ENVOLVENTE: lo que separa un viento de una cuerda no es tanto que armonicos
## tenga como que **el viento arranca despacio y se sostiene**, mientras que un
## piano y una guitarra atacan de golpe y decaen sin parar. Un mismo espectro con
## las dos envolventes ya suena a dos instrumentos; dos espectros con la misma
## envolvente suenan al mismo instrumento con otro filtro.
const ESPECTRO := [
	# PIANO: cuerpo, armonicos cayendo como 1/n. Nada exotico — es lo que hace
	# que se lea como "nota de teclado" y no como un pitido.
	[1.0, 0.55, 0.34, 0.19, 0.11, 0.06, 0.035],
	# GUITARRA: mas brillo arriba. Una cuerda pulsada tiene mucho mas contenido
	# agudo que una percutida, y es lo que le da el "tang" del pulgar.
	[1.0, 0.72, 0.52, 0.40, 0.30, 0.22, 0.16, 0.11],
	# VIENTO: casi un seno, con el TERCER armonico marcado y los pares hundidos.
	# Es el espectro de un tubo tapado, y suena a flauta sin necesidad de ruido.
	[1.0, 0.07, 0.30, 0.05, 0.12, 0.03],
]


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
## Pasos de la HOJA: cuantas filas tiene la rejilla que se escribe. 16 es un
## compas de cuatro por cuatro a semicorcheas, que es lo que la rejilla de la
## referencia deja escribir de una pasada.
@export_range(4, 64, 1) var pasos: int = 16
## La escala, en semitonos desde la tonica. Por defecto la PENTATONICA MAYOR
## —0, 2, 4, 7, 9—, que es la que no puede sonar mal consigo misma.
@export var escala: PackedInt32Array = PackedInt32Array([0, 2, 4, 7, 9])
## Tonica, en Hz. 196.00 es un SOL3.
##
## `EnjambreTuning.pitch_base` vale 174.61 —un fa— y aqui no se hereda a
## proposito: la altura del corro es una decision de escena, igual que cuantos
## musicos hay. El panel la cambia en vivo con los siete nombres naturales.
@export_range(40.0, 900.0, 0.01) var tonica: float = 196.00
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
## Cuanto tarda una nota en apagarse, en segundos. Es la de referencia: las graves
## duran mas y las agudas menos (ver `decaimiento_grave`).
@export_range(0.05, 6.0, 0.05) var nota_duracion: float = 1.1
## ATAQUE de la nota, en segundos.
##
## Sin el, la onda arranca de golpe en una amplitud cualquiera y eso es una
## discontinuidad: se oye como un CHASQUIDO delante de cada nota, y con ocho
## puestos atacando cinco veces por segundo el corro entero sonaba a estatica. Ocho
## milisegundos no se perciben como un ataque lento y quitan el clic entero.
@export_range(0.0, 0.2, 0.001) var nota_ataque: float = 0.008
## ATAQUE del viento, en segundos. Cien veces mas lento que el de una cuerda a
## proposito: el aire tarda en llenar el tubo, y ESO es lo que se oye como
## "instrumento de viento" antes que cualquier armonico.
@export_range(0.0, 0.6, 0.005) var viento_ataque: float = 0.09
## Cuanto SOSTIENE el viento antes de empezar a caer, en segundos. Un piano no
## sostiene: golpea y decae. Un viento se mantiene mientras hay aire.
@export_range(0.0, 2.0, 0.01) var viento_sostener: float = 0.32
## Multiplicadores de duracion por familia. La guitarra se apaga antes que el
## piano —una cuerda pulsada pierde energia mas rapido que uno de tres metros—.
@export_range(0.2, 3.0, 0.05) var dur_piano: float = 1.25
@export_range(0.2, 3.0, 0.05) var dur_guitarra: float = 0.85
@export_range(0.2, 3.0, 0.05) var dur_viento: float = 0.55
## Con que instrumento suena el TECLADO de la hoja. El piano por defecto: es el
## timbre mas neutro para probar una nota y volver a encontrarla.
@export var familia_teclado: Familia = Familia.PIANO
## Cuanto mas RESUENAN las graves que las agudas, como exponente.
##
## En un instrumento de verdad la cuerda larga vibra mas tiempo, y sin esto los
## ocho registros se apagaban a la vez: el bajo sonaba tan corto como el agudo y el
## corro no tenia suelo. A 0.6, el puesto grave dura casi el doble que el agudo.
@export_range(0.0, 2.0, 0.05) var decaimiento_grave: float = 0.6
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
## LA HOJA DE NOTAS. Se monta con la estacion y arranca oculta.
var panel: PanelJam

var _jugador: Node3D
var _reproductor: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
var _tabla: PackedFloat32Array = []
## Una tabla de onda por familia. Ver `ESPECTRO`.
var _tablas: Array[PackedFloat32Array] = []
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
## LA HOJA: `_hoja[paso][asiento]` vale 1 si ese musico ataca en ese paso.
## Vacia = los ocho improvisan, que es como nace la estacion.
var _hoja: Array[PackedByteArray] = []
var _encendidas: int = 0
## Cabezal de la hoja. Corre con la fase MEDIA del enjambre, no con la de nadie.
var _reloj_hoja: float = 0.0
var _fase_media_ant: float = 0.0
var _paso_hoja: int = 0


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

	_hoja.resize(pasos)
	for f in pasos:
		var fila := PackedByteArray()
		fila.resize(asientos)
		fila.fill(0)
		_hoja[f] = fila

	_subpaso.resize(asientos)
	_ultima_nota.resize(asientos)
	_brillos.resize(asientos)
	for i in asientos:
		_subpaso[i] = _paso_de(i)
		_ultima_nota[i] = 0.0
		_brillos[i] = 0.0

	panel = PanelJam.new(self)
	panel.name = "PanelJam"
	add_child(panel)

	if jugador_path.is_empty():
		EventBus.player_spawned.connect(_adoptar)
	else:
		_jugador = get_node_or_null(jugador_path) as Node3D


## LA HOJA SE ABRE CON `interact` Y SOLO ESTANDO AL LADO.
##
## La distancia importa: el mismo boton abre otras cosas en otros sitios, y una
## interfaz que se abre desde el otro lado del mapa es una tecla robada. Se mide
## al corro —no a un musico— por lo mismo que la llamada.
func _unhandled_input(evento: InputEvent) -> void:
	if panel == null or not InputMap.has_action(InputActions.INTERACT):
		return
	if not evento.is_action_pressed(InputActions.INTERACT):
		return
	if not panel.visible:
		if _jugador == null or not is_instance_valid(_jugador):
			return
		if _jugador.global_position.distance_to(global_position) > radio_llamada:
			return
	panel.alternar()
	get_viewport().set_input_as_handled()


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
	# LA HOJA MANDA SI HAY ALGO ESCRITO. Con la rejilla vacia los ocho improvisan
	# —cada uno con su fase, que es como nace la estacion—; en cuanto escribes una
	# nota, tocan lo tuyo. No hay modo que elegir: lo dice el contenido.
	if _encendidas > 0:
		_revisar_hoja()
	else:
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
	_sonar(hz, vol, pan, familia_de(i))


## Mete una nota en la mezcla, cogiendo una VOZ del pool.
##
## El pool es comun a los musicos y al teclado: probar una tecla mientras el corro
## toca no le roba la voz a nadie ni monta un segundo sintetizador. Cuando no queda
## ninguna libre se pisa la mas floja, que es la que menos se va a echar de menos.
func _sonar(hz: float, vol: float, pan: float, familia: int = Familia.PIANO) -> void:
	var libre := 0
	var mas_floja := 9.0
	for v in _voces.size():
		var dd: Dictionary = _voces[v]
		if dd.is_empty():
			libre = v
			break
		var a: float = dd["amp"]
		if a < mas_floja:
			mas_floja = a
			libre = v
	var f: int = clampi(familia, 0, _tablas.size() - 1)
	# LAS GRAVES RESUENAN MAS. Una cuerda larga vibra mas tiempo, y sin esto los
	# ocho registros se apagaban a la vez y el corro no tenia suelo.
	var dur: float = nota_duracion * pow(
		clampf(tonica / maxf(hz, 1.0), 0.35, 3.0), decaimiento_grave)
	var ataque := nota_ataque
	var sostener := 0.0
	match f:
		Familia.PIANO:
			dur *= dur_piano
		Familia.GUITARRA:
			# La guitarra ataca AUN mas seco que el piano: el martillo tiene fieltro
			# y el dedo no.
			ataque *= 0.4
			dur *= dur_guitarra
		Familia.VIENTO:
			ataque = viento_ataque
			sostener = viento_sostener
			dur *= dur_viento
	var subida: int = maxi(1, int(ataque * mix_rate))
	var tabla: PackedFloat32Array = _tablas[f]
	_voces[libre] = {
		"paso": hz * float(tabla.size()) / maxf(mix_rate, 1.0),
		"cursor": 0.0,
		"amp": 0.0,
		"tope": vol,
		"tabla": f,
		# El ataque es LINEAL y en muestras: un incremento fijo por muestra, que es
		# una suma en el bucle interno. Una curva costaria una potencia por muestra
		# y no se distinguiria en ocho milisegundos.
		"sube": float(vol) / float(subida),
		# MESETA. Solo el viento la tiene, y es la mitad de lo que lo identifica:
		# muestras sonando al tope antes de empezar a caer.
		"meseta": float(sostener * mix_rate),
		"caida": pow(0.001, 1.0 / maxf(dur * mix_rate, 1.0)),
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
	# NOTA: `grado_de()` recalcula solo el `paso`; los dos salen de la misma linea
	# a proposito. Si esto cambia, cambia alli.
	var semis: int = escala[posmod(idx, n)] + 12 * (idx / n)
	return tonica * pow(2.0, float(semis) / 12.0)


## EL CABEZAL DE LA HOJA CORRE CON LA FASE MEDIA DEL ENJAMBRE.
##
## Y no con un temporizador, que es lo que haria un secuenciador cualquiera. Es la
## decision que FUSIONA las dos mitades en vez de ponerlas una al lado de la otra:
## el reloj de la hoja ES el del corro, asi que **cuanto mas juntos van, mejor
## tocan lo que escribiste**. Desordenados, la fase media se bambolea y el compas
## sale torcido; al unisono, va como un reloj.
##
## Se lleva desenrollada porque `fase_media` da vueltas de 0 a TAU: sumar el salto
## envuelto en cada frame es lo unico que convierte un angulo en un contador.
func _revisar_hoja() -> void:
	if enjambre == null:
		return
	var media := enjambre.fase_media
	_reloj_hoja += wrapf(media - _fase_media_ant, -PI, PI)
	_fase_media_ant = media
	var por_paso: float = TAU / float(maxi(golpes_por_compas, 1))
	var p: int = posmod(int(floorf(_reloj_hoja / por_paso)), maxi(pasos, 1))
	if p == _paso_hoja:
		return
	_paso_hoja = p
	var fila: PackedByteArray = _hoja[p]
	for i in asientos:
		if fila[i] != 0:
			tocar(i)


## Enciende o apaga una celda de la hoja. Devuelve como queda.
func alternar_celda(paso: int, asiento: int) -> bool:
	if paso < 0 or paso >= pasos or asiento < 0 or asiento >= asientos:
		return false
	var fila: PackedByteArray = _hoja[paso]
	var nuevo: int = 0 if fila[asiento] != 0 else 1
	_encendidas += 1 if nuevo == 1 else -1
	fila[asiento] = nuevo
	_hoja[paso] = fila
	return nuevo == 1


func celda(paso: int, asiento: int) -> bool:
	if paso < 0 or paso >= pasos or asiento < 0 or asiento >= asientos:
		return false
	return _hoja[paso][asiento] != 0


## Borra la hoja entera y devuelve a los ocho a improvisar.
func borrar_hoja() -> void:
	for f in pasos:
		var fila: PackedByteArray = _hoja[f]
		fila.fill(0)
		_hoja[f] = fila
	_encendidas = 0


func notas_escritas() -> int:
	return _encendidas


## Por que paso va el cabezal. Lo pinta la rejilla.
func paso_actual() -> int:
	return _paso_hoja


## LA NOTA DE LA TECLA `t`, en Hz. Quince teclas en 5x3, tres octavas de la
## pentatonica: la misma escala que tocan los musicos, para que probar una nota a
## mano no pueda sonar mal contra lo que ya esta sonando.
func nota_de_tecla(t: int) -> float:
	if escala.is_empty():
		return tonica
	var n := escala.size()
	var idx: int = clampi(t, 0, TECLAS - 1)
	var semis: int = escala[posmod(idx, n)] + 12 * (idx / n)
	return tonica * pow(2.0, float(semis) / 12.0)


## Toca una tecla AHORA. Es la audicion: suena y no escribe nada.
func pulsar_tecla(t: int) -> void:
	_sonar(nota_de_tecla(t), 0.8, 0.0, familia_teclado)


## CAMBIAR EL COMPAS EN VIVO, sin reconstruir nada.
##
## Poner el mismo modelo a otra velocidad es un cambio de variable `t' = t·f`, asi
## que cada magnitud escala por SU potencia de `f` —`a_ritmo()` lo tiene escrito y
## el test lo vigila—. Aqui se aplica sobre el tuning que ya esta corriendo, no
## sobre uno nuevo: el enjambre guarda la referencia, y darle otro objeto le
## borraria las fases y devolveria el corro al caos cada vez que muevas el tempo.
func cambiar_compas(segundos: float) -> void:
	var nuevo: float = clampf(segundos, 0.2, 8.0)
	var f: float = compas_segundos / nuevo
	if is_equal_approx(f, 1.0):
		return
	compas_segundos = nuevo
	tuning.frecuencia_base *= f
	tuning.dispersion *= f
	tuning.k_min *= f
	tuning.k_max *= f
	tuning.k_subida *= f * f
	tuning.k_bajada *= f * f
	tuning.perturbacion_duracion /= f
	tuning.enganche_suavizado /= f
	# Las frecuencias YA REPARTIDAS tambien: viven en el enjambre desde
	# `reiniciar()`, y dejarlas sin escalar seria tener el acoplamiento a un ritmo
	# y a los agentes a otro.
	if enjambre != null:
		for i in enjambre.omegas.size():
			enjambre.omegas[i] *= f
		enjambre.marcapasos_omega = tuning.frecuencia_base


## EN QUE GRADO DE LA ESCALA cae el musico `i`.
##
## Publico, y sale del MISMO reparto que usa `nota_de()`. De aqui cuelgan su
## tamano, su color y la forma que le pinta la rejilla: cuatro sitios preguntando
## lo mismo con cuatro cuentas distintas es como se llega a que el corro diga una
## cosa y la hoja otra.
func grado_de(i: int) -> int:
	if asientos <= 1 or escala.is_empty():
		return 0
	var paso: int = int(roundf(
		float(registro_grados) * float(i) / float(maxi(asientos - 1, 1))))
	return posmod(paso, escala.size())


## LA NOTA RAIZ del musico `i`: la que suena cuando su ciclo esta abajo.
##
## Es su IDENTIDAD —lo que no cambia—, frente a `nota_de()`, que sube y baja con la
## fase. La rejilla la usa como cabecera de columna: "esta columna es el SOL2".
func nota_raiz_de(i: int) -> float:
	if escala.is_empty():
		return tonica
	var n := escala.size()
	var paso: int = 0
	if asientos > 1:
		paso = int(roundf(float(registro_grados) * float(i) / float(asientos - 1)))
	var semis: int = escala[posmod(paso, n)] + 12 * (paso / n)
	return tonica * pow(2.0, float(semis) / 12.0)


## QUE INSTRUMENTO TOCA el musico `i`.
##
## SALE DEL PUESTO, no del grado, y esto costo una vuelta. Colgarlo de `grado_de()`
## era mas ordenado sobre el papel —un solo numero para el color, la silueta y el
## timbre— pero el reparto que produce es malo: medido, los ocho puestos daban
## **PIANO, GUIT, PIANO, GUIT, GUIT, VIENTO, GUIT, PIANO**, o sea cuatro guitarras
## y un solo viento. Una banda no es un sorteo con sesgo.
##
## Asi que son DOS criterios y cada uno dice una cosa distinta:
##
##   grado en la escala  -> el COLOR, y el rombo o circulo de la rejilla. Es el
##                          papel MUSICAL: donde apoya el acorde.
##   puesto en el corro  -> el INSTRUMENTO, y por tanto su silueta. Es quien es.
##
## Que sean dos no contradice la regla de "un solo criterio": la regla prohibe dos
## numeros contestando la MISMA pregunta, y aqui contestan dos preguntas que no se
## parecen. Lo que si esta prohibido es que la silueta salga de uno y el sonido del
## otro — por eso `_malla_instrumento()` recibe la familia, no el grado.
func familia_de(i: int) -> int:
	return posmod(i, ESPECTRO.size())


func nombre_de_familia(i: int) -> String:
	return NOMBRE_FAMILIA[familia_de(i)]


## EL NOMBRE DE UNA FRECUENCIA, en solfeo y con octava: "SOL3", "LA#4".
##
## En solfeo y no en cifrado americano porque es lo que se pidio y lo que se lee
## sin traducir. Se calcula desde LA4 = 440 Hz, que es la referencia estandar, y no
## desde la tonica: asi el nombre sigue siendo cierto cuando se cambia de tono.
func nombre_de_nota(hz: float) -> String:
	const NOMBRES := ["DO", "DO#", "RE", "RE#", "MI", "FA",
		"FA#", "SOL", "SOL#", "LA", "LA#", "SI"]
	if hz <= 0.0:
		return "—"
	var midi: int = int(roundf(69.0 + 12.0 * log(hz / 440.0) / log(2.0)))
	return "%s%d" % [NOMBRES[posmod(midi, 12)], midi / 12 - 1]


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
			# EL DESVIO DESATURA SOBRE SU PROPIO COLOR, no sobre uno comun: cada
			# musico se apaga hacia la sombra y vuelve al SUYO, asi que se le sigue
			# reconociendo mientras va a su aire.
			var c: Color = palette.piedra_sombra.lerp(_color_de_grado(grado_de(i)), junto)
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
		# 0 en el grave, 1 en el agudo. De aqui cuelga el TAMANO.
		var t: float = float(i) / float(maxi(asientos - 1, 1))

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

		# CADA MUSICO SE DISTINGUE DE LOS DEMAS, y por dos canales que no mienten:
		#
		#   TAMANO  <- su registro. El bajo es grande y el agudo pequeno, que es la
		#              lectura fisica del tono: cuerpo grande, sonido grave. Un corro
		#              de ocho identicos no dice quien esta tocando que.
		#   COLOR   <- su GRADO en la escala, el mismo numero que decide si la
		#              rejilla lo pinta rombo o circulo. Asi el corro y la hoja se
		#              pueden mirar a la vez sin traducir.
		#
		# El BRILLO queda libre para el golpe, que es lo unico que cambia por frame.
		var cuerpo: float = lerpf(1.30, 0.72, t)
		var musico := MeshInstance3D.new()
		musico.name = "Musico%d" % i
		var caps := CapsuleMesh.new()
		caps.radius = 0.26 * cuerpo
		caps.height = 1.05 * cuerpo
		musico.mesh = caps
		var mat := _mat(_color_de_grado(grado_de(i)), 0.8)
		mat.emission_enabled = true
		mat.emission = palette.oro_palido
		mat.emission_energy_multiplier = 0.0
		musico.material_override = mat
		musico.position = p + Vector3.UP * (0.5 * 1.05 * cuerpo)
		add_child(musico)
		_musicos.append(musico)
		_mat_musico.append(mat)

		# Y EL INSTRUMENTO delante, que es lo que se ve de lejos: la silueta cambia
		# aunque el color se pierda en la niebla. Tres formas y no ocho, porque lo
		# que hay que distinguir son los GRADOS, no los individuos.
		var inst := MeshInstance3D.new()
		inst.name = "Instrumento%d" % i
		inst.mesh = _malla_instrumento(familia_de(i), cuerpo)
		inst.material_override = _mat(palette.piedra_sombra, 0.75)
		var hacia := (Vector3(-p.x, 0.0, -p.z)).normalized() * 0.42
		inst.position = p + hacia + Vector3.UP * 0.34
		add_child(inst)

	# POOL DE VOCES, y mas que asientos: una fila de la hoja con seis musicos
	# marcados son seis ataques en el mismo frame, y encima el teclado puede estar
	# sonando. Con una voz por asiento, el acorde se comia a si mismo.
	_voces.resize(asientos * 2 + 4)
	for v in _voces.size():
		_voces[v] = {}


## Un color por grado de la escala, todos de la Palette (regla dura #9). Cinco
## tonos que se distinguen entre si SIN salirse del croma que la regla #8 permite
## a un elemento de entorno.
func _color_de_grado(g: int) -> Color:
	var tonos: Array[Color] = [
		palette.lavanda_gris, palette.crema_medio, palette.piedra_media,
		palette.lavanda_profundo, palette.caliza_sol,
	]
	return tonos[posmod(g, tonos.size())]


## LA SILUETA DEL INSTRUMENTO, y cada una es la de lo que suena.
##
## No son tres formas decorativas repartidas: el que suena a piano lleva un cajon
## de teclado, el de guitarra una caja con mastil y el de viento un tubo. De lejos,
## cuando el color se pierde en la niebla, la silueta sigue diciendo que vas a oir.
func _malla_instrumento(familia: int, escala_cuerpo: float) -> Mesh:
	match posmod(familia, ESPECTRO.size()):
		Familia.PIANO:
			# Cajon de teclado: ancho, plano y horizontal.
			var t := BoxMesh.new()
			t.size = Vector3(0.52, 0.12, 0.24) * escala_cuerpo
			return t
		Familia.GUITARRA:
			# Caja de cuerda: plana y alta, de canto.
			var c := BoxMesh.new()
			c.size = Vector3(0.30, 0.46, 0.09) * escala_cuerpo
			return c
		_:
			# Tubo: fino y vertical. Es la silueta que mas se distingue de las otras
			# dos a treinta metros, y por eso se la queda el viento.
			var e := CylinderMesh.new()
			e.top_radius = 0.055 * escala_cuerpo
			e.bottom_radius = 0.075 * escala_cuerpo
			e.height = 0.62 * escala_cuerpo
			return e


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
	_tablas.clear()
	for fam in ESPECTRO.size():
		var espectro: Array = ESPECTRO[fam]
		var t := PackedFloat32Array()
		t.resize(N)
		# Se normaliza por la SUMA de amplitudes y no por el pico real: el pico de
		# una suma de senos depende de las fases y calcularlo costaria otra pasada.
		# Por la suma es una cota superior, asi que nunca satura — a cambio las
		# familias con muchos armonicos salen un pelin mas flojas, que es justo lo
		# que hace falta para que la guitarra no se coma al viento.
		var suma := 0.0
		for a in espectro:
			suma += absf(float(a))
		for i in N:
			var f := TAU * float(i) / float(N)
			var v := 0.0
			for n in espectro.size():
				v += float(espectro[n]) * sin(f * float(n + 1))
			t[i] = v / maxf(suma, 0.001)
		_tablas.append(t)
	# `_tabla` sigue existiendo y apunta a la primera: es lo que mira el test para
	# saber que el sintetizador se monto, y no merece un cambio de contrato.
	_tabla = _tablas[0]


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
	var n := _tablas[0].size()
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
			var sube: float = v["sube"]
			if sube <= 0.0 and amp < 0.0008:
				_voces[i] = {}
				continue
			var cur: float = v["cursor"]
			var tabla: PackedFloat32Array = _tablas[int(v["tabla"])]
			var m: float = tabla[int(cur) % n] * amp
			izq += m * float(v["izq"])
			der += m * float(v["der"])
			v["cursor"] = fposmod(cur + float(v["paso"]), float(n))
			if sube > 0.0:
				# Rampa de ataque: sube hasta el tope y a partir de ahi, meseta.
				amp += sube
				if amp >= float(v["tope"]):
					amp = v["tope"]
					v["sube"] = 0.0
				v["amp"] = amp
			elif v["meseta"] > 0.0:
				# MESETA: el viento se sostiene. Solo tiene que descontar muestras;
				# la amplitud ya esta en su tope.
				v["meseta"] = float(v["meseta"]) - 1.0
			else:
				v["amp"] = amp * float(v["caida"])
		# Techo blando: ocho voces al unisono se pasan de 1.0 y eso recorta feo.
		buf[s] = Vector2(clampf(izq, -1.0, 1.0), clampf(der, -1.0, 1.0))
	_playback.push_buffer(buf)


func debug_line() -> String:
	return "jam  r=%.2f  %d/%d contigo  %d golpes  hoja %d notas, paso %d" % [
		enjambre.orden if enjambre != null else 0.0,
		enganchados(), asientos, _golpes_totales, _encendidas, _paso_hoja]
