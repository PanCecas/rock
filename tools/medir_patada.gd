extends Node
## BANCO DE LA PATADA. Mide lo que se siente, no lo que se cree.
##
##   godot --headless --path . tools/MedirPatada.tscn
##
## Cinco medidas, y cada una contesta a una pregunta de FEEL que no se puede
## contestar leyendo el código:
##
##   1. ¿Qué le hace a la velocidad que YA llevabas? Es la que importa: si la
##      patada escribe un número fijo, encadenar deja de acumular y el motor pasa
##      a decidir tu velocidad en vez de tú.
##   2. ¿Y a la vertical? Un gesto aéreo que te deja cayendo igual que antes no es
##      una herramienta de aire.
##   3. ¿Se puede salir de ella? Un cuarto de segundo sin poder actuar son quince
##      frames de no ser el dueño del personaje.
##   4. ¿Qué pasa al conectar? Un enemigo solo es plataforma si te devuelve arriba.
##   5. ¿Cuánto terreno cubre?
##
## Se imprime como tabla para poder pegarla al lado de la de la pasada anterior.

var _main: Node
var _p: PlayerController
var _victima: Enemigo

var _paso: int = 0
var _t: float = 0.0
var _guion: Array = []
var _lineas: PackedStringArray = []
var _atacar: int = 0
var _saltar: int = 0

# --- Latches del gesto.
var _en_patada: bool = false
var _v_entrada: float = 0.0
var _v_durante_min: float = 9999.0
var _v_durante_max: float = 0.0
var _v_salida: float = 0.0
var _vy_entrada: float = 0.0
var _vy_durante: float = 0.0
var _vy_salida: float = 0.0
var _y_entrada: float = 0.0
var _y_caida: float = 0.0
var _origen: Vector3 = Vector3.ZERO
var _recorrido: float = 0.0
var _frames: int = 0
var _estado_prev: StringName = &""
var _estado_tras_salto: StringName = &""
var _vy_tras_impacto: float = -99.0
var _cargas_tras_impacto: int = -1

# --- LA CADENA. Con mas de una carga, lo que se mide deja de ser un gesto suelto
#     y pasa a ser cuanto aire compras encadenando.
## Encadena patadas sola: pulsa en cuanto puede y suelta para que la siguiente
## cuente como pulsacion NUEVA. Es el jugador perfecto, que es el techo de lo que
## la mecanica permite.
var _encadenar: bool = false
var _ciclo: int = 0
var _patadas: int = 0
var _aire_t: float = 0.0
var _aire_x: float = 0.0
var _aire_x0: Vector3 = Vector3.ZERO
var _midiendo_aire: bool = false


func _ready() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	await get_tree().physics_frame
	for n in get_tree().get_nodes_in_group(&"enemigos"):
		var e := n as Enemigo
		if e != null and is_instance_valid(e):
			e.vista = 0.0
	_construir()


