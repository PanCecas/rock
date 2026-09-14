extends Node
## Test funcional del MUNDO VIVO: hierba, luciernagas y bandada.
##
##   godot --headless --path . tools/TestMundoVivo.tscn
##
## Tres sistemas y un solo modelo debajo. El test va en dos mitades, por el mismo
## motivo que `TestEnjambre`:
##
##   · EL MODELO, EN SECO. Se pisa `_physics_process` a mano con dt fijo y se
##     corren minutos de simulacion en milisegundos. Aqui se comprueba lo unico
##     que se puede afirmar sin dibujar: que el campo medio es EXACTO y que
##     `a_ritmo()` es de verdad un cambio de escala de tiempo.
##   · LA MANIFESTACION, EN VIVO. El claro corriendo: que la hierba nace pegada al
##     suelo, que el rastro sigue al jugador y se desvanece, que las luciernagas
##     parpadean juntas cuando el enjambre se ordena y que la bandada mira hacia
##     donde vuela.
##
## Lo que NO comprueba, y se dice para que nadie lo confunda: si esto se VE bien.
## Eso lo mira el screenshot test (`toma "claro"`), y ninguno de los dos sustituye
## al otro — el shader de hierba podria estar entero en negro y estas 18
## comprobaciones seguirian en verde.

const PASTO := preload("res://src/world/Pasto.gd")
const LUCIERNAGAS := preload("res://src/world/Luciernagas.gd")
const BANDADA := preload("res://src/world/Bandada.gd")

## Donde se monta el claro de pruebas. Lejos de todo: aqui no hay Gym.
const CENTRO := Vector3.ZERO
const LADO := 18.0

var _pasto: Pasto
var _luc: Luciernagas
var _ban: Bandada
## Un jugador de mentira. Lo que `Pasto` necesita es un `Node3D` que se mueva, y
## traerse el `PlayerController` entero solo para eso metería su FSM, sus sensores
## y su camara en una medida que no va de nada de eso.
var _visitante: Node3D
var _fallos: PackedStringArray = []
var _cuenta: int = 0
var _paso: int = 0
var _t: float = 0.0
var _listo: bool = false
## Latches del rastro. Se miden MIENTRAS pasa: cuando el chequeo termina, la
## huella que interesaba ya se ha desvanecido.
var _huellas_vistas: int = 0
var _frescura_max: float = 0.0
## Latches del parpadeo colectivo, uno por condicion.
var _enc_min_sync: float = 9.0
var _enc_max_sync: float = -9.0
## Latches de la escolta. Se miden MIENTRAS pasa: al final de la ventana la
## bandada ya puede haber cambiado de humor.
var _escolta_max: int = 0
var _escolta_t: float = -1.0
var _radio_nube_suelta: float = 0.0
var _radio_nube_junta: float = 0.0
## Perturbaciones que ha provocado el visitante al cruzar el claro.
var _perturbadas: int = 0


func _ready() -> void:
	_montar()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_en_seco()
	_listo = true


# --- 1) EL MODELO, EN SECO ----------------------------------------------------

func _en_seco() -> void:
	_campo_medio_es_exacto()
	_a_ritmo_es_un_cambio_de_reloj()


## EL CAMPO MEDIO NO ES UNA APROXIMACION.
##
## `Enjambre._integrar()` resuelve el acoplamiento con `r·sin(ψ−θᵢ)` en vez de con
## la suma doble `(1/N)·Σⱼ sin(θⱼ−θᵢ)`. Es la misma cantidad —la identidad sale de
## desarrollar el seno— y de ahi que el coste baje de O(N²) a O(N), que es lo que
## permite mover 180 luciernagas con el mismo modelo que mueve 9 criaturas.
##
## Se comprueba calculando LAS DOS a mano sobre el mismo estado y comparandolas.
## No basta con que el sistema "siga sincronizando": eso lo haria igual una
## formula parecida, y el dia que alguien la cambie el test tiene que decir que se
## han separado, no que el resultado ya no le gusta.
func _campo_medio_es_exacto() -> void:
	var e := Enjambre.new()
	var t := EnjambreTuning.new()
	t.agentes = 24
	e.tuning = t
	e.palette = GameState.palette
	e.reiniciar()

	var peor := 0.0
	for _paso_i in 300:
		e._physics_process(1.0 / 60.0)
		var n := e.fases.size()
		for i in n:
			var suma := 0.0
			for j in n:
				suma += sin(e.fases[j] - e.fases[i])
			var doble := suma / float(n)
			var medio := e.orden * sin(e.fase_media - e.fases[i])
			peor = maxf(peor, absf(doble - medio))
	e.free()

	_afirmar(peor < 1e-5,
		"el campo medio da lo MISMO que la suma doble",
		"diferencia maxima %.9f en 300 pasos con 24 agentes; si esto crece, la\n" %
			peor + "        optimizacion ha dejado de ser una identidad y es otro modelo")


