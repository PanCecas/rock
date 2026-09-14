extends Node
## BANCO DE LA ESPADA. Mide lo que se siente, no lo que se cree.
##
##   godot --headless --path . tools/MedirEspada.tscn
##
## Seis preguntas, y ninguna se puede contestar leyendo el codigo:
##
##   1. ¿El corte te FRENA? Es la que define el arma. La patada es el verbo que
##      te mueve; si el corte tambien tocara la velocidad, serian dos versiones
##      del mismo gesto y una sobraria.
##   2. ¿Dura lo que dice y termina solo? Regla dura #27.
##   3. ¿Se puede machacar el boton? Y —lo que de verdad importa— ¿se TRAGA la
##      pulsacion que llega durante la recuperacion? Una pulsacion tragada sin
##      efecto es indistinguible de un boton que no responde.
##   4. ¿Conectar PARA el mundo? Se mide en FRAMES de pausa, no en el nombre del
##      estado al que lleva (regla dura #31). Es lo unico que hoy se ve de un
##      golpe: no hay animaciones que congelar.
##   5. ¿Vuelve sola, y cuanto tarda? Un bumeran que hay que ir a recoger es una
##      lanza con pasos extra.
##   6. **¿AL PATEARLA VA AL ENEMIGO MAS CERCANO?** Es el encargo literal. Se
##      mide por el ANGULO entre el rumbo de la espada y el enemigo, antes y
##      despues — no por el nombre del estado, que es lo que la regla #31
##      prohibe, y no con un valor absoluto, que es lo que prohibe la #22.
##
## **Con fila de control donde la admite.** Un numero sin su control no dice
## nada: "cortando sales a 19.4 m/s" solo significa algo al lado de "sin cortar,
## 19.4".

## Frames de la ventana en la que se compara la velocidad. Las dos filas —la que
## corta y la de control— miden EXACTAMENTE la misma, o no se estan comparando.
const VENTANA := 40
## Hacia donde patea el jugador en las filas del pogo. Cruzada con el rumbo de
## vuelo de la espada (+X) para que el cambio se pueda leer.
const _PATADA_DIR := Vector3.FORWARD

var _main: Node
var _p: PlayerController
var _e: Sword
var _cerca: Enemigo
var _lejos_e: Enemigo

var _paso: int = 0
var _t: float = 0.0
var _guion: Array = []
var _lineas: PackedStringArray = []
## TRAZA DE ESTADOS DEL ARMA, con el numero de fila al lado.
##
## Se queda puesta porque se gano el sitio: dos veces en la misma sesion, una fila
## dio un numero perfectamente plausible que era de otra cosa, y las dos se
## resolvieron mirando esta lista. Un banco que solo imprime resultados no puede
## decirte que el experimento no llego a ocurrir.
var _traza: PackedStringArray = []

# --- Pulsadores. Frames que queda pulsado cada boton.
var _cortar: int = 0
var _tirar: int = 0
## Machaque: pulsa y suelta sin parar durante la medida.
var _machacar: bool = false
var _ciclo: int = 0
## Ciclo propio del pulsador del tiro, para no pelearse con el del machaque.
var _ciclo_tiro: int = 0
## Pegar al jugador a la espada cada frame. La patada no sale en el frame de la
## pulsacion —pasa por el buffer y por el grupo— asi que colocarlo una vez y
## esperar deja al arma fuera de alcance cuando el golpe llega de verdad.
var _pegado: bool = false
var _pegado_dir: Vector3 = Vector3.RIGHT

# --- Latches del corte.
var _cortes: int = 0
var _en_corte: bool = false
var _frames_corte: int = 0
var _frames_corte_ultimo: int = 0
var _estado_al_cortar: StringName = &"—"
var _pausa: int = 0
var _victima_vida: float = -1.0
var _victima_murio: bool = false
## ¿Se llego a plantar una victima en esta medida? Sin esto, "no existe" y "ha
## muerto" son el mismo null.
var _planto: bool = false

# --- La ventana de velocidad.
var _fr: int = 0
var _v_inicial: float = -1.0
var _v_final: float = -1.0

