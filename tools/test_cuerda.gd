extends Node
## Test funcional de LA CUERDA — el arco único del moveset nuevo.
##
##   godot --headless --path . tools/TestCuerda.tscn
##
## Lo que se comprueba aquí es la lista de leyes del rediseño, una por una:
## empieza en el frame que se pulsa, dura menos de lo que dice su número, termina
## sola, el stick manda durante todo el arco, la salida conserva la velocidad, y
## hay UNA por tiempo de vuelo.
##
## **El ancla se coloca dentro del cono de la CÁMARA, no en coordenadas fijas.**
## El cono es parte de la mecánica —engancha lo que estás mirando— así que un
## ancla puesta en un punto del mundo probaría una cosa distinta según hacia dónde
## mirase la cámara ese día. Se lee la cámara real y se coloca relativa a ella:
## así el test no tiene que saber nada del `CameraRig` y sigue entrando por el
## camino de verdad, que es pulsar la tecla.

var _main: Node
var _p: PlayerController
var _ancla: Ancla
var _muro: StaticBody3D

## Segundos que se le dan a `_ready()` para dejar el guion montado antes de darlo
## por roto. Generoso: cargar `Main.tscn` entero no es inmediato.
const ARRANQUE_MAX := 20.0

var _paso: int = 0
var _t: float = 0.0
var _arranque: float = 0.0
var _guion: Array = []
var _fallos: PackedStringArray = []
var _visto: Dictionary = {}
## Cuenta atrás de frames pulsando la cuerda. Se pulsa la TECLA: el buffer es el
## único camino del input (regla dura #4) y forzar el estado no probaría que se
## pueda llegar a él.
var _cuerda: int = 0
var _salto: int = 0
## Stick lateral mantenido, en [-1, 1]. Para medir que el arco se dirige.
var _stick: float = 0.0

## Dónde se recoloca el ancla cada frame, respecto a la cámara. Se mantiene viva
## porque teletransportar al jugador deja a la cámara persiguiéndole unos frames:
## un ancla colocada una sola vez quedaría fuera del cono justo al pulsar.
var _ancla_grados: float = 35.0
var _ancla_dist: float = 8.0
var _ancla_detras: bool = false
var _ancla_viva: bool = false

# --- Latches. Se miden MIENTRAS pasa: al terminar la ventana el arco ya acabó.
var _t_arco: float = 0.0
var _dist_max: float = 0.0
var _largo_arco: float = 0.0
var _y0: float = 0.0
var _y_max: float = -999.0
var _lateral: float = 0.0
var _plano_dir: Vector3 = Vector3.ZERO
var _v_prev: float = 0.0
var _salida_ratio: float = 0.0
var _estado_prev: StringName = &""
## Separación entre el radio del arco y la distancia real en el instante de
## enganchar. Es la medida de que el enganche es INSTANTÁNEO y no un tirón.
var _tiron_inicial: float = -1.0


func _ready() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	await get_tree().physics_frame

	# UN TEST NO PUEDE DEPENDER DE LA IA (CLAUDE.md). El Gym trae un corral de
	# enemigos y un golpe en mitad de una medida manda al jugador a `Hitstun`, que
	# es exactamente cómo se llega a una suite intermitente.
	for n in get_tree().get_nodes_in_group(&"enemigos"):
		var e := n as Enemigo
		if e != null and is_instance_valid(e):
			e.vista = 0.0

	_ancla = Ancla.new()
	_ancla.name = "AnclaDePrueba"
	_main.add_child(_ancla)
	_ancla.global_position = Vector3(0.0, 40.0, 0.0)

	# Un muro de prueba propio, y no el del Gym: lo que se mide con él es la
	# recarga al TOCAR pared, así que tiene que estar donde el arco lo alcance sin
	# que la geometría de alrededor meta un suelo por medio.
	_muro = StaticBody3D.new()
	_muro.name = "MuroDePrueba"
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(0.6, 8.0, 12.0)
	forma.shape = caja
	_muro.add_child(forma)
	_muro.collision_layer = Layers.WORLD
	_main.add_child(_muro)
	_muro.global_position = Vector3(-30.0, 4.0, 20.0)

	_construir()


