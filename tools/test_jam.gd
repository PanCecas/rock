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
	_los_timbres()
	_la_hoja()
	_la_sincronizacion()
	_el_marcapasos()
	_el_modo_hoja()
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


# --- 3bis) Los tres timbres ---------------------------------------------------

## PIANO, GUITARRA Y VIENTO, y los tres salen del MISMO numero que el color y la
## silueta. Lo que se comprueba aqui no es que suenen bien —eso es de oido— sino
## que son de verdad tres cosas distintas y que nadie las ha desacoplado.
func _los_timbres() -> void:
	var vistas := {}
	for i in _e.asientos:
		vistas[_e.familia_de(i)] = true
	_afirmar(vistas.size() == 3,
		"el corro usa las TRES familias, no una",
		"%d familias entre los ocho puestos: %s" % [
			vistas.size(),
			", ".join(range(_e.asientos).map(func(i): return _e.nombre_de_familia(i)))])

	# Y EL REPARTO ESTA EQUILIBRADO. Esta comprobacion nacio de un fallo real: la
	# familia colgaba de `grado_de()` —mas ordenado sobre el papel— y el reparto
	# salia PIANO, GUIT, PIANO, GUIT, GUIT, VIENTO, GUIT, PIANO: cuatro guitarras y
	# **un solo viento**. Sonaba a banda de guitarras con un invitado.
	var cuantos := [0, 0, 0]
	for i in _e.asientos:
		cuantos[_e.familia_de(i)] += 1
	var menos: int = mini(cuantos[0], mini(cuantos[1], cuantos[2]))
	_afirmar(menos >= 2,
		"y el reparto esta equilibrado, no cuatro de una y uno de otra",
		"piano %d, guitarra %d, viento %d de %d puestos" % [
			cuantos[0], cuantos[1], cuantos[2], _e.asientos])

	# PERO EL REPARTO ES UN PUNTO DE PARTIDA, NO UNA LEY. Se puede reasignar en
	# vivo, y el sonido y la silueta cambian A LA VEZ: si solo cambiara uno, el
	# corro ensenaria un tubo y sonaria a guitarra.
	var antes := _e.familia_de(2)
	var malla_antes: Mesh = _e.get_node("Instrumento2").mesh
	var nueva := _e.ciclar_familia(2)
	_afirmar(nueva != antes and _e.familia_de(2) == nueva,
		"y el instrumento de cada puesto se puede reasignar",
		"el puesto 2 pasa de %s a %s" % [
			EstacionJam.NOMBRE_FAMILIA[antes], EstacionJam.NOMBRE_FAMILIA[nueva]])
	_afirmar(_e.get_node("Instrumento2").mesh != malla_antes,
		"y la silueta cambia con el sonido, no despues",
		"la malla del instrumento se rehace en la misma llamada")
	_e.asignar_familia(2, antes)

	# LA ARMONIA SE MUEVE, y la mueve el enjambre al respirar. Con un centro fijo,
	# ocho voces en la misma pentatonica repiten el mismo acorde para siempre.
	# LOS DOS CENTROS SE FIJAN A MANO. Leer "el de ahora" y compararlo con el 1 no
	# vale: para cuando esta comprobacion corre, el enjambre YA ha respirado varias
	# veces en los pasos anteriores, asi que el centro actual podia ser justo el 1 y
	# la comparacion salia contra si misma.
	_e.centro_armonico = 0
	var raiz_antes := _e.nota_raiz_de(0)
	_e.centro_armonico = 1
	var raiz_despues := _e.nota_raiz_de(0)
	_e.centro_armonico = 0
	_afirmar(absf(raiz_despues - raiz_antes) > 1.0,
		"y la ARMONIA se mueve con la progresion",
		"la raiz del puesto 0 pasa de %.1f a %.1f Hz al cambiar de centro" % [
			raiz_antes, raiz_despues])

	# Y SIGUE EN LA ESCALA en todos los centros: el desplazamiento es en GRADOS, no
	# en semitonos, asi que la pentatonica no se puede romper por aqui.
	var fuera_centros := 0
	for c in _e.progresion.size():
		_e.centro_armonico = c
		for i in _e.asientos:
			var semis: int = int(roundf(
				12.0 * log(_e.nota_raiz_de(i) / _e.tonica) / log(2.0)))
			if not _e.escala.has(posmod(semis, 12)):
				fuera_centros += 1
	_e.centro_armonico = 0
	_afirmar(fuera_centros == 0,
		"sin salirse de la escala en ningun centro",
		"%d notas fuera en %d centros x %d puestos" % [
			fuera_centros, _e.progresion.size(), _e.asientos])

	# TRES ESPECTROS DISTINTOS. Si dos tablas fueran iguales, dos familias serian
	# la misma con otro nombre.
	var iguales := 0
	for a in 3:
		for b in range(a + 1, 3):
			var dif := 0.0
			for k in 0:
				pass
			for k in _e._tablas[a].size():
				dif = maxf(dif, absf(_e._tablas[a][k] - _e._tablas[b][k]))
			if dif < 0.02:
				iguales += 1
	_afirmar(iguales == 0, "y cada familia tiene su propia onda",
		"ninguna pareja de tablas se parece a menos de 0.02")

	# LA ENVOLVENTE ES LA MITAD DEL INSTRUMENTO, y la que mas se oye: el viento
	# arranca despacio y SOSTIENE; el piano y la guitarra atacan de golpe y caen.
	# Se leen las voces recien disparadas, que es donde vive la envolvente.
	var sube := {}
	var meseta := {}
	for f in 3:
		for v in _e._voces.size():
			_e._voces[v] = {}
		_e._sonar(220.0, 1.0, 0.0, f)
		for v in _e._voces.size():
			if not _e._voces[v].is_empty():
				sube[f] = float(_e._voces[v]["sube"])
				meseta[f] = float(_e._voces[v]["meseta"])
				break
	_afirmar(sube[2] < sube[0] * 0.2 and sube[2] < sube[1] * 0.2,
		"el VIENTO ataca mucho mas despacio que las cuerdas",
		"rampa por muestra: piano %.5f, guitarra %.5f, viento %.5f" % [
			sube[0], sube[1], sube[2]])
	_afirmar(meseta[2] > 0.0 and meseta[0] == 0.0 and meseta[1] == 0.0,
		"y es el UNICO que sostiene antes de caer",
		"meseta en muestras: piano %.0f, guitarra %.0f, viento %.0f" % [
			meseta[0], meseta[1], meseta[2]])
	for v in _e._voces.size():
		_e._voces[v] = {}