# --- Latches del vuelo.
var _lejos: float = 0.0
var _origen_vuelo: Vector3 = Vector3.ZERO
var _vuelta_t: float = -1.0
var _vuelve_sola: bool = false

# --- Latches de la patada. Lo que prueba el verbo es el CAMBIO de rumbo, y un
#     cambio necesita las dos fotos.
var _rumbo_antes: Vector3 = Vector3.ZERO
var _rumbo_despues: Vector3 = Vector3.ZERO
var _grados_antes: float = -1.0
var _grados_despues: float = -1.0
var _elegido: String = "NO SE LLEGO A PATEAR"
var _pateada: bool = false
var _d_cerca: float = -1.0
var _d_lejos: float = -1.0
var _vy_rebote: float = -99.0
var _cuerda_tras_pogo: String = "?"
## Pendiente de leer la vertical del rebote en el frame siguiente al golpe.
var _leer_rebote: bool = false


func _ready() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	await get_tree().physics_frame
	await get_tree().physics_frame
	_e = _p.espada
	if _e == null:
		push_error("MedirEspada: el jugador no tiene espada")
		get_tree().quit(1)
		return
	# EL LATCH DE LA PATADA VA POR SEÑAL, no comparando el nombre del estado con
	# el del frame anterior. Sin enemigo cerca la espada REENTRA en `InFlight`, o
	# sea que el nombre no cambia y la comparacion no ve nada: la fila de control
	# salia vacia y parecia que la patada no existia. `cambiar()` emite tambien en
	# las reentradas, que es justo lo que hay que escuchar.
	_e.estado_cambiado.connect(_al_cambiar_espada)
	# LOS CORTES SE CUENTAN POR SEÑAL, no viendo pasar el estado `Swing`.
	#
	# Un corte termina y el siguiente empieza DENTRO DEL MISMO FRAME —la espada
	# vuelve a `Wielded` en su `_physics_process` y el jugador la vuelve a sacar en
	# el suyo, que corre despues—, asi que un muestreo por frame nunca ve la
	# casilla intermedia. Medido con un sondeo: `CORTE 15/16` y al frame siguiente
	# `CORTE 0/16`, sin un solo frame de `Wielded` entre medias.
	#
	# El contador decia **1 corte por segundo** cuando de verdad salian cuatro. Es
	# la regla dura #31 vista desde el otro lado: no basta con no fiarse del nombre
	# del estado al que llegas — tampoco se puede contar cuantas veces lo ves.
	_e.corte.connect(func() -> void: _cortes += 1)
	_e.estado_cambiado.connect(func(n: StringName) -> void: _traza.append('%s@paso%d' % [n, _paso]))
	_pacificar()
	_construir()


## Los enemigos del Gym no pueden estar atacando en mitad de una medida: es la
## misma razon por la que `TestFase2` los pacifica, ya escrita en CLAUDE.md.
func _pacificar() -> void:
	for n in get_tree().get_nodes_in_group(&"enemigos"):
		var e := n as Enemigo
		if e != null and is_instance_valid(e):
			e.vista = 0.0
			e.ataque = null


