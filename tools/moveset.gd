extends Node3D
## EL CIRCUITO DEL MOVESET — el PASO 6 del rediseño, y el único sitio donde el
## criterio de éxito se puede COMPROBAR jugando.
##
##   godot --path . --resolution 1280x720 tools/Moveset.tscn
##   godot --headless --path . tools/Moveset.tscn -- auto
##
## El criterio de éxito del parche 4.00 está escrito así: *«encadeno cuerda →
## patada → pared → cuerda sin tocar el suelo, y al repetirlo siento que la
## velocidad fue decisión mía, no de la física»*. El Gym tiene las piezas sueltas
## —pilares con anclas, muros, huecos— pero no tiene un sitio donde las cuatro
## estén **en fila y sean obligatorias**, y una cadena que se puede esquivar no
## prueba nada.
##
## Aquí no hay suelo. Solo tres sitios donde se aterriza —la SALIDA, la PARED y
## la META— y entre ellos vacío. Fallar un eslabón se cae, y caerse te devuelve a
## la salida: el circuito no te juzga, te devuelve a intentarlo.
##
## **Y lleva el marcador puesto.** El panel dice, en vivo, qué eslabones llevas y
## si has pisado algo por el camino. Sin eso, «lo he encadenado» es una opinión;
## con eso es una línea que se lee.
##
## **`-- auto` lo corre solo**, con su fila de control. No mide el feel —eso no se
## mide— sino una cosa concreta y aburrida: **que el hueco se pueda cruzar**. Si
## mañana bajas `patada_cargas` a 1 o tocas `cuerda_salida_mult`, este circuito
## puede volverse imposible sin que nada lo diga, y un gimnasio imposible es peor
## que no tenerlo.

## El carril donde se monta, lejos del Gym: el suelo del Gym mide 70 m y las
## referencias del screenshot test miran a lo que hay dentro. Esto vive fuera y
## por eso no toca ni una baseline.
@export var carril_z: float = -120.0
## Altura de la plataforma de salida.
@export_range(4.0, 60.0, 0.5) var altura_salida: float = 20.0
## **EL HUECO, que es el número del circuito.** Es lo que separa la SALIDA de la
## PARED, y está elegido para que la patada haga falta y no sobre.
##
## **Y NO SALE DE UNA CUENTA, SALE DE `-- auto`.** La cuenta a mano daba 22 m y
## era optimista: medido, con 22 la fila sin patear se quedaba a solo 4.2 m de la
## pared, o sea que una suelta un poco mejor la cruzaba sin patear y el eslabón
## dejaba de ser obligatorio. Con 26 las tres filas dicen lo que tienen que decir:
##
## ```
## pateando                 x=37.7 de 38.0   TOCA LA PARED
## sin patear — control     x=29.8 de 38.0   se queda corto  (8.2 m)
## pateando, sin la pared   x=47.5           sobran 9.5 m
## ```
##
## La tercera fila existe porque las otras dos no bastan: con la pared puesta el
## vuelo se PARA en ella, así que «toca la pared» no distingue llegar justo de
## llegar de sobra — y esa diferencia es la que separa un circuito exigente de uno
## que sale por casualidad.
@export_range(8.0, 60.0, 0.5) var hueco: float = 26.0
## Por debajo de esto se considera caída y se vuelve a la salida. Muy por encima
## de los −30 con los que `PlayerController._reset_si_cae()` te manda al spawn del
## Gym: si llegara ahí, el circuito te escupiría a 120 m de distancia.
@export_range(-28.0, 0.0, 0.5) var fondo: float = -12.0
## ¿Se planta el enemigo de prueba en mitad del hueco? Es la ruta alternativa:
## acertarle REBOTA y recarga, así que el mismo hueco se cruza de dos maneras.
@export var con_enemigo: bool = true

var _mundo: Node
var _p: PlayerController
var _raiz: Node3D
var _cam: Camera3D

