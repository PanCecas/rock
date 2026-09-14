extends Node
## Test funcional de LA ESPADA.
##
##   godot --headless --path . tools/TestEspada.tscn
##
## Comprueba los tres verbos por su CAMINO DE ENTRADA REAL —la tecla, el buffer y
## el estado— y no forzando la FSM del arma: un test que hace
## `fsm.cambiar(&"Swing")` mide la fisica del gesto y no si el boton llega, que es
## el fallo que el balanceo tuvo durante cuatro parches.
##
## Las leyes que se afirman aqui, y por que cada una:
##
##   · **El corte NO es una transicion del jugador.** Cortar corriendo te deja
##     corriendo. Es lo que separa la espada de la patada, que SI te mueve.
##   · **Y por eso funciona desde donde sea**, incluido colgado del arco. Es la
##     regla dura #13 comprobada del lado bueno: como no hay accion compartida
##     que repartir entre grupos, no hay grupo del que olvidarse.
##   · **Ningun boton se traga una pulsacion.** Ni el corte durante la
##     recuperacion, ni el tiro durante un corte. Los dos fallaban, los dos los
##     cazo el banco, y los dos tienen comprobacion aqui para que no vuelvan.
##   · **EL CLICK YA NO PATEA.** Es el cambio que se pidio —*«la patada que sea en
##     el espacio, no en el ataque»*— y se comprueba por el ESTADO AL QUE NO SE
##     LLEGA, que es la unica forma de afirmar que algo se ha quitado.
##   · **Patearla rebota pero NO recarga.** Tus armas las pones tu; la ley 4
##     recarga por tocar el mundo.

const GUARDIAN := preload("res://src/enemies/Guardian.tscn")

var _main: Node
var _p: PlayerController
var _e: Sword
var _victima: Enemigo

const ARRANQUE_MAX := 20.0
var _arranque: float = 0.0
var _paso: int = 0
var _t: float = 0.0
var _guion: Array = []
var _fallos: PackedStringArray = []

# --- Pulsadores.
var _cortar: int = 0
var _tirar: int = 0
## Mantener el boton de corte todo lo que dure la medida, sin soltarlo.
var _mantener_corte: bool = false
var _pegado: bool = false
var _ciclo: int = 0

# --- Latches.
var _cortes: int = 0
var _estados_al_cortar: Dictionary = {}
var _estado_antes: StringName = &""
var _estado_durante: StringName = &""
var _v_antes: float = -1.0
var _v_durante: float = -1.0
var _entro_en_kick: bool = false
var _pateada: bool = false
var _objetivo_al_patear: Node = null
var _vy_rebote: float = -99.0
var _cuerda_tras_pogo: bool = true
var _capa_en_mano: int = -1
var _capa_fuera: int = -1
var _vida_espada_ok: bool = true


func _ready() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	await get_tree().physics_frame
	await get_tree().physics_frame
	_e = _p.espada
	if _e == null:
		print("RESULTADO ESPADA: 0/0 — el jugador no tiene espada.")
		get_tree().quit(1)
		return
	# LOS CORTES SE CUENTAN POR SEÑAL. Uno termina y el siguiente empieza dentro
	# del mismo frame, asi que mirar el nombre del estado una vez por frame nunca
	# ve la casilla intermedia y cuenta de menos. Lo midio el banco: 1 corte por
	# segundo donde de verdad salian cuatro.
	_e.corte.connect(_al_cortar)
	_e.estado_cambiado.connect(_al_cambiar_espada)
	_pacificar()
	_construir()


func _pacificar() -> void:
	for n in get_tree().get_nodes_in_group(&"enemigos"):
		var e := n as Enemigo
		if e != null and is_instance_valid(e):
			e.vista = 0.0
			e.ataque = null


func _al_cortar() -> void:
	_cortes += 1
	_estados_al_cortar[_p.fsm.nombre_actual()] = true
	_estado_durante = _p.fsm.nombre_actual()
	_v_durante = _p.motor.rapidez_plana()


func _al_cambiar_espada(nombre: StringName) -> void:
	if not _pegado or _pateada:
		return
	if nombre != &"Homing" and nombre != &"InFlight":
		return
	_pateada = true
	_pegado = false
	_objetivo_al_patear = _e.objetivo
	_cuerda_tras_pogo = _p.cuerda_disponible


