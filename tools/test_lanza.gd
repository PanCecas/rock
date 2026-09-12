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
## La vista original de cada enemigo mientras dura una medida. Ver `_pacificar()`.
var _vista_guardada: Dictionary = {}
var _visto: Dictionary = {}
var _aux: float = 0.0
var _origen: Vector3 = Vector3.ZERO
var _salto: int = 0
var _boton_lanza: int = 0
var _atk_lig: int = 0
## Latch de altura. Se mide MIENTRAS pasa, no al final: cuando termina la ventana
## del chequeo la pertiga ya ha subido y ha vuelto a caer.
var _alto_max: float = -99.0
var _dist_min: float = 9999.0


func _ready() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	await get_tree().physics_frame
	_l = _p.lanza
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

		# EMPUÑAR Y DESEMPUÑAR. El INTERCAMBIO DE MOVESET que se comprobaba aqui
		# —seis chequeos: ligero, pesado, sus dos versiones aereas y el eje de
		# cada par— se fue con el combate en el parche 4.00. La lanza ya no
		# cambia como pegas, porque solo hay una forma de pegar.
		#
		# Lo que SI sigue siendo verdad es el gesto: tirarla es desequiparla, y
		# por eso lanzarla es una decision y no un tramite.
		_chequeo_("y tirarla la desempuna", 1.2,
			func() -> void:
				_p.global_position = Vector3(0.0, 0.05, 33.0)
				_p.velocity = Vector3.ZERO
				_p.call("orientar_a", Vector3(0, 0, -1))
				_boton_lanza = 3,
			func() -> bool: return not _p.lanza_empunada(),
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

		_chequeo_("el imantado no supera su tope", 0.4,
			func() -> void: pass,
			func() -> bool:
				var t: SpearTuning = _l.tuning
				return t.imantado_grados > 0.0 and t.imantado_grados <= 15.0,
			"pasado ese punto la lanza apunta por ti y acertar no significa nada"),

	]


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
	if _boton_lanza > 0:
		Input.action_press(&"throw_spear")
		_boton_lanza -= 1
		if _boton_lanza == 0:
			Input.action_release(&"throw_spear")
	if _salto > 0:
		Input.action_press(&"jump")
		_salto -= 1
		if _salto == 0:
			Input.action_release(&"jump")
	_visto[_p.fsm.nombre_actual()] = true
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


## Suelta TODAS las teclas Y APAGA LOS CONTADORES que las vuelven a pulsar.
##
## Las dos mitades hacen falta. `_salto`, `_atk_lig` y compañia son cuentas atras
## que siguen pulsando su tecla en los frames siguientes: soltarla ahora no sirve
## de nada si el frame que viene la vuelve a pulsar. Una cuenta heredada del
## chequeo anterior saca al jugador del estado en mitad de la medida — y solo a
## veces, segun cuantos frames le quedaran. Un test intermitente es peor que uno
## rojo.
func _soltar_todo() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
	_salto = 0
	_boton_lanza = 0
	_atk_lig = 0


func _chequeo_(nombre: String, dur: float, hacer: Callable, chequeo: Callable, porque: String) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "chequeo": chequeo, "porque": porque}