## `a_ritmo()` ES UN CAMBIO DE VARIABLE, no un ajuste a ojo.
##
## Escalar `ω` y `K` por el mismo factor equivale a `t' = t·factor`: el sistema
## resultante hace exactamente lo mismo, mas rapido o mas despacio. Se comprueba
## midiendo cuanto tarda cada uno en sincronizar: a mitad de reloj, el doble de
## tiempo. Si alguien escala `ω` y se olvida de `K` —el fallo natural— la razon
## `K/dispersion` cambia y este numero deja de salir.
func _a_ritmo_es_un_cambio_de_reloj() -> void:
	var normal := _tiempo_hasta_orden(EnjambreTuning.new())
	var lento := _tiempo_hasta_orden(EnjambreTuning.new().a_ritmo(0.5))
	var razon := lento / maxf(normal, 0.001)
	_afirmar(absf(razon - 2.0) < 0.15,
		"a mitad de reloj, el doble de tiempo en sincronizar",
		"normal %.1f s · a ritmo 0.5 %.1f s · razon %.2f (deberia ser 2.00)" % [
			normal, lento, razon])


func _tiempo_hasta_orden(t: EnjambreTuning) -> float:
	var e := Enjambre.new()
	e.tuning = t
	e.palette = GameState.palette
	e.reiniciar()
	var dt := 1.0 / 60.0
	var seg := 0.0
	while seg < 400.0:
		e._physics_process(dt)
		seg += dt
		if e.orden >= t.orden_saciedad:
			break
	e.free()
	return seg


# --- 2) LA MANIFESTACION, EN VIVO ---------------------------------------------

func _montar() -> void:
	var mundo := Node3D.new()
	mundo.name = "Claro"
	add_child(mundo)

	# Suelo: una losa plana y, al lado, una rampa de 70 grados. La rampa esta para
	# comprobar que la hierba NO crece en una pared, que es la unica regla de
	# siembra que se puede equivocar en silencio.
	mundo.add_child(_losa(Vector3(LADO + 10.0, 1.0, LADO + 10.0), CENTRO - Vector3.UP * 0.5, 0.0))
	mundo.add_child(_losa(Vector3(6.0, 0.6, 9.0), CENTRO + Vector3(LADO * 0.5 - 3.0, 3.0, 0.0), 70.0))

	_visitante = Node3D.new()
	_visitante.name = "Visitante"
	mundo.add_child(_visitante)
	_visitante.global_position = CENTRO + Vector3(-LADO * 0.5, 0.0, 0.0)

	_pasto = PASTO.new()
	_pasto.area = Vector2(LADO, LADO)
	_pasto.densidad = 6.0
	mundo.add_child(_pasto)
	_pasto.global_position = CENTRO
	_pasto.seguir(_visitante)

	_luc = LUCIERNAGAS.new()
	_luc.cuantas = 60
	_luc.area = Vector3(LADO, 4.0, LADO)
	mundo.add_child(_luc)
	_luc.global_position = CENTRO + Vector3.UP * 0.5
	_luc.enjambre.perturbado.connect(func(_i: int) -> void: _perturbadas += 1)

	_ban = BANDADA.new()
	_ban.criaturas = 12
	_ban.radio = 8.0
	_ban.vaiven = 3.0
	_ban.dispersion_tubo = 2.0
	mundo.add_child(_ban)
	_ban.global_position = CENTRO + Vector3.UP * 9.0