func _construir() -> void:
	_guion = [
		# =====================================================================
		# EL CORTE
		# =====================================================================
		_chequeo_("una pulsacion saca UN corte", 0.6,
			func() -> void:
				_montar(Vector3(0.0, 14.0, 18.0), 0.0)
				_cortar = 3,
			func() -> bool:
				return _cortes == 1 and _e.fsm.nombre_actual() == &"Wielded",
			"o el boton no llega, o el gesto no termina solo"),

		# MANTENER NO ES MACHACAR. Un ataque que se auto-repite mientras aguantas
		# el boton convierte el combate en dejar el dedo puesto, y ademas es un
		# MODO (regla dura #27): lo termina el jugador soltando.
		_chequeo_("MANTENERLO no auto-repite", 1.0,
			func() -> void:
				_montar(Vector3(0.0, 14.0, 18.0), 0.0)
				_mantener_corte = true,
			func() -> bool: return _cortes == 1,
			"aguantar el boton encadena cortes solo: eso es un modo, no un gesto"),

		# MACHACARLO SI. La recuperacion del .tres es el unico limite, y tiene que
		# serlo de verdad: ni mas rapido (zumbido) ni mas lento (pulsaciones
		# tragadas).
		_chequeo_("machacarlo encadena hasta el techo del .tres", 1.0,
			func() -> void:
				_montar(Vector3(0.0, 14.0, 18.0), 0.0)
				_ciclo = 0
				_mantener_corte = false
				_cortar = -1,
			func() -> bool:
				var techo: int = int(60.0 / maxf(1.0, float(_e.ataque.total_frames())))
				return _cortes >= techo - 1 and _cortes <= techo + 1,
			"o se traga pulsaciones en la recuperacion, o sale mas de lo que el .tres permite"),

		# =====================================================================
		# EL CORTE NO TE MUEVE. Es la ley que lo separa de la patada.
		# =====================================================================
		# SE MIDE EN EL AIRE, y no de pie. Un teletransporte al suelo tarda un par
		# de frames en asentarse —`is_on_floor()` es falso el primero, asi que pasa
		# por `Fall` y vuelve— y el corte cae justo ahi: la fila comparaba el
		# asentamiento, no el corte. En `Fall` el estado no se mueve solo, asi que
		# cualquier cambio es del gesto.
		_chequeo_("cortar NO te cambia de estado", 0.6,
			func() -> void:
				_montar(Vector3(0.0, 14.0, 18.0), 0.0)
				_cortar = 3,
			func() -> bool:
				return _cortes >= 1 and _estado_durante == _estado_antes,
			"si el corte cambia de estado es una transicion, y entonces te quita el control"),

		_chequeo_("cortar NO te quita velocidad", 0.7,
			func() -> void:
				_montar(Vector3(0.0, 14.0, 18.0), 20.0)
				_cortar = 3,
			func() -> bool:
				return _cortes >= 1 and _v_durante >= _v_antes - 1.0,
			"la patada es el verbo que te mueve; el corte no puede tocar la linea"),

		# =====================================================================
		# DESDE DONDE SE PUEDE CORTAR
		# =====================================================================
		# COLGADO DEL ARCO. Es la comprobacion preventiva de la regla dura #13: la
		# cuerda y la patada se olvidaron las dos de `Attached` en su dia, y las
		# dos fallaron en silencio. Aqui no hay grupo que declarar, asi que lo que
		# se afirma es justamente eso — que sigue funcionando sin declararlo.
		_chequeo_("se corta COLGADO DEL ARCO", 1.2,
			func() -> void:
				_montar(Vector3(0.0, 14.0, 18.0), 0.0)
				_p.fsm.cambiar(&"LedgeHang")
				_cortar = 3,
			func() -> bool: return _cortes >= 1,
			"si un estado de agarre se come el boton, vuelve el fallo de la regla #13"),

		# EN EL AGUA NO SE PEGA. Lo reclaman `StateSwim` y `StateUnderwater` con
		# `maneja_ataques()`, y el guardia vive ahora en el controlador: si se
		# hubiera perdido al mudarlo, esto se pone en rojo.
		# EN LA PISCINA DE VERDAD, no forzando el estado. `StateSwim` se sale solo
		# en el primer frame si no hay agua debajo, asi que un `fsm.cambiar()` a
		# secas comprueba un estado que ya no existe cuando llega el boton: la
		# primera pasada daba `jugador=Fall` y el chequeo culpaba al guardia.
		# La piscina del Gym esta en (28, 0, -28) con la superficie en y = 8.5, y se
		# entra CAYENDO desde arriba —igual que en `TestFase2`—: aparecer ya dentro
		# no dispara el sensor, y la fila daba `jugador=Fall` dentro del agua.
		_chequeo_("en el AGUA no se corta", 0.8,
			func() -> void:
				_montar(Vector3(28.0, 12.0, -28.0), 0.0)
				_cortar_tras(30),
			func() -> bool:
				return _cortes == 0 and _p.fsm.nombre_actual() in [&"Swim", &"Underwater"],
			"nadar es traversal puro: el guardia maneja_ataques() se ha perdido"),

		# =====================================================================
		# EL CLICK YA NO PATEA. El cambio que se pidio.
		# =====================================================================
		_chequeo_("el CLICK ya no patea", 0.8,
			func() -> void:
				_montar(Vector3(0.0, 14.0, 18.0), 0.0)
				_cortar = 3,
			func() -> bool: return _cortes >= 1 and not _entro_en_kick,
			"la patada sigue colgando del boton de ataque: eso es lo que se pidio quitar"),

		_chequeo_("y el ESPACIO en el aire sigue pateando", 0.8,
			func() -> void:
				_montar(Vector3(0.0, 14.0, 18.0), 0.0)
				_tirar = 0
				_saltar(4),
			func() -> bool: return _entro_en_kick and _cortes == 0,
			"si el salto no patea, la patada se ha quedado sin ninguna puerta"),

		# =====================================================================
		# TIRARLA Y RECUPERARLA
		# =====================================================================
		_chequeo_("el click derecho la tira", 0.5,
			func() -> void:
				_montar(Vector3(0.0, 14.0, 18.0), 0.0)
				_tirar = 3,
			func() -> bool: return _e.esta_fuera(),
			"el boton del tiro no llega o el arma no sale de la mano"),

		_chequeo_("y vuelve sola a la mano", 3.0,
			func() -> void:
				_montar(Vector3(0.0, 20.0, 18.0), 0.0)
				_e.lanzar(_e.punto_de_mano(), Vector3.RIGHT),
			func() -> bool: return _e.fsm.nombre_actual() == &"Wielded",
			"un bumeran que no vuelve es una lanza con pasos extra"),

		_chequeo_("con la espada FUERA no hay corte", 0.6,
			func() -> void:
				_montar(Vector3(0.0, 20.0, 18.0), 0.0)
				_e.lanzar(_e.punto_de_mano(), Vector3.RIGHT)
				_cortar = 3,
			func() -> bool: return _cortes == 0,
			"cortar sin el arma en la mano: el precio de tirarla desaparece"),

		# LAS DOS PULSACIONES QUE SE TRAGABAN. Las dos las cazo el banco.
		# LA PULSACION NO SE TRAGA, PERO SIGUE CADUCANDO. Son dos cosas distintas:
		# lo que se arreglo es que `_input_espada()` la consumiera sin poder
		# ejecutarla —desaparecia sin efecto—, no la ventana del buffer, que son
		# 0.15 s / 9 frames y vale para todo el juego igual.
		#
		# Por eso se pide en el frame 12 de un corte de 16: quedan 6 de
		# recuperacion, dentro de la ventana. Pedirlo en el frame 6 caduca, y eso
		# es correcto — lo comprobo la primera pasada de este mismo test.
		_chequeo_("pedir el TIRO a mitad de un corte NO se pierde", 1.0,
			func() -> void:
				_montar(Vector3(0.0, 20.0, 18.0), 0.0)
				_cortar = 3
				_tirar_tras(12),
			func() -> bool: return _cortes >= 1 and _e.esta_fuera(),
			"la pulsacion se consumia durante el corte y desaparecia sin efecto"),

		# =====================================================================
		# LA HURTBOX: apagada en la mano, encendida fuera.
		# =====================================================================
		_chequeo_("la hurtbox se apaga en la mano", 1.2,
			func() -> void:
				_montar(Vector3(0.0, 20.0, 18.0), 0.0)
				_capa_en_mano = _e.hurtbox.collision_layer
				_capa_fuera = -1
				_e.lanzar(_e.punto_de_mano(), Vector3.RIGHT),
			func() -> bool: return _capa_en_mano == 0 and _capa_fuera != 0,
			"una hurtbox olvidada encendida deja patear el arma a distancia cero"),

		# Y NO SE GOLPEA A SI MISMA. Es el bug que tuvo la lanza en el 4.05: su
		# hitbox es del equipo 0 y su hurtbox del 1, asi que el filtro de equipo
		# no las separa — lo hace el filtro de DUEÑO.
		_chequeo_("no se golpea a si misma en vuelo", 1.5,
			func() -> void:
				_montar(Vector3(0.0, 20.0, 18.0), 0.0)
				_vida_espada_ok = true
				_e.lanzar(_e.punto_de_mano(), Vector3.RIGHT),
			func() -> bool: return _vida_espada_ok,
			"se encuentra a si misma y se repatea cada frame, como le paso a la lanza"),

		# =====================================================================
		# LA PREGUNTA DEL ENCARGO
		# =====================================================================
		_chequeo_("patearla la manda al enemigo mas cercano", 1.6,
			func() -> void:
				_borrar_enemigos()
				_victima = _plantar(Vector3(7.0, 0.3, 26.0))
				_pogo(Vector3(0.0, 14.0, 18.0)),
			func() -> bool: return _pateada and _objetivo_al_patear == _victima,
			"la espada pateada no busca: era la mitad del encargo"),

		_chequeo_("sin enemigos, va donde pateaste", 1.4,
			func() -> void:
				_borrar_enemigos()
				_pogo(Vector3(0.0, 14.0, 18.0)),
			func() -> bool:
				return _pateada and _objetivo_al_patear == null \
					and _e.fsm.nombre_actual() != &"Wielded",
			"un boton que a veces no hace nada es un boton que se deja de pulsar"),

		_chequeo_("patearla REBOTA", 1.4,
			func() -> void:
				_borrar_enemigos()
				_pogo(Vector3(0.0, 14.0, 18.0)),
			func() -> bool: return _vy_rebote > _p.tuning.patada_rebote * 0.7,
			"sin rebote, alcanzarla en el aire no te devuelve nada"),

		_chequeo_("pero NO recarga el moveset", 1.4,
			func() -> void:
				_borrar_enemigos()
				_pogo(Vector3(0.0, 14.0, 18.0))
				_p.cuerda_disponible = false,
			func() -> bool: return not _cuerda_tras_pogo,
			"recargar con tus propias cosas es movimiento perpetuo con pasos extra"),
	]