# --- Los cuatro eslabones, EN ORDEN. Un eslabón fuera de orden no cuenta: la
#     cadena es una secuencia, no una lista de cosas que hiciste alguna vez.
const ESLABONES: PackedStringArray = ["cuerda", "patada", "pared", "cuerda"]
var _paso: int = 0
var _piso: bool = false
var _t: float = 0.0
var _mejor: float = -1.0
var _intentos: int = 0
var _estado_prev: StringName = &""
var _tocaba: bool = false
var _v_max: float = 0.0

# --- Posiciones que calcula `_construir()` y consultan el resto.
var _salida: Vector3 = Vector3.ZERO
var _ancla_a: Ancla = null
var _ancla_b: Ancla = null
var _x_pared: float = 0.0
var _pared: StaticBody3D = null

var _mat_piedra: StandardMaterial3D
var _mat_marca: StandardMaterial3D

# --- Modo automático.
var _auto: bool = false
var _guion: Array = []
var _fr: int = 0
var _fase: int = 0
var _x_max: float = -999.0
var _lineas: PackedStringArray = []
var _mirar: Vector3 = Vector3.ZERO
var _cuerda_fija: bool = false
var _cuerda_suelta: bool = true
var _toco_pared: bool = false
## Traza de estados de la pasada. Sin ella, «llego a x=2.5» no distingue «no
## engancho» de «engancho y se solto pronto», y son dos bugs distintos.
var _traza: PackedStringArray = []
var _traza_prev: StringName = &""
## Altura por debajo de la cual la pasada ya no cuenta. **Sin este corte la
## medida miente**: en el vacio la x sigue creciendo mientras caes, asi que una
## pasada que se despeño por debajo del circuito imprimia una x mayor que la
## pared y parecia que casi llegaba.
var _y_corte: float = 0.0
var _muerto: bool = false
## Para detectar el PUNTO BAJO del arco, que es donde se suelta. Ver el guion.
var _vy_min: float = 0.0
var _fr_suelta: int = -1
var _y_pared: float = -999.0
var _fr_pared: int = -1
## Modo FOTO: un plano general del circuito y a la calle. Un banco que solo
## imprime numeros no dice si la geometria esta donde uno cree — y aqui lo que se
## construye es un SITIO, no una medida.
var _foto: bool = false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_auto = args.has("auto")
	_foto = args.has("foto")
	_mundo = load("res://content/levels/Main.tscn").instantiate()
	add_child(_mundo)
	_p = _mundo.get_node_or_null("Player") as PlayerController
	await get_tree().physics_frame

	_construir()
	# EL GIMNASIO DA TODAS LAS HABILIDADES. Aquí se prueba el moveset, no la
	# progresión: llegar sin poder trepar no cambia nada de esta cadena, pero
	# llegar sin saberlo sí.
	if _p != null:
		_p.puede_escalar = true
	_volver_a_la_salida()

	if _auto or _foto:
		var rig := _mundo.get_node_or_null("CameraRig") as Node3D
		if rig != null:
			rig.process_mode = Node.PROCESS_MODE_DISABLED
		_cam = get_viewport().get_camera_3d()
		_guion = _guion_auto()
	else:
		DebugOverlay.visible_panel = true
	if _foto:
		await _retratar()


# --- LA GEOMETRÍA ------------------------------------------------------------