func _losa(tam: Vector3, pos: Vector3, grados: float) -> StaticBody3D:
	var c := StaticBody3D.new()
	c.collision_layer = Layers.WORLD
	c.collision_mask = 0
	var f := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tam
	f.shape = caja
	c.add_child(f)
	c.position = pos
	c.rotation_degrees = Vector3(0.0, 0.0, grados)
	return c


func _physics_process(delta: float) -> void:
	if not _listo:
		return
	_t += delta

	# El visitante cruza el claro de lado a lado, a velocidad de carrera. Es lo que
	# genera el rastro: pedirle a `Pasto` que estampe huellas a mano probaria
	# `pisar()`, no el seguimiento.
	if _paso >= 1 and _paso <= 2:
		_visitante.global_position += Vector3(9.4, 0.0, 0.0) * delta
	for h in _pasto.rastro():
		if h.w > 0.001:
			_huellas_vistas = maxi(_huellas_vistas, 1)
			_frescura_max = maxf(_frescura_max, h.w)

	# Latch del parpadeo: se mide el rango de "cuantas encendidas a la vez" a lo
	# largo de una ventana, no un instante. Un instante no distingue un enjambre
	# sincronizado de uno disperso — los dos pueden estar apagados justo ahora.
	if _paso == 4:
		var f := _luc.encendidas(0.3)
		_enc_min_sync = minf(_enc_min_sync, f)
		_enc_max_sync = maxf(_enc_max_sync, f)

	match _paso:
		0:
			if _t > 0.3:
				_hierba()
				_avanzar()
		1:
			if _t > 1.0:
				_avanzar()
		2:
			if _t > 0.6:
				_rastro()
				_avanzar()
		3:
			if _t > 0.1:
				# Se lleva el enjambre de las luciernagas al unisono a mano y se
				# le deja correr un ciclo entero mirando cuantas se encienden.
				var e := _luc.enjambre
				for i in e.fases.size():
					e.fases[i] = 0.4
				_avanzar()
		4:
			if _t > _luc.parpadeo_segundos * 1.2:
				_parpadeo()
				_avanzar()
		5:
			_bandada()
			# LA ESCOLTA. Se activa AQUI y no antes: con el jugador cerca la mitad
			# de la bandada deja el circuito, y las comprobaciones de arriba miden
			# justo que estan en el.
			_ban.seguir(_visitante)
			_visitante.global_position = CENTRO + Vector3(0.0, 0.0, 0.0)
			_escolta_t = -1.0
			_avanzar()
		6:
			if _escolta_t < 0.0 and _ban.escoltando() > 0:
				_escolta_t = _t
			_escolta_max = maxi(_escolta_max, _ban.escoltando())
			if _t > 16.0:
				_escolta()
				# Y AHORA SE VA. El jugador se lleva la llamada con el.
				_visitante.global_position = CENTRO + Vector3(0.0, 0.0, 90.0)
				_avanzar()
		7:
			if _t > 16.0:
				_regreso()
				# Y AHORA EL VISITANTE CRUZA EL CLARO DE LAS LUCIERNAGAS. Se hace
				# al final para no perturbarlas durante las medidas del parpadeo:
				# una criatura sorda no oye al grupo, y eso mueve el orden.
				_luc.seguir(_visitante)
				_visitante.global_position = CENTRO + Vector3(-6.0, 1.6, 0.0)
				_perturbadas = 0
				_avanzar()
		8:
			_visitante.global_position += Vector3(4.0, 0.0, 0.0) * delta
			if _t > 3.0:
				_dispersar()
				_informe()


func _avanzar() -> void:
	_paso += 1
	_t = 0.0


# --- Las comprobaciones -------------------------------------------------------