# --- 3ter) La hoja de notas ---------------------------------------------------

## LA REJILLA que se escribe, y lo que la separa de un secuenciador pegado al
## lado: **el cabezal corre con la fase MEDIA del enjambre**, no con un reloj
## propio. Es lo que fusiona las dos mitades — cuanto mas juntos van los ocho,
## mejor tocan lo que escribiste.
func _la_hoja() -> void:
	# EL TECLADO: quince teclas, y todas en la escala. Es la audicion, y si una
	# sola cayera fuera se podria estropear un acorde que ya estaba sonando bien.
	var fuera := 0
	for t in EstacionJam.TECLAS:
		var semis: int = int(roundf(
			12.0 * log(_e.nota_de_tecla(t) / _e.tonica) / log(2.0)))
		if not _e.escala.has(posmod(semis, 12)):
			fuera += 1
	_afirmar(fuera == 0 and EstacionJam.TECLAS == 15,
		"el teclado son 15 teclas (5x3) y ninguna se sale de la escala",
		"%d teclas, %d fuera; tres octavas de la pentatonica" % [
			EstacionJam.TECLAS, fuera])
	_afirmar(_e.nota_de_tecla(EstacionJam.TECLAS - 1) > _e.nota_de_tecla(0) * 3.9,
		"y recorren tres octavas de grave a agudo",
		"%.1f Hz -> %.1f Hz" % [
			_e.nota_de_tecla(0), _e.nota_de_tecla(EstacionJam.TECLAS - 1)])

	# LA HOJA VACIA NO CAMBIA NADA. Es la invariante que permite que la estacion
	# nazca improvisando y solo obedezca cuando le escribes algo.
	_e.borrar_hoja()
	_afirmar(_e.notas_escritas() == 0, "la hoja nace vacia y los ocho improvisan",
		"sin nada escrito no hay modo que elegir: lo dice el contenido")

	# ESCRIBIR Y BORRAR una celda.
	_e.alternar_celda(3, 2)
	var puesta := _e.celda(3, 2)
	_e.alternar_celda(3, 2)
	_afirmar(puesta and not _e.celda(3, 2) and _e.notas_escritas() == 0,
		"una celda se enciende y se apaga, y la cuenta cuadra",
		"encender, leer, apagar y volver a cero")

	# CON LA HOJA ESCRITA MANDA LA HOJA. Se marca UN solo musico en UN solo paso y
	# se comprueba que los demas se callan: si siguieran improvisando, la rejilla
	# seria decoracion.
	_ataques.clear()
	_e.borrar_hoja()
	_e.alternar_celda(0, 5)
	_e.alternar_celda(8, 5)
	var antes := _e.golpes()
	_avanzar(40.0)
	var cuenta := {}
	for a in _ataques:
		cuenta[int(a.y)] = int(cuenta.get(int(a.y), 0)) + 1
	var ajenos := 0
	for k in cuenta:
		if k != 5:
			ajenos += int(cuenta[k])
	_afirmar(_e.golpes() > antes and ajenos == 0,
		"con la hoja escrita, SOLO tocan los musicos marcados",
		"%d ataques del puesto 5 y %d de los otros siete en 40 s" % [
			int(cuenta.get(5, 0)), ajenos])

	# Y EL CABEZAL VA AL COMPAS DEL CORRO. Dos celdas en 16 pasos separadas por
	# medio ciclo de hoja: la hoja entera dura `pasos / golpes_por_compas` compases.
	var vueltas: float = 40.0 / (_e.compas_segundos * float(_e.pasos)
		/ float(_e.golpes_por_compas))
	var esperados: float = vueltas * 2.0
	var razon: float = float(cuenta.get(5, 0)) / maxf(esperados, 1.0)
	_afirmar(razon > 0.6 and razon < 1.6,
		"y el cabezal corre al compas del corro, no a un reloj suyo",
		"%d ataques en 40 s, esperados ~%.0f (%d pasos a %.2f s de compas)" % [
			int(cuenta.get(5, 0)), esperados, _e.pasos, _e.compas_segundos])

	# BORRAR DEVUELVE A IMPROVISAR.
	_ataques.clear()
	_e.borrar_hoja()
	_avanzar(12.0)
	var tocaron := {}
	for a in _ataques:
		tocaron[int(a.y)] = true
	_afirmar(tocaron.size() >= _e.asientos - 1,
		"y borrar la hoja los devuelve a improvisar a los ocho",
		"%d de %d puestos volvieron a sonar en 12 s" % [tocaron.size(), _e.asientos])


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
	var quienes := _observar_enganches(30.0)
	var cerca := quienes.size()

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
	for i in _e.asientos:
		var c := _e.tuning.curiosidad(i, _e.asientos)
		if quienes.has(i):
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

	# Y SON SIEMPRE LOS MISMOS, y esto costo aprenderlo dos veces.
	#
	# La comprobacion nacio pidiendo el mismo conjunto exacto en dos pasadas y salio
	# roja: [0,2,4] contra [4,5]. La conclusion que saque fue que el conjunto
	# dependia del estado —de en que fase les pillaras— y rebaje la afirmacion a
	# "salen de la mitad curiosa". **Era mentira mia, no del sistema.**
	#
	# Lo que fallaba era el VISTAZO: miraba el enganche al final de la ventana, y el
	# acoplamiento respira, asi que hay instantes en los que el corro se esta
	# deshaciendo y nadie pasa del umbral aunque medio minuto antes te siguieran
	# cuatro. Mirando MIENTRAS pasa (`_observar_enganches`), las dos pasadas dan
	# [0, 2, 4, 5, 7] identico desde puntos de partida distintos.
	#
	# Y eso es lo que hace que el corro se pueda aprender: los mismos musicos te
	# hacen caso siempre, porque la curiosidad es un rasgo fijo. Es mejor que un
	# sorteo, y ahora esta afirmado en vez de rebajado.
	_visitante.global_position = Vector3(0.0, 0.0, 400.0)
	_e.enjambre.reiniciar()
	_avanzar(20.0)
	_visitante.global_position = _e.global_position
	var otra_vez := _observar_enganches(30.0)
	var intrusos := 0
	for i in (quienes + otra_vez):
		if _e.tuning.curiosidad(i, _e.asientos) > _e.fraccion_curiosa + 0.06:
			intrusos += 1
	_afirmar(otra_vez == quienes and not otra_vez.is_empty() and intrusos == 0,
		"y son SIEMPRE los mismos, desde otro punto de partida",
		"%s en una pasada, %s en otra; %d fuera de la mitad que escucha" % [
			str(quienes), str(otra_vez), intrusos])

	_visitante.global_position = Vector3(0.0, 0.0, 400.0)
	_avanzar(25.0)
	_afirmar(_e.enganchados() == 0, "te vas y se sueltan",
		"%d enganchados 25 s despues de irte" % _e.enganchados())


