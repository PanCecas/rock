
extends Node
## Test funcional de los enemigos del parche 3.03.
##
##   godot --headless --path . tools/TestEnemigos.tscn
##
## Comprueba lo que se puede comprobar sin ojos: que el cono de vision descarta lo
## que tiene detras, que la carga NO persigue —que es lo que la hace esquivable—,
## que el volador dispara tres y se reposiciona, y que al coloso mediano se le
## puede trepar. El feel se sigue juzgando jugando.

const EMBESTIDOR := preload("res://src/enemies/Embestidor.tscn")
const VOLADOR := preload("res://src/enemies/Volador.tscn")
const COLOSO := preload("res://src/enemies/ColosoMediano.tscn")
const PROYECTIL := preload("res://src/enemies/Proyectil.tscn")

var _main: Node
var _p: PlayerController
var _paso: int = 0
var _t: float = 0.0
var _reloj: float = 0.0
var _guion: Array = []
var _fallos: PackedStringArray = []

var _e: Enemigo = null
var _aux: float = 0.0
var _pos: Vector3 = Vector3.ZERO
## Latches: un estado que dura tres decimas no se puede comprobar solo al final.
var _visto: Dictionary = {}
var _proyectiles_max: int = 0


func _ready() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	_construir()


func _construir() -> void:
	_guion = [
		# --- EMBESTIDOR: el cono de vision -----------------------------------
		# Con rotation.y = 0 el frente (-basis.z) apunta a -Z. Asi que DETRAS es +Z.
		_chequeo_("de espaldas NO te ve", 0.5,
			func() -> void:
				_crear(EMBESTIDOR, Vector3(0, 0.2, 0), "res://content/data/attacks/embestida.tres")
				_e.rotation.y = 0.0
				# Dentro del radio de vision, pero a su espalda.
				_p.global_position = Vector3(0, 0.05, 5.0),
			func() -> bool: return _e.fsm.nombre_actual() == &"Dormido",
			"con el jugador fuera del cono no debe despertarse"),

		# Enemigo NUEVO: reusar el anterior lo daria por despierto y el test
		# pasaria por arrastre en vez de por detectar nada.
		_chequeo_("de frente SI te ve", 0.5,
			func() -> void:
				_crear(EMBESTIDOR, Vector3(0, 0.2, 0), "res://content/data/attacks/embestida.tres")
				_e.rotation.y = 0.0
				_p.global_position = Vector3(0, 0.05, -6.0),
			func() -> bool: return _e.fsm.nombre_actual() != &"Dormido",
			"dentro del cono y sin pared en medio tiene que detectarte"),

		# --- EMBESTIDOR: la carga NO persigue --------------------------------
		# Es LA propiedad que la hace esquivable. Si corrigiera el rumbo seria un
		# misil teledirigido y la unica respuesta posible seria correr.
		_chequeo_("la carga fija el rumbo", 2.2,
			func() -> void:
				_p.global_position = Vector3(0, 0.05, 6.0)
				_e.global_position = Vector3(0, 0.2, 0)
				_e.objetivo = _p
				_e.fsm.cambiar(&"Anticipar")
				_visto.clear()
				_aux = 0.0,
			func() -> bool:
				# Se aparto el jugador en pleno anticipar y aun asi carga recto.
				return _visto.has(&"Embestir") and _aux > 3.0,
			"la carga debe recorrer camino en linea recta aunque el jugador se aparte"),

		# --- VOLADOR ----------------------------------------------------------
		_chequeo_("el volador no cae", 0.6,
			func() -> void:
				_crear(VOLADOR, Vector3(0, 6.0, 0), "res://content/data/attacks/volador_disparo.tres")
				(_e as Volador).proyectil = PROYECTIL
				_p.global_position = Vector3(0, 0.05, 8.0)
				_pos = _e.global_position,
			func() -> bool: return _e.global_position.y > _pos.y - 1.0,
			"con `vuela` puesto la gravedad no le aplica"),

		_chequeo_("dispara una rafaga de tres", 1.2,
			func() -> void:
				_e.objetivo = _p
				_proyectiles_max = 0
				_e.fsm.cambiar(&"Rafaga"),
			func() -> bool: return _proyectiles_max >= 3,
			"la rafaga tiene que soltar los tres disparos"),

		_chequeo_("y recarga reposicionandose", 1.6,
			func() -> void:
				_pos = _e.global_position
				_visto.clear()
				_e.fsm.cambiar(&"Recargar"),
			func() -> bool: return (_visto.has(&"Recargar")
				and _e.global_position.distance_to(_pos) > 4.0),
			"recargar tiene que ALEJARLO: es su ventana de vulnerabilidad y debe verse"),

		# --- COLOSO MEDIANO ---------------------------------------------------
		_chequeo_("el coloso es escalable", 0.5,
			func() -> void:
				_crear(COLOSO, Vector3(0, 3.6, 0), ""),
			func() -> bool: return _e.get_collision_layer_value(4),
			"su collider tiene que estar en la capa CLIMBABLE o no se puede trepar"),

		_chequeo_("y no ataca", 1.2,
			func() -> void:
				_e.objetivo = _p
				_p.global_position = _e.global_position + Vector3(0, -3.0, 3.0)
				_visto.clear(),
			func() -> bool: return not _visto.has(&"Telegrafia") and not _visto.has(&"Atacar"),
			"por ahora su unico trabajo es dejarse escalar"),

		_chequeo_("el jugador se agarra a el", 1.6,
			func() -> void:
				_p.global_position = _e.global_position + Vector3(0, -1.5, 2.6)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Fall")
				Input.action_press(&"grab")
				_visto.clear(),
			func() -> bool: return _p.pared.hay_pared,
			"el WallSensor tiene que ver su cuerpo como pared escalable"),
	]