func _hierba() -> void:
	var mm := _pasto.multimesh.multimesh
	_afirmar(_pasto.briznas() > 200,
		"la hierba se siembra y se pega al suelo",
		"%d briznas sobre un claro de %.0f x %.0f" % [_pasto.briznas(), LADO, LADO])

	# Todas a ras de suelo, ninguna flotando ni enterrada.
	var peor := 0.0
	var en_rampa := 0
	for i in mm.instance_count:
		var p := _pasto.global_transform * mm.get_instance_transform(i).origin
		peor = maxf(peor, absf(p.y - CENTRO.y))
		# La rampa de 70 grados esta al borde +X y arranca en y = 3: cualquier
		# brizna por encima de un metro ha nacido en ella.
		if p.y > CENTRO.y + 1.0:
			en_rampa += 1
	_afirmar(peor < 0.15,
		"ninguna brizna flota ni queda enterrada",
		"la mas desviada esta a %.3f m del suelo" % peor)
	_afirmar(en_rampa == 0,
		"en una pared de 70 grados no crece hierba",
		"%d briznas nacidas por encima del suelo; `pendiente_max` = %.0f grados" % [
			en_rampa, _pasto.pendiente_max])

	# Y el viento tiene que estar REGISTRADO. Un `global uniform` que no existe en
	# `project.godot` no da error visible: el shader compila y la hierba se queda
	# quieta, que se lee como "el viento no funciona" y no como "falta un ajuste".
	var globales := RenderingServer.global_shader_parameter_get_list()
	var faltan := PackedStringArray()
	for n in ["viento_direccion", "viento_fuerza", "viento_escala",
			"viento_velocidad", "viento_temblor"]:
		if not globales.has(StringName(n)):
			faltan.append(n)
	_afirmar(faltan.is_empty(),
		"el viento existe como uniform GLOBAL",
		"los cinco registrados en project.godot > shader_globals" if faltan.is_empty()
			else "FALTAN: %s" % ", ".join(faltan))


func _rastro() -> void:
	var r := _pasto.rastro()
	_afirmar(_huellas_vistas > 0 and _frescura_max > 0.9,
		"caminar deja huellas en el rastro",
		"frescura maxima vista %.2f" % _frescura_max)

	# LA RANURA 0 ES EL JUGADOR AHORA MISMO, no la ultima huella estampada.
	#
	# La tolerancia es medio `rastro_paso` y no cero a proposito: el rastro se
	# escribe en `_process` —ritmo de RENDER, porque es lo que alimenta un shader—
	# y el jugador se mueve en fisica, asi que la ranura 0 arrastra como mucho un
	# frame de retraso. A 9.4 m/s eso son 16 cm, medidos. Lo que esta comprobacion
	# separa es "sigue al jugador" de "es una huella vieja", y para eso medio paso
	# sobra: las huellas nacen a `rastro_paso` de distancia.
	var d := Vector3(r[0].x, r[0].y, r[0].z).distance_to(_visitante.global_position)
	_afirmar(r[0].w > 0.99 and d < _pasto.rastro_paso * 0.5,
		"la ranura 0 es el jugador, en vivo",
		"w=%.2f y a %.3f m de donde esta (un frame a 9.4 m/s son 0.16 m)" % [r[0].w, d])

	# LAS HUELLAS SE ORDENAN DE MAS FRESCA A MAS VIEJA. Sin este orden, tirar la
	# mas vieja al llenarse la lista tiraria una cualquiera.
	var ordenadas := true
	var anterior := 1.1
	for i in range(1, r.size()):
		if r[i].w <= 0.001:
			break
		if r[i].w > anterior + 0.001:
			ordenadas = false
		anterior = r[i].w
	_afirmar(ordenadas, "y van de la mas fresca a la mas vieja",
		"la lista tiene que estar ordenada para que se tire SIEMPRE la mas vieja")

	# SE DESVANECEN. Es la mitad de la mecanica que pidio el usuario: "un rastro
	# que se desvanece". Se mira la misma huella antes y despues.
	var antes: float = r[1].w
	var pos_antes := Vector3(r[1].x, r[1].y, r[1].z)
	await get_tree().create_timer(0.9).timeout
	var r2 := _pasto.rastro()
	var despues := -1.0
	for i in range(1, r2.size()):
		if Vector3(r2[i].x, r2[i].y, r2[i].z).distance_to(pos_antes) < 0.01:
			despues = r2[i].w
			break
	_afirmar(despues >= 0.0 and despues < antes - 0.1,
		"y la huella se DESVANECE con el tiempo",
		"la misma huella paso de %.2f a %.2f en 0.9 s (duracion %.1f s)" % [
			antes, despues, _pasto.rastro_duracion])