# --- 6) El modo hoja: escribir NO es jugar ------------------------------------

## MIENTRAS ESCRIBES NO JUEGAS, y hay que probarlo por el camino real.
##
## La hoja NO pausa el arbol —se abre para escuchar el corro, y con el juego
## congelado dejaria de sonar—, asi que el jugador se queda vivo debajo. Si nadie
## le corta el input, escribir una nota es tambien correr, saltar y atacar.
##
## Se prueba abriendo el PANEL, no emitiendo la senal a mano: lo que hay que
## afirmar es que abrir la interfaz desconecta al jugador, no que la senal haga lo
## que dice. Un `InputBuffer` de verdad escucha, igual que el del jugador.
func _el_modo_hoja() -> void:
	var buffer := InputBuffer.new()
	add_child(buffer)
	Input.action_press(&"move_forward")
	Input.action_press(&"attack_light")

	_afirmar(not buffer.silenciado and buffer.move_vector().length() > 0.5,
		"con la hoja cerrada el jugador obedece",
		"move_vector %.2f con W pulsada" % buffer.move_vector().length())

	_e.panel.abrir()
	var mueve := buffer.move_vector().length()
	var sostiene := buffer.is_held(&"move_forward")
	_afirmar(buffer.silenciado and mueve < 0.001 and not sostiene,
		"ABRIR LA HOJA desconecta al jugador, con las teclas pulsadas",
		"move_vector %.2f, is_held %s; se corta en el `InputBuffer` porque la
" % [
			mueve, str(sostiene)] +
		"        regla dura #4 garantiza que es el UNICO que habla con Input: ahi