func _construir() -> void:
	_guion = [
		# =====================================================================
		# 1) ¿EL CORTE TE FRENA? La pregunta que define el arma.
		#    En el AIRE y sin stick: ahi la horizontal solo la puede tocar quien
		#    la escriba a proposito, asi que cualquier diferencia es del corte.
		# =====================================================================
		_medida("CONTROL: volar sin cortar", 0.9,
			func() -> void:
				_colocar(Vector3(0.0, 14.0, 18.0), 20.0),
			func() -> String:
				return "v %5.1f -> %5.1f m/s   cortes 0" % [_v_inicial, _v_final]),

		_medida("volar Y CORTAR", 0.9,
			func() -> void:
				_colocar(Vector3(0.0, 14.0, 18.0), 20.0)
				_cortar = 3,
			func() -> String:
				return "v %5.1f -> %5.1f m/s   cortes %d   desde %s" % [
					_v_inicial, _v_final, _cortes, _estado_al_cortar]),

		# =====================================================================
		# 2) ¿DURA LO QUE DICE Y TERMINA SOLO?
		# =====================================================================
		_medida("cuanto dura el corte", 0.9,
			func() -> void:
				_colocar(Vector3(0.0, 14.0, 18.0), 0.0)
				_cortar = 3,
			func() -> String:
				var datos := _e.ataque
				var dice: int = datos.total_frames() if datos != null else 0
				return "%d frames medidos / %d que dice el .tres   acaba en %s" % [
					_frames_corte_ultimo, dice, _e.fsm.nombre_actual()]),

		# =====================================================================
		# 3) ¿SE PUEDE MACHACAR? Control: el maximo teorico del .tres.
		# =====================================================================
		_medida("machacar el boton 1 s", 1.0,
			func() -> void:
				_colocar(Vector3(0.0, 14.0, 18.0), 0.0)
				_machacar = true,
			func() -> String:
				var datos := _e.ataque
				var techo: float = 60.0 / maxf(1.0, float(datos.total_frames()))
				return "%d cortes   (el techo del .tres son %.1f)   jugador: %s" % [
					_cortes, techo, _p.fsm.nombre_actual()]),

		# =====================================================================
		# 4) ¿CONECTAR PARA EL MUNDO? Regla dura #31: la magnitud, no el estado.
		# =====================================================================
		_medida("CONTROL: cortar al aire", 0.7,
			func() -> void:
				_borrar_enemigos()
				_colocar(Vector3(0.0, 14.0, 18.0), 0.0)
				_cortar = 3,
			func() -> String:
				return "PAUSA %d frames   victima: sin tocar" % _pausa),

		_medida("cortar a un enemigo", 0.9,
			func() -> void:
				_borrar_enemigos()
				_colocar(Vector3(0.0, 0.9, 18.0), 0.0)
				_cerca = _plantar(Vector3(1.9, 0.3, 18.0), "Cerca")
				_mirar(Vector3.RIGHT)
				_cortar = 3,
			func() -> String:
				return "PAUSA %d frames   %d corte   victima: %s" % [
					_pausa, _cortes, _estado_victima()]),

		_medida("y machacandolo, cuantos aguanta", 1.6,
			func() -> void:
				_borrar_enemigos()
				_colocar(Vector3(0.0, 0.9, 18.0), 0.0)
				_cerca = _plantar(Vector3(1.9, 0.3, 18.0), "Cerca")
				_mirar(Vector3.RIGHT)
				_machacar = true,
			func() -> String:
				return "%d cortes   victima: %s" % [_cortes, _estado_victima()]),

		# =====================================================================
		# 5) ¿VUELVE SOLA?
		# =====================================================================
		_medida("tirarla y esperar", 3.0,
			func() -> void:
				_colocar(Vector3(0.0, 14.0, 18.0), 0.0)
				_mirar(Vector3.RIGHT)
				_tirar = 40,
			func() -> String:
				if not _vuelve_sola:
					return "NO VOLVIO   se alejo %.1f m   sigue en %s" % [
						_lejos, _e.fsm.nombre_actual()]
				return "se alejo %.1f m (tope %.0f) y volvio en %.2f s" % [
					_lejos, _e.tuning.alcance, _vuelta_t]),

		# =====================================================================
		# 6) LA PREGUNTA DEL ENCARGO.
		# =====================================================================
		_medida("CONTROL: patearla SIN enemigos", 1.4,
			func() -> void:
				_borrar_enemigos()
				_preparar_pogo(Vector3(0.0, 14.0, 18.0)),
			func() -> String:
				return "va a: %-24s el rumbo gira %.0f grados" % [
					_elegido, _giro_de_rumbo()]),

		_medida("patearla CON un enemigo al lado", 1.6,
			func() -> void:
				_borrar_enemigos()
				# EL ENEMIGO NO ESTA EN LA LINEA DE TIRO, y es a proposito: si lo
				# estuviera, "va hacia el" no distinguiria buscar de seguir recto.
				_cerca = _plantar(Vector3(7.0, 0.3, 26.0), "Cerca")
				_preparar_pogo(Vector3(0.0, 14.0, 18.0)),
			func() -> String:
				return "hacia el enemigo: %.0f grados ANTES -> %.0f DESPUES   va a: %s" % [
					_grados_antes, _grados_despues, _elegido]),

		_medida("con DOS, elige el mas cercano", 1.6,
			func() -> void:
				_borrar_enemigos()
				_cerca = _plantar(Vector3(7.0, 0.3, 26.0), "Cerca")
				_lejos_e = _plantar(Vector3(-16.0, 0.3, 30.0), "Lejos")
				_preparar_pogo(Vector3(0.0, 14.0, 18.0)),
			func() -> String:
				return "va a: %-24s (al patear: Cerca %.1f m · Lejos %.1f m)" % [
					_elegido, _d_cerca, _d_lejos]),

		_medida("patearla REBOTA pero NO recarga", 1.4,
			func() -> void:
				_borrar_enemigos()
				_preparar_pogo(Vector3(0.0, 14.0, 18.0))
				_p.cuerda_disponible = false,
			func() -> String:
				return "vy tras el pogo %+.1f (rebote %.1f)   cuerda: %s" % [
					_vy_rebote, _p.tuning.patada_rebote, _cuerda_tras_pogo]),
	]


