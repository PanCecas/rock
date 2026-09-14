extends Node
## Test funcional de LA PATADA — el único movimiento ofensivo.
##
##   godot --headless --path . tools/TestPatada.tscn
##
## Comprueba las leyes del moveset una por una, igual que `TestCuerda`: empieza en
## el frame en que se pulsa, dura lo que dice su número, termina sola, el stick la
## dirige entera, y hay UNA por tiempo de vuelo.
##
## Y las dos que son suyas y de nadie más:
##
##   · **Cruza huecos aunque no golpee nada.** Es lo que la convierte en una
##     herramienta de movimiento en vez de en un ataque.
##   · **Conectar RECARGA.** Un enemigo pasa a ser una plataforma, y esa es la
##     frase entera del diseño: golpear es seguir moviéndote.
##
## **El anti-spam se mide aquí y no se da por supuesto.** La recarga es un FLANCO
## de contacto, no un nivel; sin esa distinción, patear a ras de suelo devuelve la
## carga en el mismo frame en que se gasta y machacar el botón es un dash continuo
## a 18 m/s. Tiene su propia comprobación.

const GUARDIAN := preload("res://src/enemies/Guardian.tscn")

var _main: Node
var _p: PlayerController
var _victima: Enemigo
var _ancla: Ancla

const ARRANQUE_MAX := 20.0
var _arranque: float = 0.0
var _paso: int = 0
var _t: float = 0.0
var _guion: Array = []
var _fallos: PackedStringArray = []
var _visto: Dictionary = {}
var _atacar: int = 0
## Machaque del Espacio: pulsa y suelta sin parar durante la comprobacion.
var _machacar_salto: bool = false
## Cuantas veces se ha ENTRADO en `Kick` dentro de la comprobacion actual.
var _patadas_contadas: int = 0
var _stick: float = 0.0
## Frames que faltan para empujar el stick, contados DENTRO del gesto.
var _stick_tras: int = -1
## Frames que faltan para pulsar SALTO, contados DENTRO del gesto.
var _saltar_tras: int = -1
var _cuerda: int = 0
var _ancla_viva: bool = false
var _ciclo_salto: int = 0

# --- Latches. Se miden MIENTRAS pasa: al cerrar la ventana el gesto ya acabó.
var _t_patada: float = 0.0
var _v_min: float = 9999.0
var _v_max: float = 0.0
var _y0: float = 0.0
var _dy: float = 0.0
var _origen: Vector3 = Vector3.ZERO
var _recorrido: float = 0.0
var _lateral: float = 0.0
var _frente: Vector3 = Vector3.ZERO
var _estado_prev: StringName = &""
var _v_salida: float = 0.0
## Velocidad en el primer frame observable del gesto. Es la medida del startup.
var _v_primera: float = 0.0
## Velocidad del plano justo ANTES de entrar en el gesto. Es contra esta contra la
## que se comprueba que la patada no resta.
var _v_antes: float = 0.0
var _v_plano_prev: float = 0.0
## Vertical mas alta vista DESPUES de conectar. Es el rebote.
var _vy_rebote: float = -99.0
## Frames que el juego se ha quedado PARADO durante el escenario. Es lo unico de
## un impacto que hoy se ve: `HitstopManager.congelar()` para `AnimationTree`s y
## este juego se prueba con capsulas grises (regla dura #7), asi que no hay
## animacion que parar. Si esto vale cero, conectar no se siente — y valia cero.
var _frames_pausa: int = 0
## Rumbo de la lanza ANTES de patearla, y si llego a cambiar.
##
## **Se engancha cuando pasa, no se lee al final.** La primera version comparaba
## el rumbo en el ultimo frame de la ventana y ahi la lanza ya podia haber
## seguido curvandose, haber aterrizado o haber recibido una segunda patada: el
## chequeo medía el final de una historia en vez del momento del verbo.
var _rumbo_antes: Vector3 = Vector3.ZERO
var _rumbo_vigilado: bool = false
var _rumbo_cambio: bool = false
## Mantiene al jugador PEGADO a la lanza mientras dure el chequeo.
##
## Colocarlo una sola vez no vale: la lanza sigue volando y la patada no sale en
## el frame en que se pulsa —el buffer, el grupo y las cargas se toman los suyos—,
## asi que cuando por fin salia, el blanco ya se habia ido. Pegandolo cada frame
## lo que se mide es la PATADA y no la punteria del banco.
var _pegado_a_la_lanza: bool = false


