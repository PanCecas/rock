extends Node
## Test funcional de la ESTACION DE JAM.
##
##   godot --headless --path . tools/TestJam.tscn
##
## Corre EN SECO: se pisan `_physics_process` a mano con dt fijo y se simulan
## minutos en milisegundos. Es lo mismo que hacen `TestEnjambre` y la primera
## mitad de `TestMundoVivo`, y aqui hace mas falta todavia, porque **en headless
## el driver de audio es un maniqui**: no hay altavoz que escuchar. Todo lo que se
## afirma de la musica se afirma contando ATAQUES y mirando las notas, nunca
## leyendo el aparato que suena — es la regla dura #23 aplicada al audio.
##
## Lo que NO comprueba, y se dice para que nadie lo confunda: si esto suena BIEN.
## Que la escala sea agradable, que el registro este bien repartido o que el
## decaimiento tenga cuerpo son juicios de oido y se hacen en `tools/Jam.tscn`.
## Aqui se comprueba que el sistema hace lo que dice: que las notas caen en la
## escala, que el compas es el que se pidio, y que al sincronizarse los ocho
## atacan A LA VEZ — que es la unica afirmacion audible que se puede medir.

const ESTACION := preload("res://src/world/EstacionJam.gd")

const DT := 1.0 / 60.0
## Ventana para considerar que dos ataques son "el mismo instante", en segundos.
## 40 ms es el umbral clasico por debajo del cual dos ataques se oyen como uno.
const JUNTOS := 0.04

var _e: EstacionJam
var _visitante: Node3D
var _fallos: PackedStringArray = []
var _cuenta: int = 0
## Registro de ataques: (segundo, puesto). Lo llena la senal, no una sonda.
var _ataques: Array[Vector2] = []
var _reloj: float = 0.0


func _ready() -> void:
	_montar()
	await get_tree().physics_frame
	await get_tree().physics_frame

	_el_corro()
	_las_notas()
	_el_compas()
	_la_sincronizacion()
	_el_marcapasos()
	_informe()


func _montar() -> void:
	_visitante = Node3D.new()
	_visitante.name = "Visitante"
	add_child(_visitante)
	# LEJOS del corro para empezar: la mitad de las comprobaciones son sobre el
	# sistema SIN marcapasos, y un visitante dentro del radio de llamada las
	# contaminaria todas sin decirlo.
	_visitante.global_position = Vector3(0.0, 0.0, 400.0)

	_e = ESTACION.new()
	_e.name = "EstacionJam"
	add_child(_e)
	_e.seguir(_visitante)
	_e.golpe.connect(_anotar)
	# El motor NO los pisa: los pisa este test, con dt fijo.
	_e.set_physics_process(false)
	_e.set_process(false)
	_e.enjambre.set_physics_process(false)


func _anotar(indice: int, _hz: float) -> void:
	_ataques.append(Vector2(_reloj, float(indice)))


## Avanza el sistema ENTERO un tiempo exacto. El enjambre primero y la estacion
## despues, en el mismo orden que el motor: la estacion lee fases, asi que
## invertirlo la dejaria mirando el frame anterior.
func _avanzar(segundos: float) -> void:
	for _i in int(segundos / DT):
		_e.enjambre._physics_process(DT)
		_e._physics_process(DT)
		_reloj += DT


# --- 1) El corro --------------------------------------------------------------