func _construir() -> void:
	_guion = [
		# --- ENGANCHE ---------------------------------------------------------
		_chequeo_("hay ancla delante y la Z engancha", 0.5,
			func() -> void:
				_soltar_en(Vector3(0.0, 12.0, 20.0))
				_ancla_viva = true
				_cuerda = 4,
			func() -> bool: return _visto.has(&"Grapple"),
			"si la Z con un ancla delante no engancha, no hay mecánica que probar"),

		_chequeo_("y el enganche es INSTANTÁNEO, sin tirón", 0.1,
			func() -> void: pass,
			func() -> bool:
				# El radio del arco es la distancia a la que estabas: si fueran
				# distintos, el primer frame daría un tirón hacia el ancla y eso es
				# justo el "tiempo de viaje" que el diseño prohíbe.
				return _tiron_inicial >= 0.0 and _tiron_inicial < 0.05,
			"un radio distinto de la distancia es un tirón, y un tirón es viaje"),

		_chequeo_("el arco NO se pasa de su radio", 0.9,
			func() -> void: pass,
			func() -> bool:
				return _largo_arco > 0.0 and _dist_max <= _largo_arco + 0.35,
			"eso es la restricción de distancia: sin ella la cuerda es una goma"),

		# --- EL ARCO TERMINA SOLO ---------------------------------------------
		_chequeo_("y se suelta SOLO antes de su tope", 1.2,
			func() -> void: pass,
			func() -> bool:
				var tope: float = _p.tuning.cuerda_arco_max
				return (_p.fsm.nombre_actual() != &"Grapple"
					and _t_arco > 0.0 and _t_arco <= tope + 0.05),
			"un arco que no caduca no es un movimiento, es un modo de transporte"),

		_chequeo_("no gana altura: no hay energía gratis", 0.1,
			func() -> void: pass,
			func() -> bool: return _y_max <= _y0 + 0.6,
			"la corrección de la restricción levanta al jugador, y eso hay que pagarlo"),

		_chequeo_("al soltar CONSERVA la velocidad, y la premia", 0.1,
			func() -> void: pass,
			func() -> bool:
				# El multiplicador es 1.15. Se mide contra el frame anterior a la
				# salida, y con margen: el estado que recibe ya aplica su propio
				# frame de física antes de que se pueda leer nada.
				return _salida_ratio > 1.05 and _salida_ratio < 1.35,
			"frenar al soltar convertiría el arco en un adorno: no serviría para llegar"),

		# --- EL STICK MANDA DURANTE TODO EL ARCO ------------------------------
		_chequeo_("el stick DIRIGE el arco", 1.1,
			func() -> void:
				_soltar_en(Vector3(0.0, 12.0, 20.0))
				_ancla_viva = true
				_cuerda = 4
				# Lateral puro: lo que se mide es que el arco se sale de su plano,
				# y eso solo lo puede hacer una aceleración tangencial.
				_stick = 1.0,
			func() -> bool: return _lateral > 1.5,
			"sin autoridad direccional el arco es una animación con la que se colisiona"),

		# --- UNA POR TIEMPO DE VUELO ------------------------------------------
		_chequeo_("gastada la cuerda, en el aire no hay otra", 0.8,
			func() -> void:
				_stick = 0.0
				# En el aire y ya sin carga: el chequeo anterior la gastó y no ha
				# tocado nada desde entonces.
				_p.global_position = Vector3(0.0, 16.0, 20.0)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Fall")
				_p.cuerda_disponible = false
				_visto.clear()
				_ancla_viva = true
				_cuerda = 6,
			func() -> bool: return not _visto.has(&"Grapple"),
			"la carga es la moneda: sin ella cada arco dejaría de costar nada"),

		_chequeo_("tocar SUELO la devuelve", 1.6,
			func() -> void:
				_soltar_todo()
				_p.global_position = Vector3(0.0, 0.6, 20.0)
				_p.velocity = Vector3.ZERO
				_p.cuerda_disponible = false
				_visto.clear(),
			func() -> bool: return _p.cuerda_disponible,
			"si no se recargara al aterrizar, la cuerda sería de un solo uso por partida"),

		_chequeo_("tocar PARED también", 1.4,
			func() -> void:
				_soltar_todo()
				# Pegado al muro de prueba y empujando contra él, en el aire.
				_p.global_position = _muro.global_position + Vector3(0.9, 2.0, 0.0)
				_p.velocity = Vector3(-6.0, 0.0, 0.0)
				_p.fsm.cambiar(&"Fall")
				_p.cuerda_disponible = false
				_visto.clear(),
			func() -> bool: return _p.cuerda_disponible,
			"encadenar cuerda→pared→cuerda es el criterio de éxito: sin esto no existe"),

		# --- LOS TRES FILTROS DEL ANCLA ---------------------------------------
		_chequeo_("un ancla DETRÁS no engancha", 0.9,
			func() -> void:
				_soltar_en(Vector3(0.0, 12.0, 20.0))
				_ancla_detras = true
				_ancla_viva = true
				_cuerda = 6,
			func() -> bool: return not _visto.has(&"Grapple"),
			"engancha lo que MIRAS: sin cono te tira hacia la que acabas de soltar"),

		_chequeo_("y una FUERA DE ALCANCE tampoco", 0.9,
			func() -> void:
				_soltar_en(Vector3(0.0, 12.0, 20.0))
				_ancla_dist = _p.tuning.cuerda_rango + 6.0
				_ancla_viva = true
				_cuerda = 6,
			func() -> bool: return not _visto.has(&"Grapple"),
			"`cuerda_rango` es el número que dibuja los niveles: tiene que morder"),

		_chequeo_("ni una TAPADA por el mundo", 0.9,
			func() -> void:
				_soltar_todo()
				_ancla_dist = 8.0
				# Al otro lado del muro de prueba, a su misma altura: en rango y en
				# el cono, pero sin línea de visión.
				_p.global_position = _muro.global_position + Vector3(6.0, 0.0, 0.0)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Fall")
				_p.cuerda_disponible = true
				_ancla.global_position = _muro.global_position + Vector3(-5.0, 0.0, 0.0)
				_visto.clear()
				_cuerda = 8,
			func() -> bool: return not _visto.has(&"Grapple"),
			"engancharse a través de una pared se lee como un bug aunque sea cómodo"),

		# --- SALIR SALTANDO ---------------------------------------------------
		_chequeo_("saltar suelta la cuerda", 1.0,
			func() -> void:
				_soltar_en(Vector3(0.0, 12.0, 20.0))
				_ancla_viva = true
				_cuerda = 4,
			func() -> bool: return _visto.has(&"Grapple"),
			"primero hay que colgarse para poder soltarse"),

		_chequeo_("y sale de verdad, con la inercia puesta", 0.6,
			func() -> void:
				_visto.clear()
				_salto = 4,
			func() -> bool:
				return (_visto.has(&"Jump")
					and _p.fsm.nombre_actual() != &"Grapple"),
			"el arco se usa para LLEGAR a un sitio, y llegar termina en un salto"),
	]