# --- Montaje ------------------------------------------------------------------

func _montar(pos: Vector3, rapidez: float) -> void:
	_soltar_todo()
	_p.global_position = pos
	_p.velocity = Vector3.RIGHT * rapidez
	_p.stamina.llenar()
	_p.recargar_moveset()
	_p.fsm.cambiar(&"Fall" if pos.y > 2.0 else &"Idle")
	_p.reset_physics_interpolation()
	if _e.fsm.nombre_actual() != &"Wielded":
		_e.fsm.cambiar(&"Wielded")
	_e.global_position = _e.punto_de_mano()
	_e.reset_physics_interpolation()
	_mirar(Vector3.RIGHT)

	_cortes = 0
	_estados_al_cortar.clear()
	_estado_antes = _p.fsm.nombre_actual()
	_estado_durante = &"?"
	_v_antes = rapidez
	_v_durante = -1.0
	_entro_en_kick = false
	_pateada = false
	_objetivo_al_patear = null
	_vy_rebote = -99.0
	_cuerda_tras_pogo = true
	_leer_rebote = false


## SUELTA TODO AL CERRAR UNA MEDIDA, no al abrir la siguiente.
##
## `_montar()` corre dentro de `hacer`, que va DESPUES de los pulsadores: sin
## esto, la primera pulsacion de cada comprobacion la daba todavia la anterior.
## En el banco eso colo un corte de 16 frames al principio de la fila del tiro y
## la pulsacion caducaba dentro (la ventana del buffer son 9).
func _soltar_todo() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_cortar = 0
	_cortar_en = -1
	_tirar = 0
	_tirar_en = -1
	_saltar_en = -1
	_mantener_corte = false
	_pegado = false
	_ciclo = 0
	if _p != null:
		_p.buffer.clear()