func _ready() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	await get_tree().physics_frame

	# UN TEST NO PUEDE DEPENDER DE LA IA (CLAUDE.md). El corral del Gym trae
	# enemigos despiertos y un golpe en mitad de una medida manda al jugador a
	# `Hitstun`: así es como se llega a una suite intermitente.
	for n in get_tree().get_nodes_in_group(&"enemigos"):
		var e := n as Enemigo
		if e != null and is_instance_valid(e):
			e.vista = 0.0

	# Un ancla de prueba para la cadena cuerda -> patada. Se recoloca cada frame
	# respecto a la camara, igual que en `TestCuerda`: el cono es parte de la
	# mecanica, asi que un ancla en coordenadas fijas probaria otra cosa segun
	# hacia donde mirase la camara ese dia.
	_ancla = Ancla.new()
	_ancla.name = "AnclaDePrueba"
	_main.add_child(_ancla)
	_ancla.global_position = Vector3(0.0, 60.0, 0.0)

	_construir()


## El ancla, colocada a 35 grados sobre la direccion de la camara y a 8 m del
## JUGADOR. Ver `TestCuerda._recolocar_ancla()` para el porque de los dos origenes.
func _recolocar_ancla() -> void:
	var cam := _p.camara()
	if cam == null:
		return
	var frente := -cam.global_basis.z
	var derecha := cam.global_basis.x.normalized()
	var arriba := frente.rotated(derecha, deg_to_rad(35.0))
	if arriba.y < frente.y:
		arriba = frente.rotated(derecha, -deg_to_rad(35.0))
	_ancla.global_position = _p.global_position + arriba.normalized() * 8.0


## Un Guardián quieto y ciego donde se le diga. Ciego porque lo que se mide es el
## golpe DEL JUGADOR: un enemigo que además ataca solo mete ruido.
func _plantar_victima(pos: Vector3) -> void:
	if _victima != null and is_instance_valid(_victima):
		_victima.queue_free()
	_victima = GUARDIAN.instantiate() as Enemigo
	_main.add_child(_victima)
	_victima.global_position = pos
	_victima.vista = 0.0
	_victima.ataque = null