## Deja al jugador quieto y en el aire, con la cuerda cargada y el guion limpio.
func _soltar_en(pos: Vector3) -> void:
	_soltar_todo()
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.stamina.llenar()
	_p.momentum_libre = 0.0
	_p.cuerda_disponible = true
	_p.fsm.cambiar(&"Fall")
	_visto.clear()
	_t_arco = 0.0
	_dist_max = 0.0
	_largo_arco = 0.0
	_y0 = pos.y
	_y_max = -999.0
	_lateral = 0.0
	_plano_dir = Vector3.ZERO
	_salida_ratio = 0.0
	_tiron_inicial = -1.0


func _soltar_todo() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
	_cuerda = 0
	_salto = 0
	_stick = 0.0
	_ancla_viva = false
	_ancla_detras = false
	_ancla_grados = 35.0
	_ancla_dist = 8.0


## EL ANCLA, COLOCADA CADA FRAME: dirección de la CÁMARA, distancia desde el
## JUGADOR.
##
## Los dos orígenes, igual que los usa `Ancla.mejor()`. Y el de la distancia tiene
## que ser el jugador o el test no mide lo que dice: tras un teletransporte la
## cámara tarda unos frames en alcanzarle, así que un ancla puesta a 8 m de ELLA
## caía a 20.7 m del jugador —fuera de alcance— y el chequeo culpaba a la cuerda.
##
## `grados` la levanta sobre la dirección de la cámara: hace falta para que haya
## CAÍDA —un ancla a la altura de los ojos no da péndulo, da un radio fijo— y 35°
## cabe de sobra dentro del cono de 55°, así que sigue siendo una candidata
## legítima y no un caso especial.
func _recolocar_ancla() -> void:
	var cam := _p.camara()
	if cam == null:
		return
	var frente := -cam.global_basis.z
	var derecha := cam.global_basis.x.normalized()
	var arriba := frente.rotated(derecha, deg_to_rad(_ancla_grados))
	if arriba.y < frente.y:
		arriba = frente.rotated(derecha, -deg_to_rad(_ancla_grados))
	if _ancla_detras:
		arriba = -arriba
	_ancla.global_position = _p.global_position + arriba.normalized() * _ancla_dist


