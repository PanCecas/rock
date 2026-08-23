extends Node
## Test funcional de la Fase 2: combate.
##
##   godot --headless --path . tools/TestFase2.tscn
##
## Comprueba lo que se puede comprobar sin ojos: que la cadena encadena, que el
## daño llega, que las cancelaciones abren cuando deben y que el parry convierte
## un golpe en una apertura. El feel del combate sigue juzgándose en vídeo.

var _main: Node
var _p: PlayerController
var _g: Guardian

var _paso: int = 0
var _t: float = 0.0
var _reloj: float = 0.0
var _fallos: PackedStringArray = []
var _visitados: Dictionary = {}
var _guion: Array = []


func _ready() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	EventBus.player_state_changed.connect(
		func(_a: StringName, n: StringName) -> void: _visitados[n] = true)
	_construir_guion()


func _construir_guion() -> void:
	_guion = [
		_paso_("colocarse", 0.6, func() -> void:
			_lancero()
			_colocar(2.0), &"Idle"),

		# --- Cadena ligera ----------------------------------------------------
		_chequeo_("golpe 1 conecta", 0.35,
			func() -> void:
				_vida_antes = _g.salud.actual
				_pulsar(&"attack_light"),
			func() -> bool: return _g.salud.actual < _vida_antes,
			"el primer golpe debe quitar vida"),
		# La cadena solo encadena DENTRO del ataque, pasado `frame_cadena`. Pulsar
		# cuando L1 ya termino no encadena: empieza un L1 nuevo. Por eso los pasos
		# son cortos y encajan con las ventanas reales del .tres.
		_paso_("abrir cadena", 0.16, func() -> void:
			_soltar_todo()
			_reponer()
			_colocar(2.0)
			_pulsar(&"attack_light"), &"Attack"),
		# 0.10 s = 6 frames. Hacen falta: ~2 de latencia entre action_press y que el
		# InputBuffer lo vea, 1 para que StateAttack lo consuma, y margen.
		_chequeo_("encadena a L2", 0.10,
			func() -> void:
				_soltar_todo()
				_pulsar(&"attack_light"),
			func() -> bool: return _indice_ataque() >= 2,
			"pulsar dentro de la ventana debe encadenar al segundo golpe"),
		_paso_("esperar ventana", 0.16, func() -> void: _soltar_todo(), &"Attack"),
		_chequeo_("encadena a L3", 0.10,
			func() -> void: _pulsar(&"attack_light"),
			func() -> bool: return _indice_ataque() >= 3,
			"la cadena debe llegar al finisher"),

		# --- Cancelaciones ----------------------------------------------------
		_chequeo_("ataque -> dash", 0.4,
			func() -> void:
				_soltar_todo()
				_reponer()
				_colocar(2.0)
				_p.fsm.cambiar(&"Attack", {"datos": _p.ataque_ligero, "indice": 1})
				_esperar_frames = 8,
			func() -> bool: return _visitados.has(&"Dash"),
			"el dash debe poder cancelar el ataque tras la ventana activa"),

		# --- Aéreo: LA regla del sistema --------------------------------------
		_chequeo_("aéreo repone dash", 0.45,
			func() -> void:
				_soltar_todo()
				_reponer()
				_colocar(1.8)
				_p.global_position += Vector3.UP * 1.2
				_p.fsm.cambiar(&"Fall")
				_p.dash_cargas = 0
				_pulsar(&"attack_light"),
			func() -> bool: return _p.dash_cargas > 0,
			"conectar en el aire debe devolver una carga de dash"),

		# --- Picado -----------------------------------------------------------
		_chequeo_("picado golpea en área", 1.2,
			func() -> void:
				_soltar_todo()
				_reponer()
				_colocar(1.5)
				_p.global_position += Vector3.UP * 3.0
				_p.fsm.cambiar(&"Fall")
				_vida_antes = _g.salud.actual
				_pulsar(&"attack_heavy"),
			func() -> bool: return _visitados.has(&"Plunge") and _g.salud.actual < _vida_antes,
			"el picado debe entrar y reventar en área al aterrizar"),

		# --- Parry ------------------------------------------------------------
		_chequeo_("parry quiebra la guardia", 0.35,
			func() -> void:
				_soltar_todo()
				_reponer()
				_colocar(2.0)
				_p.fsm.cambiar(&"Parry")
				# Un golpe enemigo entregado a mano: orquestar la IA para que
				# ataque en el frame exacto haría el test frágil sin probar más.
				_p.recibir_golpe(Golpe.new(
					_g, _g.ataque, _p.global_position, (_p.global_position - _g.global_position).normalized())),
			func() -> bool: return _g.poise.rota and _p.salud.fraccion() > 0.99,
			"el parry no debe costar vida y debe quebrar al atacante"),

		# --- Recibir daño -----------------------------------------------------
		_chequeo_("encajar un golpe", 0.3,
			func() -> void:
				_soltar_todo()
				_reponer()
				_colocar(2.0)
				_p.fsm.cambiar(&"Idle")
				_p.iframes = 0.0
				_vida_antes = _p.salud.actual
				_p.recibir_golpe(Golpe.new(
					_g, _g.ataque, _p.global_position, (_p.global_position - _g.global_position).normalized())),
			func() -> bool: return _p.salud.actual < _vida_antes and _visitados.has(&"Hitstun"),
			"un golpe sin parry debe doler y aturdir"),

		# --- i-frames del dash ------------------------------------------------
		_chequeo_("los i-frames esquivan", 0.3,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.iframes = 0.2
				_vida_antes = _p.salud.actual
				_p.recibir_golpe(Golpe.new(
					_g, _g.ataque, _p.global_position, Vector3.FORWARD)),
			func() -> bool: return is_equal_approx(_p.salud.actual, _vida_antes),
			"con i-frames activos el golpe no debe entrar"),
	]


