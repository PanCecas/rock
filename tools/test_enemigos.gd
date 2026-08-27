
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
var _remate: bool = false


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

		# EL BUG DEL VOLADOR INALCANZABLE. `punto_de_vuelo()` se anclaba a la Y del
		# jugador: saltabas y subia contigo manteniendo el hueco. Estaba definido
		# como inalcanzable.
		_chequeo_("su altura NO sigue al jugador al saltar", 0.4,
			func() -> void:
				_e.objetivo = _p
				_p.global_position = Vector3(0, 0.05, 6.0),
			func() -> bool:
				var en_suelo: float = (_e as Volador).punto_de_vuelo().y
				# Como si el jugador saltara cinco metros.
				_p.global_position = Vector3(0, 5.05, 6.0)
				var en_aire: float = (_e as Volador).punto_de_vuelo().y
				_p.global_position = Vector3(0, 0.05, 6.0)
				return absf(en_aire - en_suelo) < 0.5,
			"si su altura de vuelo sube contigo, saltar no recorta nada y no se alcanza nunca"),

		# --- APUNTADO EN 3D --------------------------------------------------
		# El caso que estaba roto: un enemigo JUSTO ENCIMA daba vector plano cero,
		# caia en el `continue` de `_buscar()` y era inseleccionable. Mirar hacia
		# arriba lo empeoraba, porque la referencia tambien se aplastaba.
		_chequeo_("un enemigo encima se puede fijar", 0.5,
			func() -> void:
				_crear(VOLADOR, Vector3(0, 5.2, 0), "res://content/data/attacks/volador_disparo.tres")
				_p.global_position = Vector3(0, 0.05, 0),
			func() -> bool:
				# Se apunta a mano hacia arriba —lo que hace el jugador al mirar al
				# cielo— porque el controlador reescribe esto cada frame con el
				# frente de la camara.
				_p.targeting.actualizar(Vector3(0.1, 1.0, 0.0).normalized())
				return _p.targeting.objetivo() == _e,
			"con la Y aplastada un enemigo vertical no existe para el soft-lock"),

		_chequeo_("y se le apunta hacia arriba", 0.4,
			func() -> void: pass,
			func() -> bool:
				_p.targeting.actualizar(Vector3(0.1, 1.0, 0.0).normalized())
				var d := _p.targeting.direccion_3d()
				# Muy por encima: la componente vertical tiene que dominar.
				return d.y > 0.8 and _p.targeting.distancia_3d() > 3.0,
			"direccion_3d() tiene que subir; la plana sigue siendo plana para encarar"),

		_chequeo_("y la plana sigue plana", 0.3,
			func() -> void: pass,
			func() -> bool:
				_p.targeting.actualizar(Vector3(0.1, 1.0, 0.0).normalized())
				return is_zero_approx(_p.targeting.direccion_a_objetivo().y),
			"si esta se inclina, pegar a algo que vuela despega al jugador"),

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

		# EL BUG DEL ARRASTRE. Un cuerpo en la capa WORLD es una plataforma movil
		# para `move_and_slide`: al girar arrastra a quien tenga encima a ω·r, sin
		# tocarle la velocidad. Con 360°/s y radio 2.2 eran 13.8 m/s —mas que
		# correr— y el jugador salia disparado en circulos.
		_chequeo_("y no te arrastra mas rapido que andar", 0.3,
			func() -> void: pass,
			func() -> bool:
				return _e.arrastre_en_el_borde() < _p.tuning.velocidad_caminar,
			"si el borde barre mas rapido que caminar, no puedes andar en contra"),

		# LAS TRES PIEZAS QUE IMPIDEN EL ARRASTRE. Se comprueban por separado porque
		# cada una, por si sola, lo reintroduce entera: el movimiento se aplicaba
		# DOS VECES —`move_and_slide` acarreando desde WORLD y `arrastrar()`
		# moviendote con el marco— y montarse encima era un caos.
		_chequeo_("no cuenta como plataforma movil", 0.3,
			func() -> void: pass,
			func() -> bool:
				# En WORLD, `move_and_slide` acarrea. En COLOSSUS_SURFACE el jugador
				# choca igual —su mascara la incluye— pero no hereda el giro.
				return (not (_e as CollisionObject3D).get_collision_layer_value(1)
					and (_e as CollisionObject3D).get_collision_layer_value(11)),
			"si vuelve a la capa WORLD, girar arrastra a quien tenga encima"),

		_chequeo_("y el jugador solo acarrea desde mundo estatico", 0.3,
			func() -> void: pass,
			func() -> bool:
				return (_p.platform_floor_layers == Layers.WORLD
					and _p.platform_wall_layers == Layers.WORLD),
			"por defecto son TODAS las capas, que es como empezo el bug"),

		_chequeo_("y agarrarse a el no lo adopta como marco", 0.6,
			func() -> void:
				_p.global_position = _e.global_position + Vector3(0.0, 1.0, 2.5)
				_p.set("velocity", Vector3.ZERO)
				_p.call("orientar_a", Vector3(0, 0, -1))
				_p.fsm.cambiar(&"Climb"),
			func() -> bool: return _p.superficie.frame == null,
			"un marco movil arrastra; hoy nadie declara serlo y eso es lo correcto"),

		# --- PUNTO DEBIL: la interfaz contra colosos (Fase 3, etapa 6) ---------
		# Declara QUE LO ABRE, no QUIEN. El coloso no conoce la lanza: conoce una
		# etiqueta, y la lanza la trae. Anadir un arma nueva es escribirle
		# `etiquetas` en su `.tres`; el coloso no se toca.
		_chequeo_("tiene un punto debil", 0.3,
			func() -> void: pass,
			func() -> bool: return _punto_debil() != null,
			"sin punto debil un coloso es un saco de vida y no un nivel"),

		_chequeo_("un ataque SIN la llave apenas le hace nada", 0.6,
			func() -> void:
				var wp := _punto_debil()
				wp.reiniciar()
				_e.salud.actual = _e.salud.maxima
				# El pesado de la espada: contundente, no perforante.
				_golpear_punto_debil(_p.ataque_pesado),
			func() -> bool:
				var perdida: float = _e.salud.maxima - _e.salud.actual
				return perdida > 0.0 and perdida < _p.ataque_pesado.dano,
			"cero lo haria inmune y eso se lee como un bug; poco se lee como una defensa"),

		_chequeo_("y CON la llave le hace mucho mas", 0.6,
			func() -> void:
				var wp := _punto_debil()
				wp.reiniciar()
				_e.salud.actual = _e.salud.maxima
				_golpear_punto_debil(_p.ataque_lanza_ligero),
			func() -> bool:
				var perdida: float = _e.salud.maxima - _e.salud.actual
				return perdida > _p.ataque_lanza_ligero.dano * 2.0,
			"la lanza es la herramienta indispensable POR LO QUE DECLARA, no porque el coloso la conozca"),

		_chequeo_("y a la tercera queda abierto al remate", 1.0,
			func() -> void:
				var wp := _punto_debil()
				wp.reiniciar()
				_e.salud.actual = _e.salud.maxima
				_remate = false
				wp.remate_disponible.connect(func() -> void: _remate = true, CONNECT_ONE_SHOT)
				for i in wp.golpes_para_abrir:
					_golpear_punto_debil(_p.ataque_lanza_ligero),
			func() -> bool: return _remate and _punto_debil().abierto,
			"uno solo haria el remate un accidente; varios lo convierten en algo que se busca"),

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


func _punto_debil() -> WeakPoint:
	if _e == null or not is_instance_valid(_e):
		return null
	return _e.get_node_or_null("PuntoDebil") as WeakPoint


## Entrega un golpe A MANO en el punto debil. Igual que hace `TestFase2` con los
## golpes enemigos: orquestar al jugador para que acierte en el frame exacto hace
## el test fragil sin probar nada mas. Lo que se mide es la INTERFAZ.
func _golpear_punto_debil(datos: AttackData) -> void:
	var wp := _punto_debil()
	if wp == null or datos == null:
		return
	wp.recibir(Golpe.new(_p, datos, wp.global_position, Vector3.FORWARD))
