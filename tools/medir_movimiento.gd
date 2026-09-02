extends Node
## Mide el feel de la locomocion en numeros. No opina: cronometra.
##
##   godot --headless --path . tools/MedirMovimiento.tscn
##
## Existe por la misma razon que `medir_paleta.gd`: antes de tocar una constante
## porque "se siente resbaladizo", conviene saber CUANTOS metros resbala. Un
## numero se puede discutir; una sensacion, no.
##
## Cada medida imprime tambien el valor de tuning del que depende, para que se vea
## de un vistazo que hay que mover.

const OBJETIVO_PARADO := 0.5

var _p: PlayerController
var _main: Node
var _paso: int = 0
var _t: float = 0.0
var _guion: Array = []
var _lineas: PackedStringArray = []

# Acumuladores de la medida en curso.
var _t0: float = 0.0
var _pos0: Vector3 = Vector3.ZERO
var _vel0: float = 0.0
var _midiendo: bool = false
var _dir0: Vector3 = Vector3.ZERO
var _modo: String = "DESPUES (correccion 2.05)"


func _ready() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController

	# `-- antes` reproduce el comportamiento previo a la correccion 2.05 SIN tocar
	# codigo: los tres cambios eran de valor, y dos de ellos —el techo aereo y el
	# frenado al soltar— se replican poniendo el parametro nuevo al valor que
	# tenia implicito el codigo viejo.
	if OS.get_cmdline_user_args().has("antes"):
		_modo = "ANTES (valores de la 2.04)"
		_p.tuning.frenado_soltar = _p.tuning.frenado_momentum
		_p.tuning.aceleracion_aire = 25.0
		_p.tuning.control_aereo_techo = _p.tuning.velocidad_correr

	_construir()


func _construir() -> void:
	_guion = [
		# --- 1) Cuanto tarda en arrancar -------------------------------------
		_medida("aceleracion desde parado", 5.0,
			func() -> void:
				_colocar(Vector3(0.0, 0.05, 0.0))
				_mirar_a(-90.0)
				_pulsar(&"move_forward")
				_arrancar(),
			func() -> String:
				return "%.2f s  ·  %.1f m  (llega a %.1f m/s)" % [
					_t - _t0, _dist(), _p.motor.rapidez_plana()],
			func() -> bool:
				return _p.motor.rapidez_plana() >= _p.tuning.velocidad_correr * 0.9),

		# --- 2) LA MEDIDA DEL "LOOSE MOVEMENT" -------------------------------
		# Correr a tope y SOLTAR. Lo que se cronometra es el patinaje.
		_medida("frenada al soltar el stick", 6.0,
			func() -> void:
				_soltar_todo()
				_arrancar(),
			func() -> String:
				return "%.2f s  ·  %.2f m de patinaje  (desde %.1f m/s)" % [
					_t - _t0, _dist(), _vel0],
			func() -> bool:
				return _p.motor.rapidez_plana() < OBJETIVO_PARADO),

		# --- 3) Frenada pidiendo la direccion CONTRARIA ----------------------
		_paso_("recoger carrerilla", 2.0, func() -> void:
			_colocar(Vector3(0.0, 0.05, 0.0))
			_mirar_a(-90.0)
			_pulsar(&"move_forward")),
		_medida("frenada pidiendo lo contrario", 4.0,
			func() -> void:
				_soltar(&"move_forward")
				_pulsar(&"move_back")
				_arrancar(),
			func() -> String:
				return "%.2f s  ·  %.2f m antes de invertir" % [_t - _t0, _dist()],
			func() -> bool:
				return _p.superficie.plano(_p.velocity).dot(_dir0) < 0.0),

		# --- 4) CONTROL AEREO: cuanto se puede corregir en el aire -----------
		_paso_("carrerilla para saltar", 2.0, func() -> void:
			_soltar_todo()
			_colocar(Vector3(0.0, 0.05, 0.0))
			_mirar_a(-90.0)
			_pulsar(&"move_forward")),
		_medida("inversion en el aire", 0.55,
			func() -> void:
				_p.motor.set_vertical(_p.tuning.velocidad_salto())
				_p.fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true}, true)
				_soltar(&"move_forward")
				_pulsar(&"move_back")
				_arrancar(),
			func() -> String:
				var proyeccion := _p.superficie.plano(_p.velocity).dot(_dir0)
				var estado := "INVERTIDO del todo" if proyeccion < 0.0 else "aun avanzando"
				return "salio a %.1f m/s; a 0.55 s lleva %.1f m/s en ese eje (%s)" % [
					_vel0, proyeccion, estado]),

		# --- 6) SALIR DEL SURF Y GIRAR ---------------------------------------
		# El reporte era "despues del surf el personaje sigue en linea recta y no
		# puedo direccionarlo". Lo que se cronometra aqui es exactamente eso: se
		# suelta Shift, se pide otra direccion, y se mide CUANTO TARDA la
		# velocidad en obedecer y cuantos metros recorre mientras tanto.
		_paso_("entrar en surf", 2.5, func() -> void:
			_soltar_todo()
			_colocar(Vector3(0.0, 0.05, 40.0))
			_mirar_a(-90.0)
			_pulsar(&"move_forward")
			_pulsar(&"sprint")
			_pulsar(&"dash")),
		_medida("girar 90 al salir del surf", 6.0,
			func() -> void:
				_soltar(&"dash")
				_soltar(&"sprint")
				_soltar(&"move_forward")
				_pulsar(&"move_right")
				_arrancar(),
			func() -> String:
				return "%.2f s  ·  %.2f m de linea recta  (salio a %.1f m/s)" % [
					_t - _t0, _dist(), _vel0],
			func() -> bool: return _giro_hecho(80.0)),
		_paso_("volver al surf", 2.5, func() -> void:
			_soltar_todo()
			_colocar(Vector3(0.0, 0.05, 40.0))
			_mirar_a(-90.0)
			_pulsar(&"move_forward")
			_pulsar(&"sprint")
			_pulsar(&"dash")),
		_medida("invertir al salir del surf", 8.0,
			func() -> void:
				_soltar(&"dash")
				_soltar(&"sprint")
				_soltar(&"move_forward")
				_pulsar(&"move_back")
				_arrancar(),
			func() -> String:
				return "%.2f s  ·  %.2f m antes de invertir  (salio a %.1f m/s)" % [
					_t - _t0, _dist(), _vel0],
			func() -> bool:
				return _p.superficie.plano(_p.velocity).dot(_dir0) < 0.0),

		# --- 5) Salto desde PARADO: cuanta velocidad se gana en el aire ------
		_medida("velocidad ganada saltando parado", 0.55,
			func() -> void:
				_soltar_todo()
				_colocar(Vector3(0.0, 0.05, 0.0))
				_mirar_a(-90.0)
				_p.velocity = Vector3.ZERO
				_p.motor.set_vertical(_p.tuning.velocidad_salto())
				_p.fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true}, true)
				_pulsar(&"move_forward")
				_arrancar(),
			func() -> String:
				return "de 0 a %.1f m/s en el aire%s (correr = %.1f)" % [
					_p.motor.rapidez_plana(),
					"" if not _p.is_on_floor() else "  [OJO: ya habia aterrizado]",
					_p.tuning.velocidad_correr]),
	]