" +
		"        se apagan de una vez el movimiento, los ataques, el salto y la lanza")

	# Y LO GUARDADO NO SE EJECUTA AL CERRAR. Una pulsacion que estaba en el buffer
	# justo antes de abrir saldria al volver, y eso se siente como un fantasma.
	var fantasma := buffer.consume(&"attack_light")
	_afirmar(not fantasma, "y el buffer se vacia, sin pulsaciones fantasma",
		"nada guardado sobrevive a abrir la interfaz")

	_e.panel.cerrar()
	_afirmar(not buffer.silenciado and buffer.move_vector().length() > 0.5,
		"y cerrarla se lo devuelve",
		"move_vector %.2f" % buffer.move_vector().length())

	Input.action_release(&"move_forward")
	Input.action_release(&"attack_light")
	buffer.queue_free()


# --- Informe ------------------------------------------------------------------

## QUIENES ENGANCHAN EN ESTA VENTANA, mirando MIENTRAS pasa y no al final.
##
## Un vistazo al segundo 30 no vale: el acoplamiento respira con histeresis, asi
## que hay instantes en los que el corro se esta deshaciendo y NADIE pasa del
## umbral aunque medio minuto antes te siguieran cuatro. Nacio asi y la segunda
## pasada salio con la lista vacia — no porque no engancharan, sino porque se miro
## en el momento equivocado. Es el mismo problema de los latches del rastro de la
## hierba en `TestMundoVivo`: cuando el chequeo termina, lo que interesaba ya paso.
func _observar_enganches(segundos: float) -> Array[int]:
	var vistos := {}
	var trozos := int(segundos / 0.5)
	for _t in trozos:
		_avanzar(0.5)
		for i in _e.asientos:
			if _e.enjambre.enganche_de(i) > 0.6:
				vistos[i] = true
	var lista: Array[int] = []
	for k in vistos:
		lista.append(int(k))
	lista.sort()
	return lista


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
