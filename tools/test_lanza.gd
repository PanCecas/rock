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
var _victima: Enemigo
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
var _salto: int = 0
var _cuerda: int = 0
var _boton_lanza: int = 0
var _atk_lig: int = 0
var _atk_pes: int = 0
## Latches de la carga en viaje.
var _enemigo_vy: float = -99.0
var _enemigo_vida: float = 0.0
var _cruzo: bool = false
var _vel_llegada: float = 0.0
## Latches del zip. Se miden MIENTRAS pasa, no al final: cuando termina la
## ventana del chequeo el jugador ya ha llegado arriba y ha vuelto a caer.
var _alto_max: float = -99.0
var _dist_min: float = 9999.0
## Latches del pendulo.
var _swing_ymin: float = 999.0
var _swing_ymax: float = -999.0
var _swing_vmax: float = 0.0
var _swing_y0: float = 0.0
## Mayor salto de velocidad entre frames colgado. ES la medida de lo clunky.
var _swing_tiron: float = 0.0
var _v_ant: float = 0.0


func _ready() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	await get_tree().physics_frame
	_l = _p.lanza
	_construir()


func _construir() -> void:
	_guion = [
		_chequeo_("el jugador tiene LA lanza, guardada", 0.3,
			func() -> void: pass,
			func() -> bool: return _l != null and _l.fsm.nombre_actual() == &"Holstered",
			"empieza guardada: el kit base es la espada y empunarla es lo que lo cambia"),

		_chequeo_("se clava en un muro", 1.4,
			func() -> void:
				_l.fsm.cambiar(&"Wielded")
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

		# UN SOLO BOTON. Eran tres teclas —T tirar, Y recuperar, Z cuerda— y dos de
		# ellas al otro lado del teclado, sin alcance desde WASD.
		_chequeo_("el boton de la lanza la TIRA si la llevas", 1.0,
			func() -> void:
				_l.fsm.cambiar(&"Wielded")
				_p.global_position = Vector3(0.0, 0.05, 33.0)
				_p.velocity = Vector3.ZERO
				_p.call("orientar_a", Vector3(0, 0, -1))
				_visto.clear()
				_boton_lanza = 3,
			func() -> bool: return not _l.en_mano(),
			"con la lanza en la mano, el boton la lanza"),

		_chequeo_("y el MISMO boton la recupera", 2.0,
			func() -> void:
				_visto.clear()
				_boton_lanza = 3,
			func() -> bool: return _visto.has(&"Returning") or _l.en_mano(),
			"sin ella, el mismo boton la llama de vuelta: son las dos mitades del mismo verbo"),

		# --- CAMBIAR DE POSICION (etapa 2) ------------------------------------
		_chequeo_("la cuerda te lleva hasta la lanza clavada", 2.2,
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

		# --- BALANCEO (etapa 4) -----------------------------------------------
		# El ancla se coloca a mano y alta: es una MEDICION del pendulo, y para que
		# haya pendulo hace falta caida. Con la lanza clavada en el muro de 5 m la
		# cuerda llegaria al suelo antes de completar el arco.
		_chequeo_("colgarse de la lanza clavada", 2.6,
			func() -> void:
				_l.global_position = Vector3(0.0, 20.0, 0.0)
				_l.fsm.cambiar(&"Embedded", {
					"punto": _l.global_position, "normal": Vector3.UP})
				_p.global_position = _l.global_position + Vector3(0.0, -0.2, 14.0)
				_p.velocity = Vector3.ZERO
				_p.stamina.llenar()
				_swing_y0 = _p.global_position.y
				_swing_ymin = 999.0
				_swing_ymax = -999.0
				_swing_vmax = 0.0
				# POR LA TECLA, no forzando el estado. Este chequeo estaba escrito
				# con `fsm.cambiar(&"SpearSwing")` y por eso daba verde mientras el
				# balanceo no aparecia jugando: comprobaba la fisica del pendulo y
				# NO que se pueda entrar en el.
				_p.fsm.cambiar(&"Fall")
				_cuerda = 3,
			func() -> bool: return _visto.has(&"SpearSwing") and _swing_vmax > 5.0,
			"pulsar la cuerda en el aire, con la lanza clavada, tiene que colgarte"),

		_chequeo_("el pendulo llega abajo del arco", 0.1,
			func() -> void: pass,
			func() -> bool:
				# Ancla a 20 con cuerda de 14: el punto bajo esta en 6.
				return absf(_swing_ymin - 6.0) < 0.6,
			"si no baja hasta el radio, la cuerda no esta restringiendo nada"),

		_chequeo_("y NO gana energia al subir", 0.1,
			func() -> void: pass,
			func() -> bool: return _swing_ymax <= _swing_y0 + 0.5,
			"con la gravedad asimetrica del juego el arco subia 6 m por encima de donde empezaba"),

		_chequeo_("la cuerda se acorta para despejar el suelo", 2.2,
			func() -> void:
				# Ancla BAJA con el jugador lejos: la cuerda natural seria mas
				# larga que la altura del ancla y el fondo del arco caeria bajo
				# tierra. Asi se veia el balanceo desde fuera: te estrellabas en el
				# primer cuarto de arco y parecia que no funcionaba.
				_l.global_position = Vector3(16.0, 6.0, 34.0)
				_l.fsm.cambiar(&"Embedded", {
					"punto": _l.global_position, "normal": Vector3.UP})
				# Dentro del suelo del Gym (70x70 centrado en el origen): en z=43
				# no hay nada debajo, y sin suelo no hay altura que despejar.
				_p.global_position = Vector3(16.0, 4.0, 25.0)
				_p.velocity = Vector3(0, -2, 0)
				_p.stamina.llenar()
				_swing_ymin = 999.0
				_swing_vmax = 0.0
				_visto.clear()
				_p.fsm.cambiar(&"Fall")
				_cuerda = 3,
			func() -> bool: return _visto.has(&"SpearSwing") and _swing_ymin > 0.4,
			"con la cuerda mas larga que el ancla, el arco pasa BAJO TIERRA y te estrellas"),

		# DESDE EL SUELO, UNA SOLA PULSACION. Es lo que se reporto como clunky:
		# antes hacian falta dos gestos y dos estados —zip en el suelo, balanceo en
		# el aire— para algo que en la cabeza del jugador es un movimiento.
		_chequeo_("una sola Z desde el suelo ya te cuelga", 2.4,
			func() -> void:
				_l.global_position = Vector3(16.0, 9.3, 34.0)
				_l.fsm.cambiar(&"Embedded", {
					"punto": _l.global_position, "normal": Vector3.UP})
				_p.global_position = Vector3(16.0, 0.05, 25.0)
				_p.velocity = Vector3.ZERO
				_p.stamina.llenar()
				_swing_tiron = 0.0
				_swing_vmax = 0.0
				_visto.clear()
				_p.fsm.cambiar(&"Idle")
				_cuerda = 3,
			func() -> bool:
				return (_visto.has(&"SpearSwing")
					and _p.fsm.nombre_actual() == &"SpearSwing"
					and _p.global_position.y > 1.0),
			"engancharse a algo clavado es UNA accion, la empieces en el suelo o en el aire"),

		_chequeo_("y no da tirones al pasar de recoger a girar", 0.1,
			func() -> void: pass,
			func() -> bool: return _swing_tiron < 3.0,
			"escribiendo la velocidad el salto era de 16.75 m/s en un frame: ESO es lo clunky"),

		_chequeo_("balancearse NO gasta stamina", 1.5,
			func() -> void:
				_l.global_position = Vector3(16.0, 9.3, 34.0)
				_l.fsm.cambiar(&"Embedded", {
					"punto": _l.global_position, "normal": Vector3.UP})
				_p.global_position = Vector3(16.0, 4.0, 25.0)
				_p.velocity = Vector3.ZERO
				_p.stamina.llenar()
				_p.fsm.cambiar(&"Fall")
				_cuerda = 3,
			func() -> bool:
				return (_p.fsm.nombre_actual() == &"SpearSwing"
					and _p.stamina.fraccion() > 0.99),
			"balancearse no puede vaciar la barra"),

		_chequeo_("y con la stamina a CERO no te suelta", 1.0,
			func() -> void:
				# El caso que antes expulsaba: agotado a mitad de arco.
				_p.stamina.actual = 0.0,
			func() -> bool: return _p.fsm.nombre_actual() == &"SpearSwing",
			"GroupAttached suelta a quien se agota; el balanceo no participa de esa regla"),

		_chequeo_("saltar suelta la cuerda", 1.0,
			func() -> void:
				_p.stamina.llenar()
				_visto.clear()
				_salto = 3,
			func() -> bool:
				return _visto.has(&"Jump") and _p.fsm.nombre_actual() != &"SpearSwing",
			"el balanceo se usa para LLEGAR a un sitio, y llegar termina en un salto"),

		# --- ATRAVESAR --------------------------------------------------------
		_chequeo_("atraviesa a los enemigos sin pararse", 1.2,
			func() -> void:
				# Al aire libre, lejos del muro: aqui interesa que NO se pare.
				# A lo ancho del corral: el Embestidor esta a 7 m y detras queda
				# sitio libre. Tirar hacia el coloso no valdria: clavarse en un
				# coloso es lo que la lanza DEBE hacer, no un fallo.
				# x=4 esta pasados los muros del wall-run (x 1.3..2.3), que cortaban
				# el disparo a metro y medio de salir.
				# A la mano primero: los chequeos del pendulo la dejan clavada a
				# veinte metros, y de ahi no se puede lanzar.
				_l.fsm.cambiar(&"Wielded")
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
		# EL INTERCAMBIO DE MOVESET. No es un remapeo: los botones siguen
		# significando lo mismo y lo unico que cambia es que AttackData sale.
		_chequeo_("guardada, el moveset es el de siempre", 0.3,
			func() -> void: _l.fsm.cambiar(&"Holstered"),
			func() -> bool:
				return (_p.ataque_ligero_actual() == _p.ataque_ligero
					and _p.ataque_pesado_actual() == _p.ataque_pesado),
			"sin lanza empunada no puede salir un ataque de lanza"),

		_chequeo_("empunada, cambia el moveset entero", 0.4,
			func() -> void:
				# Por el TOGGLE, no forzando el estado: asi se comprueba tambien
				# que la tecla de guardar/sacar hace lo que dice.
				_l.fsm.cambiar(&"Holstered")
				_l.alternar_empunada(),
			func() -> bool:
				return (_p.ataque_ligero_actual() == _p.ataque_lanza_ligero
					and _p.ataque_pesado_actual() == _p.ataque_lanza_pesado),
			"empunarla cambia los DOS, no solo uno"),

		# EL MOVESET AEREO. Sin el, empunar la lanza solo cambiaba la mitad del
		# combate: en el aire seguian saliendo los clavados a mano.
		_chequeo_("empunada, el aire tambien cambia", 0.3,
			func() -> void: pass,
			func() -> bool:
				return (_p.ataque_aereo_ligero_actual() == _p.ataque_lanza_aereo_ligero
					and _p.ataque_aereo_pesado_actual() == _p.ataque_lanza_aereo_pesado),
			"un moveset que cambia en el suelo y no en el aire es medio moveset"),

		_chequeo_("y guardada mandan los clavados", 0.3,
			func() -> void: _l.fsm.cambiar(&"Holstered"),
			func() -> bool:
				return (_p.ataque_aereo_ligero_actual() == null
					and _p.ataque_aereo_pesado_actual() == null),
			"sin lanza el kit aereo a mano tiene que quedar intacto"),

		_chequeo_("el aereo ligero es preciso y el pesado en area", 0.4,
			func() -> void: _l.fsm.cambiar(&"Wielded"),
			func() -> bool:
				var lig: AttackData = _p.ataque_lanza_aereo_ligero
				var pes: AttackData = _p.ataque_lanza_aereo_pesado
				# MISMO eje que en suelo: un moveset que cambia de criterio al
				# saltar no es un moveset, son dos.
				return (lig.radio < pes.radio * 0.5
					and lig.max_objetivos < pes.max_objetivos
					and lig.frames_windup < pes.frames_windup
					and lig.arco_grados < pes.arco_grados),
			"el eje tiene que ser el mismo en el suelo y en el aire"),

		_chequeo_("el ligero de lanza es preciso y el pesado en area", 0.3,
			func() -> void: pass,
			func() -> bool:
				var lig: AttackData = _p.ataque_lanza_ligero
				var pes: AttackData = _p.ataque_lanza_pesado
				# El eje del moveset: rapido y preciso contra lento y en area.
				return (lig.radio < pes.radio * 0.5
					and lig.max_objetivos < pes.max_objetivos
					and lig.frames_windup < pes.frames_windup
					and lig.arco_grados < pes.arco_grados),
			"si los dos pegan igual, no hay moveset: hay dos botones para lo mismo"),

		_chequeo_("y tirarla la desempuna", 1.2,
			func() -> void:
				_p.global_position = Vector3(0.0, 0.05, 33.0)
				_p.velocity = Vector3.ZERO
				_p.call("orientar_a", Vector3(0, 0, -1))
				_boton_lanza = 3,
			func() -> bool:
				return (not _p.lanza_empunada()
					and _p.ataque_ligero_actual() == _p.ataque_ligero),
			"tirarla ES desequiparla: por eso lanzar es una decision y no un tramite"),

		# --- VUELO ------------------------------------------------------------

		# PERTIGA. `docs/03 §4.1` la llama "una mecanica de plataformas disfrazada
		# de arma", y es literal: no hace dano, no tiene hitbox, y su unico trabajo
		# es llevarte donde el salto no llega.
		# Colocarse y ASENTARSE primero: `is_on_floor()` refleja el ultimo
		# `move_and_slide`, asi que recien teletransportado el jugador todavia
		# cuenta como en el aire y el salto saldria como salto aereo.
		_chequeo_("colocarse junto a la lanza clavada", 0.5,
			func() -> void:
				_l.global_position = Vector3(0.0, 2.0, 30.0)
				_l.fsm.cambiar(&"Embedded", {
					"punto": _l.global_position, "normal": Vector3.UP})
				_p.global_position = Vector3(0.0, 0.05, 31.5)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Idle"),
			func() -> bool: return _p.is_on_floor() and _p.hay_pertiga(),
			"sin suelo bajo los pies y lanza al lado no hay pertiga que probar"),

		_chequeo_("saltar junto a la lanza clavada te impulsa", 1.4,
			func() -> void:
				_alto_max = -99.0
				# Mantenida todo el ascenso: este juego tiene jump cut, asi que
				# soltar mientras subes recorta el salto y la pertiga no se
				# distinguiria de un salto normal. Se suelta al acabar el paso.
				_salto = 80,
			func() -> bool:
				# Un salto normal sube 2.6 m. Con pertiga tiene que pasar de largo.
				return _alto_max > 4.5,
			"con pertiga se llega a una altura que el salto solo no alcanza"),

		_chequeo_("asentarse sin lanza cerca", 0.5,
			func() -> void:
				_l.fsm.cambiar(&"Holstered")
				_p.global_position = Vector3(0.0, 0.05, 31.5)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Idle"),
			func() -> bool: return _p.is_on_floor() and not _p.hay_pertiga(),
			"guardada no sirve de apoyo: te apoyas en algo firme, no en lo que llevas"),

		_chequeo_("y sin lanza cerca el salto es el de siempre", 1.4,
			func() -> void:
				_alto_max = -99.0
				# Mantenida todo el ascenso: este juego tiene jump cut, asi que
				# soltar mientras subes recorta el salto y la pertiga no se
				# distinguiria de un salto normal. Se suelta al acabar el paso.
				_salto = 80,
			func() -> bool: return _alto_max < 3.6,
			"si la pertiga saliera siempre, el salto normal dejaria de existir"),

		# CARGA EN VIAJE. Golpear mientras la cuerda te lleva convierte la velocidad
		# del viaje en dos cosas distintas: atravesar o impactar.
		_chequeo_("preparar un enemigo en el camino", 0.6,
			func() -> void:
				_l.global_position = Vector3(11.0, 6.0, -20.0)
				_l.fsm.cambiar(&"Embedded", {
					"punto": _l.global_position, "normal": Vector3.UP})
				_p.global_position = Vector3(11.0, 0.05, -30.0)
				_p.velocity = Vector3.ZERO
				_p.stamina.llenar()
				_preparar_victima(Vector3(11.0, 0.2, -25.0)),
			func() -> bool: return _victima != null and is_instance_valid(_victima),
			"sin nadie en medio no hay nada que atravesar ni que mandar a volar"),

		_chequeo_("la carga LIGERA hiere y NO te para", 1.8,
			func() -> void:
				_enemigo_vida = _victima.salud.actual
				_cruzo = false
				_p.fsm.cambiar(&"Fall")
				_cuerda = 4
				_atk_lig = 30,
			func() -> bool:
				# Le ha hecho dano Y ha seguido de largo: cruzo su posicion.
				return _victima.salud.actual < _enemigo_vida and _cruzo,
			"atravesar es herir sin pararse; si te frena, es un muro y no un enemigo"),

		_chequeo_("la PESADA los manda a volar", 2.0,
			func() -> void:
				_p.global_position = Vector3(11.0, 0.05, -30.0)
				_p.velocity = Vector3.ZERO
				_p.stamina.llenar()
				_preparar_victima(Vector3(11.0, 0.2, -25.0))
				_enemigo_vy = -99.0
				_p.fsm.cambiar(&"Fall")
				_cuerda = 4
				_atk_pes = 30,
			func() -> bool: return _enemigo_vy > 3.0,
			"con la inercia del viaje, el pesado tiene que levantarlo del suelo"),

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

	if _atk_lig > 0:
		Input.action_press(&"attack_light")
		_atk_lig -= 1
		if _atk_lig == 0:
			Input.action_release(&"attack_light")
	if _atk_pes > 0:
		Input.action_press(&"attack_heavy")
		_atk_pes -= 1
		if _atk_pes == 0:
			Input.action_release(&"attack_heavy")
	if _boton_lanza > 0:
		Input.action_press(&"throw_spear")
		_boton_lanza -= 1
		if _boton_lanza == 0:
			Input.action_release(&"throw_spear")
	if _cuerda > 0:
		Input.action_press(&"rope")
		_cuerda -= 1
		if _cuerda == 0:
			Input.action_release(&"rope")
	if _salto > 0:
		Input.action_press(&"jump")
		_salto -= 1
		if _salto == 0:
			Input.action_release(&"jump")
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
	if _victima != null and is_instance_valid(_victima):
		_enemigo_vy = maxf(_enemigo_vy, _victima.velocity.y)
		# ¿Ha cruzado al enemigo? El viaje va hacia -Z; cruzarlo es pasar de largo.
		if _p.global_position.z < _victima.global_position.z - 0.6:
			_cruzo = true
	if _p.fsm.nombre_actual() == &"SpearSwing":
		_swing_ymin = minf(_swing_ymin, _p.global_position.y)
		_swing_ymax = maxf(_swing_ymax, _p.global_position.y)
		var v := _p.velocity.length()
		_swing_tiron = maxf(_swing_tiron, absf(v - _v_ant))
		_v_ant = v
		_swing_vmax = maxf(_swing_vmax, v)
	else:
		_v_ant = _p.velocity.length()
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


## Un Guardian quieto y pacificado en mitad del camino. Pacificado porque lo que
## se mide es el golpe DEL JUGADOR: un enemigo que ademas ataca solo mete ruido.
func _preparar_victima(pos: Vector3) -> void:
	if _victima != null and is_instance_valid(_victima):
		_victima.queue_free()
	var g := load("res://src/enemies/Guardian.tscn").instantiate() as Enemigo
	g.palette = GameState.palette
	# CON AttackData aunque no vaya a atacar: su estado Recuperar lo lee al
	# recibir un golpe, y sin el revienta.
	g.ataque = load("res://content/data/attacks/guardian_lancero.tres")
	_main.add_child(g)
	g.global_position = pos
	g.vista = 0.0
	g.fsm.cambiar(&"Dormido")
	_victima = g