func _physics_process(delta: float) -> void:
	_reloj += delta
	if _reloj > 40.0:
		_fallos.append("el test se colgo")
		_informe()
		return
	if _paso >= _guion.size():
		_informe()
		return
	_t += delta

	# Latches, antes de nada.
	if _e != null and is_instance_valid(_e):
		_visto[_e.fsm.nombre_actual()] = true
		if _e.fsm.nombre_actual() == &"Embestir":
			_aux = maxf(_aux, absf(_e.global_position.z))
	_proyectiles_max = maxi(_proyectiles_max, _contar_proyectiles())

	var actual: Dictionary = _guion[_paso]
	if is_zero_approx(_t - delta):
		(actual["hacer"] as Callable).call()
	if _t >= float(actual["dur"]):
		if not (actual["chequeo"] as Callable).call():
			_fallos.append("%-32s %s\n      [estado=%s  pos=%.1f,%.1f,%.1f]" % [
				actual["nombre"], actual["porque"],
				_e.fsm.nombre_actual() if _e != null and is_instance_valid(_e) else "?",
				_e.global_position.x if _e != null else 0.0,
				_e.global_position.y if _e != null else 0.0,
				_e.global_position.z if _e != null else 0.0])
		else:
			print("  OK    %s" % actual["nombre"])
		_paso += 1
		_t = 0.0


func _informe() -> void:
	set_physics_process(false)
	print("RESULTADO ENEMIGOS: %d/%d comprobaciones." % [_guion.size() - _fallos.size(), _guion.size()])
	if not _fallos.is_empty():
		print("--- FALLOS ---")
		for f in _fallos:
			print("  " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)


func _chequeo_(nombre: String, dur: float, hacer: Callable, chequeo: Callable, porque: String) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "chequeo": chequeo, "porque": porque}


## Crea un enemigo limpio. Se libera el anterior: dos enemigos vivos a la vez
## harian que un test midiera al que no toca.
func _crear(escena: PackedScene, pos: Vector3, ruta_ataque: String) -> void:
	if _e != null and is_instance_valid(_e):
		_e.queue_free()
	_e = escena.instantiate() as Enemigo
	if not ruta_ataque.is_empty():
		_e.ataque = load(ruta_ataque)
	_e.palette = GameState.palette
	_main.add_child(_e)
	_e.global_position = pos
	_visto.clear()


func _contar_proyectiles() -> int:
	var n := 0
	for hijo in _main.get_children():
		if hijo is Proyectil:
			n += 1
	return n
