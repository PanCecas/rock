extends Node
## BANCO DE LA CADENA: ¿sobrevive la velocidad al tocar el mundo?
##
##   godot --headless --path . tools/MedirCadena.tscn
##
## El moveset del parche 4.00 se sostiene sobre una sola promesa —«encadenar
## limpio acumula velocidad»— y esa promesa la rompe cualquier estado que
## escriba `velocity = Vector3.ZERO` al recibirte. Este banco va a buscarlos por
## el camino real: llegar lanzado a un muro, a un canto, a una rampa.
##
## **Mide DOS cosas por transición, y las dos hacen falta:**
##
##   · a qué estado te manda el contacto —porque un estado que no querías es un
##     problema aunque conserve la velocidad—, y
##   · qué queda de la rapidez que traías.
##
## Se imprime en una tabla para poder pegarla al lado de la de la pasada
## anterior, igual que `MedirPatada`.

var _main: Node
var _p: PlayerController

var _paso: int = 0
var _t: float = 0.0
var _guion: Array = []
var _lineas: PackedStringArray = []

# --- Latches del contacto.
var _v_lanzado: float = 0.0
var _v_min_tras: float = 9999.0
var _v_final: float = 0.0
var _estados: PackedStringArray = []
var _estado_prev: StringName = &""
var _cargas_min: int = 99
var _cargas_max: int = -1
var _pared_frames: int = 0
## Rapidez EN EL CONTACTO y unos frames DESPUES. Leerla al final de la ventana no
## vale: el jugador ya ha caido al suelo y lo que se mide es la friccion del
## suelo, no lo que hizo el muro.
var _v_al_tocar: float = -1.0
var _v_tras_tocar: float = -1.0
var _frames_desde_toque: int = -1
var _recargas: int = 0
var _cargas_prev: int = -1
var _v_plano_prev: float = 0.0
## Rapidez en el PRIMER frame dentro de `_espiar`. Es donde se ve si el estado te
## recibe conservando o borrando.
var _espiar: StringName = &""
var _v_estado: float = -1.0
## Curva de la rapidez frame a frame, para ver si el tope corta o decae.
var _curva: PackedFloat32Array = PackedFloat32Array()
var _midiendo_curva: bool = false


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
		# LA PARED ESCALABLE DEL GYM, en (24, 6, 20) con la cara en z = 19.5.
		# Se llega lanzado y EMPUJANDO, que es el caso real: encadenas hacia un muro
		# y sigues pidiendo esa dirección porque quieres seguir por ahí.
		_medida("llegar a un muro a 30 m/s, empujando", 1.4,
			func() -> void:
				_lanzar(Vector3(24.0, 3.0, 27.0), Vector3.FORWARD * 30.0, true),
			func() -> String:
				return "v %.1f -> %.1f   estados: %s" % [
					_v_lanzado, _v_final, _traza()]),

		# EL MISMO MURO Y EL MISMO GESTO, pero SIN LA HABILIDAD DE TREPAR. Es la
		# comparacion que decide si el candado sirve: con ella te agarra y te pone a
		# cero, sin ella la pared vuelve a ser un sitio del que rebotar.
		_medida("el mismo muro SIN la habilidad", 1.4,
			func() -> void:
				_lanzar(Vector3(24.0, 3.0, 27.0), Vector3.FORWARD * 30.0, true)
				_p.puede_escalar = false,
			func() -> String:
				return "v %.1f -> %.1f   estados: %s" % [
					_v_lanzado, _v_final, _traza()]),

		# EL MISMO MURO, sin pedir la dirección. Es la fila de control: separa lo
		# que hace el CONTACTO de lo que hace la ADHERENCIA AUTOMÁTICA, que solo se
		# arma si el stick insiste.
		_medida("el mismo muro, SIN empujar — control", 1.4,
			func() -> void:
				_lanzar(Vector3(24.0, 3.0, 27.0), Vector3.FORWARD * 30.0, false),
			func() -> String:
				return "v %.1f -> %.1f   estados: %s" % [
					_v_lanzado, _v_final, _traza()]),

		# ESCALANDO: ¿el flanco de recarga se dispara solo? Si `is_on_wall()`
		# parpadea mientras se trepa, las cargas se rellenan sin tocar nada nuevo y
		# el presupuesto aéreo deja de ser un presupuesto.
		_medida("escalando: ¿se rellenan las cargas solas?", 2.0,
			func() -> void:
				_lanzar(Vector3(24.0, 3.0, 27.0), Vector3.FORWARD * 30.0, true)
				_p.patada_cargas = 0
				_p.cuerda_disponible = false
				_recargas = 0
				_cargas_prev = 0,
			func() -> String:
				return "%d recargas en 2 s   pared %d/%d frames   cargas %d..%d" % [
					_recargas, _pared_frames, int(2.0 * 60.0),
					_cargas_min if _cargas_min < 99 else 0, _cargas_max]),

		# ROZANDO, que es el caso que de verdad importa. De frente perder toda la
		# velocidad es FISICAMENTE CORRECTO —te has estrellado— y medir solo eso no
		# dice nada. Lo que tiene que sobrevivir es la componente que va A LO LARGO
		# del muro.
		#
		# En el corredor de wall-run del Gym: dos muros de 24 m de largo a x = ±1.3,
		# sin suelo cerca. Y se lee EN EL CONTACTO, no al final de la ventana: al
		# final el jugador ya ha aterrizado y lo que se mediria es la friccion del
		# suelo echandole la culpa al muro.
		_medida("ROZAR un muro a 16 grados, a 30 m/s", 0.7,
			func() -> void:
				var dir := Vector3(0.28, 0.0, -0.96).normalized()
				_lanzar(Vector3(0.0, 6.0, -24.0), dir * 30.0, false),
			func() -> String: return _linea_roce()),

		_medida("y el mismo roce a 35 grados", 0.7,
			func() -> void:
				var dir := Vector3(0.57, 0.0, -0.82).normalized()
				_lanzar(Vector3(-0.4, 6.0, -24.0), dir * 30.0, false),
			func() -> String: return _linea_roce()),

		# --- LOS ESTADOS QUE TE RECIBEN ---------------------------------------
		# La regla del genero, escrita en el propio documento: "nunca reinicies la
		# velocidad horizontal al entrar a un estado; convierte, escala o proyecta".
		# Aqui se va a buscar quien la incumple, llegando lanzado a cada uno.
		_medida("DASHEAR viniendo a 36 m/s", 0.5,
			func() -> void:
				_lanzar(Vector3(0.0, 10.0, 6.0), Vector3.RIGHT * 36.0, false)
				_v_estado = -1.0
				_espiar = &"Dash"
				_p.fsm.cambiar(&"Dash"),
			func() -> String:
				return "entra %.1f -> primer frame dentro %.1f" % [_v_lanzado, _v_estado]),

		_medida("PARRY viniendo a 15 m/s", 0.5,
			func() -> void:
				_lanzar(Vector3(0.0, 0.3, 6.0), Vector3.RIGHT * 15.0, false)
				_v_estado = -1.0
				_espiar = &"Parry"
				_p.fsm.cambiar(&"Parry"),
			func() -> String:
				return "entra %.1f -> primer frame dentro %.1f" % [_v_lanzado, _v_estado]),

		# EL TOPE. Con un clamp duro, pasar de 34 a 22 ocurre en UN frame y el
		# momentum ganado no se siente ganado. Con un soft cap decae, y lo que se mide
		# es cuanto tarda.
		_medida("de 34 m/s al tope: ¿corte o caida?", 1.2,
			func() -> void:
				_lanzar(Vector3(0.0, 30.0, 6.0), Vector3.RIGHT * 34.0, false)
				_curva = PackedFloat32Array()
				_midiendo_curva = true,
			func() -> String:
				_midiendo_curva = false
				var t := PackedStringArray()
				for i in [0, 3, 6, 12, 24, 48]:
					if i < _curva.size():
						t.append("%dfr %.1f" % [i, _curva[i]])
				return " · ".join(t)),

		# EL CANTO. Otro receptor de momentum, y el que más se cruza en un arco:
		# la repisa del Gym, a media altura de la pared.
		_medida("llegar a un canto a 25 m/s", 1.4,
			func() -> void:
				_lanzar(Vector3(24.0, 6.6, 27.0), Vector3.FORWARD * 25.0, true),
			func() -> String:
				return "v %.1f -> %.1f   estados: %s" % [
					_v_lanzado, _v_final, _traza()]),
	]