func _parpadeo() -> void:
	# EL DESTELLO ES ESTRECHO. `pow(ciclo, dureza)` con exponente alto deja el
	# brillo casi a cero casi todo el rato: lo que se lee es el PULSO. Con brillo
	# proporcional al ciclo, una luciernaga es una bombilla que sube y baja.
	var suma_ciclo := 0.0
	var suma_brillo := 0.0
	for i in _luc.cuantas:
		suma_ciclo += _luc.enjambre.ciclo_de(i)
		suma_brillo += _luc.brillo_de(i)
	suma_ciclo /= float(_luc.cuantas)
	suma_brillo /= float(_luc.cuantas)
	_afirmar(suma_brillo < suma_ciclo * 0.5,
		"el destello es un PULSO, no un brillo proporcional",
		"ciclo medio %.2f contra brillo medio %.2f: la potencia tiene que aplastarlo" % [
			suma_ciclo, suma_brillo])

	# SINCRONIZADAS, EL CLARO ENTERO LATE. Se mide el RANGO a lo largo de un ciclo
	# completo, no un instante: al unisono, "cuantas estan encendidas" tiene que
	# recorrer casi todo el intervalo de 0 a 1.
	var rango := _enc_max_sync - _enc_min_sync
	_afirmar(_enc_max_sync > 0.8 and _enc_min_sync < 0.2,
		"al unisono, el claro entero parpadea a la vez",
		"la fraccion encendida recorrio de %.2f a %.2f (rango %.2f)" % [
			_enc_min_sync, _enc_max_sync, rango])

	# NINGUNA SE ESCAPA DE SU CLARO.
	var fuera := 0
	for i in _luc.cuantas:
		var p := _luc.posicion_de(i) - _luc.global_position
		if absf(p.x) > _luc.area.x * 0.5 + _luc.deriva + 0.01 \
				or absf(p.z) > _luc.area.z * 0.5 + _luc.deriva + 0.01:
			fuera += 1
	_afirmar(fuera == 0, "y ninguna se sale del claro",
		"%d luciernagas fuera de su caja mas la deriva" % fuera)

	# PERTURBAR ALCANZA A LA MAS CERCANA. Es la interaccion entera.
	var objetivo := 7
	var antes := _luc.enjambre.fase_de(objetivo)
	var tocada := _luc.perturbar_cerca(_luc.posicion_de(objetivo), 1.0)
	_afirmar(tocada == objetivo and not is_equal_approx(antes, _luc.enjambre.fase_de(objetivo)),
		"perturbar por posicion alcanza a la de al lado",
		"se pidio la %d y respondio la %d" % [objetivo, tocada])

	_nube()


func _bandada() -> void:
	var mm := _ban.multimesh.multimesh
	_afirmar(mm.instance_count == _ban.criaturas,
		"la bandada tiene sus criaturas",
		"%d instancias" % mm.instance_count)

	# TODAS SOBRE EL CIRCUITO. Se comprueba contra la curva analitica: una
	# criatura solo puede estar a `dispersion_tubo` de la linea, que es lo que la
	# hace una BANDADA y no un puñado de bichos sueltos.
	var peor := 0.0
	for i in mm.instance_count:
		var u := _ban.enjambre.fase_de(i)
		# `_punto()` ya trae el ladeo dentro desde el 3.13: el circuito puede estar
		# inclinado, pero la orbita alrededor del jugador tiene que ser horizontal.
		var sobre_curva: Vector3 = _ban.global_transform * _ban._punto(u)
		peor = maxf(peor, _ban.posicion_de(i).distance_to(sobre_curva))
	_afirmar(peor <= _ban.dispersion_tubo + 0.01,
		"todas vuelan dentro del tubo del circuito",
		"la mas descolgada esta a %.2f m de la linea (tubo %.2f)" % [
			peor, _ban.dispersion_tubo])

	# MIRAN HACIA DONDE VUELAN, y se comprueba con SIGNO (regla dura #22): un
	# valor absoluto no distingue "va hacia delante" de "va de espaldas", que es
	# exactamente el bug del frente de los enemigos de la 3.08.
	#
	# El frente de estas criaturas es −Z, el convenio del bando enemigo, porque su
	# malla se construye tumbada hacia −Z en `_malla_cinta()`.
	var peor_coseno := 1.0
	for i in mm.instance_count:
		var va := (_ban.global_basis * _ban._tangente(_ban.enjambre.fase_de(i))).normalized()
		peor_coseno = minf(peor_coseno, _ban.frente_de(i).dot(va))
	_afirmar(peor_coseno > 0.98,
		"y miran HACIA donde vuelan, no de espaldas",
		"peor coseno entre el frente y la tangente: %+.3f" % peor_coseno)

	# LA SINCRONIZACION SE VE EN LA FORMA DEL GRUPO. Es la razon de que esto use
	# Kuramoto y no boids: al unisono la bandada va apretada en un tramo del
	# circuito, y dispersa se estira por todo el. Se mide el arco que ocupa.
	var arco_disperso := _arco_ocupado()
	var e := _ban.enjambre
	for i in e.fases.size():
		e.fases[i] = 1.1
	_ban._colocar()
	var arco_junto := _arco_ocupado()
	_afirmar(arco_junto < arco_disperso * 0.5,
		"al unisono la bandada va APRETADA, dispersa se estira",
		"arco ocupado: %.0f grados dispersa contra %.0f al unisono" % [
			rad_to_deg(arco_disperso), rad_to_deg(arco_junto)])