# --- Utilidades de montaje ----------------------------------------------------

func _colocar(pos: Vector3, rapidez: float) -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
	_leer_rebote = false
	_cortar = 0
	_tirar = 0
	_machacar = false
	_pegado = false
	_ciclo = 0

	_p.global_position = pos
	_p.velocity = Vector3.RIGHT * rapidez
	_p.stamina.llenar()
	_p.recargar_moveset()
	_p.fsm.cambiar(&"Fall" if pos.y > 2.0 else &"Idle")
	_p.reset_physics_interpolation()

	# La espada vuelve a la mano de golpe: cada medida empieza armada.
	if _e.fsm.nombre_actual() != &"Wielded":
		_e.fsm.cambiar(&"Wielded")
	_e.global_position = _e.punto_de_mano()
	_e.reset_physics_interpolation()

	_cortes = 0
	_en_corte = false
	_frames_corte = 0
	_frames_corte_ultimo = 0
	_estado_al_cortar = &"—"
	_pausa = 0
	_victima_vida = -1.0
	_victima_murio = false
	_planto = false
	_fr = 0
	_v_inicial = -1.0
	_v_final = -1.0
	_lejos = 0.0
	_origen_vuelo = pos
	_vuelta_t = -1.0
	_vuelve_sola = false
	_rumbo_antes = Vector3.ZERO
	_rumbo_despues = Vector3.ZERO
	_grados_antes = -1.0
	_grados_despues = -1.0
	_elegido = "NO SE LLEGO A PATEAR"
	_pateada = false
	_leer_rebote = false
	_d_cerca = -1.0
	_d_lejos = -1.0
	_vy_rebote = -99.0
	_cuerda_tras_pogo = "?"


## SUELTA TODOS LOS BOTONES AL CERRAR UNA MEDIDA, y no al abrir la siguiente.
##
## `_colocar()` tambien los suelta, pero corre DENTRO de `hacer`, que va despues
## de `_pulsadores()`: la primera pulsacion de cada fila la daba todavia la fila
## anterior. Con el machaque encendido eso salia carisimo — la fila del tiro
## empezaba con un corte de 16 frames colado, y los 3 frames de `throw_sword`
## caducaban dentro de el (la ventana del buffer son 9). El banco decia
## `NO VOLVIO` sobre un tiro que nunca se llego a pedir.
##
## Lo cazo la traza de estados: `Wielded > Swing > Wielded` durante la fila del
## tiro, y ni un solo `InFlight`. De ahi que la traza se quede puesta.
func _soltar_todo() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_cortar = 0
	_tirar = 0
	_machacar = false
	_pegado = false
	if _p != null:
		_p.buffer.clear()


## Gira la CAMARA, que es de donde salen el corte y el tiro. Girar el cuerpo no
## vale: `_direccion_de_tiro()` lee la camara, igual que la cuerda.
func _mirar(dir: Vector3) -> void:
	var cam := _p.camara()
	if cam == null:
		return
	var plano := Vector3(dir.x, 0.0, dir.z)
	if plano.is_zero_approx():
		return
	cam.global_transform = Transform3D(
		Basis.looking_at(plano.normalized(), Vector3.UP), cam.global_position)


