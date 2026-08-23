extends Node
## Test funcional de la Fase 1: conduce al jugador con input simulado y comprueba
## que la FSM llega a cada estado.
##
##   godot --headless --path . tools/TestFase1.tscn
##
## Es una ESCENA y no un `--script` a propósito: en modo script Godot no registra
## los autoloads y ningún archivo que use EventBus o GameState llega a compilar.
##
## No sustituye a jugarlo (el feel no se testea), pero atrapa las regresiones de
## "el dash ya no entra" antes de que cuesten media tarde.

var _main: Node
var _p: PlayerController
var _paso: int = 0
var _t: float = 0.0
var _visitados: Dictionary = {}
var _fallos: PackedStringArray = []
var _guion: Array = []
var _reloj_global: float = 0.0


func _ready() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	EventBus.player_state_changed.connect(
		func(_a: StringName, n: StringName) -> void: _visitados[n] = true)
	_construir_guion()


func _construir_guion() -> void:
	_guion = [
		_paso_("asentarse", 1.0, func() -> void: _teleport(Vector3(0, 1.0, 4)), &"Idle"),
		_paso_("andar", 0.5, func() -> void: _pulsar(&"move_forward"), &"Move"),
		_paso_("saltar", 0.25, func() -> void: _pulsar(&"jump"), &"Jump"),
		_paso_("caer", 0.7, func() -> void: _soltar(&"jump"), &"Fall"),
		_paso_("dash aéreo", 0.12, func() -> void: _pulsar(&"dash"), &"Dash"),
		_paso_("planear", 0.9, func() -> void:
			_soltar_todo()
			# Alto y cayendo: el planeo tiene un retardo de despliegue a propósito,
			# para que un salto normal no abra la capa por accidente.
			_teleport(Vector3(0.0, 25.0, 4.0))
			_p.fsm.cambiar(&"Fall")
			_pulsar(&"glide"), &"Glide"),
		_paso_("agarrar canto", 1.2, func() -> void:
			_soltar_todo()
			# Justo delante de la repisa de 2 m del Gym (x=20, cara en z=-12.5).
			_teleport(Vector3(20.0, 1.3, -13.1))
			_p.orientar_a(Vector3(0, 0, 1))
			_p.fsm.cambiar(&"Fall"), &"LedgeHang"),
		# Subir es empujar hacia arriba; saltar es SALTAR desde el canto.
		_paso_("subir el canto", 0.8, func() -> void: _pulsar(&"move_forward"), &"LedgeClimb"),
		_paso_("recolgarse", 1.0, func() -> void:
			_soltar_todo()
			_teleport(Vector3(20.0, 1.3, -13.1))
			_p.orientar_a(Vector3(0, 0, 1))
			_p.fsm.cambiar(&"Fall"), &"LedgeHang"),
		_chequeo_("saltar del canto", 0.5,
			func() -> void: _pulsar(&"jump"),
			func() -> bool: return _p.fsm.actual.categoria == &"Airborne" and _p.saltos_aereos > 0,
			"saltar colgado debe despegar y dejar el doble salto disponible"),
		_paso_("escalar pared", 1.2, func() -> void:
			_soltar_todo()
			# Pared CLIMBABLE del Gym (x=24, cara en z=19.5).
			_teleport(Vector3(24.0, 2.5, 19.0))
			_p.orientar_a(Vector3(0, 0, 1))
			_p.fsm.cambiar(&"Fall")
			_pulsar(&"grab"), &"Climb"),
		# Pasillo de wall-run del Gym: muros en x=±1.8 con las caras interiores en
		# x=±1.3. Correr a lo largo pone la pared al costado; ir contra ella la
		# pone al frente. Esa distinción es la que separa wall-run de wall-slide.
		_paso_("wall-run", 0.6, func() -> void:
			_soltar_todo()
			_teleport(Vector3(-0.8, 6.0, -34.0))
			_p.fsm.cambiar(&"Fall")
			_p.velocity = Vector3(0.0, 0.0, -8.0)
			_pulsar(&"move_forward"), &"WallRun"),
		_paso_("wall-slide", 0.8, func() -> void:
			_soltar_todo()
			_teleport(Vector3(-0.8, 6.0, -34.0))
			_p.fsm.cambiar(&"Fall")
			_p.velocity = Vector3(-2.0, -1.0, 0.0)
			_pulsar(&"move_forward"), &"WallSlide"),
		# El slide exige llevar velocidad: hay que correr de verdad antes.
		_paso_("coger carrerilla", 0.9, func() -> void:
			_soltar_todo()
			_teleport(Vector3(0.0, 0.05, 4.0))
			_p.fsm.cambiar(&"Idle")
			_pulsar(&"move_forward"), &"Move"),
		_paso_("deslizarse", 0.8, func() -> void: _pulsar(&"crouch"), &"Slide"),

		# --- Pase de feel: dash NieR, planeo por mantener, wall-jump Mario ------

		# Una pulsacion NUEVA salta; no puede abrir la capa a la vez.
		_chequeo_("pulsar = doble salto", 0.3,
			func() -> void:
				_soltar_todo()
				_teleport(Vector3(0.0, 30.0, 4.0))
				_p.fsm.cambiar(&"Fall")
				_p.tiempo_en_aire = 1.0
				_pulsar_espacio(),
			func() -> bool: return _p.saltos_aereos == 0 and _p.fsm.nombre_actual() != &"Glide",
			"la pulsacion debe gastarse en el salto sin abrir la capa"),
		# Y seguir manteniendo esa MISMA tecla planea a partir del apice.
		_chequeo_("mantener = planear", 1.4,
			func() -> void: pass,
			func() -> bool: return _p.fsm.nombre_actual() == &"Glide",
			"mantener el boton de salto en el aire debe desplegar la capa"),
		_chequeo_("soltar = dejar de planear", 0.3,
			func() -> void: _soltar_todo(),
			func() -> bool: return _p.fsm.nombre_actual() != &"Glide",
			"soltar el boton debe cerrar la capa"),

		# TAP: dash corto y a correr normal.
		_chequeo_("dash tap", 0.5,
			func() -> void:
				_soltar_todo()
				_teleport(Vector3(0.0, 0.05, 4.0))
				_p.fsm.cambiar(&"Move")
				_pulsar(&"move_forward")
				_pulsar(&"dash")
				_soltar(&"dash"),
			func() -> bool: return _p.fsm.nombre_actual() == &"Move",
			"un toque debe devolver a carrera normal"),
		# HOLD: el dash desemboca en sprint continuo sin soltar el boton.
		_chequeo_("dash hold = sprint", 0.6,
			func() -> void:
				_soltar_todo()
				_teleport(Vector3(0.0, 0.05, 4.0))
				_p.fsm.cambiar(&"Move")
				_pulsar(&"move_forward")
				_pulsar(&"dash"),
			func() -> bool: return _p.motor.rapidez_plana() >= _p.tuning.velocidad_sprint - 0.5,
			"mantener el dash debe encadenar a sprint continuo"),

		# Wall-jump: sube de verdad y conserva momentum.
		_chequeo_("wall-jump Mario", 0.35,
			func() -> void:
				_soltar_todo()
				_teleport(Vector3(-0.8, 6.0, -34.0))
				_p.fsm.cambiar(&"Fall")
				_p.velocity = Vector3(-4.0, -2.0, -5.0)
				_pulsar(&"move_forward"),
			func() -> bool: return _p.fsm.nombre_actual() == &"WallSlide",
			"chocar contra la pared debe enganchar sin tener que empujar hacia ella"),
		# Ventana corta a proposito: a 0.25 s la gravedad ya se ha comido 5 m/s y
		# la medicion no diria nada del impulso inicial.
		_chequeo_("rebote con altura", 0.1,
			func() -> void: _pulsar_espacio(),
			func() -> bool: return (
				_p.motor.get_vertical() > _p.tuning.walljump_vertical * 0.7
				and _p.motor.rapidez_plana() > 4.0),
			"el rebote debe subir de verdad y conservar velocidad horizontal"),
	]