## Cuanto arco del circuito ocupa la bandada, en radianes. Es la anchura del
## grupo medida sobre la curva, y no la dispersion en metros: en un circuito
## cerrado dos criaturas en extremos opuestos estan cerca en linea recta.
func _arco_ocupado() -> float:
	var e := _ban.enjambre
	var n := e.fases.size()
	if n == 0:
		return 0.0
	# Se mide contra la fase media, envolviendo a [-pi, pi]: sin envolver, una
	# criatura en 0.01 y otra en 6.27 rad darian casi una vuelta entera cuando en
	# realidad son vecinas.
	var peor := 0.0
	for i in n:
		peor = maxf(peor, absf(wrapf(e.fases[i] - e.fase_media, -PI, PI)))
	return peor * 2.0


## LA NUBE SE APRIETA AL SINCRONIZARSE.
##
## Es lo que convierte 180 bichos independientes en un ENJAMBRE: la
## sincronizacion se ve en la FORMA del grupo y no solo en la luz. Y sale del
## mismo `r` que decide el parpadeo, no de un segundo sistema.
func _nube() -> void:
	var e := _luc.enjambre
	for i in e.fases.size():
		e.fases[i] = 0.9
	e._medir_orden()
	_luc._colocar()
	_radio_nube_junta = _luc.radio_nube()

	const AUREO := PI * (3.0 - sqrt(5.0))
	for i in e.fases.size():
		e.fases[i] = fposmod(float(i) * AUREO, TAU)
	e._medir_orden()
	_luc._colocar()
	_radio_nube_suelta = _luc.radio_nube()

	_afirmar(_radio_nube_junta < _radio_nube_suelta * 0.9,
		"al unisono la nube se APRIETA, dispersa se abre",
		"radio medio %.2f m al unisono contra %.2f m dispersa" % [
			_radio_nube_junta, _radio_nube_suelta])


## CRUZAR EL CLARO LO DESORDENA, y con techo.
func _dispersar() -> void:
	_afirmar(_perturbadas > 0,
		"cruzar el claro desordena a las luciernagas",
		"%d perturbadas al pasar entre ellas" % _perturbadas)
	# CON TECHO. Sin cadencia se perturbaria una por frame —180 en tres
	# segundos— y el enjambre no volveria a sincronizar nunca: el efecto que se
	# busca es la VUELTA, y sin vuelta no hay efecto.
	var techo := int(_luc.dispersar_cadencia * 3.0) + 2
	_afirmar(_perturbadas <= techo,
		"y la cadencia le pone techo",
		"%d en 3 s, tope %d (cadencia %.1f/s)" % [
			_perturbadas, techo, _luc.dispersar_cadencia])


