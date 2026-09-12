extends Node
## Test funcional de LA PATADA — el único movimiento ofensivo.
##
##   godot --headless --path . tools/TestPatada.tscn
##
## Comprueba las leyes del moveset una por una, igual que `TestCuerda`: empieza en
## el frame en que se pulsa, dura lo que dice su número, termina sola, el stick la
## dirige entera, y hay UNA por tiempo de vuelo.
##
## Y las dos que son suyas y de nadie más:
##
##   · **Cruza huecos aunque no golpee nada.** Es lo que la convierte en una
##     herramienta de movimiento en vez de en un ataque.
##   · **Conectar RECARGA.** Un enemigo pasa a ser una plataforma, y esa es la
##     frase entera del diseño: golpear es seguir moviéndote.
##
## **El anti-spam se mide aquí y no se da por supuesto.** La recarga es un FLANCO
## de contacto, no un nivel; sin esa distinción, patear a ras de suelo devuelve la
## carga en el mismo frame en que se gasta y machacar el botón es un dash continuo
## a 18 m/s. Tiene su propia comprobación.

const GUARDIAN := preload("res://src/enemies/Guardian.tscn")

var _main: Node
var _p: PlayerController
var _victima: Enemigo

const ARRANQUE_MAX := 20.0
var _arranque: float = 0.0
var _paso: int = 0
var _t: float = 0.0
var _guion: Array = []
var _fallos: PackedStringArray = []
var _visto: Dictionary = {}
var _atacar: int = 0
var _stick: float = 0.0
## Frames que faltan para empujar el stick, contados DENTRO del gesto.
var _stick_tras: int = -1

# --- Latches. Se miden MIENTRAS pasa: al cerrar la ventana el gesto ya acabó.
var _t_patada: float = 0.0
var _v_min: float = 9999.0
var _v_max: float = 0.0
var _y0: float = 0.0
var _dy: float = 0.0
var _origen: Vector3 = Vector3.ZERO
var _recorrido: float = 0.0
var _lateral: float = 0.0
var _frente: Vector3 = Vector3.ZERO
var _estado_prev: StringName = &""
var _v_salida: float = 0.0
## Velocidad en el primer frame observable del gesto. Es la medida del startup.
var _v_primera: float = 0.0


func _ready() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	await get_tree().physics_frame

	# UN TEST NO PUEDE DEPENDER DE LA IA (CLAUDE.md). El corral del Gym trae
	# enemigos despiertos y un golpe en mitad de una medida manda al jugador a
	# `Hitstun`: así es como se llega a una suite intermitente.
	for n in get_tree().get_nodes_in_group(&"enemigos"):
		var e := n as Enemigo
		if e != null and is_instance_valid(e):
			e.vista = 0.0

	_construir()


## Un Guardián quieto y ciego donde se le diga. Ciego porque lo que se mide es el
## golpe DEL JUGADOR: un enemigo que además ataca solo mete ruido.
func _plantar_victima(pos: Vector3) -> void:
	if _victima != null and is_instance_valid(_victima):
		_victima.queue_free()
	_victima = GUARDIAN.instantiate() as Enemigo
	_main.add_child(_victima)
	_victima.global_position = pos
	_victima.vista = 0.0
	_victima.ataque = null