func _physics_process(delta: float) -> void:
	if _paso >= _guion.size():
		_informe()
		return
	_t += delta

	var actual: Dictionary = _guion[_paso]
	if is_zero_approx(_t - delta) or not bool(actual.get("iniciado", false)):
		actual["iniciado"] = true
		(actual["hacer"] as Callable).call()

	# Corte anticipado: no tiene sentido esperar 3 s si ya se paro en 1.2.
	if _midiendo and actual.has("fin") and (actual["fin"] as Callable).call():
		_cerrar(actual)
		return

	if _t >= float(actual["dur"]):
		_cerrar(actual)


func _cerrar(actual: Dictionary) -> void:
	if actual.has("leer"):
		_lineas.append("  %-34s %s" % [actual["nombre"], (actual["leer"] as Callable).call()])
	_paso += 1
	_t = 0.0
	_midiendo = false


func _informe() -> void:
	set_physics_process(false)
	var t := _p.tuning
	print("
--- MEDIDAS DE LOCOMOCION · " + _modo + " ---")
	for l in _lineas:
		print(l)
	print("\n--- TUNING QUE LAS GOBIERNA ---")
	print("  aceleracion_suelo  %.1f      frenado_soltar     %.1f" % [t.aceleracion_suelo, t.frenado_soltar])
	print("  aceleracion_aire   %.1f      frenado_aire       %.1f" % [t.aceleracion_aire, t.frenado_aire])
	print("  frenado_momentum   %.1f      suavizado_velocidad %.2f s" % [t.frenado_momentum, t.suavizado_velocidad])
	print("  velocidad_correr   %.1f      velocidad_maxima   %.1f" % [t.velocidad_correr, t.velocidad_maxima])
	get_tree().quit(0)


# --- Utilidades ---------------------------------------------------------------

func _medida(nombre: String, dur: float, hacer: Callable, leer: Callable,
		fin: Callable = Callable()) -> Dictionary:
	# `dur` es solo el tope de seguridad. Lo que cierra la medida es `fin`: una
	# medida que termina por reloj no mide nada, informa del reloj.
	var corte := fin if fin.is_valid() else (func() -> bool: return false)
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "leer": leer, "fin": corte}


func _paso_(nombre: String, dur: float, hacer: Callable) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer}


func _arrancar() -> void:
	_t0 = _t
	_pos0 = _p.global_position
	_vel0 = _p.motor.rapidez_plana()
	var d := _p.motor.direccion_plana()
	_dir0 = d if not d.is_zero_approx() else _p.direccion_frontal()
	_midiendo = true


## ¿La velocidad ya apunta a donde se esta pidiendo, con ese margen en grados?
##
## Se mide contra la DIRECCION PEDIDA y no contra la inicial: lo que se reporto no
## es "tarda en frenar", es "no obedece". Son dos cosas distintas y solo la segunda
## es un bug de control.
func _giro_hecho(grados: float) -> bool:
	var v := _p.superficie.plano(_p.velocity)
	if v.length() < 0.5:
		return false
	var pedida := _p.superficie.direccion_movimiento(_p.buffer.move_vector(), _p.camara())
	if pedida.is_zero_approx():
		return false
	return rad_to_deg(v.normalized().angle_to(pedida)) <= grados


func _dist() -> float:
	var d := _p.global_position - _pos0
	d.y = 0.0
	return d.length()


func _colocar(pos: Vector3) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.stamina.llenar()
	_p.fsm.cambiar(&"Idle")


func _mirar_a(yaw: float) -> void:
	var rig := _main.get_node_or_null("CameraRig")
	if rig == null:
		return
	rig.set("_yaw", yaw)
	rig.set("_realinea", 0.0)


func _pulsar(a: StringName) -> void:
	Input.action_press(a)


func _soltar(a: StringName) -> void:
	Input.action_release(a)


func _soltar_todo() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