func _el_corro() -> void:
	_afirmar(_e.asientos == 8, "son OCHO puestos",
		"la referencia son ocho, y es lo que cabe en el corro sin taparse")

	var peor := 0.0
	var minimo := 999.0
	for i in _e.asientos:
		var d := (_e.sitio(i) - _e.global_position)
		d.y = 0.0
		peor = maxf(peor, absf(d.length() - _e.radio))
		for j in _e.asientos:
			if j != i:
				minimo = minf(minimo, _e.sitio(i).distance_to(_e.sitio(j)))
	_afirmar(peor < 0.01, "y estan en corro, todos a la misma distancia del centro",
		"el que mas se sale esta a %.3f m del radio %.2f" % [peor, _e.radio])
	_afirmar(minimo > 1.2, "con hueco para pasar entre ellos",
		"los dos mas juntos estan a %.2f m; al centro se entra andando" % minimo)

	# NO HAY ROTACION, igual que en el Jardin. Se comprueba DESPUES de dejarlo
	# correr: montarlo y mirar sin avanzar un frame pasaria igual con el bug.
	_avanzar(20.0)
	var giro := 0.0
	for i in _e.asientos:
		var b := (_e.get_node("Musico%d" % i) as Node3D).transform.basis.orthonormalized()
		giro = maxf(giro, (b.x - Vector3.RIGHT).length() + (b.z - Vector3.BACK).length())
	_afirmar(giro < 1e-4, "y NINGUNO rota, ni un frame",
		"desvio maximo de la identidad %.7f tras 20 s" % giro)


# --- 2) Las notas -------------------------------------------------------------

## TODA nota cae en la escala, venga el ciclo de donde venga.
##
## Se barre el ciclo entero a mano en vez de fiarse de lo que salga corriendo: el
## enjambre no visita todos los valores en una pasada corta, y un grado mal
## calculado en un extremo del ciclo pasaria desapercibido justo donde mas se
## nota.
func _las_notas() -> void:
	var fuera := 0
	var grados := {}
	for i in _e.asientos:
		for paso in 60:
			# Se pisa la fase para barrer el ciclo entero de ese puesto.
			_e.enjambre.fases[i] = TAU * float(paso) / 60.0
			var hz := _e.nota_de(i)
			var semis: int = int(roundf(12.0 * log(hz / _e.tonica) / log(2.0)))
			var g: int = posmod(semis, 12)
			grados[g] = true
			if not _e.escala.has(g):
				fuera += 1
	_afirmar(fuera == 0, "TODA nota cae en la pentatonica",
		"480 combinaciones de puesto y ciclo, %d fuera de la escala; es lo unico\n" %
			fuera + "        que hace que ocho voces sin director no puedan chocar")
	_afirmar(grados.size() == _e.escala.size(),
		"y se usan los cinco grados, no uno",
		"salieron %d grados distintos de %d" % [grados.size(), _e.escala.size()])

	# EL REGISTRO SUBE DANDO LA VUELTA AL CORRO. Es lo que convierte el unisono en
	# un acorde en vez de en una sola voz mas fuerte.
	for i in _e.asientos:
		_e.enjambre.fases[i] = 0.0
	var grave := _e.nota_de(0)
	var agudo := _e.nota_de(_e.asientos - 1)
	var octavas: float = log(agudo / grave) / log(2.0)
	_afirmar(agudo > grave * 1.9,
		"el puesto 0 es el bajo y el ultimo el agudo",
		"%.1f Hz -> %.1f Hz, %.2f octavas (se pidieron %d grados de escala)" % [
			grave, agudo, octavas, _e.registro_grados])
	var sube := true
	for i in range(1, _e.asientos):
		if _e.nota_de(i) < _e.nota_de(i - 1) - 0.01:
			sube = false
	_afirmar(sube, "y sube puesto a puesto, sin saltos hacia atras",
		"se ve de donde sale cada nota dando la vuelta al corro")

	# EL GOLPE A MANO suena la nota de ESE puesto, no la del enjambre entero.
	_e.enjambre.fases[3] = 1.0
	var esperada := _e.nota_de(3)
	_e.tocar(3)
	_afirmar(absf(_e.nota_sonando(3) - esperada) < 0.01,
		"`tocar()` suena la nota del puesto que se le pide",
		"pedido el 3: %.2f Hz" % _e.nota_sonando(3))


# --- 3) El compas -------------------------------------------------------------