## Monta el pogo: tira la espada y engancha el pegado, que hace el resto.
##
## **La espada vuela hacia +X y la patada apunta a −Z**, cruzadas a proposito. Con
## las dos en la misma direccion, "sale hacia donde pateaste" y "sigue como iba"
## producen el mismo numero y la fila de control no distingue nada — que es lo que
## paso en la primera pasada: `el rumbo gira 0 grados`, correcto e inutil.
##
## La direccion de la patada se pide por el camino REAL —camara mas stick— y no
## escribiendola en el `msg`: `StateKick` la saca de ahi, y un banco que fuerza la
## entrada mide otra cosa que el juego.
func _preparar_pogo(pos: Vector3) -> void:
	_colocar(pos, 0.0)
	_mirar(Vector3.RIGHT)
	_e.lanzar(_e.punto_de_mano(), Vector3.RIGHT)
	_mirar(_PATADA_DIR)
	Input.action_press(&"move_forward")
	_pegado = true
	_pegado_dir = _PATADA_DIR


func _plantar(pos: Vector3, como: String) -> Enemigo:
	_planto = true
	var e := load("res://src/enemies/Guardian.tscn").instantiate() as Enemigo
	e.name = como
	_main.add_child(e)
	e.global_position = pos
	e.vista = 0.0
	e.ataque = null
	return e


## LIMPIA EL CORRAL ENTERO, no solo lo que planto el banco.
##
## El Gym trae seis enemigos y la fila de control dice "sin enemigos": sin esto,
## la espada encontraria uno a treinta metros y el control mediria otra cosa. Es
## la misma clase de fallo que la fila de control mal montada — el numero sale,
## parece bueno, y es de otro experimento.
func _borrar_enemigos() -> void:
	for n in get_tree().get_nodes_in_group(&"enemigos"):
		var e := n as Enemigo
		if e != null and is_instance_valid(e):
			e.remove_from_group(&"enemigos")
			e.queue_free()
	_cerca = null
	_lejos_e = null


func _dist(e: Enemigo) -> float:
	if e == null or not is_instance_valid(e):
		return -1.0
	return _e.global_position.distance_to(e.global_position)


func _estado_victima() -> String:
	# EL ORDEN IMPORTA: un enemigo muerto se libera enseguida, asi que para cuando
	# se lee la fila ya no hay a quien preguntar. Un latch que no puede distinguir
	# «no paso» de «no pude mirar» es un latch que miente — la primera pasada decia
	# `desaparecio (montaje malo)` sobre un enemigo que simplemente habia muerto.
	if _victima_murio or (_planto and (_cerca == null or not is_instance_valid(_cerca))):
		return "MURIO en el acto"
	if _cerca == null:
		return "no se planto ninguna"
	if _victima_vida < 0.0:
		return "SIN TOCAR (%.0f/%.0f de vida)" % [
			_cerca.salud.actual, _cerca.salud.maxima]
	return "-%.0f de vida (%.0f/%.0f)" % [
		_victima_vida, _cerca.salud.actual, _cerca.salud.maxima]


## Cuanto ha girado el rumbo con la patada. Las dos fotos se toman en el frame
## del golpe, no al leer la fila: para entonces la espada ya va de vuelta.
func _giro_de_rumbo() -> float:
	if _rumbo_antes.is_zero_approx() or _rumbo_despues.is_zero_approx():
		return 0.0
	return rad_to_deg(_rumbo_antes.angle_to(_rumbo_despues))