## Tres sitios donde se aterriza y vacío entre ellos. Que NO haya suelo es el
## diseño entero: la condición «sin tocar el suelo» deja de ser una regla que hay
## que vigilar y pasa a ser la forma del sitio.
func _construir() -> void:
	var p: Palette = GameState.palette
	_mat_piedra = StandardMaterial3D.new()
	_mat_piedra.albedo_color = p.caliza_sol if "caliza_sol" in p else Color(0.8, 0.78, 0.7)
	_mat_marca = StandardMaterial3D.new()
	_mat_marca.albedo_color = p.oro_palido

	_raiz = Node3D.new()
	_raiz.name = "Circuito"
	add_child(_raiz)

	var y := altura_salida
	# Justo APOYADO, no un metro por encima: la caidita de colocarse era un
	# transitorio de vy -6 -> 0 y el detector del punto bajo del arco la leia como
	# el fondo del arco. Un banco no puede medir su propio teletransporte.
	_salida = Vector3(0.0, y + 0.95, carril_z)

	# 1) SALIDA. Ancha, porque empezar no es la parte difícil.
	_bloque("Salida", Vector3(9.0, 1.0, 9.0), Vector3(0.0, y - 0.5, carril_z), _mat_piedra)
	# Y EL CARTEL DICE EL GESTO REAL, que no es el que uno supone. De pie sobre la
	# plataforma la Z engancha pero el arco no arranca: el suelo te sostiene y la
	# restriccion no EMPUJA, solo impide alejarse. Lo cazo `-- auto` en su primera
	# pasada — la traza decia `Grapple > Idle` y x=2.5 —. El gesto que funciona es
	# mantener la Z y andar al vacio: en cuanto pierdes el suelo, el arco te coge.
	_cartel("SALIDA — manten Z y CAMINA al vacio", Vector3(0.0, y + 2.6, carril_z))

	# 2) EL ANCLA DE SALIDA. Delante y arriba: hace falta CAÍDA por debajo o el
	#    enganche no da arco, da un radio fijo (ver `docs/08_MANUAL.md §2`).
	_ancla_a = _ancla("Ancla_Salida", Vector3(12.0, y + 7.0, carril_z))
	_cartel("1 · CUERDA", Vector3(12.0, y + 8.8, carril_z))

	# 3) EL HUECO. Aquí no hay nada, y ese es el punto.
	var x_bajo := 12.0                       # bajo el ancla: donde se suelta
	_x_pared = x_bajo + hueco
	# POR ENCIMA de la linea de vuelo: a la altura del enemigo se pisaba con su
	# cartel y las dos frases salian una sobre otra. Lo vio la foto, no un numero.
	_cartel("2 · PATADA — el hueco no se cruza cayendo",
		Vector3(x_bajo + hueco * 0.5, y + 3.0, carril_z))

	# 4) LA PARED. Alta y ancha: llegar es lo difícil, acertarla no debería serlo.
	#    Va de cara al jugador, así que recibe de frente — wall-slide y wall-jump—
	#    y el contacto RECARGA el moveset entero, que es para lo que está.
	_pared = _bloque("Pared", Vector3(1.2, 22.0, 16.0),
		Vector3(_x_pared + 0.6, y - 9.0, carril_z), _mat_marca)
	_cartel("3 · PARED — tocarla recarga todo", Vector3(_x_pared + 1.6, y + 2.5, carril_z))

	# 5) EL ANCLA DE META, Y VA EN ESTE LADO DE LA PARED. **Al otro no funciona, y
	#    no por gusto: por geometria y por fisica, las dos medidas.**
	#
	#    · GEOMETRIA. Se llega a la pared a y=17.4 y la pared mide 22: desde ahi,
	#      la linea de vision a cualquier cosa que haya detras entra en el muro y
	#      el filtro la descarta —correctamente: engancharse a traves de una pared
	#      se lee como un bug—. Lo cazo `-- auto`: `cadena 3/4`, con los tres
	#      primeros eslabones hechos y el cuarto mudo.
	#    · FISICA. Y subir a verla tampoco vale: **un pendulo no gana altura**. El
	#      arco devuelve como mucho lo que caiste (regla dura #16 y la deuda de
	#      altura de `StateGrapple.post_move()`), asi que no hay forma de pasar por
	#      encima de un muro de 22 m con la cuerda. Un circuito que lo pidiera
	#      seria imposible y parecería un bug del jugador.
	#
	#    Asi que el circuito DA LA VUELTA, y eso lo mejora: obliga a girar la
	#    camara en el aire, que es la habilidad de verdad de este moveset.
	_ancla_b = _ancla("Ancla_Meta", Vector3(_x_pared - 9.0, y + 6.0, carril_z))
	_cartel("4 · CUERDA — date la vuelta", Vector3(_x_pared - 9.0, y + 7.8, carril_z))

	# 6) META. Grande y baja, y DETRAS: el segundo arco convierte la caida en
	#    velocidad hacia atras. El premio es aterrizar, no volver a acertar.
	_bloque("Meta", Vector3(15.0, 1.0, 15.0),
		Vector3(_x_pared - 24.0, y - 17.5, carril_z), _mat_marca)
	_cartel("META", Vector3(_x_pared - 24.0, y - 14.5, carril_z))

	if con_enemigo:
		_enemigo_de_prueba(Vector3(x_bajo + hueco * 0.55, y - 6.5, carril_z))


