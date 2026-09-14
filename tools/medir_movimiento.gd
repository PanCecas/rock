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
## Altura maxima alcanzada dentro de la medida. Es lo unico que dice si un salto
## se perdio contra una esquina: el estado no cambia —sigues en `Jump`— y la
## velocidad tampoco lo cuenta, porque `move_and_slide` la pone a cero sin avisar.
var _y_pico: float = -999.0
## EL ALERO: un techo con una esquina, construido por el banco porque el Gym no
## tiene ninguno. Sin geometria que rozar no se puede medir un roce.
var _alero: StaticBody3D = null
## Rapidez plana en el frame en que se toca suelo, y unos frames despues. Es lo
## que mide el bunnyhop: lo que el ATERRIZAJE se queda de lo que traias.
var _v_al_tocar: float = -1.0
var _v_tras_tocar: float = -1.0
var _fr_tocar: int = -1
var _tocaba: bool = false
const ALERO_CENTRO := Vector3(-10.0, 0.0, -34.0)


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

	_montar_alero()
	_construir()


## Un bloque con un borde limpio en x = -10 y la cara inferior a y = 2.0.
##
## **La altura importa y costo una pasada.** Con el alero a 3.0 el jugador se
## paraba a 1.06 m **tambien sin solape**: el techo cortaba el salto entero,
## control incluido, y las tres filas salian identicas por una razon que no era la
## esquina. A 2.0 el salto limpio pasa de largo —sube sus 2.6— y solo lo para el
## solape, que es lo unico que se quiere medir.
func _montar_alero() -> void:
	_alero = StaticBody3D.new()
	_alero.name = "Alero"
	_alero.collision_layer = Layers.WORLD
	var caja := BoxMesh.new()
	caja.size = Vector3(4.0, 1.0, 4.0)
	var malla := MeshInstance3D.new()
	malla.mesh = caja
	_alero.add_child(malla)
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = caja.size
	col.shape = forma
	_alero.add_child(col)
	add_child(_alero)
	_alero.global_position = ALERO_CENTRO + Vector3(2.0, 2.5, 0.0)


