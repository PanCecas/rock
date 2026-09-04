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
## La vista original de cada enemigo mientras dura una medida. Ver `_pacificar()`.
var _vista_guardada: Dictionary = {}
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
## --- Resortera (3.08) ---
var _an: Anclaje
## Mantiene la cuerda pulsada hasta que se baje a mano. La resortera se TENSA
## mientras aguantas y DISPARA al soltar, asi que un contador de frames no vale:
## soltaria el tiro cuando le tocara, no cuando lo pida el chequeo.
var _cuerda_fija: bool = false
## Flanco de bajada de `_cuerda_fija`: la tecla se suelta UNA vez, no cada frame.
var _cuerda_suelta: bool = true
var _anclaje_boton: int = 0
var _tension_max: float = 0.0
## Velocidad maxima vista DESPUES de salir de la resortera. Es el disparo.
var _disparo_vel: float = 0.0
var _midiendo_disparo: bool = false


func _ready() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	await get_tree().physics_frame
	_l = _p.lanza
	_an = _p.dagas[0] if not _p.dagas.is_empty() else null
	_construir()


## CIEGA A LOS ENEMIGOS DEL GYM, Y LOS DESCIEGA.
##
## `CLAUDE.md` ya lo tenia escrito para `TestFase2` —"un test no puede depender de
## la IA"— y a esta suite le faltaba. El sintoma fue el de siempre: intermitente y
## sin relacion aparente. La pertiga fallaba 2 de cada 5 pasadas, y lo que se medía
## no era una altura corta —el margen es enorme, 8.55 m contra un umbral de 4.5—
## sino **`alto_max = 0.018`**: el jugador ni despegaba. Una sonda dijo por que en
## una linea: `estado=Hitstun`. Alguien le habia pegado en mitad de un salto.
##
## SE CIEGA Y SE DEVUELVE LA VISTA, y no de una vez para siempre: cegarlos a todos
## en `_ready()` fue el primer intento y **rompio dos comprobaciones** que si
## necesitan que un enemigo reaccione. La ceguera dura lo que dura la medida.
func _pacificar(ciegos: bool) -> void:
	for n in get_tree().get_nodes_in_group(&"enemigos"):
		var e := n as Enemigo
		if e == null or not is_instance_valid(e):
			continue
		if ciegos:
			if not _vista_guardada.has(e):
				_vista_guardada[e] = e.vista
			e.vista = 0.0
		elif _vista_guardada.has(e):
			e.vista = _vista_guardada[e]
	if not ciegos:
		_vista_guardada.clear()


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

		# EL BUG DE LA Z CON LA LANZA GUARDADA (3.10). Reportado como "un bug raro
		# al subirse a la cima del gigante, y con la Z sin tener equipada la
		# lanza". Son el mismo fallo: `intentar_cuerda()` solo descartaba
		# `en_mano()`, que es cierto SOLO en `Wielded`, asi que con la lanza
		# GUARDADA la negacion daba true y el zip tiraba del jugador hacia una
		# lanza invisible parada donde estuviera — al arrancar, el spawn.
		#
		# Desde lo alto del coloso eso es un viaje cruzando el mapa entero, que es
		# donde se nota. A ras de suelo pasaba desapercibido.
		_chequeo_("con la lanza GUARDADA, la Z no hace nada", 0.9,
			func() -> void:
				_l.fsm.cambiar(&"Holstered")
				# Lanza "fantasma" lejos, que es justo el estado que causaba el
				# bug: guardada y con la transformada rancia de otro sitio.
				_l.global_position = Vector3(0.0, 1.0, 0.0)
				_p.global_position = Vector3(11.0, 0.05, -32.0)
				_p.velocity = Vector3.ZERO
				_p.stamina.llenar()
				_aux = _p.stamina.actual
				_origen = _p.global_position
				_visto.clear()
				_cuerda = 3,
			func() -> bool:
				# Ni cambia de estado, ni gasta stamina, ni se mueve del sitio.
				return (not _visto.has(&"SpearZip")
					and not _visto.has(&"SpearSwing")
					and is_equal_approx(_p.stamina.actual, _aux)
					and _p.global_position.distance_to(_origen) < 2.0),
			"guardada no es un destino: `en_mano()` no basta, hace falta `esta_fuera()`"),

		# Y EL MISMO FALLO EN EL BOTON DE LA LANZA. `_input_lanza()` preguntaba
		# `en_mano()` para decidir entre tirar y recuperar, asi que con la lanza
		# GUARDADA caia en "recuperar" —que se niega, porque `Holstered` no es
		# recuperable— y el boton no hacia NADA. Como la partida empieza guardada,
		# eso significa que al arrancar el juego la lanza no se podia tirar sin
		# pulsar Tab antes. `Spear.lanzar()` ya aceptaba guardada: la intencion
		# estaba escrita y el guardia la contradecia.
		_chequeo_("el boton la tira tambien GUARDADA, sin pasar por Tab", 1.0,
			func() -> void:
				_l.fsm.cambiar(&"Holstered")
				_p.global_position = Vector3(0.0, 0.05, 33.0)
				_p.velocity = Vector3.ZERO
				_p.call("orientar_a", Vector3(0, 0, -1))
				_visto.clear()
				_boton_lanza = 3,
			func() -> bool: return _l.esta_fuera() or _visto.has(&"InFlight"),
			"la partida empieza con la lanza guardada: si el boton no la tira, no hay lanza"),

		_chequeo_("y guardada sigue a la mano, sin transformada rancia", 0.5,
			func() -> void:
				# Se vuelve a guardar EXPRESAMENTE: el chequeo anterior la tiro, y
				# lo que se mide aqui es el estado `Holstered`, no el que quede.
				_l.fsm.cambiar(&"Holstered")
				_p.fsm.cambiar(&"Fall")
				_p.global_position = Vector3(-6.0, 0.05, 12.0)
				_p.velocity = Vector3.ZERO,
			func() -> bool:
				return _l.global_position.distance_to(_p.global_position) < 3.0,
			"una posicion vieja en un objeto invisible es una trampa para quien la lea"),

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
		# LA INVARIANTE, PRECISADA (3.10). La lanza atraviesa lo que NO se puede
		# agarrar —colosos, bichos grandes— y se queda clavada en lo que sí. Ese
		# reparto es lo que le da a la lanza el papel que iba a tener la segunda
		# daga: agarrar un segundo enemigo sin duplicar un arma.
		#
		# Asi que el enemigo de esta prueba se declara NO agarrable: lo que se mide
		# aqui es que sigue atravesando lo que no es presa.
		_chequeo_("atraviesa a los enemigos sin pararse", 1.2,
			func() -> void:
				# NADIE AGARRABLE en el camino: lo que se mide es que atraviesa lo que
				# NO es presa, y el corral tiene un Embestidor que si lo es — se le
				# clavaria con razon y el test culparia a la invariante equivocada.
				for e in get_tree().get_nodes_in_group(&"enemigos"):
					(e as Enemigo).agarrable = false
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
				# CIEGOS YA AQUI, un paso antes de medir. Cegarlos justo al empezar
				# el salto no basta: un enemigo que ya habia iniciado su ataque lo
				# termina igual, y el golpe cae dentro de la ventana medida.
				_pacificar(true)
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
				# SOLTAR ANTES DE PULSAR. El `InputBuffer` registra el FLANCO, no la
				# tecla mantenida: si `jump` viene pulsada de un paso anterior, poner
				# `_salto = 80` no genera ninguna pulsacion nueva y el salto no
				# ocurre. Medido cuando salio intermitente: `alto_max` no era 4.4
				# —cerca del umbral— sino **0.018**, o sea el jugador ni despego.
				# Un paso que depende de como acabo el anterior es un test fragil.
				_soltar_todo()
				# Y SE SALE DE `Hitstun` A MANO si ya venia tocado. Cegarlos impide
				# el golpe SIGUIENTE, no deshace el anterior, y desde `Hitstun` no se
				# salta: `alto_max` salia 0.018 con el jugador plantado en el suelo.
				_p.fsm.cambiar(&"Idle")
				_p.velocity = Vector3.ZERO
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
				# Ver el paso de la pertiga: el mismo motivo, y aqui el fallo seria
				# aun peor porque un salto que no ocurre pasa el `< 3.6` sin haber
				# probado nada.
				_soltar_todo()
				_p.fsm.cambiar(&"Idle")
				_p.velocity = Vector3.ZERO
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
				# Se acabaron los saltos medidos: los enemigos vuelven a ver, porque
				# lo que viene si los necesita despiertos.
				_pacificar(false)
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

		# =====================================================================
		# LA RESORTERA (3.08). Dos cuerdas, tension y disparo.
		# =====================================================================

		# EL CAMINO DE ENTRADA, POR SU BOTON. El anclaje se tira con su tecla y se
		# clava solo; no se le fuerza el estado. Un test que coloca el anclaje a
		# mano no prueba que se pueda PONER, que es la leccion que dejo escrita el
		# balanceo cuando estaba en verde sin poder entrar en el.
		_chequeo_("el anclaje existe y se guarda", 0.3,
			func() -> void: pass,
			func() -> bool: return _an != null and _an.guardado(),
			"la segunda cuerda tiene que existir y empezar recogida"),

		_chequeo_("se tira con su boton y se clava", 1.2,
			func() -> void:
				# SALIR DEL BALANCEO ANTES DE MOVER AL JUGADOR. Los chequeos de la
				# carga en viaje lo dejan colgado de la lanza clavada en el corral,
				# y teletransportarlo sin soltar la cuerda hace que la restriccion
				# lo arrastre 44 m de vuelta en cuanto arranca el frame. El anclaje
				# entonces perseguia a un jugador que cruzaba el mapa, y el fallo
				# parecia del retorno cuando era de la preparacion.
				_p.fsm.cambiar(&"Fall")
				_l.fsm.cambiar(&"Wielded")
				_p.global_position = Vector3(0.0, 0.05, 33.0)
				_p.velocity = Vector3.ZERO
				_p.call("orientar_a", Vector3(0, 0, -1))
				_anclaje_boton = 3,
			func() -> bool: return _an.clavado(),
			"contra el muro se para en seco, igual que la lanza"),

		# CON DOS DAGAS, EL BOTON REPARTE: tira mientras te quede alguna guardada, y
		# recoge cuando ya no queda ninguna. Es la misma regla del boton de la lanza
		# —"si la llevas la tiras, si no vuelve"— extendida a un par, y por eso no
		# hay que aprender nada nuevo.
		# Y VUELVE VOLANDO, como la lanza. Desaparecer y reaparecer en la mano se
		# lee como un teletransporte: no sabes si lo has recogido o lo has perdido.
		# Es la misma leccion que `SpearReturning`, aplicada al anclaje.
		_chequeo_("y el MISMO boton la recoge, volando", 0.9,
			func() -> void:
				_visto.clear()
				_anclaje_boton = 3,
			func() -> bool: return _an.guardado() and _visto.has(&"anclaje_volviendo"),
			"o lo tienes puesto o no lo tienes, y eso se ve: un boton basta"),

		# CON LOS DOS PUNTOS PUESTOS, LA MISMA Z DA OTRA COSA. No hay tecla nueva:
		# lo que decide es cuantas cuerdas hay puestas, y eso se ve.
		_chequeo_("con DOS puntos, la cuerda da resortera", 0.6,
			func() -> void:
				_colgar_entre(Vector3(16.0, 20.0, 22.0), Vector3(16.0, 20.0, 30.0),
					Vector3(16.0, 14.0, 26.0))
				_tension_max = 0.0
				_visto.clear()
				_cuerda_fija = true,
			func() -> bool: return _p.fsm.nombre_actual() == &"Slingshot",
			"dos anclajes son un elastico, no un pendulo: el estado tiene que ser otro"),

		# TENSION. Alejarse de los dos puntos estira las dos bandas, y cada una
		# tira de vuelta con mas fuerza cuanto mas estirada. Aqui quien tira es la
		# gravedad —el jugador cuelga por debajo— porque es determinista; en la
		# mano del jugador quien tira es el stick.
		# La ventana es CORTA a proposito: 0.22 s. Con las dos bandas a
		# `resortera_rigidez` el conjunto oscila con periodo ~0.76 s, asi que el
		# estiramiento maximo cae a un cuarto de periodo —0.19 s— y despues el
		# elastico ya te esta devolviendo. Con una ventana de medio segundo el
		# chequeo soltaba con las cuerdas casi flojas y medía un tiro de nada:
		# la tension estaba, pero no en el instante de soltar.
		_chequeo_("alejarse de los anclajes acumula tension", 0.22,
			func() -> void: _p.velocity = Vector3(0, -26.0, 0),
			func() -> bool: return _tension_max > 8.0,
			"si estirarse no acumulara nada, no habria nada que disparar"),

		# EL DISPARO. Soltar el boton es el gatillo.
		_chequeo_("soltar dispara, y por encima del clamp global", 0.7,
			func() -> void:
				_cuerda_fija = false
				_disparo_vel = 0.0
				_midiendo_disparo = true,
			func() -> bool: return _disparo_vel > _p.tuning.velocidad_maxima,
			"el clamp global (22) se comeria el disparo entero: por eso existe momentum_libre"),

		_chequeo_("y sale de la resortera", 0.3,
			func() -> void: _midiendo_disparo = false,
			func() -> bool: return _p.fsm.nombre_actual() != &"Slingshot",
			"disparar es salir: quedarse colgado despues de soltar no seria un disparo"),

		# Y EL CASO CONTRARIO, que es el que se lee como un fallo si no existe:
		# rozar el boton sin haber tirado no puede catapultarte.
		_chequeo_("soltar SIN tensar no catapulta", 0.5,
			func() -> void:
				_colgar_entre(Vector3(16.0, 20.0, 22.0), Vector3(16.0, 20.0, 30.0),
					Vector3(16.0, 14.0, 26.0))
				_cuerda_fija = true,
			func() -> bool: return _p.fsm.nombre_actual() == &"Slingshot",
			"hace falta estar colgado para poder soltar sin tension"),

		_chequeo_("y se suelta sin impulso", 0.35,
			func() -> void:
				_cuerda_fija = false
				_disparo_vel = 0.0
				_midiendo_disparo = true,
			func() -> bool: return _disparo_vel < _p.tuning.velocidad_maxima,
			"por debajo de `resortera_estirado_min` se suelta y ya: no hay tiro"),

		# DISPARAR DESDE EL SUELO. Es el caso que se rompia solo: al soltar pisando
		# tierra se salia a `Idle`, y la friccion de suelo se comia el tiro en tres
		# frames —tensabas de pie, salias disparado y te frenabas en el sitio—.
		_chequeo_("tensar de pie en el suelo", 0.3,
			func() -> void:
				_midiendo_disparo = false
				_colgar_entre(Vector3(16.0, 10.0, 25.0), Vector3(16.0, 10.0, 27.0),
					Vector3(16.0, 0.05, 26.0))
				_cuerda_fija = true,
			func() -> bool: return _p.fsm.nombre_actual() == &"Slingshot",
			"con dos puntos encima, colgarse tambien vale desde el suelo"),

		# El estirado se hace TELETRANSPORTANDO al jugador: los largos de reposo se
		# fijan al engancharse, asi que apartarse 10 m estira las dos bandas 4 m
		# cada una. Es artificial a proposito —lo que se mide aqui no es como se
		# tensa, es que el tiro SOBREVIVE al suelo—; tensar de verdad se prueba
		# arriba, con la gravedad haciendo el trabajo.
		_chequeo_("y el disparo desde el suelo no se frena", 0.5,
			func() -> void:
				_p.global_position = Vector3(26.0, 0.05, 26.0)
				_cuerda_fija = false
				_disparo_vel = 0.0
				_midiendo_disparo = true,
			func() -> bool: return _disparo_vel > _p.tuning.velocidad_maxima,
			"un disparo que sale a Idle lo borra la friccion: tiene que salir a Fall"),

		# UN SOLO PUNTO SIGUE SIENDO EL BALANCEO. La resortera no puede haberse
		# comido el pendulo: son dos verbos y el jugador elige cual con la posicion
		# de sus cuerdas, no con un menu.
		_chequeo_("con UN solo punto vuelve a ser balanceo", 1.2,
			func() -> void:
				_midiendo_disparo = false
				# TODAS las dagas, no solo la primera: basta con que quede una clavada
				# en mundo para que la resortera siga lista.
				for d in _p.dagas:
					d.recuperar()
					d.estado = Anclaje.Estado.GUARDADO
				_l.global_position = Vector3(16.0, 20.0, 22.0)
				_l.fsm.cambiar(&"Embedded", {
					"punto": _l.global_position, "normal": Vector3.UP})
				_p.global_position = Vector3(16.0, 14.0, 26.0)
				_p.velocity = Vector3.ZERO
				_p.stamina.llenar()
				_p.fsm.cambiar(&"Fall")
				_visto.clear()
				_cuerda = 3,
			func() -> bool:
				return _visto.has(&"SpearSwing") and not _visto.has(&"Slingshot"),
			"recoger un anclaje devuelve el pendulo: quien elige el verbo es el jugador"),

		# --- 3.12: LA Z ESTANDO ADHERIDO --------------------------------------
		# Los cuatro verbos de cuerda viven en `Attached`, que es el mismo grupo
		# al que perteneces cuando escalas. `GroupAttached` no llamaba a
		# `intentar_cuerda()`: **escalando o colgado de un canto la Z no hacia
		# nada**, y el sintoma era silencio. Se prueba por el camino de entrada
		# REAL —la tecla y el `InputBuffer`—, no forzando el estado.
		_chequeo_("adherido a la pared, agarrado de verdad", 0.6,
			func() -> void:
				_soltar_todo()
				_cuerda_fija = false
				for d in _p.dagas:
					if is_instance_valid(d):
						d.recuperar()
						d.estado = Anclaje.Estado.GUARDADO
				# Contra la pared escalable del Gym: centro (24,6,20), cara z=19.5.
				_p.global_position = Vector3(24.0, 0.3, 19.1)
				_p.velocity = Vector3.ZERO
				_p.stamina.llenar()
				# ENCARARLO, y no es cosmetica: `WallSensor` sondea hacia
				# `direccion_frontal()`, que sin velocidad devuelve la Z del visual.
				# Colocado sin girar, el jugador miraba hacia donde lo hubiera
				# dejado el chequeo anterior y la sonda frontal no encontraba el
				# muro — el mismo detalle que documenta `_ante_coloso` en el test
				# visual. De ahi que esta comprobacion saliera 1 de cada 2.
				_p.orientar_a(Vector3(0.0, 0.0, 1.0))
				# SALIR DEL ESTADO ANTERIOR A MANO. El chequeo de antes termina
				# BALANCEANDOSE, y `SpearSwing` es un estado de `Attached`: alli no
				# hay agarre automatico ni lo pide nadie, asi que el jugador se
				# quedaba colgado al lado del muro y esta comprobacion fallaba 1 de
				# cada 3. Cuando salia verde era porque un enemigo le habia pegado
				# y el `Hitstun` lo soltaba — o sea, dependiendo de la IA, que es
				# justo lo que CLAUDE.md prohibe.
				_p.fsm.cambiar(&"Fall")
				Input.action_press(&"grab")
				_l.global_position = Vector3(24.0, 9.0, 19.4)
				_l.fsm.cambiar(&"Embedded", {
					"punto": _l.global_position, "normal": Vector3.BACK})
				_visto.clear(),
			func() -> bool: return _p.fsm.nombre_actual() == &"Climb",
			"sin estar escalando de verdad, lo de abajo no probaria nada"),

		_chequeo_("y la Z sigue existiendo ahi", 0.8,
			func() -> void:
				_visto.clear()
				_cuerda = 4,
			func() -> bool: return _visto.has(&"SpearSwing") or _visto.has(&"SpearZip"),
			"la cuerda estaba en Grounded y en Airborne y NO en Attached: regla dura #13 del reves"),
	]