func _physics_process(delta: float) -> void:
	# UN TEST NO SE CUELGA: FALLA. Si el guion nunca se llega a construir —porque
	# el jugador no cargo, porque una clase no esta registrada— esto se quedaba
	# devolviendo para siempre y la suite no terminaba nunca. Un proceso colgado no
	# dice que esta roto; hay que ir a buscarlo.
	if _guion.is_empty():
		_arranque += delta
		if _arranque > ARRANQUE_MAX:
			push_error("TestCuerda: el guion no se construyo en %.0f s" % ARRANQUE_MAX)
			print("RESULTADO CUERDA: 0/0 — el guion no llego a construirse.")
			print("  El jugador es %s. ¿Esta `Ancla` registrada? `--import`." % (
				"null" if _p == null else "valido"))
			set_physics_process(false)
			get_tree().quit(1)
		return
	if _paso >= _guion.size():
		_informe()
		return
	_t += delta

	# EL ANCLA SE CONGELA AL ENGANCHAR. Seguir recolocandola contra la camara
	# mientras cuelgas mueve el ancla DEBAJO del jugador frame a frame: el radio
	# deja de significar nada y la medida no prueba la restriccion, prueba que un
	# ancla que anda arrastra. Se coloca para poder engancharse, y ahi se queda.
	if _ancla_viva and _p.fsm.nombre_actual() != &"Grapple":
		_recolocar_ancla()

	# --- Teclas. Siempre por el InputMap, nunca forzando el estado.
	if _cuerda > 0:
		Input.action_press(&"rope")
		_cuerda -= 1
		if _cuerda == 0:
			Input.action_release(&"rope")
	if _salto > 0:
		Input.action_press(&"jump")
		_salto -= 1
		if _salto == 0:
			Input.action_release(&"jump")
	if is_zero_approx(_stick):
		Input.action_release(&"move_right")
	else:
		Input.action_press(&"move_right")

	# --- Latches del arco.
	var estado := _p.fsm.nombre_actual()
	_visto[estado] = true
	if estado == &"Grapple":
		var punto: Vector3 = _p.fsm.actual.call("punto_cuerda")
		var largo: Variant = _p.fsm.actual.get("_largo")
		var d := _p.global_position.distance_to(punto)
		if _estado_prev != &"Grapple":
			# EL FRAME DEL ENGANCHE. Es el único en el que se puede medir si hubo
			# tirón: un frame después la física ya lo ha disuelto.
			_largo_arco = float(largo) if largo is float else 0.0
			_tiron_inicial = absf(d - _largo_arco)
			_plano_dir = _p.superficie.plano(punto - _p.global_position).normalized()
			_t_arco = 0.0
		_t_arco += delta
		_dist_max = maxf(_dist_max, d)
		_y_max = maxf(_y_max, _p.global_position.y)
		# Desvío LATERAL: lo que se sale del plano en el que empezó el arco. Un
		# péndulo sin stick se queda en su plano, así que todo lo que haya aquí lo
		# ha puesto el jugador.
		if not _plano_dir.is_zero_approx():
			var lado := _plano_dir.cross(_p.superficie.up).normalized()
			_lateral = maxf(_lateral, absf((_p.global_position - punto).dot(lado)))
	elif _estado_prev == &"Grapple" and _v_prev > 1.0:
		# LA SALIDA. Se mide en el plano: la vertical la toca la gravedad del
		# estado que recibe y mediría eso en vez del multiplicador.
		_salida_ratio = _p.superficie.plano(_p.velocity).length() / _v_prev
	if estado == &"Grapple":
		_v_prev = _p.superficie.plano(_p.velocity).length()
	_estado_prev = estado

	# --- El guion.
	var actual: Dictionary = _guion[_paso]
	if is_zero_approx(_t - delta):
		(actual["hacer"] as Callable).call()
	if _t >= float(actual["dur"]):
		if not (actual["chequeo"] as Callable).call():
			_fallos.append("%-42s %s\n      [estado=%s  arco=%.2fs  ratio=%.2f]" % [
				actual["nombre"], actual["porque"], estado, _t_arco, _salida_ratio])
		else:
			print("  OK    %s" % actual["nombre"])
		_paso += 1
		_t = 0.0


func _informe() -> void:
	set_physics_process(false)
	print("RESULTADO CUERDA: %d/%d comprobaciones." % [
		_guion.size() - _fallos.size(), _guion.size()])
	if not _fallos.is_empty():
		print("--- FALLOS ---")
		for f in _fallos:
			print("  " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)


func _chequeo_(nombre: String, dur: float, hacer: Callable, chequeo: Callable, porque: String) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "chequeo": chequeo, "porque": porque}
