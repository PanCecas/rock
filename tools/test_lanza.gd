extends Node
## Test funcional de la lanza — Etapa 1 de la Fase 3.
##
##   godot --headless --path . tools/TestLanza.tscn
##
## El criterio de la etapa es UNO y esta al final: tirarla contra un muro,
## subirse encima y quedarse ahi. Lo de antes son las piezas que lo hacen
## posible, comprobadas por separado para que un fallo diga DONDE esta.

var _main: Node
var _p: PlayerController
var _l: Spear
var _paso: int = 0
var _t: float = 0.0
var _reloj: float = 0.0
var _guion: Array = []
var _fallos: PackedStringArray = []
var _visto: Dictionary = {}
var _aux: float = 0.0
var _origen: Vector3 = Vector3.ZERO
## Pulsa la cuerda durante unos frames: 1 = con lanza fuera, 2 = con lanza en mano.
var _zip: int = 0
var _vel_llegada: float = 0.0
## Latches del zip. Se miden MIENTRAS pasa, no al final: cuando termina la
## ventana del chequeo el jugador ya ha llegado arriba y ha vuelto a caer.
var _alto_max: float = -99.0
var _dist_min: float = 9999.0


func _ready() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	await get_tree().physics_frame
	_l = _p.lanza
	_construir()


func _construir() -> void:
	_guion = [
		_chequeo_("el jugador tiene LA lanza", 0.3,
			func() -> void: pass,
			func() -> bool: return _l != null and _l.en_mano(),
			"el Gym la crea y se la entrega; sin ella no hay nada que probar"),

		# --- VUELO ------------------------------------------------------------
		_chequeo_("se clava en un muro", 1.4,
			func() -> void:
				# Frente al muro de la lanza, mirandolo.
				_p.global_position = Vector3(0.0, 0.05, 33.0)
				_p.velocity = Vector3.ZERO
				_visto.clear()
				_l.lanzar(_p.global_position + Vector3.UP, Vector3(0, 0.25, -1).normalized()),
			func() -> bool: return _l.clavada_en_algo(),
			"contra geometria se para EN SECO: eso es clavarse"),

		_chequeo_("y al clavarse es plataforma", 0.3,
			func() -> void: pass,
			func() -> bool:
				var pl := _l.get_node_or_null("Plataforma") as StaticBody3D
				return pl != null and pl.get_collision_layer_value(1),
			"poder quedarse DE PIE encima es la mitad de la mecanica"),

		# EL CRITERIO DE LA ETAPA.
		_chequeo_("el jugador se queda DE PIE encima", 1.8,
			func() -> void:
				_p.global_position = _l.global_position + Vector3(0, 1.2, 0)
				_p.velocity = Vector3.ZERO
				_aux = _l.global_position.y,
			func() -> bool:
				return _p.is_on_floor() and _p.global_position.y > _aux - 0.3,
			"CRITERIO DE LA ETAPA 1: tirarla, clavarla y subirse"),

		# --- RECUPERACION -----------------------------------------------------
		_chequeo_("vuelve a la mano", 2.0,
			func() -> void:
				_p.global_position = Vector3(0.0, 0.05, 33.0)
				_p.velocity = Vector3.ZERO
				_visto.clear()
				_l.recuperar(),
			func() -> bool: return _l.en_mano() and _l.fsm.anterior == &"Returning",
			"y pasa por Returning: volver en linea recta parece teletransporte"),

		_chequeo_("y al volver deja de ser plataforma", 0.3,
			func() -> void: pass,
			func() -> bool:
				var pl := _l.get_node_or_null("Plataforma") as StaticBody3D
				return pl != null and not pl.get_collision_layer_value(1),
			"una plataforma que sobrevive a la lanza es un bloque flotante"),

		# --- CAMBIAR DE POSICION (etapa 2) ------------------------------------
		_chequeo_("zip: te acerca a la lanza clavada", 2.2,
			func() -> void:
				_p.global_position = Vector3(0.0, 0.05, 33.0)
				_p.velocity = Vector3.ZERO
				_p.stamina.llenar()
				_l.lanzar(_p.global_position + Vector3.UP, Vector3(0, 0.35, -1).normalized())
				_aux = 0.0
				_visto.clear()
				_alto_max = -99.0
				_dist_min = 9999.0
				_zip = 1,
			func() -> bool:
				# Llego a la lanza Y gano altura. Las dos medidas son latches: al
				# terminar la ventana ya ha vuelto a caer, asi que preguntarlo al
				# final mediria la gravedad, no el zip.
				return _dist_min < 4.0 and _alto_max > 2.0,
			"tirarla a lo alto y subirse es el bucle de progresion vertical"),

		_chequeo_("y al llegar CONSERVA momentum", 0.1,
			func() -> void: pass,
			func() -> bool: return _vel_llegada > 1.0,
			"frenarse en seco al llegar convierte el zip en un colocador, no en un enlace"),

		_chequeo_("sin lanza fuera de la mano no hay zip", 0.8,
			func() -> void:
				# Directo a la mano y no `recuperar()`: recuperar tarda dos decimas
				# en volver, y durante ese vuelo la lanza SIGUE estando fuera de la
				# mano, asi que el zip disparaba con razon y el test medía otra cosa.
				_l.fsm.cambiar(&"Wielded")
				_p.global_position = Vector3(0.0, 0.05, 33.0)
				_p.velocity = Vector3.ZERO
				_p.stamina.llenar()
				_visto.clear()
				_zip = 2,
			func() -> bool: return not _visto.has(&"SpearZip"),
			"con la lanza en la mano no hay a donde tirar"),

		# --- ATRAVESAR --------------------------------------------------------
		_chequeo_("atraviesa a los enemigos sin pararse", 1.2,
			func() -> void:
				# Al aire libre, lejos del muro: aqui interesa que NO se pare.
				# A lo ancho del corral: el Embestidor esta a 7 m y detras queda
				# sitio libre. Tirar hacia el coloso no valdria: clavarse en un
				# coloso es lo que la lanza DEBE hacer, no un fallo.
				# x=4 esta pasados los muros del wall-run (x 1.3..2.3), que cortaban
				# el disparo a metro y medio de salir.
				_p.global_position = Vector3(4.0, 0.05, -32.0)
				_p.velocity = Vector3.ZERO
				_visto.clear()
				_aux = 0.0
				_origen = _p.global_position + Vector3.UP
				_l.lanzar(_origen, Vector3(1, 0.02, 0).normalized()),
			func() -> bool:
				# Recorrio camino de verdad: no se quedo clavado en el primer cuerpo.
				return _aux > 10.0,
			"un enemigo alcanzado recibe dano y la lanza SIGUE"),

		# --- IMANTADO ---------------------------------------------------------
		_chequeo_("el imantado no supera su tope", 0.4,
			func() -> void: pass,
			func() -> bool:
				var t: SpearTuning = _l.tuning
				return t.imantado_grados > 0.0 and t.imantado_grados <= 15.0,
			"pasado ese punto la lanza apunta por ti y acertar no significa nada"),
	]