var _vida_antes: float = 0.0
var _esperar_frames: int = 0


func _physics_process(delta: float) -> void:
	_reloj += delta
	if _reloj > 60.0:
		_fallos.append("el test se colgó")
		_informe()
		return
	if _paso >= _guion.size():
		_informe()
		return

	# Un dash pedido en mitad de un ataque necesita que pasen unos frames antes
	# de que la ventana de cancelación se abra.
	if _esperar_frames > 0:
		_esperar_frames -= 1
		if _esperar_frames == 0:
			_pulsar(&"dash")

	var actual: Dictionary = _guion[_paso]
	if is_zero_approx(_t):
		(actual["hacer"] as Callable).call()
	_t += delta

	if _t >= float(actual["dur"]):
		var esperado: StringName = actual["espera"]
		if esperado != &"" and not _visitados.has(esperado):
			_fallos.append("%-24s no se alcanzó %s" % [actual["nombre"], esperado])
		if actual.has("chequeo") and not (actual["chequeo"] as Callable).call():
			_fallos.append("%-24s %s" % [actual["nombre"], actual["porque"]])
		else:
			print("  OK    %s" % actual["nombre"])
		_paso += 1
		_t = 0.0


func _informe() -> void:
	set_physics_process(false)
	print("RESULTADO: %d/%d comprobaciones." % [_guion.size() - _fallos.size(), _guion.size()])
	if not _fallos.is_empty():
		print("--- FALLOS ---")
		for f in _fallos:
			print("  " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)


# --- Utilidades ---------------------------------------------------------------

func _paso_(nombre: String, dur: float, hacer: Callable, espera: StringName) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "espera": espera}


func _chequeo_(nombre: String, dur: float, hacer: Callable, chequeo: Callable, porque: String) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "espera": &"",
		"chequeo": chequeo, "porque": porque}


func _lancero() -> void:
	for g in get_tree().get_nodes_in_group(&"guardianes"):
		if (g as Guardian).tipo == Guardian.Tipo.LANCERO:
			_g = g
			return
	_g = get_tree().get_nodes_in_group(&"guardianes")[0]


## Coloca al jugador a `dist` metros del Guardián, mirándolo. El Guardián se
## congela para que la IA no mueva el objetivo en mitad de la comprobación.
func _colocar(dist: float) -> void:
	_g.estado = Guardian.Estado.DORMIDO
	_g.velocity = Vector3.ZERO
	var pos := _g.global_position + Vector3(0, 0, dist)
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.orientar_a(Vector3(0, 0, -1))


func _reponer() -> void:
	_p.salud.actual = _p.salud.maxima
	_p.salud.vivo = true
	_p.stamina.llenar()
	_p.recargar_aire()
	_p.iframes = 0.0
	_g.salud.actual = _g.salud.maxima
	_g.salud.vivo = true
	_g.poise.actual = _g.poise.maxima
	_g.poise.rota = false
	_p.fsm.cambiar(&"Idle")


func _indice_ataque() -> int:
	if _p.fsm.actual == null or _p.fsm.actual.name != &"Attack":
		return 0
	return int(_p.fsm.actual.get("_indice"))


func _pulsar(accion: StringName) -> void:
	Input.action_press(accion)


func _soltar_todo() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