func _el_compas() -> void:
	# NACIO AFIRMANDO QUE EN HEADLESS NO HAY PLAYBACK, y era falso: el driver
	# maniqui devuelve uno perfectamente valido que se traga las muestras. Se deja
	# lo que si es cierto y si importa —que la tabla de onda y el altavoz se montan
	# sin tarjeta de sonido—, porque lo que separa "hace musica" de "habla con un
	# altavoz" se prueba en la comprobacion siguiente, contando ataques.
	_afirmar(_e._tabla.size() == 1024 and _e._reproductor != null,
		"el sintetizador se monta sin depender de la tarjeta de sonido",
		"driver: %s, tabla de %d muestras" % [
			AudioServer.get_driver_name(), _e._tabla.size()])

	_ataques.clear()
	var antes := _e.golpes()
	_avanzar(30.0)
	var dados := _e.golpes() - antes
	# Cada puesto ataca `golpes_por_compas` veces por vuelta de su fase. Las
	# frecuencias propias estan repartidas alrededor de la base, asi que el ritmo
	# medio del corro sale de ella.
	var por_seg: float = float(_e.asientos * _e.golpes_por_compas) / _e.compas_segundos
	var esperados: float = por_seg * 30.0
	var razon: float = float(dados) / maxf(esperados, 1.0)
	_afirmar(dados > 0, "la estacion TOCA sin altavoz",
		"%d ataques en 30 s; lo que suena es externo, el hecho no" % dados)
	_afirmar(razon > 0.75 and razon < 1.35,
		"y toca al compas que se le pidio",
		"%d ataques en 30 s, esperados ~%.0f (compas %.2f s x %d golpes)" % [
			dados, esperados, _e.compas_segundos, _e.golpes_por_compas])

	# TODOS TOCAN. Un puesto mudo es el fallo silencioso de este sistema: el corro
	# suena igual de lleno y falta una voz.
	var mudos := 0
	var cuenta := {}
	for a in _ataques:
		cuenta[int(a.y)] = int(cuenta.get(int(a.y), 0)) + 1
	for i in _e.asientos:
		if not cuenta.has(i):
			mudos += 1
	_afirmar(mudos == 0, "y tocan los ocho, ninguno se queda mudo",
		"%d puestos sin un solo ataque en 30 s" % mudos)


# --- 4) La sincronizacion -----------------------------------------------------

## LA AFIRMACION AUDIBLE, y la unica que se puede medir sin oidos: **cuando el
## enjambre se ordena, los ocho atacan a la vez.**
##
## No se mide con `r`. `r` es alineamiento de fase por definicion, y los ataques
## salen de la fase, asi que compararlos seria decir que un numero es igual a si
## mismo. Lo que se cuenta es cuantos ataques caen dentro de la misma ventana de
## 40 ms: disperso, cada uno cae solo; al unisono, caen de ocho en ocho. Eso es lo
## que se oye.
func _la_sincronizacion() -> void:
	var suelto := _desfase(0.0, 0.40)
	var junto := _desfase(0.82, 1.01)

	_afirmar(suelto > 0.0 and junto > 0.0,
		"se llega a ver el corro suelto Y junto en la misma pasada",
		"desfase medio %.0f ms con r bajo, %.0f ms con r alto" % [suelto, junto])
	_afirmar(junto < suelto * 0.8,
		"AL UNISONO SE JUNTAN LOS ATAQUES, y sueltos cada uno cae por su lado",
		"cada ataque tiene el del vecino a %.0f ms con r>0.82, contra %.0f ms con
" % [
			junto, suelto] +
		"        r<0.40. Se aprieta un 30 por ciento y no un 90, y eso es a
" +
		"        PROPOSITO: el acoplamiento se suelta en `orden_saciedad` = 0.86, asi
" +
		"        que el corro nunca llega a cuadrar del todo. Una banda perfectamente
" +
		"        cuadrada suena a secuenciador, no a ocho personas tocando")

	# LOS DESVIADOS SUENAN MAS FLOJO. Es lo que convierte el orden en VOLUMEN: sin
	# esto el caos y el unisono suenan igual de fuertes y la transicion no se oye.
	_e.enjambre.reiniciar()
	_avanzar(4.0)
	var peor_desvio := -1.0
	var mejor_desvio := 2.0
	var amp_peor := 0.0
	var amp_mejor := 0.0
	for i in _e.asientos:
		var d := _e.enjambre.desvio_de(i)
		if d > peor_desvio:
			peor_desvio = d
			amp_peor = _e.enjambre.amplitud_de(i) / maxf(_e.enjambre.ciclo_de(i), 0.001)
		if d < mejor_desvio:
			mejor_desvio = d
			amp_mejor = _e.enjambre.amplitud_de(i) / maxf(_e.enjambre.ciclo_de(i), 0.001)
	_afirmar(amp_mejor > amp_peor,
		"y el que va a su aire canta mas flojo que el que va con el grupo",
		"desvio %.2f -> factor %.2f contra desvio %.2f -> %.2f" % [
			peor_desvio, amp_peor, mejor_desvio, amp_mejor])