var _tirar_en: int = -1
var _cortar_en: int = -1
var _saltar_en: int = -1
var _leer_rebote: bool = false


func _tirar_tras(frames: int) -> void:
	_tirar_en = frames


func _cortar_tras(frames: int) -> void:
	_cortar_en = frames


func _saltar(frames: int) -> void:
	_saltar_en = 1
	_saltar_frames = frames


var _saltar_frames: int = 3


## Monta el pogo: tira la espada hacia +X y patea hacia −Z. **Cruzadas**, para que
## "va hacia donde pateaste" y "sigue como iba" no den el mismo resultado.
func _pogo(pos: Vector3) -> void:
	_montar(pos, 0.0)
	_e.lanzar(_e.punto_de_mano(), Vector3.RIGHT)
	_mirar(Vector3.FORWARD)
	Input.action_press(&"move_forward")
	_pegado = true


func _mirar(dir: Vector3) -> void:
	var cam := _p.camara()
	if cam == null:
		return
	var plano := Vector3(dir.x, 0.0, dir.z)
	if plano.is_zero_approx():
		return
	cam.global_transform = Transform3D(
		Basis.looking_at(plano.normalized(), Vector3.UP), cam.global_position)


func _plantar(pos: Vector3) -> Enemigo:
	var e := GUARDIAN.instantiate() as Enemigo
	_main.add_child(e)
	e.global_position = pos
	e.vista = 0.0
	e.ataque = null
	return e