func _construir() -> void:
	_guion = [
		# --- EL GESTO ---------------------------------------------------------
		_chequeo_("el botón da una patada", 0.4,
			func() -> void:
				_colocar(Vector3(0.0, 8.0, 20.0))
				_atacar = 4,
			func() -> bool: return _visto.has(&"Kick"),
			"si el botón no patea, no hay mecánica que probar"),

		_chequeo_("no tiene anticipación: el primer frame ya es el bueno", 0.1,
			func() -> void: pass,
			func() -> bool:
				# Dos mitades de la misma ley. En los DATOS, cero frames de
				# windup —que es la unidad en la que se piensa el combate aqui—;
				# y en el JUEGO, velocidad de crucero desde el primer frame que
				# se puede observar.
				#
				# Contar frames entre la pulsación y el cambio de estado —que es
				# lo que hacía antes— mide el ORDEN DE LOS NODOS tanto como el
				# juego: con un umbral apretado falla por fontanería y con uno
				# holgado no afirma nada.
				var d: AttackData = _p.ataque_patada
				return (d != null and d.frames_windup == 0
					and _v_primera > _p.tuning.patada_velocidad - 0.6),
			"una patada que empieza quieta es un telegrafiado, y esto no telegrafia"),

		_chequeo_("dura lo que dice su número y termina sola", 0.6,
			func() -> void: pass,
			func() -> bool:
				var tope: float = _p.tuning.patada_duracion
				return (_p.fsm.nombre_actual() != &"Kick"
					and _t_patada > 0.0 and _t_patada <= tope + 0.05),
			"un gesto que se sostiene deja de ser un gesto (regla dura #27)"),

		_chequeo_("a velocidad CONSTANTE", 0.1,
			func() -> void: pass,
			func() -> bool:
				var v: float = _p.tuning.patada_velocidad
				return absf(_v_min - v) < 0.6 and absf(_v_max - v) < 0.6,
			"si acelera o frena, la trayectoria deja de poder leerse antes de pulsar"),

		# LA GRAVEDAD LA TOCA, PERO A UNA FRACCION, y ese es el cambio del 4.04.
		#
		# Antes estaba apagada del todo y el chequeo pedia `_dy < 0.25`: cero caida.
		# Eso es lo que se reporto como «parece que vuelas» — un planeo horizontal
		# de un cuarto de segundo. Ahora describe un ARCO, asi que lo que hay que
		# afirmar es que cae MENOS que en caida libre, no que no cae.
		#
		# En 0.25 s de caida libre a -38 se pierden 1.19 m. Con el impulso de
		# entrada, la patada sube en vez de bajar; el tope de abajo es generoso a
		# proposito porque lo que se prohibe es la caida LIBRE, no un numero.
		_chequeo_("la gravedad la toca, pero a una fraccion", 0.1,
			func() -> void: pass,
			func() -> bool: return _dy < 0.9,
			"con la gravedad apagada del todo, patear se ve como volar"),

		# --- CRUZA HUECOS -----------------------------------------------------
		_chequeo_("cruza un hueco sin golpear nada", 0.6,
			func() -> void:
				_colocar(Vector3(0.0, 8.0, 20.0))
				_atacar = 4,
			func() -> bool:
				# 0.25 s a 18 m/s son 4.5 m. Con margen para el frame de entrada.
				var esperado: float = (_p.tuning.patada_duracion
					* _p.tuning.patada_velocidad) * 0.8
				return _recorrido >= esperado,
			"es una herramienta de movimiento antes que un ataque, y eso se mide"),

		# EL STICK SE PIDE A MITAD DEL GESTO, Y NO AL PULSAR.
		#
		# Empujando desde el principio esto no probaría nada: la patada LEE el
		# stick al entrar para elegir su dirección, así que saldría recta hacia
		# donde ya estabas empujando y el desvío sería cero. La ley que hay que
		# comprobar es otra —"autoridad direccional durante TODO el movimiento"—
		# y solo se ve cambiando de idea a mitad.
		_chequeo_("el stick la DIRIGE a mitad del gesto", 0.6,
			func() -> void:
				_colocar(Vector3(0.0, 8.0, 20.0))
				_atacar = 4
				_stick_tras = 5,
			func() -> bool: return _lateral > 0.4,
			"sin autoridad direccional es una animación con la que se colisiona"),

		# --- CONECTAR ---------------------------------------------------------
		_chequeo_("conectar DERROTA de un golpe", 1.0,
			func() -> void:
				_stick = 0.0
				_plantar_victima(Vector3(6.0, 0.3, 20.0))
				_colocar(Vector3(0.0, 0.9, 20.0))
				_p.call("orientar_a", Vector3.RIGHT)
				_atacar = 4,
			func() -> bool:
				return _victima == null or not is_instance_valid(_victima) \
					or not _victima.salud.vivo,
			"un golpe que no resuelve nada devuelve el combate al machaque"),

		_chequeo_("y RECARGA la cuerda y la patada", 0.1,
			func() -> void: pass,
			func() -> bool: return _p.cuerda_disponible and _p.patada_cargas > 0,
			"el enemigo es una plataforma: golpearle es SEGUIR moviéndote"),

		_chequeo_("y te devuelve ARRIBA", 0.1,
			func() -> void: pass,
			func() -> bool: return _vy_rebote > _p.tuning.patada_rebote * 0.7,
			"sin rebote, golpear es el final de una linea en vez de un eslabon"),

		# Y EL GOLPE PARA EL JUEGO. Regla dura #31: el chequeo de arriba mira la
		# MAGNITUD del rebote, pero el rebote puede estar perfecto y el golpe no
		# sentirse igualmente. Medido antes de arreglarlo: **0 frames de pausa**.
		# La pausa se pedia de un frame y se descontaba en el mismo tick en que se
		# pedia, asi que no llegaba a existir para nadie.
		_chequeo_("y PARA el juego un instante", 0.1,
			func() -> void: pass,
			func() -> bool: return _frames_pausa >= 3,
			"un golpe que no para nada no se siente; es lo unico que hoy se ve"),

		# --- PATEAR TU PROPIA ARMA LANZADA ------------------------------------
		# Conectar con un enemigo lo MATA en el acto, asi que sobre el no hay
		# segundo pogo. La lanza es lo unico que sobrevive a la patada, y desde el
		# 4.05 lo que la patada le hace no es tirarla: la REDIRIGE.
		#
		# El 4.02 la paraba a flotar y la patada la mandaba al suelo. Se reporto
		# que eso estaba mal por los dos lados —«que no se quede pausada» y «al
		# patearla que cambie de trayectoria»— y tenian razon: una diana que se
		# cae es un escalon de un solo uso, y el verbo del documento es redirigir.
		_chequeo_("la lanza tirada se alcanza EN VUELO", 0.35,
			func() -> void:
				_colocar(Vector3(0.0, 10.0, 34.0))
				var l: Spear = _p.lanza
				if l != null and is_instance_valid(l):
					l.fsm.cambiar(&"Wielded")
					l.lanzar(_p.global_position, Vector3.RIGHT),
			func() -> bool:
				var l: Spear = _p.lanza
				return (l != null and is_instance_valid(l)
					and l.fsm.nombre_actual() == &"InFlight"
					and l.hurtbox != null and l.hurtbox.collision_layer != 0),
			"si no se puede alcanzar en el aire, no hay nada que redirigir"),

		# Y AL PATEARLA CAMBIA DE RUMBO. Se mide el rumbo, no el estado: seguir en
		# `InFlight` es lo que hacia antes de la patada tambien (regla dura #31).
		_chequeo_("y al patearla CAMBIA DE RUMBO", 0.4,
			func() -> void:
				var l: Spear = _p.lanza
				if l != null and is_instance_valid(l):
					_rumbo_antes = l.direccion
					_rumbo_cambio = false
					_rumbo_vigilado = true
					# Mirando hacia -Z, que es perpendicular al rumbo que llevaba:
					# asi el cambio no se puede confundir con la curva que la
					# gravedad le estaba dando de todas formas.
					_pegado_a_la_lanza = true
					_p.fsm.cambiar(&"Fall")
					_p.reset_physics_interpolation()
				_vy_rebote = -99.0
				# LA MARCA SE PONE AQUI, en el frame de la patada, y no antes:
				# mientras la lanza vuela el jugador CAE, y si le da tiempo a
				# aterrizar el suelo le recarga el moveset y el chequeo siguiente
				# culpa a la patada de lo que hizo el suelo.
				_p.cuerda_disponible = false
				_atacar = 4,
			func() -> bool:
				_rumbo_vigilado = false
				_pegado_a_la_lanza = false
				return _rumbo_cambio,
			"si el rumbo no cambia, patearla no es un verbo: es un adorno"),

		_chequeo_("y ademas te rebota", 0.1,
			func() -> void: pass,
			func() -> bool: return _vy_rebote > _p.tuning.patada_rebote * 0.7,
			"sin rebote, alcanzarla en el aire no te devuelve nada"),

		# Y LA REGLA QUE LA HACE SOSTENIBLE. La ley 4 recarga el moveset al tocar
		# suelo, pared o enemigo: tres cosas que pone el NIVEL. Tu lanza la pones
		# tu, asi que recargar pateandola seria una maquina de movimiento perpetuo
		# con dos pasos —tirar, patear, recargar, recuperar, tirar—.
		_chequeo_("pero NO recarga el moveset", 0.1,
			func() -> void: pass,
			func() -> bool: return not _p.cuerda_disponible,
			"recargar con tus propias cosas es un movimiento perpetuo con pasos extra"),

		# LOS TRES RECURSOS AEREOS SON UN PRESUPUESTO, NO TRES CUENTAS.
		#
		# El salto aereo se reponia solo desde el suelo, el agua, un canto, un parry
		# y el wall-jump: tocar una PARED o acertar una PATADA devolvian la cuerda y
		# las patadas pero NO el salto. En mitad de una cadena el boton dejaba de
		# responder mientras los otros dos seguian vivos, y eso se lee como que el
		# salto esta roto y no como que se ha gastado.
		_chequeo_("y el salto aéreo vuelve con ellas", 0.1,
			func() -> void: pass,
			func() -> bool: return _p.saltos_aereos >= _p.tuning.saltos_aereos,
			"tres recursos aéreos y dos cuentas distintas es una cuenta de más"),

		# --- UNA POR TIEMPO DE VUELO ------------------------------------------
		_chequeo_("sin cargas, en el aire no hay patada", 0.7,
			func() -> void:
				_colocar(Vector3(0.0, 14.0, 20.0))
				_p.patada_cargas = 0
				_visto.clear()
				_atacar = 8,
			func() -> bool: return not _visto.has(&"Kick"),
			"la carga es la moneda: sin ella cada patada dejaría de costar nada"),

		_chequeo_("tocar suelo la devuelve", 1.8,
			func() -> void:
				_soltar_todo()
				_colocar(Vector3(0.0, 3.0, 20.0))
				_p.patada_cargas = 0,
			func() -> bool: return _p.patada_cargas > 0,
			"si no se recargara al aterrizar sería de un solo uso por partida"),

		# --- EL ANTI-SPAM -----------------------------------------------------
		#
		# **ESTA COMPROBACION SE REESCRIBIO EN EL 4.06, y no por gusto.** Antes
		# pateaba A RAS DE SUELO machacando el boton de ataque, y esa situacion ya
		# no se puede montar: en el suelo el Espacio SALTA. La ley que protegia
		# —*la recarga es un FLANCO de contacto, no un nivel*— sigue siendo la
		# misma y sigue importando, asi que lo que cambia es donde se pregunta: en
		# el AIRE, machacando, el presupuesto tiene que agotarse y no rellenarse.
		#
		# Su pareja, «tocar suelo la devuelve», cubre la otra mitad: el flanco SI
		# recarga. Las dos juntas dicen lo mismo que decia la vieja sola.
		_chequeo_("machacando en el aire el presupuesto SE AGOTA", 1.0,
			func() -> void:
				_soltar_todo()
				# Alto y sin nada que rozar: cualquier recarga que salga aqui es
				# una recarga inventada.
				_p.global_position = Vector3(0.0, 30.0, 20.0)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Fall")
				_p.recargar_moveset()
				_patadas_contadas = 0
				_visto.clear()
				_machacar_salto = true,
			func() -> bool:
				return (_patadas_contadas == _p.tuning.patada_cargas
					and _p.patada_cargas <= 0)
				,
			"con la recarga como NIVEL, machacar el botón sería un dash continuo"),

		_chequeo_("pero saltar y caer sí", 1.8,
			func() -> void:
				_soltar_todo()
				_p.global_position = Vector3(0.0, 3.0, 20.0)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Fall"),
			func() -> bool: return _p.patada_cargas > 0,
			"la recarga es un gesto —salir y volver—, no una cuenta atrás"),

		# --- EL AGUA NO SE PATEA ----------------------------------------------
		_chequeo_("en el agua no hay patada", 1.2,
			func() -> void:
				_soltar_todo()
				# El estanque del Gym, en (28, 0, -28).
				_p.global_position = Vector3(28.0, 6.0, -28.0)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Fall")
				_p.patada_cargas = _p.tuning.patada_cargas
				_visto.clear()
				_atacar = 10,
			func() -> bool:
				return _visto.has(&"Swim") and not _visto.has(&"Kick"),
			"nadar es traversal puro: una patada dentro se salta la física del medio"),

		# --- LA PATADA NO RESTA ------------------------------------------------
		# Es el defecto que se arreglo en la segunda pasada y el que mas se notaba:
		# escribia 18 m/s cada frame, asi que entrar lanzado y patear te QUITABA
		# velocidad. Medido antes del arreglo: 29.8 -> 18.0.
		_chequeo_("entrando lanzado, NO te quita velocidad", 0.7,
			func() -> void:
				_colocar(Vector3(0.0, 12.0, 20.0))
				# El permiso de momentum, a mano: sin el, el clamp global (22) se
				# comeria los 30 antes de que la patada pudiera heredarlos y la
				# medida culparia a la patada de lo que hace el clamp.
				_p.velocity = Vector3.RIGHT * 30.0
				_atacar = 4,
			func() -> bool:
				return _v_antes > 25.0 and _v_max > _v_antes - 0.6,
			"una patada que te frena convierte encadenar en un castigo"),

		_chequeo_("y sale con ella puesta", 0.1,
			func() -> void: pass,
			func() -> bool: return _v_salida > _v_antes - 1.5,
			"la ley 5 del rediseño: encadenar limpio acumula velocidad"),

		# --- SE PUEDE SALIR DE ELLA -------------------------------------------
		# LA CUERDA LA CORTA. **Ya no el salto**, y no es una perdida: desde el 4.04
		# Espacio en el aire ES la patada, asi que pulsarlo a mitad de una encadena
		# otra —que es justamente poder seguir mandando— en vez de cancelarla.
		# Lo que sigue teniendo que poder interrumpirla es un verbo DISTINTO.
		_chequeo_("tirar de la cuerda la corta", 0.9,
			func() -> void:
				_soltar_todo()
				_colocar(Vector3(0.0, 16.0, 20.0))
				_ancla_viva = true
				_atacar = 4
				_cuerda = 10,
			func() -> bool: return _visto.has(&"Grapple"),
			"quince frames sin poder actuar son quince frames sin ser el dueño"),

		# --- LA CADENA, que es el criterio de exito ---------------------------
		_chequeo_("colgarse del ancla", 0.6,
			func() -> void:
				_colocar(Vector3(0.0, 12.0, 20.0))
				_ancla_viva = true
				_cuerda = 4,
			func() -> bool: return _visto.has(&"Grapple"),
			"primero hay que colgarse para poder encadenar"),

		_chequeo_("y patear DESDE el arco", 0.6,
			func() -> void:
				_visto.clear()
				_atacar = 4,
			func() -> bool: return _visto.has(&"Kick"),
			"la cadena cuerda -> patada es el criterio de exito: sin esto no existe"),

		# --- SALIDA -----------------------------------------------------------
		_chequeo_("al terminar CONSERVA la velocidad", 0.7,
			func() -> void:
				_soltar_todo()
				_colocar(Vector3(0.0, 10.0, 20.0))
				_atacar = 4,
			func() -> bool:
				return _v_salida > _p.tuning.patada_velocidad * 0.75,
			"frenar al acabar convertiría el remate de una línea en un frenazo"),
	]