func _construir() -> void:
	_guion = [
		# --- EL GESTO ---------------------------------------------------------
		_chequeo_("el botón da una patada", 0.4,
			func() -> void:
				_colocar(Vector3(0.0, 8.0, 20.0))
				_atacar = 4,
			func() -> bool: return _visto.has(&"Kick"),
			"si el botón no patea, no hay mecánica que probar"),

		_chequeo_("no tiene anticipación: el primer frame ya es el bueno", 0.1,
			func() -> void: pass,
			func() -> bool:
				# Dos mitades de la misma ley. En los DATOS, cero frames de
				# windup —que es la unidad en la que se piensa el combate aqui—;
				# y en el JUEGO, velocidad de crucero desde el primer frame que
				# se puede observar.
				#
				# Contar frames entre la pulsación y el cambio de estado —que es
				# lo que hacía antes— mide el ORDEN DE LOS NODOS tanto como el
				# juego: con un umbral apretado falla por fontanería y con uno
				# holgado no afirma nada.
				var d: AttackData = _p.ataque_patada
				return (d != null and d.frames_windup == 0
					and _v_primera > _p.tuning.patada_velocidad - 0.6),
			"una patada que empieza quieta es un telegrafiado, y esto no telegrafia"),

		_chequeo_("dura lo que dice su número y termina sola", 0.6,
			func() -> void: pass,
			func() -> bool:
				var tope: float = _p.tuning.patada_duracion
				return (_p.fsm.nombre_actual() != &"Kick"
					and _t_patada > 0.0 and _t_patada <= tope + 0.05),
			"un gesto que se sostiene deja de ser un gesto (regla dura #27)"),

		_chequeo_("a velocidad CONSTANTE", 0.1,
			func() -> void: pass,
			func() -> bool:
				var v: float = _p.tuning.patada_velocidad
				return absf(_v_min - v) < 0.6 and absf(_v_max - v) < 0.6,
			"si acelera o frena, la trayectoria deja de poder leerse antes de pulsar"),

		_chequeo_("y sin que la gravedad la toque", 0.1,
			func() -> void: pass,
			func() -> bool: return _dy < 0.25,
			"media patada cayendo no cruza el hueco que se ve que cruza"),

		# --- CRUZA HUECOS -----------------------------------------------------
		_chequeo_("cruza un hueco sin golpear nada", 0.6,
			func() -> void:
				_colocar(Vector3(0.0, 8.0, 20.0))
				_atacar = 4,
			func() -> bool:
				# 0.25 s a 18 m/s son 4.5 m. Con margen para el frame de entrada.
				var esperado: float = (_p.tuning.patada_duracion
					* _p.tuning.patada_velocidad) * 0.8
				return _recorrido >= esperado,
			"es una herramienta de movimiento antes que un ataque, y eso se mide"),

		# EL STICK SE PIDE A MITAD DEL GESTO, Y NO AL PULSAR.
		#
		# Empujando desde el principio esto no probaría nada: la patada LEE el
		# stick al entrar para elegir su dirección, así que saldría recta hacia
		# donde ya estabas empujando y el desvío sería cero. La ley que hay que
		# comprobar es otra —"autoridad direccional durante TODO el movimiento"—
		# y solo se ve cambiando de idea a mitad.
		_chequeo_("el stick la DIRIGE a mitad del gesto", 0.6,
			func() -> void:
				_colocar(Vector3(0.0, 8.0, 20.0))
				_atacar = 4
				_stick_tras = 5,
			func() -> bool: return _lateral > 0.4,
			"sin autoridad direccional es una animación con la que se colisiona"),

		# --- CONECTAR ---------------------------------------------------------
		_chequeo_("conectar DERROTA de un golpe", 1.0,
			func() -> void:
				_stick = 0.0
				_plantar_victima(Vector3(6.0, 0.3, 20.0))
				_colocar(Vector3(0.0, 0.9, 20.0))
				_p.call("orientar_a", Vector3.RIGHT)
				_atacar = 4,
			func() -> bool:
				return _victima == null or not is_instance_valid(_victima) \
					or not _victima.salud.vivo,
			"un golpe que no resuelve nada devuelve el combate al machaque"),

		_chequeo_("y RECARGA la cuerda y la patada", 0.1,
			func() -> void: pass,
			func() -> bool: return _p.cuerda_disponible and _p.patada_disponible,
			"el enemigo es una plataforma: golpearle es SEGUIR moviéndote"),

		# --- UNA POR TIEMPO DE VUELO ------------------------------------------
		_chequeo_("en el aire solo hay una", 0.7,
			func() -> void:
				_colocar(Vector3(0.0, 14.0, 20.0))
				_p.patada_disponible = false
				_visto.clear()
				_atacar = 8,
			func() -> bool: return not _visto.has(&"Kick"),
			"la carga es la moneda: sin ella cada patada dejaría de costar nada"),

		_chequeo_("tocar suelo la devuelve", 1.8,
			func() -> void:
				_soltar_todo()
				_colocar(Vector3(0.0, 3.0, 20.0))
				_p.patada_disponible = false,
			func() -> bool: return _p.patada_disponible,
			"si no se recargara al aterrizar sería de un solo uso por partida"),

		# --- EL ANTI-SPAM -----------------------------------------------------
		_chequeo_("patear a ras de suelo NO la recarga", 0.9,
			func() -> void:
				_soltar_todo()
				_p.global_position = Vector3(0.0, 0.3, 20.0)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Idle")
				_p.patada_disponible = true
				_visto.clear()
				_atacar = 4,
			func() -> bool:
				# Se pateó —y por tanto se gastó— y el contacto continuo del suelo
				# NO la ha devuelto: hace falta salir y volver.
				return _visto.has(&"Kick") and not _p.patada_disponible,
			"con la recarga como NIVEL, machacar el botón sería un dash continuo"),

		_chequeo_("pero saltar y caer sí", 1.8,
			func() -> void:
				_soltar_todo()
				_p.global_position = Vector3(0.0, 3.0, 20.0)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Fall"),
			func() -> bool: return _p.patada_disponible,
			"la recarga es un gesto —salir y volver—, no una cuenta atrás"),

		# --- EL AGUA NO SE PATEA ----------------------------------------------
		_chequeo_("en el agua no hay patada", 1.2,
			func() -> void:
				_soltar_todo()
				# El estanque del Gym, en (28, 0, -28).
				_p.global_position = Vector3(28.0, 6.0, -28.0)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Fall")
				_p.patada_disponible = true
				_visto.clear()
				_atacar = 10,
			func() -> bool:
				return _visto.has(&"Swim") and not _visto.has(&"Kick"),
			"nadar es traversal puro: una patada dentro se salta la física del medio"),

		# --- SALIDA -----------------------------------------------------------
		_chequeo_("al terminar CONSERVA la velocidad", 0.7,
			func() -> void:
				_soltar_todo()
				_colocar(Vector3(0.0, 10.0, 20.0))
				_atacar = 4,
			func() -> bool:
				return _v_salida > _p.tuning.patada_velocidad * 0.75,
			"frenar al acabar convertiría el remate de una línea en un frenazo"),
	]