## LA ESCOLTA: algunas, no todas, y las que la ecuacion permite.
func _escolta() -> void:
	var n := _ban.criaturas
	var cuantas := _ban.escoltando()
	_afirmar(cuantas > 0 and cuantas < n,
		"con el jugador cerca escoltan ALGUNAS, no todas",
		"%d de %d, y la primera enganchó a los %.1f s" % [cuantas, n, _escolta_t])

	# QUIEN VIENE SE DECIDE EN DOS PASOS, y hay que comprobar los dos.
	#
	#   1. QUIEN OYE  — la `curiosidad`, un rasgo fijo. Es lo que hace que sean
	#      "algunas y no todas", y que sean SIEMPRE LAS MISMAS.
	#   2. QUIEN AGUANTA — la condicion de Kuramoto con forzamiento,
	#      `|ωᵢ − Ω| ≤ Aᵢ`. Aqui es necesaria pero no discrimina: la llamada es
	#      mas fuerte que el acoplamiento del grupo a proposito —si no, no
	#      despegaria nadie— y con esa A la cumplen todas las que oyen. Se
	#      comprueba igual, porque el dia que alguien baje `escolta_fuerza` esta
	#      es la linea que dira por que dejo de venir nadie.
	var e := _ban.enjambre
	var a := _ban.tuning.k_max * _ban.escolta_fuerza
	var peor := 0.0
	var cur_dentro := 0.0
	var cur_fuera := 0.0
	var n_dentro := 0
	var n_fuera := 0
	for i in n:
		var c := _ban.tuning.curiosidad(i, n)
		if _ban.escolta_de(i) >= 0.6:
			peor = maxf(peor, absf(e.omegas[i] - e.marcapasos_omega))
			cur_dentro += c
			n_dentro += 1
		else:
			cur_fuera += c
			n_fuera += 1
	cur_dentro /= maxf(float(n_dentro), 1.0)
	cur_fuera /= maxf(float(n_fuera), 1.0)

	_afirmar(n_dentro > 0 and peor <= a,
		"toda escolta cumple la condicion de enganche",
		"|ω−Ω| maximo entre las que vienen: %.3f · A = %.3f" % [peor, a])
	_afirmar(n_dentro > 0 and n_fuera > 0 and cur_dentro < cur_fuera,
		"y las que vienen son LAS CURIOSAS, siempre las mismas",
		"curiosidad media %.2f las que escoltan · %.2f las que no (corte %.2f)" % [
			cur_dentro, cur_fuera, _ban.escolta_fraccion])

	# RODEAN. La distancia de una escolta al jugador tiene que ser la del circulo,
	# no la del circuito: es la diferencia entre acompañar y pasar cerca.
	var desvio := 0.0
	for i in n:
		if _ban.escolta_de(i) < 0.85:
			continue
		var d := _ban.posicion_de(i).distance_to(_visitante.global_position)
		var ideal := sqrt(_ban.orbita_radio * _ban.orbita_radio
			+ _ban.orbita_alto * _ban.orbita_alto)
		desvio = maxf(desvio, absf(d - ideal))
	_afirmar(desvio < 2.2,
		"y RODEAN al jugador, no solo pasan cerca",
		"la escolta mas desviada esta a %.2f m del radio de la orbita" % desvio)


## EL REGRESO. El jugador se va y la bandada vuelve sola, sin nada que lo ordene.
func _regreso() -> void:
	_afirmar(_ban.escoltando() == 0,
		"cuando el jugador se va, se sueltan",
		"quedan %d escoltando de las %d que llegó a haber" % [
			_ban.escoltando(), _escolta_max])

	var peor := 0.0
	for i in _ban.criaturas:
		var u := _ban.enjambre.fase_de(i)
		var sobre_curva: Vector3 = _ban.global_transform * _ban._punto(u)
		peor = maxf(peor, _ban.posicion_de(i).distance_to(sobre_curva))
	_afirmar(peor <= _ban.dispersion_tubo + 0.01,
		"y vuelven TODAS al circuito",
		"la mas descolgada esta a %.2f m de la linea (tubo %.2f)" % [
			peor, _ban.dispersion_tubo])


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
		print("RESULTADO MUNDO VIVO: %d/%d comprobaciones." % [_cuenta, _cuenta])
	else:
		print("RESULTADO MUNDO VIVO: %d/%d — %d FALLOS:" % [
			_cuenta - _fallos.size(), _cuenta, _fallos.size()])
		for f in _fallos:
			print("   · %s" % f)
	get_tree().quit(0 if _fallos.is_empty() else 1)