func _physics_process(delta: float) -> void:
	_reloj += delta
	if _reloj > 45.0:
		_fallos.append("el test se colgo")
		_informe()
		return
	if _guion.is_empty():
		return
	if _paso >= _guion.size():
		_informe()
		return
	_t += delta

	if _zip > 0:
		# Se pulsa a mano: el buffer es el unico camino del input (regla dura #4)
		# y esta es la forma de simular una pulsacion desde un test.
		Input.action_press(&"rope")
		_zip -= 1
		if _zip == 0:
			Input.action_release(&"rope")
	_visto[_p.fsm.nombre_actual()] = true
	if _p.fsm.nombre_actual() == &"SpearZip":
		_vel_llegada = _p.velocity.length()
	_alto_max = maxf(_alto_max, _p.global_position.y)
	if _l != null and is_instance_valid(_l):
		_dist_min = minf(_dist_min, _p.global_position.distance_to(_l.global_position))
	if _l != null and is_instance_valid(_l):
		_visto[_l.fsm.nombre_actual()] = true
		if _l.fsm.nombre_actual() == &"InFlight":
			_aux = maxf(_aux, _l.global_position.distance_to(_origen))

	var actual: Dictionary = _guion[_paso]
	if is_zero_approx(_t - delta):
		(actual["hacer"] as Callable).call()
	if _t >= float(actual["dur"]):
		if not (actual["chequeo"] as Callable).call():
			_fallos.append("%-38s %s\n      [lanza=%s]" % [
				actual["nombre"], actual["porque"],
				_l.fsm.nombre_actual() if _l != null else "?"])
		else:
			print("  OK    %s" % actual["nombre"])
		_paso += 1
		_t = 0.0


func _informe() -> void:
	set_physics_process(false)
	print("RESULTADO LANZA: %d/%d comprobaciones." % [_guion.size() - _fallos.size(), _guion.size()])
	if not _fallos.is_empty():
		print("--- FALLOS ---")
		for f in _fallos:
			print("  " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)


func _chequeo_(nombre: String, dur: float, hacer: Callable, chequeo: Callable, porque: String) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "chequeo": chequeo, "porque": porque}