func _colocar(pos: Vector3) -> void:
	_soltar_todo()
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.stamina.llenar()
	_p.momentum_libre = 0.0
	_p.cuerda_disponible = true
	_p.patada_disponible = true
	_p.fsm.cambiar(&"Fall")
	_visto.clear()
	_t_patada = 0.0
	_v_min = 9999.0
	_v_max = 0.0
	_y0 = pos.y
	_dy = 0.0
	_origen = pos
	_recorrido = 0.0
	_lateral = 0.0
	_frente = Vector3.ZERO
	_v_salida = 0.0
	_v_primera = 0.0
	_stick_tras = -1


func _soltar_todo() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
	_atacar = 0
	_stick = 0.0
	_stick_tras = -1


func _physics_process(delta: float) -> void:
	if _guion.is_empty():
		_arranque += delta
		if _arranque > ARRANQUE_MAX:
			push_error("TestPatada: el guion no se construyo en %.0f s" % ARRANQUE_MAX)
			print("RESULTADO PATADA: 0/0 — el guion no llego a construirse.")
			set_physics_process(false)
			get_tree().quit(1)
		return
	if _paso >= _guion.size():
		_informe()
		return
	_t += delta

	# --- Teclas. Siempre por el InputMap: forzar el estado no probaria que se
	#     pueda LLEGAR a el.
	if _atacar > 0:
		Input.action_press(&"attack_light")
		_atacar -= 1
		if _atacar == 0:
			Input.action_release(&"attack_light")
	if is_zero_approx(_stick):
		Input.action_release(&"move_right")
	else:
		Input.action_press(&"move_right")

	# --- Latches.
	var estado := _p.fsm.nombre_actual()
	_visto[estado] = true
	if estado == &"Kick":
		if _estado_prev != &"Kick":
			_t_patada = 0.0
			_y0 = _p.global_position.y
			_origen = _p.global_position
			_frente = _p.superficie.plano(_p.velocity).normalized()
			_v_primera = _p.velocity.length()
		elif _stick_tras > 0:
			_stick_tras -= 1
			if _stick_tras == 0:
				_stick = 1.0
		_t_patada += delta
		var v := _p.velocity.length()
		_v_min = minf(_v_min, v)
		_v_max = maxf(_v_max, v)
		_dy = maxf(_dy, absf(_p.global_position.y - _y0))
		_recorrido = maxf(_recorrido, _p.global_position.distance_to(_origen))
		# Desvio LATERAL respecto a la direccion en la que salio: sin stick, una
		# patada va recta, asi que todo lo que haya aqui lo ha puesto el jugador.
		if not _frente.is_zero_approx():
			var lado := _frente.cross(_p.superficie.up).normalized()
			_lateral = maxf(_lateral, absf((_p.global_position - _origen).dot(lado)))
	elif _estado_prev == &"Kick":
		_v_salida = _p.superficie.plano(_p.velocity).length()
	_estado_prev = estado

	# --- El guion.
	var actual: Dictionary = _guion[_paso]
	if is_zero_approx(_t - delta):
		(actual["hacer"] as Callable).call()
	if _t >= float(actual["dur"]):
		if not (actual["chequeo"] as Callable).call():
			_fallos.append("%-40s %s\n      [estado=%s  patada=%.2fs  v=%.1f..%.1f  rec=%.1f  lat=%.2f]" % [
				actual["nombre"], actual["porque"], estado, _t_patada,
				_v_min if _v_min < 9999.0 else 0.0, _v_max, _recorrido, _lateral])
		else:
			print("  OK    %s" % actual["nombre"])
		_paso += 1
		_t = 0.0


func _informe() -> void:
	set_physics_process(false)
	print("RESULTADO PATADA: %d/%d comprobaciones." % [
		_guion.size() - _fallos.size(), _guion.size()])
	if not _fallos.is_empty():
		print("--- FALLOS ---")
		for f in _fallos:
			print("  " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)


func _chequeo_(nombre: String, dur: float, hacer: Callable, chequeo: Callable, porque: String) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "chequeo": chequeo, "porque": porque}