## LA PATADA, LATCHEADA POR SEÑAL. Ver la nota de `_ready()`.
func _al_cambiar_espada(nombre: StringName) -> void:
	if not _pegado or _pateada:
		return
	if nombre != &"Homing" and nombre != &"InFlight":
		return
	_pateada = true
	_pegado = false
	_rumbo_despues = _e.direccion
	_d_cerca = _dist(_cerca)
	_d_lejos = _dist(_lejos_e)
	_elegido = "NADIE (sale hacia donde pateaste)"
	# POR IDENTIDAD, NO POR NOMBRE. El nombre que imprime un nodo instanciado no
	# es el que le pones tu si hay colision en el arbol, y la primera pasada lo
	# demostro: la fila decia `@CharacterBody3D@514`, que no dice a quien eligio.
	if _e.objetivo != null and is_instance_valid(_e.objetivo):
		if _e.objetivo == _cerca:
			_elegido = "el CERCANO"
		elif _e.objetivo == _lejos_e:
			_elegido = "el LEJANO"
		else:
			_elegido = "otro (%s)" % _e.objetivo.name
	_cuerda_tras_pogo = "RECARGADA" if _p.cuerda_disponible else "sigue gastada"
	# EL REBOTE SE LEE UN FRAME DESPUES, y no aqui.
	#
	# Esta señal salta DENTRO de `hitbox.golpear()`, o sea antes de que
	# `StateKick._al_conectar()` escriba la vertical: leerla en este punto da la
	# de antes del golpe. Medido en la primera pasada: `vy -0.2` con el rebote
	# puesto en 10.0. Es la regla dura #31 otra vez —medir la magnitud— pero con
	# el problema del INSTANTE en vez del de la casilla.
	_leer_rebote = true


func _physics_process(delta: float) -> void:
	if _p == null or _guion.is_empty():
		return
	if _paso >= _guion.size():
		_informe()
		return
	_t += delta

	_pulsadores()
	_latches(delta)

	var actual: Dictionary = _guion[_paso]
	if is_zero_approx(_t - delta):
		(actual["hacer"] as Callable).call()
	if _t >= float(actual["dur"]):
		_lineas.append("  %-34s %s" % [
			actual["nombre"], (actual["leer"] as Callable).call()])
		_paso += 1
		_t = 0.0
		_soltar_todo()


func _pulsadores() -> void:
	if _machacar:
		# Dos frames pulsado y dos sueltos: sin el hueco,
		# `is_action_just_pressed` no vuelve a dispararse.
		_ciclo = (_ciclo + 1) % 4
		if _ciclo < 2:
			Input.action_press(&"attack_light")
		else:
			Input.action_release(&"attack_light")
	elif _cortar > 0:
		Input.action_press(&"attack_light")
		_cortar -= 1
		if _cortar == 0:
			Input.action_release(&"attack_light")

	# EL TIRO SE INSISTE HASTA QUE SALE, como haria un jugador.
	#
	# Tres frames de pulsacion no bastan para montar esta fila, y no por un fallo
	# del juego: la fila anterior deja un corte a medias y la ventana del buffer
	# son 9 frames contra los 16 que dura el gesto, asi que la pulsacion caduca
	# dentro del corte. Eso es correcto —el buffer tiene el largo que tiene— pero
	# convierte la medida en una carrera contra el montaje.
	#
	# Que UNA sola pulsacion la tira desde la mano esta comprobado aparte, con un
	# sondeo limpio; lo que esta fila mide es el VIAJE, y para eso hace falta que
	# el viaje empiece.
	if _tirar > 0:
		_tirar -= 1
		if _e.esta_fuera():
			Input.action_release(&"throw_sword")
			_tirar = 0
			# Y SE VACIA EL BUFFER. El mismo boton que la tira la LLAMA DE VUELTA,
			# asi que una pulsacion de sobra esperando en el buffer la recuperaba
			# al frame siguiente: `se alejo 0.6 m y volvio en 0.02 s`. Es el juego
			# haciendo lo correcto y el banco pidiendo dos cosas a la vez.
			_p.buffer.clear()
		else:
			_ciclo_tiro = (_ciclo_tiro + 1) % 4
			if _ciclo_tiro < 2:
				Input.action_press(&"throw_sword")
			else:
				Input.action_release(&"throw_sword")

	# EL POGO. El jugador se pega a la espada CADA FRAME y pulsa el salto, que es
	# donde vive la patada desde el 4.06.
	if _pegado and _e.esta_fuera():
		# El jugador SE PONE detras de la espada EN LA LINEA DE LA PATADA, para
		# que el arma le quede dentro del arco de 130 grados.
		_p.global_position = _e.global_position - _pegado_dir * 1.6
		_p.velocity = Vector3.ZERO
		_p.reset_physics_interpolation()
		_p.patada_cargas = maxi(_p.patada_cargas, 1)
		if _p.fsm.nombre_actual() != &"Kick":
			_p.fsm.cambiar(&"Fall")
		_ciclo = (_ciclo + 1) % 4
		if _ciclo < 2:
			Input.action_press(&"jump")
		else:
			Input.action_release(&"jump")