## Un salto vertical con la capsula solapando el borde del alero `solape` metros.
## Con 0 no toca nada y es la fila de control.
func _saltar_bajo_el_alero(solape: float) -> void:
	_soltar_todo()
	# El borde del alero esta en x = -10 y la capsula mide 0.4 de radio: a
	# -10.4 la roza justo, y cada centimetro que se suma es solape.
	_colocar(ALERO_CENTRO + Vector3(-0.4 - 0.4 + solape, 0.05, 0.0))
	_p.velocity = Vector3.ZERO
	_p.motor.set_vertical(_p.tuning.velocidad_salto())
	# SIN JUMP CUT. El banco no mantiene ninguna tecla, asi que `StateJump` recorta
	# el salto en el primer frame por no tener el boton pulsado y lo que se medía
	# era el salto CORTO: 1.06 m en las tres filas, tocara o no tocara el alero.
	_p.fsm.cambiar(&"Jump",
		{"numero": 1, "conservar_vertical": true, "sin_corte": true}, true)
	_y_pico = _p.global_position.y


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
		# --- LA ESQUINA -------------------------------------------------------
		# Un salto que roza un techo por un dedo se pierde entero, y el sintoma es
		# invisible: no cambia de estado —sigues en `Jump`— y la velocidad no lo
		# cuenta, porque `move_and_slide` la pone a cero sin avisar. Lo unico que
		# lo dice es la ALTURA que llegaste a alcanzar.
		#
		# Es el punto #16 del Tier B del documento de movimiento. Antes de
		# implementarlo hay que saber si el problema existe: una capsula resbala
		# por las esquinas mucho mejor que una caja, y puede que Godot ya lo este
		# resolviendo solo.
		_medida("salto limpio bajo el alero — control", 1.2,
			func() -> void: _saltar_bajo_el_alero(0.0),
			func() -> String:
				return "sube %.2f m (el salto entero son %.2f)" % [
					_y_pico - 0.05, _p.tuning.altura_salto_max]),

		_medida("el mismo salto rozando la esquina 12 cm", 1.2,
			func() -> void: _saltar_bajo_el_alero(0.12),
			func() -> String:
				return "sube %.2f m" % [_y_pico - 0.05]),

		_medida("y rozandola 25 cm", 1.2,
			func() -> void: _saltar_bajo_el_alero(0.25),
			func() -> String:
				return "sube %.2f m" % [_y_pico - 0.05]),

		# Y HASTA DONDE AGUANTA. El radio de la capsula es 0.4: a 0.35 solo le
		# quedan 5 cm libres y a 0.55 ya esta mas dentro que fuera. Sin estas dos
		# filas, "la capsula se escurre" seria una afirmacion sin limite conocido.
		_medida("rozandola 35 cm (radio = 40)", 1.2,
			func() -> void: _saltar_bajo_el_alero(0.35),
			func() -> String:
				return "sube %.2f m" % [_y_pico - 0.05]),

		_medida("y metiendose 55 cm, mas dentro que fuera", 1.2,
			func() -> void: _saltar_bajo_el_alero(0.55),
			func() -> String:
				return "sube %.2f m" % [_y_pico - 0.05]),

		# --- EL BUNNYHOP (#13 del Tier B) -------------------------------------
		# «Ventana de conservacion al aterrizar»: caer lanzado y volver a saltar no
		# deberia costarte la linea. La pregunta no es "cuanto conserva el
		# aterrizaje" sino **si aterrizar cuesta algo comparado con no hacerlo**, y
		# por eso la fila de control es EL AIRE y no el suelo.
		#
		# Se mide la rapidez al final de una ventana fija, no en el contacto: un
		# bunnyhop toca el suelo UN frame o ninguno, y un latch de contacto se lo
		# pierde. La primera version imprimia -1.0 —"no llego a tocar"— y la
		# conclusion habria sido que no aterriza, cuando lo que pasaba es que no se
		# puede mirar ahi.
		_medida("aterrizar a 30 y rebotar (bunnyhop)", 0.7,
			func() -> void:
				_soltar_todo()
				_colocar(Vector3(-10.0, 0.45, -20.0))
				_mirar_a(-90.0)
				_p.velocity = Vector3.RIGHT * 30.0
				_p.fsm.cambiar(&"Fall")
				# Sin salto aereo: con el, la pulsacion se la come el doble salto y
				# el jugador no llega a pisar. Asi se queda en el buffer —el grupo
				# ni la consulta— y sale al tocar, que es el gesto que se mide.
				_p.saltos_aereos = 0
				_pulsar(&"jump"),
			func() -> String:
				_soltar(&"jump")
				return "%.1f m/s al final" % _p.motor.rapidez_plana()),

		_medida("lo mismo SIN rebotar, corriendo", 0.7,
			func() -> void:
				_soltar_todo()
				_colocar(Vector3(-10.0, 0.45, -20.0))
				_mirar_a(-90.0)
				_p.velocity = Vector3.RIGHT * 30.0
				_p.fsm.cambiar(&"Fall")
				# SIGUE PIDIENDO LA DIRECCION. Sin el stick esto no seria «aterrizar
				# corriendo», seria «aterrizar y soltarlo todo», y el freno de
				# soltar (26 m/s²) es otro numero: la comparacion culparia al
				# aterrizaje de lo que hace dejar de pedir.
				_pulsar(&"move_forward"),
			func() -> String:
				_soltar(&"move_forward")
				return "%.1f m/s al final" % _p.motor.rapidez_plana()),

		# EL AIRE COMO CONTROL. Sin esta fila no se sabe cuanto de lo perdido lo
		# quito el SUELO y cuanto el tope de velocidad, que actua igual volando.
		_medida("y sin tocar el suelo — control", 0.7,
			func() -> void:
				_soltar_todo()
				_colocar(Vector3(-10.0, 12.0, -20.0))
				_mirar_a(-90.0)
				_p.velocity = Vector3.RIGHT * 30.0
				_p.fsm.cambiar(&"Fall"),
			func() -> String:
				return "%.1f m/s al final%s" % [
					_p.motor.rapidez_plana(),
					"  [OJO: aterrizo]" if _p.is_on_floor() else ""]),

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

	_y_pico = maxf(_y_pico, _p.global_position.y)

	var pisa := _p.is_on_floor()
	if pisa and not _tocaba and _v_al_tocar < 0.0:
		_v_al_tocar = _p.motor.rapidez_plana()
		_fr_tocar = 0
	_tocaba = pisa
	if _fr_tocar >= 0:
		_fr_tocar += 1
		if _fr_tocar == 8:
			_v_tras_tocar = _p.motor.rapidez_plana()

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