## DESFASE MEDIO en milisegundos: de cada ataque al mas cercano de OTRO puesto,
## mirando solo los tramos donde `r` esta en rango.
##
## Dos versiones anteriores no median nada y las dos por la misma razon: un umbral
## convierte una magnitud continua en un si/no y tira la mitad de la informacion.
## Contar "ataques por instante" agrupando por ventanas de 40 ms daba 1.43 contra
## 1.36; preguntar "¿tienes compania a menos de 40 ms?" daba 62% contra 52%. Los
## dos son ciertos y los dos son inutiles, porque con ocho puestos atacando cinco
## veces por segundo las coincidencias por azar ya son la mitad.
##
## En milisegundos no hay umbral que elegir y la magnitud se lee sola.
##
## Se recorre el sistema muestreando `r` a la vez que se anotan los ataques, y se
## descartan los de fuera de rango. Simular las dos condiciones por separado no
## valdria: el mismo enjambre pasa por las dos solo, y forzar `r` a mano seria
## fabricar el resultado.
func _desfase(r_min: float, r_max: float) -> float:
	_e.enjambre.reiniciar()
	_ataques.clear()
	var validos: Array[Vector2] = []
	for _i in int(90.0 / DT):
		_ataques.clear()
		_e.enjambre._physics_process(DT)
		_e._physics_process(DT)
		_reloj += DT
		var r := _e.enjambre.orden
		if r >= r_min and r < r_max:
			for a in _ataques:
				validos.append(a)
	if validos.is_empty():
		return 0.0

	var suma := 0.0
	var cuantos := 0
	for i in validos.size():
		var t: float = validos[i].x
		var puesto: float = validos[i].y
		var cerca := 9.0
		var j := i - 1
		while j >= 0 and t - validos[j].x < cerca:
			if validos[j].y != puesto:
				cerca = minf(cerca, t - validos[j].x)
			j -= 1
		j = i + 1
		while j < validos.size() and validos[j].x - t < cerca:
			if validos[j].y != puesto:
				cerca = minf(cerca, validos[j].x - t)
			j += 1
		if cerca < 8.0:
			suma += cerca
			cuantos += 1
	return (suma / float(cuantos)) * 1000.0 if cuantos > 0 else 0.0


# --- 5) El marcapasos ---------------------------------------------------------