func _colocar(pos: Vector3) -> void:
	_soltar_todo()
	# LOS VERBOS QUE DEJO PEDIDOS EL ESCENARIO ANTERIOR. Sin esto, un chequeo que
	# pulsa la Z deja el contador corriendo y el ancla viva, y el siguiente empieza
	# con medio gesto ya hecho: el fallo aparece en el chequeo de al lado y parece
	# suyo.
	_cuerda = 0
	_ancla_viva = false
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.stamina.llenar()
	_p.cuerda_disponible = true
	# Y SE OLVIDA EL ANCLA USADA. Todos los chequeos comparten el mismo nodo
	# `Ancla`, y desde el 4.01 la que acabas de soltar queda vetada hasta que
	# toques el mundo: sin esto, el escenario siguiente no podia engancharse y el
	# fallo salia en un chequeo que no tenia nada que ver.
	_p.ultima_ancla = null
	_p.patada_cargas = _p.tuning.patada_cargas
	_p.fsm.cambiar(&"Fall")
	_visto.clear()
	_t_patada = 0.0
	_v_min = 9999.0
	_v_max = 0.0
	_y0 = pos.y
	_dy = 0.0
	_origen = pos
	_recorrido = 0.0
	_lateral = 0.0
	_frente = Vector3.ZERO
	_v_salida = 0.0
	_v_primera = 0.0
	_v_antes = 0.0
	_vy_rebote = -99.0
	_frames_pausa = 0
	_stick_tras = -1
	_saltar_tras = -1