## Lanza al jugador desde `pos` con `vel`, opcionalmente manteniendo la dirección
## de avance pulsada. El permiso de momentum se abre a mano: sin él el clamp
## global (22) recorta los 30 antes de que nada del mundo los toque, y la medida
## culparía al muro de lo que hace el clamp.
func _lanzar(pos: Vector3, vel: Vector3, empujando: bool) -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
	_p.global_position = pos
	_p.velocity = vel
	_p.stamina.llenar()
	_p.recargar_moveset()
	# La habilidad vuelve a estar puesta en cada medida: el Gym la da, y una medida
	# no puede heredar el estado de la anterior.
	_p.puede_escalar = true
	_p.call("orientar_a", vel.normalized())
	_p.fsm.cambiar(&"Fall")
	_p.reset_physics_interpolation()
	if empujando:
		Input.action_press(&"move_forward")
	_v_lanzado = _p.superficie.plano(vel).length()
	_v_min_tras = 9999.0
	_v_final = 0.0
	_estados = PackedStringArray([str(_p.fsm.nombre_actual())])
	_pared_frames = 0
	_espiar = &""
	_midiendo_curva = false
	_v_al_tocar = -1.0
	_v_tras_tocar = -1.0
	_frames_desde_toque = -1
	_cargas_min = 99
	_cargas_max = -1