## Deja al jugador colgando entre los dos anclajes, con la lanza en A y el
## anclaje en B. Los dos se colocan a mano PORQUE lo que se mide aqui es la
## fisica del elastico; que se pueda LLEGAR a ponerlos lo comprueban los tres
## chequeos de arriba, cada uno por su boton.
func _colgar_entre(a: Vector3, b: Vector3, jugador: Vector3) -> void:
	_l.global_position = a
	_l.fsm.cambiar(&"Embedded", {"punto": a, "normal": Vector3.UP})
	_an.global_position = b
	_an.estado = Anclaje.Estado.CLAVADO
	_p.global_position = jugador
	_p.velocity = Vector3.ZERO
	_p.stamina.llenar()
	_p.momentum_libre = 0.0
	_p.fsm.cambiar(&"Fall")


func _physics_process(delta: float) -> void:
	_reloj += delta
	if _reloj > 60.0:
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
	# La cuerda mantenida necesita SOLTARSE de verdad al bajar la bandera. Dejar de
	# llamar a `action_press` no suelta nada: la accion se queda pulsada para
	# siempre, y la resortera —que dispara al soltar— no disparaba nunca. Hace
	# falta el flanco, no el nivel.
	if _cuerda_fija:
		Input.action_press(&"rope")
		_cuerda_suelta = false
	elif not _cuerda_suelta:
		Input.action_release(&"rope")
		_cuerda_suelta = true
	elif _cuerda > 0:
		Input.action_press(&"rope")
		_cuerda -= 1
		if _cuerda == 0:
			Input.action_release(&"rope")
	if _anclaje_boton > 0:
		Input.action_press(&"throw_anchor")
		_anclaje_boton -= 1
		if _anclaje_boton == 0:
			Input.action_release(&"throw_anchor")
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
	# Latch del retorno del anclaje: dura dos decimas, asi que preguntarlo al final
	# del chequeo mediria que ya ha llegado, no que haya volado.
	if _an != null and is_instance_valid(_an) and _an.estado == Anclaje.Estado.RETORNO:
		_visto[&"anclaje_volviendo"] = true
	# Resortera: la tension se mide MIENTRAS cuelgas —al soltar ya no existe— y el
	# disparo DESPUES de salir, que es donde se ve si el clamp global se lo come.
	if _p.fsm.nombre_actual() == &"Slingshot":
		_tension_max = maxf(_tension_max, float(_p.fsm.actual.get("_tension")))
	elif _midiendo_disparo:
		_disparo_vel = maxf(_disparo_vel, _p.velocity.length())
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


## Suelta TODAS las teclas Y APAGA LOS CONTADORES que las vuelven a pulsar.
##
## Las dos mitades hacen falta. `_cuerda`, `_zip` y compañia son cuentas atras que
## siguen pulsando su tecla en los frames siguientes: soltarla ahora no sirve de
## nada si el frame que viene la vuelve a pulsar. Con la Z ya viva estando
## adherido (3.12), una `_cuerda` heredada del chequeo anterior sacaba al jugador
## de `Climb` a `SpearSwing` en mitad de la medida — y solo a veces, segun cuantos
## frames le quedaran. Un test intermitente es peor que uno rojo.
func _soltar_todo() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
	_cuerda = 0
	_zip = 0
	_salto = 0
	_boton_lanza = 0
	_atk_lig = 0
	_atk_pes = 0
	_anclaje_boton = 0
	_cuerda_fija = false


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
	# NO AGARRABLE por defecto en las pruebas de la lanza: lo que miden es que
	# ATRAVIESA, y un bicho agarrable la pararia con razon. Quien quiera probar el
	# agarre lo pone a true expresamente.
	g.agarrable = false
	g.fsm.cambiar(&"Dormido")
	_victima = g