func _physics_process(delta: float) -> void:
	_reloj_global += delta
	if _reloj_global > 60.0:
		_fallos.append("el test se colgó: 60 s sin terminar el guion")
		_informe()
		return

	if _paso >= _guion.size():
		_informe()
		return

	var actual: Dictionary = _guion[_paso]
	if is_zero_approx(_t):
		(actual["hacer"] as Callable).call()
	_t += delta

	if _t >= float(actual["dur"]):
		var esperado: StringName = actual["espera"]
		if esperado != &"" and not _visitados.has(esperado):
			_fallos.append("%-24s no se alcanzó %s (estado final: %s)" % [
				actual["nombre"], esperado, _p.fsm.nombre_actual()])
		if actual.has("chequeo") and not (actual["chequeo"] as Callable).call():
			_fallos.append("%-24s %s  (estado: %s, vel %.1f, saltos %d)" % [
				actual["nombre"], actual["porque"], _p.fsm.nombre_actual(),
				_p.motor.rapidez_plana(), _p.saltos_aereos])
		_paso += 1
		_t = 0.0


func _informe() -> void:
	set_physics_process(false)
	var esperados: Array[StringName] = [&"Idle", &"Move", &"Jump", &"Fall", &"Dash", &"Glide",
		&"LedgeHang", &"LedgeClimb", &"Climb", &"WallRun", &"WallSlide", &"Slide"]
	var ok := 0
	print("--- ESTADOS VISITADOS ---")
	for e in esperados:
		var visitado: bool = _visitados.has(e)
		if visitado:
			ok += 1
		print("  %s %s" % ["OK   " if visitado else "FALLA", e])
	print("RESULTADO: %d/%d estados alcanzados." % [ok, esperados.size()])
	if not _fallos.is_empty():
		print("--- FALLOS ---")
		for f in _fallos:
			print("  " + f)
	get_tree().quit(0 if ok == esperados.size() else 1)


# --- Utilidades ---------------------------------------------------------------

func _paso_(nombre: String, dur: float, hacer: Callable, espera: StringName) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "espera": espera}


## Paso que además comprueba una condición al terminar. Para lo que no se ve en
## la lista de estados visitados: velocidad conservada, saltos gastados, etc.
func _chequeo_(nombre: String, dur: float, hacer: Callable, chequeo: Callable, porque: String) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "espera": &"",
		"chequeo": chequeo, "porque": porque}


func _teleport(pos: Vector3) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.stamina.llenar()
	_p.recargar_aire()
	_p.tiempo_sin_borde = 0.0


func _pulsar(accion: StringName) -> void:
	Input.action_press(accion)


## Simula la TECLA Espacio, que dispara `jump` y `glide` a la vez. Pulsar solo la
## acción `jump` no probaría nada: el conflicto que estamos verificando nace
## precisamente de que las dos comparten tecla.
func _pulsar_espacio() -> void:
	Input.action_press(&"jump")
	Input.action_press(&"glide")


func _soltar(accion: StringName) -> void:
	Input.action_release(accion)


func _soltar_todo() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