func _latches(delta: float) -> void:
	_fr += 1
	if _leer_rebote:
		_leer_rebote = false
		_vy_rebote = _p.superficie.vertical(_p.velocity)
	if HitstopManager.global_activo():
		_pausa += 1
	if _cerca != null and is_instance_valid(_cerca) and _cerca.salud != null:
		var perdida: float = _cerca.salud.maxima - _cerca.salud.actual
		if perdida > 0.0:
			_victima_vida = perdida
		if not _cerca.salud.vivo:
			_victima_murio = true

	var plano := _p.motor.rapidez_plana()
	var estado_espada := _e.fsm.nombre_actual()

	# --- LA VENTANA DE VELOCIDAD. Las dos filas miden los mismos frames.
	if _fr == 1:
		_v_inicial = plano
	if _fr == VENTANA:
		_v_final = plano

	# --- EL CORTE. La CUENTA va por señal (ver `_ready()`); aqui solo se mide
	#     cuanto dura uno, que si se puede leer por frame mientras no se encadene.
	if estado_espada == &"Swing":
		if not _en_corte:
			_en_corte = true
			_frames_corte = 0
			_estado_al_cortar = _p.fsm.nombre_actual()
		_frames_corte += 1
	elif _en_corte:
		_en_corte = false
		_frames_corte_ultimo = _frames_corte

	# --- EL VUELO.
	if _e.esta_fuera():
		_lejos = maxf(_lejos, _origen_vuelo.distance_to(_e.global_position))
		if _vuelta_t < 0.0:
			_vuelta_t = 0.0
		else:
			_vuelta_t += delta
	elif _vuelta_t > 0.0 and not _vuelve_sola:
		_vuelve_sola = true

	# --- EL RUMBO DE ANTES. Se refresca cada frame hasta que la patada lo
	#     congela: entre el tiro y el golpe la espada frena y cae, o sea que su
	#     rumbo de salida ya no es el que llevaba al recibir la patada.
	if _pegado and not _pateada:
		_rumbo_antes = _e.direccion
		if _cerca != null and is_instance_valid(_cerca):
			_grados_antes = rad_to_deg(_e.direccion.angle_to(_hacia(_cerca)))

	if estado_espada == &"Homing" and _cerca != null and is_instance_valid(_cerca):
		var g := rad_to_deg(_e.direccion.angle_to(_hacia(_cerca)))
		_grados_despues = g if _grados_despues < 0.0 else minf(_grados_despues, g)


func _hacia(e: Enemigo) -> Vector3:
	return (e.global_position + Vector3.UP * 0.9) - _e.global_position


func _informe() -> void:
	set_physics_process(false)
	var t := _e.tuning
	print("\n=== LA ESPADA, MEDIDA ===\n")
	for l in _lineas:
		print(l)
	print("\n--- TRAZA DE LA ESPADA, fila por fila ---")
	print("  " + " ".join(_traza))
	print("\n--- LOS NUMEROS QUE LA GOBIERNAN ---")
	print("  velocidad      %5.1f m/s   alcance         %5.1f m" % [
		t.velocidad, t.alcance])
	print("  vel_retorno    %5.1f m/s   radio_atrape    %5.2f m" % [
		t.velocidad_retorno, t.radio_atrape])
	print("  busqueda_rango %5.1f m     busqueda_vel    %5.1f m/s" % [
		t.busqueda_rango, t.busqueda_velocidad])
	print("  busqueda_giro  %5.0f gr/s  busqueda_vida   %5.2f s" % [
		t.busqueda_giro, t.busqueda_vida])
	var d := _e.ataque
	if d != null:
		print("  corte: %d+%d+%d frames  dano %.0f  alcance %.1f m  arco %.0f" % [
			d.frames_windup, d.frames_activo, d.frames_recuperacion,
			d.dano, d.alcance, d.arco_grados])
	get_tree().quit(0)


func _medida(nombre: String, dur: float, hacer: Callable, leer: Callable) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "leer": leer}