func _el_marcapasos() -> void:
	_e.enjambre.reiniciar()
	_avanzar(6.0)
	var lejos := _e.enganchados()

	_visitante.global_position = _e.global_position
	_avanzar(30.0)
	var cerca := _e.enganchados()

	_afirmar(lejos == 0, "de lejos no te sigue nadie",
		"%d puestos enganchados con el visitante a 400 m" % lejos)
	_afirmar(cerca > 0, "acercarse les da TU compas",
		"%d de %d puestos" % [cerca, _e.asientos])
	_afirmar(cerca < _e.asientos,
		"pero NO a todos: algunos siguen a lo suyo",
		"%d de %d. Si engancharan los ocho, el corro seria un metronomo tuyo y\n" % [
			cerca, _e.asientos] +
		"        dejaria de tener vida propia — paso en la bandada y costo un rasgo\n" +
		"        fijo mas arreglarlo")

	# Y SON LOS CURIOSOS, que es la parte que NO sale de la ecuacion.
	#
	# Esta comprobacion nacio afirmando que todo enganchado cumple
	# `|ωᵢ − Ω| ≤ A` —la condicion de punto fijo en el marco que gira con el
	# marcapasos— y salio roja con 2 de 5 incumpliendola. No era un fallo de la
	# ecuacion: el acoplamiento del GRUPO arrastra detras a quien por si solo no
	# podria seguir el ritmo. La condicion es exacta para un oscilador forzado
	# aislado, y estos no lo estan.
	#
	# Asi que lo que se afirma es lo que de verdad decide: que enganchan los que
	# escuchan. Y como la curiosidad es un rasgo FIJO, siempre son los mismos.
	var curiosos := 0.0
	var sordos := 0.0
	var n_c := 0
	var n_s := 0
	var quienes: Array[int] = []
	for i in _e.asientos:
		var c := _e.tuning.curiosidad(i, _e.asientos)
		if _e.enjambre.enganche_de(i) > 0.6:
			quienes.append(i)
			curiosos += c
			n_c += 1
		else:
			sordos += c
			n_s += 1
	var media_c: float = curiosos / maxf(float(n_c), 1.0)
	var media_s: float = sordos / maxf(float(n_s), 1.0)
	_afirmar(n_c > 0 and n_s > 0 and media_c < media_s,
		"y los que te siguen son los CURIOSOS",
		"curiosidad media %.2f los que vienen contra %.2f los que no" % [
			media_c, media_s])

	# Y SALEN SIEMPRE DE LA MISMA MITAD DEL CORRO.
	#
	# Esta comprobacion nacio pidiendo el mismo conjunto EXACTO en dos pasadas, y
	# es falso: [0,2,4] la primera vez y [4,5] la segunda. No es aleatorio —el
	# sistema es determinista, `omega()` y `curiosidad()` son funciones del indice—
	# sino dependiente del ESTADO: que un curioso enganche o no depende de en que
	# fase le pilles y de por donde vaya la histeresis del acoplamiento. Llegar en
	# otro momento te da otro subconjunto, y eso esta bien: el corro no es una
	# maquina expendedora.
	#
	# Lo que si es invariante, y es lo que hace que el reparto se pueda aprender,
	# es de DONDE salen: solo los curiosos reciben tiron, asi que nadie fuera de esa
	# mitad puede acabar siguiendote por mucho que se acople el grupo.
	_visitante.global_position = Vector3(0.0, 0.0, 400.0)
	_e.enjambre.reiniciar()
	_avanzar(20.0)
	_visitante.global_position = _e.global_position
	_avanzar(30.0)
	var otra_vez: Array[int] = []
	for i in _e.asientos:
		if _e.enjambre.enganche_de(i) > 0.6:
			otra_vez.append(i)
	var intrusos := 0
	for i in (quienes + otra_vez):
		if _e.tuning.curiosidad(i, _e.asientos) > _e.fraccion_curiosa + 0.06:
			intrusos += 1
	_afirmar(intrusos == 0 and not otra_vez.is_empty(),
		"y salen SIEMPRE de la mitad curiosa, llegues cuando llegues",
		"%s en una pasada, %s en otra; %d fuera de la mitad que escucha" % [
			str(quienes), str(otra_vez), intrusos])

	_visitante.global_position = Vector3(0.0, 0.0, 400.0)
	_avanzar(25.0)
	_afirmar(_e.enganchados() == 0, "te vas y se sueltan",
		"%d enganchados 25 s despues de irte" % _e.enganchados())


# --- Informe ------------------------------------------------------------------

func _afirmar(bien: bool, nombre: String, porque: String) -> void:
	_cuenta += 1
	if bien:
		print("  OK    %s" % nombre)
		if not porque.is_empty():
			print("        (%s)" % porque)
	else:
		print("  FALLO %s" % nombre)
		print("        %s" % porque)
		_fallos.append(nombre)


func _informe() -> void:
	print("")
	if _fallos.is_empty():
		print("RESULTADO JAM: %d/%d comprobaciones." % [_cuenta, _cuenta])
	else:
		print("RESULTADO JAM: %d/%d — %d FALLOS:" % [
			_cuenta - _fallos.size(), _cuenta, _fallos.size()])
		for f in _fallos:
			print("   · %s" % f)
	get_tree().quit(0 if _fallos.is_empty() else 1)