## EL ENEMIGO ES LA OTRA RUTA, no un adorno. Acertarle DERROTA, REBOTA y recarga,
## así que el mismo hueco se cruza de dos maneras: dos patadas seguidas, o una
## patada a la cabeza y el rebote. Que haya dos soluciones es lo que convierte un
## hueco en una decisión.
##
## Se le quita la vista y el ataque: aquí se prueba el moveset, no una pelea, y un
## enemigo que persigue mueve el objetivo entre intento e intento.
func _enemigo_de_prueba(pos: Vector3) -> void:
	var e := load("res://src/enemies/Guardian.tscn").instantiate() as Enemigo
	_raiz.add_child(e)
	e.global_position = pos
	e.vista = 0.0
	e.ataque = null
	# Sin gravedad que lo tire al vacío: es una plataforma con forma de enemigo.
	e.set_physics_process(false)
	_cartel("(o patea al enemigo: acertar REBOTA)", pos + Vector3(0.0, 2.4, 0.0))


func _bloque(nombre: String, tam: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = nombre
	cuerpo.collision_layer = Layers.WORLD
	var malla := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	malla.mesh = caja
	malla.material_override = mat
	cuerpo.add_child(malla)
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = tam
	col.shape = forma
	cuerpo.add_child(col)
	_raiz.add_child(cuerpo)
	cuerpo.global_position = pos
	return cuerpo


func _ancla(nombre: String, pos: Vector3) -> Ancla:
	var a := Ancla.new()
	a.name = nombre
	_raiz.add_child(a)
	a.global_position = pos
	return a


func _cartel(texto: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = texto
	l.font_size = 96
	l.pixel_size = 0.0075
	l.modulate = GameState.palette.crema_bruma
	l.outline_modulate = GameState.palette.verde_negro
	l.outline_size = 20
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.double_sided = true
	_raiz.add_child(l)
	l.global_position = pos


# --- EL MARCADOR -------------------------------------------------------------

## EL PLANO GENERAL: de lado y de lejos, que es como se lee un circuito. De frente
## los cuatro hitos se tapan entre ellos y no se ve cual es el hueco.
func _retratar() -> void:
	DebugOverlay.visible_panel = false
	var y := altura_salida
	var medio := Vector3(_x_pared * 0.5, y - 5.0, carril_z)
	_cam.global_position = medio + Vector3(0.0, 10.0, 52.0)
	_cam.look_at(medio, Vector3.UP)
	_cam.reset_physics_interpolation()
	for i in 16:
		_cam.look_at(medio, Vector3.UP)
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://moveset")
	var ruta := "user://moveset/circuito.png"
	get_viewport().get_texture().get_image().save_png(ruta)
	print("
=== EL CIRCUITO DEL MOVESET ===")
	print("  %s" % ProjectSettings.globalize_path(ruta))
	get_tree().quit(0)


func _physics_process(delta: float) -> void:
	if _p == null or _foto:
		return
	if _auto:
		_correr_auto(delta)
		return

	_t += delta
	_seguir_cadena()
	if _p.global_position.y < fondo:
		_volver_a_la_salida()


## LA CADENA, leída del juego y no de un guion. Avanza EN ORDEN: un eslabón que
## llega fuera de turno no cuenta, porque lo que se prueba es la secuencia.
func _seguir_cadena() -> void:
	var estado := _p.fsm.nombre_actual()
	var tocando := _p.is_on_floor() or _p.is_on_wall()
	_v_max = maxf(_v_max, _p.superficie.plano(_p.velocity).length())

	if _paso < ESLABONES.size():
		var toca := ESLABONES[_paso]
		var cumplido := false
		match toca:
			"cuerda": cumplido = estado == &"Grapple" and _estado_prev != &"Grapple"
			"patada": cumplido = estado == &"Kick" and _estado_prev != &"Kick"
			"pared": cumplido = _p.is_on_wall() and not _tocaba
		if cumplido:
			_paso += 1
			if _paso >= ESLABONES.size():
				_mejor = _t if _mejor < 0.0 else minf(_mejor, _t)

	# PISAR ROMPE LA CADENA, y solo antes de cerrarla: aterrizar en la META es el
	# premio, no un fallo. El suelo se lee como FLANCO —igual que la recarga del
	# moveset— porque lo que importa es el momento en que pasa.
	if _paso < ESLABONES.size() and _p.is_on_floor() and not _tocaba:
		if _t > 0.4:
			_piso = true
	_tocaba = tocando
	_estado_prev = estado


func _process(_delta: float) -> void:
	if _auto or _p == null:
		return
	var marcas := PackedStringArray()
	for i in ESLABONES.size():
		marcas.append("%s %s" % [ESLABONES[i], "OK" if i < _paso else "·"])
	DebugOverlay.set_line("circuito", "CADENA   %s" % "   ".join(marcas))
	var veredicto := "en curso"
	if _paso >= ESLABONES.size():
		veredicto = "COMPLETA en %.2f s" % _t
	elif _piso:
		veredicto = "ROTA — pisaste suelo (F4 o cáete para reiniciar)"
	DebugOverlay.set_line("circuito2", "%s   ·   pico %.1f m/s   ·   intentos %d%s" % [
		veredicto, _v_max, _intentos,
		"   ·   mejor %.2f s" % _mejor if _mejor >= 0.0 else ""])


func _unhandled_input(evento: InputEvent) -> void:
	if _auto:
		return
	var k := evento as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F4:
		_volver_a_la_salida()


func _volver_a_la_salida() -> void:
	if _p == null:
		return
	_intentos += 1
	_p.global_position = _salida
	_p.velocity = Vector3.ZERO
	_p.stamina.llenar()
	_p.recargar_moveset()
	_p.recargar_aire()
	_p.buffer.clear()
	_p.fsm.cambiar(&"Fall")
	_p.reset_physics_interpolation()
	_paso = 0
	_piso = false
	_t = 0.0
	_v_max = 0.0
	_tocaba = false
	_estado_prev = &""


# --- `-- auto`: ¿SE PUEDE CRUZAR EL HUECO? -----------------------------------
#
# No mide el feel. Mide la única cosa de este circuito que se puede romper en
# silencio cambiando un número en otra parte: que el hueco siga siendo cruzable
# con patadas e imposible sin ellas. Las dos filas hacen falta — un hueco que se
# cruza cayendo no obliga a nada, y uno que no se cruza ni pateando no se puede
# terminar.

func _guion_auto() -> Array:
	return [
		{"nombre": "cruzar el hueco PATEANDO", "patadas": true, "dur": 340},
		{"nombre": "el mismo hueco SIN patear — control", "patadas": false, "dur": 220},
		# EL MARGEN. Con la pared puesta, la fila de arriba se para EN ella, asi que
		# su numero no dice si llego justa o de sobra — y esa diferencia es la que
		# separa un circuito exigente de uno que sale por casualidad. Quitando la
		# pared, el mismo vuelo dice hasta donde llega de verdad.
		{"nombre": "pateando, sin la pared — el margen", "patadas": true, "dur": 220,
			"sin_pared": true},
	]


func _correr_auto(_delta: float) -> void:
	if _fase >= _guion.size():
		_informe()
		return
	var actual: Dictionary = _guion[_fase]

	if _fr == 0:
		_volver_a_la_salida()
		_x_max = -999.0
		_toco_pared = false
		_cuerda_fija = false
		_muerto = false
		_y_pared = -999.0
		_fr_pared = -1
		if _pared != null:
			_pared.collision_layer = 0 if bool(actual.get("sin_pared", false)) else Layers.WORLD
		_vy_min = 0.0
		_fr_suelta = -1
		_traza = PackedStringArray()
		_traza_prev = &""
		# El pie de la pared: por debajo de ahi la pasada esta perdida.
		_y_corte = altura_salida - 20.0

	# LA CÁMARA, conducida a mano: el cono es parte de la mecánica de la cuerda
	# (`Ancla.mejor()` lo mide desde el ojo), así que dejarlo al azar del rig
	# convertiría esto en una medida del rig.
	# LA CAMARA MIRA AL ANCLA MIENTRAS SE CUELGA, Y AL FRENTE EN CUANTO SE SUELTA.
	#
	# No es cosmetica: la patada sale hacia donde pide el stick EN COORDENADAS DE
	# CAMARA, asi que dejarla clavada en el ancla —que a mitad del arco ya queda
	# DETRAS— hacia que las patadas empujaran hacia atras. Medido: la fila que
	# pateaba llegaba a x=15.7 y la de control, sin patear, a x=17.9. Patear salia
	# peor que no patear, y la culpa era del encuadre del banco, no de la patada.
	_mirar = _ancla_a.global_position
	if _fr_suelta > 0:
		_mirar = Vector3(_x_pared + 6.0, altura_salida - 6.0, carril_z)
	# Y AL CUARTO ESLABON. Tocar la pared recarga el moveset entero, asi que la
	# cuerda vuelve a estar ahi; lo unico que hace falta es mirar al ancla
	# siguiente, que es exactamente lo que hace un jugador.
	if _paso >= 3:
		_mirar = _ancla_b.global_position
		if _fr_pared < 0:
			_fr_pared = _fr
		elif _fr - _fr_pared == 6:
			_cuerda_fija = true
	if _cam != null:
		var dir := (_mirar - _p.global_position)
		if dir.length() > 0.5:
			dir = dir.normalized()
			_cam.global_position = _p.global_position - dir * 6.0 + Vector3.UP * 2.0
			_cam.look_at(_mirar, Vector3.UP)

	if _cuerda_fija:
		Input.action_press(&"rope")
		_cuerda_suelta = false
	elif not _cuerda_suelta:
		Input.action_release(&"rope")
		_cuerda_suelta = true

	_fr += 1
	# EL GUION, y es el gesto de un jugador y no una secuencia de frames:
	#
	#   1. manten la Z y anda al vacio (de pie el arco no arranca),
	#   2. SUELTA EN EL PUNTO BAJO del arco —ahi es donde va mas rapido, y es la
	#      unica decision que la cuerda le pide al jugador—,
	#   3. y patea.
	#
	# El paso 2 NO es un numero de frame: se detecta. La vertical del arco pasa de
	# muy negativa a positiva justo al cruzar el fondo, asi que ese cruce ES el
	# punto bajo. Con un frame fijo, cambiar la altura del ancla o el hueco movia
	# el fondo y la medida empezaba a soltar en otro sitio sin decirlo.
	if _fr == 3:
		_cuerda_fija = true
	elif _fr == 6:
		Input.action_press(&"move_forward")

	var vy := _p.superficie.vertical(_p.velocity)
	# Y SOLO EN EL AIRE. De pie el arco no corre —el suelo sostiene— asi que la
	# vertical de ahi no es la del pendulo: es la del aterrizaje.
	if _cuerda_fija and _p.fsm.nombre_actual() == &"Grapple" and not _p.is_on_floor():
		_vy_min = minf(_vy_min, vy)
		if _vy_min < -6.0 and vy >= 0.0:
			_cuerda_fija = false
			_fr_suelta = _fr
	if bool(actual["patadas"]) and _fr_suelta > 0:
		var d := _fr - _fr_suelta
		# LAS TRES CARGAS, porque el circuito se dimensiona contra el presupuesto
		# COMPLETO y no contra medio. Con dos, la fila de patadas llegaba a la
		# pared por 30 cm y eso no es un margen, es una casualidad.
		# EL ESPACIO, no el click. Desde el 4.06 la patada solo cuelga del salto:
		# el boton de ataque es de la espada. La fila de patadas de `-- auto` se
		# conducia con el click, o sea que desde entonces media un boton que ya no
		# hace nada — y una fila de control que no ejecuta el verbo no dice que el
		# verbo sobre, dice que el banco dejo de preguntarlo.
		if d == 8 or d == 26 or d == 44:
			Input.action_press(&"jump")
		elif d == 10 or d == 28 or d == 46:
			Input.action_release(&"jump")

	_t += _delta
	_seguir_cadena()
	var est := _p.fsm.nombre_actual()
	if est != _traza_prev:
		if _traza.size() < 7:
			_traza.append(str(est))
		_traza_prev = est
	if _p.global_position.y < _y_corte:
		_muerto = true
	if not _muerto:
		_x_max = maxf(_x_max, _p.global_position.x)
	if _p.is_on_wall() and _p.global_position.x > 4.0:
		if not _toco_pared:
			# A QUE ALTURA se llega a la pared. Es el numero que coloca el ancla de
			# meta: puesta a ojo en lo alto quedaba a 21.7 m del punto de contacto,
			# fuera del alcance de 19, y el cuarto eslabon no existia.
			_y_pared = _p.global_position.y
		_toco_pared = true

	if _fr >= int(actual["dur"]) or (_muerto and _fr > 60):
		var veredicto := "   se queda corto"
		if _toco_pared:
			veredicto = "   TOCA LA PARED a y=%.1f (ancla_meta a %.1f m)" % [
				_y_pared,
				_ancla_b.global_position.distance_to(
					Vector3(_x_pared, _y_pared, carril_z))]
		if bool(actual.get("sin_pared", false)):
			veredicto = "   sobran %.1f m" % (_x_max - _x_pared)
		# Y SI SE PISO ALGO. La cadena completa no vale si por el camino tocaste
		# suelo: el criterio de exito dice «sin tocar el suelo» y esa mitad de la
		# frase es la que la hace dificil.
		_lineas.append("  %-38s llego a x=%.1f de %.1f%s   cadena %d/4 %s   [%s]" % [
			actual["nombre"], _x_max, _x_pared, veredicto, _paso,
			"PISANDO" if _piso else "sin pisar", " > ".join(_traza)])
		_fase += 1
		_fr = 0
		for a in InputMap.get_actions():
			if Input.is_action_pressed(a):
				Input.action_release(a)


func _informe() -> void:
	set_physics_process(false)
	print("\n=== EL CIRCUITO DEL MOVESET ===\n")
	print("  hueco configurado: %.1f m   (de x=12.0 a x=%.1f)\n" % [hueco, _x_pared])
	for l in _lineas:
		print(l)
	print("\n  Lo que tiene que salir: la primera fila TOCA LA PARED y la segunda")
	print("  se queda corta. Si las dos tocan, el hueco no obliga a patear; si")
	print("  ninguna toca, el circuito no se puede terminar.")
	get_tree().quit(0)