## Una linea de roce, leida en el contacto. Si no llego a tocar el muro se dice,
## en vez de imprimir un porcentaje de una cosa que no paso.
func _linea_roce() -> String:
	if _v_al_tocar < 0.0:
		return "NO llego a tocar el muro   estados: %s" % _traza()
	var tras: float = _v_tras_tocar if _v_tras_tocar >= 0.0 else _v_final
	return "al tocar %.1f -> 10 frames despues %.1f   (%.0f%% conservado)   %s" % [
		_v_al_tocar, tras, 100.0 * tras / maxf(_v_al_tocar, 0.001), _traza()]


func _traza() -> String:
	return " > ".join(_estados)


func _physics_process(delta: float) -> void:
	if _p == null or _guion.is_empty():
		return
	if _paso >= _guion.size():
		_informe()
		return
	_t += delta

	var estado := _p.fsm.nombre_actual()
	if estado != _estado_prev:
		if _estados.size() < 8:
			_estados.append(str(estado))
		_estado_prev = estado
	var plano := _p.superficie.plano(_p.velocity).length()
	_v_final = plano
	_v_min_tras = minf(_v_min_tras, plano)
	if _p.is_on_wall():
		_pared_frames += 1
		if _v_al_tocar < 0.0:
			_v_al_tocar = _v_plano_prev
			_frames_desde_toque = 0
	if _frames_desde_toque >= 0:
		_frames_desde_toque += 1
		if _frames_desde_toque == 10:
			_v_tras_tocar = plano
	_v_plano_prev = plano
	if _espiar != &"" and estado == _espiar and _v_estado < 0.0:
		_v_estado = plano
	if _midiendo_curva and _curva.size() < 64:
		_curva.append(plano)
	_cargas_min = mini(_cargas_min, _p.patada_cargas)
	_cargas_max = maxi(_cargas_max, _p.patada_cargas)
	if _p.patada_cargas > _cargas_prev:
		_recargas += 1
	_cargas_prev = _p.patada_cargas

	var actual: Dictionary = _guion[_paso]
	if is_zero_approx(_t - delta):
		(actual["hacer"] as Callable).call()
	if _t >= float(actual["dur"]):
		_lineas.append("  %-38s %s" % [
			actual["nombre"], (actual["leer"] as Callable).call()])
		_paso += 1
		_t = 0.0


func _informe() -> void:
	set_physics_process(false)
	print("\n=== LA CADENA CONTRA EL MUNDO ===\n")
	for l in _lineas:
		print(l)
	print("\n--- QUIEN PUEDE COMERSE LA VELOCIDAD ---")
	print("  velocidad_maxima      %.1f m/s   (el clamp global)" % _p.tuning.velocidad_maxima)
	print("  escalada_auto_tiempo  %.2f s     (lo que tarda la adherencia en armarse)" % _p.tuning.escalada_auto_tiempo)
	get_tree().quit(0)


func _medida(nombre: String, dur: float, hacer: Callable, leer: Callable) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "leer": leer}