func _construir() -> void:
	_guion = [
		# 1) LO QUE LE HACE A LA VELOCIDAD QUE YA LLEVAS.
		_medida("entra PARADO", 0.9,
			func() -> void:
				_colocar(Vector3(0.0, 10.0, 20.0), 0.0)
				_atacar = 4,
			func() -> String:
				return "v_ent %5.1f -> durante %5.1f..%5.1f -> sale %5.1f" % [
					_v_entrada, _v_durante_min, _v_durante_max, _v_salida]),

		_medida("entra LANZADO a 30 m/s", 0.9,
			func() -> void:
				_colocar(Vector3(0.0, 10.0, 20.0), 30.0)
				_atacar = 4,
			func() -> String:
				var d := _v_salida - _v_entrada
				return "v_ent %5.1f -> durante %5.1f..%5.1f -> sale %5.1f   (%+.1f)" % [
					_v_entrada, _v_durante_min, _v_durante_max, _v_salida, d]),

		# 2) LA VERTICAL.
		_medida("entra CAYENDO a -18 m/s", 0.9,
			func() -> void:
				_colocar(Vector3(0.0, 22.0, 20.0), 6.0)
				_p.velocity.y = -18.0
				_atacar = 4,
			func() -> String:
				return "vy_ent %6.1f -> durante %6.1f -> sale %6.1f   caida en el gesto %.2f m" % [
					_vy_entrada, _vy_durante, _vy_salida, _y_caida]),

		# 3) ¿SE PUEDE SALIR?
		_medida("saltar a mitad del gesto", 1.0,
			func() -> void:
				_colocar(Vector3(0.0, 14.0, 20.0), 6.0)
				_atacar = 4
				_saltar = 14,
			func() -> String:
				return "estado 8 frames despues de pulsar salto: %s" % _estado_tras_salto),

		# 4) CONECTAR.
		_medida("conectar con un enemigo", 1.2,
			func() -> void:
				_plantar_victima(Vector3(7.0, 0.3, 20.0))
				_colocar(Vector3(0.0, 0.9, 20.0), 0.0)
				_p.call("orientar_a", Vector3.RIGHT)
				_vy_tras_impacto = -99.0
				_cargas_tras_impacto = -1
				_atacar = 4,
			func() -> String:
				return "vy justo tras el impacto %6.1f   cargas %s" % [
					_vy_tras_impacto,
					"?" if _cargas_tras_impacto < 0 else str(_cargas_tras_impacto)]),

		# 5) LA CADENA, y su FILA DE CONTROL. Sin la caida a secas al lado, el
		#    numero de la cadena no dice nada: hay que saber cuanto aire tenias ya.
		_medida("caida libre — fila de control", 2.6,
			func() -> void:
				_colocar(Vector3(-14.0, 18.0, 6.0), 9.0)
				_abrir_aire(),
			func() -> String:
				return "%.2f s en el aire, %.1f m de avance, 0 patadas" % [
					_aire_t, _aire_x]),

		_medida("la misma caida, encadenando", 2.6,
			func() -> void:
				_colocar(Vector3(-14.0, 18.0, 6.0), 9.0)
				_abrir_aire()
				_encadenar = true,
			func() -> String:
				# Cruza el Gym, asi que el terreno le va devolviendo cargas por el
				# camino —tocar pared recarga— y salen mas de las configuradas. Eso
				# es la mecanica funcionando, no un fallo: el tope limpio lo mide la
				# linea de abajo, en caida vertical y sin nada que rozar.
				return "%.2f s en el aire, %.1f m de avance, %d patadas (el terreno da mas)" % [
					_aire_t, _aire_x, _patadas]),

		_medida("el tope, en caida limpia", 1.4,
			func() -> void:
				_colocar(Vector3(0.0, 16.0, 6.0), 0.0)
				_patadas = 0
				_encadenar = true,
			func() -> String:
				return "%d patadas con %d cargas configuradas" % [
					_patadas, _p.tuning.patada_cargas]),

		# 6) TERRENO.
		_medida("terreno cubierto", 0.9,
			func() -> void:
				_colocar(Vector3(0.0, 14.0, 20.0), 0.0)
				_atacar = 4,
			func() -> String:
				return "%.2f m en %d frames (%.2f s)" % [
					_recorrido, _frames, _frames / 60.0]),
	]


func _plantar_victima(pos: Vector3) -> void:
	if _victima != null and is_instance_valid(_victima):
		_victima.queue_free()
	_victima = load("res://src/enemies/Guardian.tscn").instantiate() as Enemigo
	_main.add_child(_victima)
	_victima.global_position = pos
	_victima.vista = 0.0
	_victima.ataque = null


## Arranca la cuenta del tiempo de vuelo. Se cierra sola al tocar suelo.
func _abrir_aire() -> void:
	_patadas = 0
	_aire_t = 0.0
	_aire_x = 0.0
	_aire_x0 = _p.global_position
	_midiendo_aire = true


## Coloca al jugador en el aire con una velocidad horizontal dada. El permiso de
## momentum se abre a mano: sin el, el clamp global (22) se comeria los 30 antes
## de que la patada pudiera tocarlos y la medida no diria nada de la patada.
func _colocar(pos: Vector3, rapidez: float) -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
	_atacar = 0
	_saltar = 0
	_p.global_position = pos
	_p.velocity = Vector3.RIGHT * rapidez
	_p.stamina.llenar()
	_p.momentum_libre = 6.0
	_p.momentum_techo = 40.0
	_p.cuerda_disponible = true
	_p.recargar_moveset()
	_p.fsm.cambiar(&"Fall")
	_encadenar = false
	_ciclo = 0
	_midiendo_aire = false
	_en_patada = false
	_v_entrada = 0.0
	_v_durante_min = 9999.0
	_v_durante_max = 0.0
	_v_salida = 0.0
	_vy_entrada = 0.0
	_vy_durante = 0.0
	_vy_salida = 0.0
	_y_entrada = pos.y
	_y_caida = 0.0
	_origen = pos
	_recorrido = 0.0
	_frames = 0
	_estado_tras_salto = &"—"