func _soltar_todo() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
	_atacar = 0
	_machacar_salto = false
	_ciclo_salto = 0
	_stick = 0.0
	_stick_tras = -1
	_saltar_tras = -1
	_cuerda = 0
	_ancla_viva = false


func _physics_process(delta: float) -> void:
	if _guion.is_empty():
		_arranque += delta
		if _arranque > ARRANQUE_MAX:
			push_error("TestPatada: el guion no se construyo en %.0f s" % ARRANQUE_MAX)
			print("RESULTADO PATADA: 0/0 — el guion no llego a construirse.")
			set_physics_process(false)
			get_tree().quit(1)
		return
	if _paso >= _guion.size():
		_informe()
		return
	_t += delta

	# --- Teclas. Siempre por el InputMap: forzar el estado no probaria que se
	#     pueda LLEGAR a el.
	# EL ANCLA SE CONGELA AL ENGANCHAR: seguir recolocandola contra la camara
	# mientras cuelgas la mueve DEBAJO del jugador y el radio deja de significar
	# nada. Mismo motivo que en `TestCuerda`.
	if _ancla_viva and _p.fsm.nombre_actual() != &"Grapple":
		_recolocar_ancla()
	if _machacar_salto:
		# Dos frames pulsado y dos sueltos: sin el hueco,
		# `is_action_just_pressed` no vuelve a dispararse.
		_ciclo_salto = (_ciclo_salto + 1) % 4
		if _ciclo_salto < 2:
			Input.action_press(&"jump")
		else:
			Input.action_release(&"jump")
	# LA PATADA SE PIDE CON EL SALTO, no con el boton de ataque.
	#
	# Es el cambio del 4.06: `attack_light` es de la espada y en el aire el Espacio
	# patea. El test se conducia con el click y con eso media un boton que ya no
	# hace nada — 13 de 27 en rojo y todas con `patada=0.00s`, que es como se lee
	# "el gesto no llego a existir".
	if _atacar > 0:
		Input.action_press(&"jump")
		_atacar -= 1
		if _atacar == 0:
			Input.action_release(&"jump")
	if _cuerda > 0:
		Input.action_press(&"rope")
		_cuerda -= 1
		if _cuerda == 0:
			Input.action_release(&"rope")
	if _saltar_tras > 0:
		_saltar_tras -= 1
		if _saltar_tras == 0:
			Input.action_press(&"jump")
	elif _saltar_tras == 0:
		Input.action_release(&"jump")
		_saltar_tras = -1
	if is_zero_approx(_stick):
		Input.action_release(&"move_right")
	else:
		Input.action_press(&"move_right")

	# --- Latches.
	var estado := _p.fsm.nombre_actual()
	_visto[estado] = true
	var plano_ahora := _p.superficie.plano(_p.velocity).length()
	if estado == &"Kick":
		if _estado_prev != &"Kick":
			_v_antes = _v_plano_prev
			_t_patada = 0.0
			_y0 = _p.global_position.y
			_origen = _p.global_position
			_frente = _p.superficie.plano(_p.velocity).normalized()
			_v_primera = _p.velocity.length()
		elif _stick_tras > 0:
			_stick_tras -= 1
			if _stick_tras == 0:
				_stick = 1.0
		_t_patada += delta
		var v := plano_ahora
		_v_min = minf(_v_min, v)
		_v_max = maxf(_v_max, v)
		# CUANTO CAE, con signo. Antes era el desvio ABSOLUTO, y eso valia mientras
		# la patada tuviera la gravedad apagada —no se movia en vertical, asi que
		# subir o bajar daba igual—. Desde que describe un arco SUBE casi un metro,
		# y un desvio absoluto contaba esa subida como si se estuviera cayendo.
		_dy = maxf(_dy, _y0 - _p.global_position.y)
		_recorrido = maxf(_recorrido, _p.global_position.distance_to(_origen))
		# Desvio LATERAL respecto a la direccion en la que salio: sin stick, una
		# patada va recta, asi que todo lo que haya aqui lo ha puesto el jugador.
		if not _frente.is_zero_approx():
			var lado := _frente.cross(_p.superficie.up).normalized()
			_lateral = maxf(_lateral, absf((_p.global_position - _origen).dot(lado)))
	elif _estado_prev == &"Kick":
		_v_salida = plano_ahora
		_vy_rebote = maxf(_vy_rebote, _p.superficie.vertical(_p.velocity))
	if _rumbo_vigilado:
		var lv: Spear = _p.lanza
		if lv != null and is_instance_valid(lv):
			if _pegado_a_la_lanza and not _rumbo_cambio:
				_p.global_position = lv.global_position + Vector3(0.0, -0.3, 1.5)
				_p.velocity = Vector3.ZERO
				_p.call("orientar_a", Vector3.FORWARD)
			if lv.direccion.dot(_rumbo_antes) < 0.6:
				_rumbo_cambio = true
	if HitstopManager.global_activo():
		_frames_pausa += 1
	if estado == &"Kick" and _estado_prev != &"Kick":
		_patadas_contadas += 1
	_v_plano_prev = plano_ahora
	_estado_prev = estado

	# --- El guion.
	var actual: Dictionary = _guion[_paso]
	if is_zero_approx(_t - delta):
		(actual["hacer"] as Callable).call()
	if _t >= float(actual["dur"]):
		if not (actual["chequeo"] as Callable).call():
			_fallos.append("%-40s %s\n      [estado=%s  patada=%.2fs  v=%.1f..%.1f  rec=%.1f  lat=%.2f]" % [
				actual["nombre"], actual["porque"], estado, _t_patada,
				_v_min if _v_min < 9999.0 else 0.0, _v_max, _recorrido, _lateral])
		else:
			print("  OK    %s" % actual["nombre"])
		_paso += 1
		_t = 0.0


func _informe() -> void:
	set_physics_process(false)
	print("RESULTADO PATADA: %d/%d comprobaciones." % [
		_guion.size() - _fallos.size(), _guion.size()])
	if not _fallos.is_empty():
		print("--- FALLOS ---")
		for f in _fallos:
			print("  " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)


func _chequeo_(nombre: String, dur: float, hacer: Callable, chequeo: Callable, porque: String) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "chequeo": chequeo, "porque": porque}