func _borrar_enemigos() -> void:
	for n in get_tree().get_nodes_in_group(&"enemigos"):
		var e := n as Enemigo
		if e != null and is_instance_valid(e):
			e.remove_from_group(&"enemigos")
			e.queue_free()
	_victima = null


func _physics_process(delta: float) -> void:
	if _guion.is_empty():
		_arranque += delta
		if _arranque > ARRANQUE_MAX:
			print("RESULTADO ESPADA: 0/0 — el guion no llego a construirse.")
			set_physics_process(false)
			get_tree().quit(1)
		return
	if _paso >= _guion.size():
		_informe()
		return
	_t += delta

	_pulsadores()
	_latches()

	var actual: Dictionary = _guion[_paso]
	if is_zero_approx(_t - delta):
		(actual["hacer"] as Callable).call()
	if _t >= float(actual["dur"]):
		if not (actual["chequeo"] as Callable).call():
			_fallos.append("%-46s %s\n      [espada=%s  jugador=%s  cortes=%d  kick=%s  pateada=%s]" % [
				actual["nombre"], actual["porque"], _e.fsm.nombre_actual(),
				_p.fsm.nombre_actual(), _cortes, _entro_en_kick, _pateada])
		else:
			print("  OK    %s" % actual["nombre"])
		_paso += 1
		_t = 0.0
		_soltar_todo()


func _pulsadores() -> void:
	if _cortar_en > 0:
		_cortar_en -= 1
		if _cortar_en == 0:
			_cortar = 3
			_cortar_en = -1
	if _mantener_corte:
		Input.action_press(&"attack_light")
	elif _cortar < 0:
		# Machaque: pulsa y suelta sin parar.
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

	if _tirar_en > 0:
		_tirar_en -= 1
		if _tirar_en == 0:
			_tirar = 3
			_tirar_en = -1
	if _tirar > 0:
		_tirar -= 1
		if _e.esta_fuera():
			Input.action_release(&"throw_sword")
			_tirar = 0
			_p.buffer.clear()
		else:
			Input.action_press(&"throw_sword")
			if _tirar == 0:
				Input.action_release(&"throw_sword")

	if _saltar_en > 0:
		_saltar_frames -= 1
		Input.action_press(&"jump")
		if _saltar_frames <= 0:
			Input.action_release(&"jump")
			_saltar_en = -1

	# EL POGO. El jugador se pega a la espada CADA FRAME y pulsa el salto, que es
	# donde vive la patada desde el 4.06.
	if _pegado and _e.esta_fuera():
		_p.global_position = _e.global_position - Vector3.FORWARD * 1.6
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


func _latches() -> void:
	if _leer_rebote:
		_leer_rebote = false
		_vy_rebote = _p.superficie.vertical(_p.velocity)
	if _pateada and _vy_rebote < -98.0:
		_leer_rebote = true
	if _p.fsm.nombre_actual() == &"Kick":
		_entro_en_kick = true
	if _e.esta_fuera():
		_capa_fuera = _e.hurtbox.collision_layer
		# LA ESPADA NO PUEDE SER SU PROPIA VICTIMA. Si se golpeara a si misma,
		# `InFlight` se reentraria cada frame y la rapidez no bajaria nunca — que
		# es exactamente el sintoma con el que se cazo el mismo bug en la lanza.
		var ultimo: Golpe = _e.hitbox.ultimo
		if ultimo != null and ultimo.victima == _e:
			_vida_espada_ok = false


func _informe() -> void:
	set_physics_process(false)
	print("RESULTADO ESPADA: %d/%d comprobaciones." % [
		_guion.size() - _fallos.size(), _guion.size()])
	if not _fallos.is_empty():
		print("--- FALLOS ---")
		for f in _fallos:
			print("  " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)


func _chequeo_(nombre: String, dur: float, hacer: Callable, chequeo: Callable, porque: String) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "chequeo": chequeo, "porque": porque}