func _physics_process(delta: float) -> void:
	if _p == null or _guion.is_empty():
		return
	if _paso >= _guion.size():
		_informe()
		return
	_t += delta

	if _encadenar:
		# Dos frames pulsado y dos sueltos: sin el hueco, `is_action_just_pressed`
		# no vuelve a dispararse y la segunda patada no llegaria a pedirse nunca.
		_ciclo = (_ciclo + 1) % 4
		if _ciclo < 2 and _p.patada_cargas > 0 and _p.fsm.nombre_actual() != &"Kick":
			Input.action_press(&"attack_light")
		else:
			Input.action_release(&"attack_light")
	elif _atacar > 0:
		Input.action_press(&"attack_light")
		_atacar -= 1
		if _atacar == 0:
			Input.action_release(&"attack_light")
	if _saltar > 0:
		_saltar -= 1
		if _saltar == 8:
			Input.action_press(&"jump")
		elif _saltar == 5:
			Input.action_release(&"jump")
		elif _saltar == 0:
			_estado_tras_salto = _p.fsm.nombre_actual()

	var estado := _p.fsm.nombre_actual()
	var plano := _p.superficie.plano(_p.velocity).length()
	var vy := _p.superficie.vertical(_p.velocity)

	if _midiendo_aire:
		if _p.is_on_floor():
			_midiendo_aire = false
		else:
			_aire_t += delta
			_aire_x = _p.superficie.plano(_p.global_position - _aire_x0).length()

	if estado == &"Kick":
		if not _en_patada:
			_patadas += 1
			_en_patada = true
			_v_entrada = _vel_anterior
			_vy_entrada = _vy_anterior
			_y_entrada = _p.global_position.y
			_origen = _p.global_position
			_frames = 0
		_frames += 1
		_v_durante_min = minf(_v_durante_min, plano)
		_v_durante_max = maxf(_v_durante_max, plano)
		_vy_durante = vy
		_y_caida = maxf(_y_caida, _y_entrada - _p.global_position.y)
		_recorrido = maxf(_recorrido, _p.global_position.distance_to(_origen))
	else:
		_en_patada = false
	if estado != &"Kick" and _estado_prev == &"Kick":
		_v_salida = plano
		_vy_salida = vy
		if _vy_tras_impacto < -98.0 and _cargas_tras_impacto < 0:
			_vy_tras_impacto = vy
			_cargas_tras_impacto = _leer_cargas()

	_vel_anterior = plano
	_vy_anterior = vy
	_estado_prev = estado

	var actual: Dictionary = _guion[_paso]
	if is_zero_approx(_t - delta):
		(actual["hacer"] as Callable).call()
	if _t >= float(actual["dur"]):
		_lineas.append("  %-28s %s" % [
			actual["nombre"], (actual["leer"] as Callable).call()])
		_paso += 1
		_t = 0.0


var _vel_anterior: float = 0.0
var _vy_anterior: float = 0.0


## Las cargas son un `int` desde el rediseno, pero esto tiene que seguir
## imprimiendo algo si algun dia vuelven a ser un `bool`.
func _leer_cargas() -> int:
	var v: Variant = _p.get("patada_cargas")
	if v is int:
		return int(v)
	var b: Variant = _p.get("patada_disponible")
	return 1 if b is bool and bool(b) else 0


func _informe() -> void:
	set_physics_process(false)
	var t := _p.tuning
	print("\n=== LA PATADA, MEDIDA ===\n")
	for l in _lineas:
		print(l)
	print("\n--- LOS NUMEROS QUE LA GOBIERNAN ---")
	print("  patada_duracion   %.2f s     patada_velocidad  %.1f m/s" % [
		t.patada_duracion, t.patada_velocidad])
	print("  patada_giro       %.0f grad/s" % t.patada_giro_grados_seg)
	print("  patada_cargas     %d          patada_rebote     %.1f m/s" % [
		t.patada_cargas, t.patada_rebote])
	print("  patada_salida_vertical %.1f m/s" % t.patada_salida_vertical)
	print("  velocidad_maxima  %.1f m/s   (el clamp global)" % t.velocidad_maxima)
	get_tree().quit(0)


func _medida(nombre: String, dur: float, hacer: Callable, leer: Callable) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "leer": leer}
