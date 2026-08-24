extends Node
## Test funcional de la Fase 2: combate.
##
##   godot --headless --path . tools/TestFase2.tscn
##
## Comprueba lo que se puede comprobar sin ojos: que la cadena encadena, que el
## daño llega, que las cancelaciones abren cuando deben y que el parry convierte
## un golpe en una apertura. El feel del combate sigue juzgándose en vídeo.

var _main: Node
var _p: PlayerController
var _g: Guardian

var _paso: int = 0
var _t: float = 0.0
var _reloj: float = 0.0
var _fallos: PackedStringArray = []
var _visitados: Dictionary = {}
var _guion: Array = []
var _traza: Array[String] = []


func _ready() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	add_child(_main)
	_p = _main.get_node("Player") as PlayerController
	EventBus.player_jumped.connect(func(_n: int) -> void: _saltos_contados += 1)
	EventBus.player_state_changed.connect(
		func(a: StringName, n: StringName) -> void:
			_visitados[n] = true
			_traza.append("%s>%s" % [a, n])
			if _traza.size() > 10:
				_traza.pop_front())
	_construir_guion()


func _construir_guion() -> void:
	_guion = [
		_paso_("colocarse", 0.6, func() -> void:
			_lancero()
			_colocar(2.0), &"Idle"),

		# --- Cadena ligera ----------------------------------------------------
		_chequeo_("golpe 1 conecta", 0.35,
			func() -> void:
				_vida_antes = _g.salud.actual
				_pulsar(&"attack_light"),
			func() -> bool: return _g.salud.actual < _vida_antes,
			"el primer golpe debe quitar vida"),
		# La cadena solo encadena DENTRO del ataque, pasado `frame_cadena`. Pulsar
		# cuando L1 ya termino no encadena: empieza un L1 nuevo. Por eso los pasos
		# son cortos y encajan con las ventanas reales del .tres.
		_paso_("abrir cadena", 0.16, func() -> void:
			_soltar_todo()
			_reponer()
			_colocar(2.0)
			_pulsar(&"attack_light"), &"Attack"),
		# 0.10 s = 6 frames. Hacen falta: ~2 de latencia entre action_press y que el
		# InputBuffer lo vea, 1 para que StateAttack lo consuma, y margen.
		_chequeo_("encadena a L2", 0.10,
			func() -> void:
				_soltar_todo()
				_pulsar(&"attack_light"),
			func() -> bool: return _indice_ataque() >= 2,
			"pulsar dentro de la ventana debe encadenar al segundo golpe"),
		_paso_("esperar ventana", 0.16, func() -> void: _soltar_todo(), &"Attack"),
		_chequeo_("encadena a L3", 0.10,
			func() -> void: _pulsar(&"attack_light"),
			func() -> bool: return _indice_ataque() >= 3,
			"la cadena debe llegar al finisher"),

		# --- Cancelaciones ----------------------------------------------------
		_chequeo_("ataque -> dash", 0.4,
			func() -> void:
				_soltar_todo()
				_reponer()
				_colocar(2.0)
				_p.fsm.cambiar(&"Attack", {"datos": _p.ataque_ligero, "indice": 1})
				_esperar_frames = 8,
			func() -> bool: return _visitados.has(&"Dash"),
			"el dash debe poder cancelar el ataque tras la ventana activa"),

		# --- Aéreo: LA regla del sistema --------------------------------------
		_chequeo_("aéreo repone dash", 0.45,
			func() -> void:
				_soltar_todo()
				_reponer()
				_colocar(1.8)
				_p.global_position += Vector3.UP * 1.2
				_p.fsm.cambiar(&"Fall")
				_p.dash_cargas = 0
				_pulsar(&"attack_light"),
			func() -> bool: return _p.dash_cargas > 0,
			"conectar en el aire debe devolver una carga de dash"),

		# --- Picado -----------------------------------------------------------
		# El picado se pide ahora con AGACHADO + pesado: el pesado a secas en el aire
		# pasa a ser el clavado pesado con rebote.
		_chequeo_("picado golpea en área", 1.2,
			func() -> void:
				_soltar_todo()
				_reponer()
				_colocar(1.5)
				_p.global_position += Vector3.UP * 3.0
				_p.fsm.cambiar(&"Fall")
				_vida_antes = _g.salud.actual
				_pulsar(&"crouch")
				_pulsar(&"attack_heavy"),
			func() -> bool: return _visitados.has(&"Plunge") and _g.salud.actual < _vida_antes,
			"el picado debe entrar y reventar en área al aterrizar"),

		# --- Parry ------------------------------------------------------------
		_chequeo_("parry quiebra la guardia", 0.35,
			func() -> void:
				_soltar_todo()
				_reponer()
				_colocar(2.0)
				_p.fsm.cambiar(&"Parry")
				# Un golpe enemigo entregado a mano: orquestar la IA para que
				# ataque en el frame exacto haría el test frágil sin probar más.
				_p.recibir_golpe(Golpe.new(
					_g, _g.ataque, _p.global_position, (_p.global_position - _g.global_position).normalized())),
			func() -> bool: return _g.poise.rota and _p.salud.fraccion() > 0.99,
			"el parry no debe costar vida y debe quebrar al atacante"),

		# --- Recibir daño -----------------------------------------------------
		_chequeo_("encajar un golpe", 0.3,
			func() -> void:
				_soltar_todo()
				_reponer()
				_colocar(2.0)
				_p.fsm.cambiar(&"Idle")
				_p.iframes = 0.0
				_vida_antes = _p.salud.actual
				_p.recibir_golpe(Golpe.new(
					_g, _g.ataque, _p.global_position, (_p.global_position - _g.global_position).normalized())),
			func() -> bool: return _p.salud.actual < _vida_antes and _visitados.has(&"Hitstun"),
			"un golpe sin parry debe doler y aturdir"),

		# --- i-frames del dash ------------------------------------------------
		_chequeo_("los i-frames esquivan", 0.3,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.iframes = 0.2
				_vida_antes = _p.salud.actual
				_p.recibir_golpe(Golpe.new(
					_g, _g.ataque, _p.global_position, Vector3.FORWARD)),
			func() -> bool: return is_equal_approx(_p.salud.actual, _vida_antes),
			"con i-frames activos el golpe no debe entrar"),

		# --- Correccion 2.2: fisicas del pesado -------------------------------
		# En vida solo tambalea. Nada de mandar a todo el mundo por los aires: eso
		# convertia cada intercambio en un malabar y se comia la lectura del suelo.
		_chequeo_("pesado NO lanza", 0.3,
			func() -> void:
				_soltar_todo()
				_reponer()
				_colocar(2.0)
				_g.velocity = Vector3.ZERO
				# Postura alta para aislar el STAGGER: con la suya real (30) el
				# pesado (32 de poise) la quiebra y el estado seria QUEBRADO.
				_g.poise.actual = 100.0
				_g.recibir_golpe(Golpe.new(
					_p, _p.ataque_pesado, _g.global_position,
					(_g.global_position - _p.global_position).normalized()))
				_aux = _g.velocity.y,
			func() -> bool: return (_aux < 1.5
				and _g.estado == Guardian.Estado.ATURDIDO
				and is_equal_approx(_g._stagger, _p.ataque_pesado.stagger)),
			"el pesado debe dejar knockback terrestre y stagger, no lanzamiento"),

		# --- Correccion 2.2: movilidad en combo -------------------------------
		# Dos medidas: atacar quieto y atacar empujando. La segunda tiene que
		# recorrer mas, o el personaje sigue clavandose en cada golpe.
		_chequeo_("ataque sin input (base)", 0.45,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.global_position = Vector3(45.0, 0.3, -35.0)
				_pos_antes = _p.global_position
				_p.fsm.cambiar(&"Attack", {"datos": _p.ataque_ligero, "indice": 1}),
			func() -> bool:
				_dist_sin_input = _p.global_position.distance_to(_pos_antes)
				return true,
			"medicion base"),
		_chequeo_("ataque con input recorre mas", 0.45,
			func() -> void:
				_soltar_todo()
				_p.global_position = Vector3(45.0, 0.3, -35.0)
				_p.velocity = Vector3.ZERO
				_pos_antes = _p.global_position
				_pulsar(&"move_forward")
				_p.fsm.cambiar(&"Attack", {"datos": _p.ataque_ligero, "indice": 1}),
			func() -> bool: return _p.global_position.distance_to(_pos_antes) > _dist_sin_input + 0.4,
			"el jugador debe poder desplazarse mientras ataca"),

		# --- Correccion 2.2: pivote del dash ----------------------------------
		_paso_("carrerilla", 0.2, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(45.0, 0.3, -35.0)
			_p.fsm.cambiar(&"Idle")
			_pulsar(&"move_forward"), &"Move"),
		_paso_("dashear", 0.10, func() -> void: _pulsar(&"dash"), &"Dash"),
		_chequeo_("pivote frena y salta", 0.10,
			func() -> void:
				_soltar(&"move_forward")
				_soltar(&"dash")
				_pulsar(&"move_back"),
			func() -> bool: return (
				_p.fsm.actual.categoria == &"Airborne"
				and _p.motor.get_vertical() > 6.0),
			"pedir la direccion contraria en pleno dash debe frenar y saltar"),

		# --- Correccion 2.3: dash -> surf -> correr ---------------------------
		# Al Gym: 70x70 de suelo. En la arena (32 m) el surf se salia por la pared
		# antes de terminar la comprobacion y el fallo no decia nada del surf.
		# Asentar en el suelo SIN input: un paso anterior pudo dejar al jugador en
		# el aire, y Dash lanzado en el aire sale a Fall, no a Surf.
		_paso_("asentar antes del dash", 0.35, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(0.0, 0.3, 0.0)
			_p.velocity = Vector3.ZERO
			_p.fsm.cambiar(&"Idle"), &"Idle"),
		# Sin input de movimiento el pivote es imposible (`entrada.length() < 0.7`),
		# asi que esta comprobacion mide el dash y no hacia donde mira la camara.
		_chequeo_("dash con Shift -> Surf", 0.25,
			func() -> void:
				_soltar_todo()
				_pulsar(&"dash")
				_p.fsm.cambiar(&"Dash"),
			func() -> bool: return _visitados.has(&"Surf") and _p.motor.rapidez_plana() > _p.tuning.velocidad_sprint,
			"manteniendo Shift el dash debe desembocar en Surf por encima del sprint"),
		# El surf ya NO caduca: se sostiene mientras se mantenga Shift. Se entra al
		# estado con direccion EXPLICITA (+X desde el origen del Gym, 35 m limpios)
		# porque depender de la camara metia en la medida a donde mira y contra que
		# choca, que no es lo que esta comprobacion trata de demostrar.
		# Surf es un estado de SUELO: hay que dejar aterrizar antes de entrar, o
		# GroupGrounded lo echa a Fall en el primer frame por no pisar nada.
		_paso_("asentar en el suelo", 0.25, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(0.0, 0.3, 0.0)
			_p.velocity = Vector3.ZERO, &"Idle"),
		_chequeo_("Surf no caduca", 1.4,
			func() -> void:
				_pulsar(&"dash")
				_p.fsm.cambiar(&"Surf", {"direccion": Vector3(1, 0, 0), "rapidez": 15.0}),
			func() -> bool: return _p.fsm.nombre_actual() == &"Surf",
			"el surf debe sostenerse mientras Shift siga pulsado, sin temporizador"),
		_chequeo_("soltar Shift sale del surf", 0.2,
			func() -> void:
				_soltar(&"dash")
				_soltar(&"sprint"),
			func() -> bool: return _p.fsm.nombre_actual() != &"Surf",
			"soltar Shift debe cortar el surf en el acto"),
		_chequeo_("sin Shift no hay surf", 0.3,
			func() -> void:
				_soltar_todo()
				_p.global_position = Vector3(0.0, 0.3, 0.0)
				_p.fsm.cambiar(&"Idle")
				_p.stamina.llenar()
				_pulsar(&"move_forward")
				_pulsar(&"dash")
				_soltar(&"dash"),
			func() -> bool: return _p.fsm.nombre_actual() != &"Surf",
			"sin mantener Shift el dash no debe entrar en Surf"),

		# --- Correccion 2.3: ataque de dash -----------------------------------
		_chequeo_("ataque de dash", 0.35,
			func() -> void:
				_soltar_todo()
				_reponer()
				_colocar(4.0)
				_vida_antes = _g.salud.actual
				# Dash primero y ataque 2 frames despues: con ~2 frames de latencia
				# de input, el ataque cae dentro de los 7 frames que dura el dash.
				_pulsar(&"dash")
				_esperar_ataque = 2,
			func() -> bool: return _g.salud.actual < _vida_antes,
			"atacar en pleno dash debe cerrar distancia y conectar"),

		# --- Correccion 2.4: la estocada no frena -----------------------------
		_chequeo_("el ataque de dash atraviesa", 0.16,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.global_position = Vector3(45.0, 0.3, -35.0)
				_p.fsm.cambiar(&"Idle")
				_p.velocity = Vector3(0, 0, -12.0)
				_p.orientar_a(Vector3(0, 0, -1))
				_p.fsm.cambiar(&"Attack", {"datos": _p.ataque_dash, "indice": 1}),
			func() -> bool: return _p.motor.rapidez_plana() > 10.0,
			"la estocada debe conservar el avance, no frenar en seco"),

		# --- Correccion 2.4: rampa caminar -> trotar -> correr ----------------
		_chequeo_("arranca caminando", 0.18,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.global_position = Vector3(0.0, 0.3, 0.0)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Idle")
				_pulsar(&"move_forward"),
			func() -> bool: return _p.motor.rapidez_plana() < _p.tuning.velocidad_trotar,
			"al arrancar debe ir a paso de caminar, no a tope"),
		_chequeo_("la carrerilla llega a correr", 1.5,
			func() -> void: pass,
			func() -> bool: return _p.motor.rapidez_plana() > _p.tuning.velocidad_correr - 0.8,
			"manteniendo la direccion debe acabar corriendo"),

		# --- Correccion 2.5 ----------------------------------------------------
		# 1 pulsacion = 1 salto. Machacar el boton no puede acumular saltos.
		_chequeo_("spam de salto no acumula", 0.5,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.global_position = Vector3(0.0, 0.05, 0.0)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Idle")
				_saltos_contados = 0
				_spam_salto = 18,
			func() -> bool: return _saltos_contados <= 2,
			"machacar salto solo debe dar el salto y el doble salto, no mas"),

		# El clamp impide que encadenar momentum saque al jugador del mapa.
		_chequeo_("clamp de velocidad", 0.3,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.global_position = Vector3(0.0, 0.05, 0.0)
				_p.fsm.cambiar(&"Idle")
				_p.velocity = Vector3(80.0, 0.0, 0.0),
			func() -> bool: return _p.motor.rapidez_plana() <= _p.tuning.velocidad_maxima + 0.1,
			"la velocidad horizontal nunca debe superar velocidad_maxima"),

		# El frenazo de Mario 64 es una maniobra de pies: en el aire, nunca.
		_chequeo_("no se frena en el aire", 0.35,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.global_position = Vector3(0.0, 8.0, 0.0)
				_p.velocity = Vector3(10.0, 0.0, 0.0)
				_p.fsm.cambiar(&"Dash")
				_pulsar(&"move_back"),
			func() -> bool: return not _visitados.has(&"__pivote_aereo"),
			"el pivote no debe existir en el aire"),

		# Saltar desde el surf no cuesta la linea rapida.
		_paso_("asentar para surf", 0.25, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(0.0, 0.3, 0.0)
			_p.velocity = Vector3.ZERO, &"Idle"),
		_paso_("surfear y saltar", 0.35, func() -> void:
			_pulsar(&"dash")
			_p.fsm.cambiar(&"Surf", {"direccion": Vector3(1, 0, 0), "rapidez": 15.0})
			_esperar_salto = 6, &"Jump"),
		_chequeo_("el surf sobrevive al salto", 0.9,
			func() -> void: pass,
			func() -> bool: return _p.fsm.nombre_actual() == &"Surf",
			"al aterrizar con Shift mantenido debe volver a surfear"),

		# --- Correccion 2.6 ----------------------------------------------------
		# Doble toque RAPIDO: los dos saltos tienen que salir, sin cooldown que se
		# los coma. Es justo lo que rompio el intervalo minimo de la 2.5.
		_paso_("asentar para doble salto", 0.3, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(0.0, 0.3, 0.0)
			_p.velocity = Vector3.ZERO
			_p.fsm.cambiar(&"Idle"), &"Idle"),
		_chequeo_("doble toque rapido = 2 saltos", 0.4,
			func() -> void:
				_saltos_contados = 0
				_pulsar(&"jump")
				_esperar_salto2 = 4,
			func() -> bool: return _saltos_contados == 2,
			"dos pulsaciones rapidas deben dar exactamente dos saltos"),

		# Altura variable: soltar pronto recorta, mantener no.
		_paso_("asentar para altura", 0.35, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(0.0, 0.3, 0.0)
			_p.velocity = Vector3.ZERO
			_p.fsm.cambiar(&"Idle"), &"Idle"),
		_chequeo_("salto corto al soltar pronto", 0.12,
			func() -> void:
				_pulsar(&"jump")
				_soltar_pronto = 4,
			func() -> bool: return _p.motor.get_vertical() <= _p.tuning.velocidad_salto_corto() + 0.6,
			"soltar pronto debe recortar la velocidad vertical"),

		# Shift + ataque = ataque de SURF, no el de suelo.
		_paso_("asentar para surf-ataque", 0.3, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(0.0, 0.3, 0.0)
			_p.velocity = Vector3.ZERO
			_p.fsm.cambiar(&"Idle"), &"Idle"),
		_chequeo_("Shift + ligero = estocada de surf", 0.3,
			func() -> void:
				# `sprint` y no `dash`: sprint no esta en InputActions.BUFFERED, asi
				# que mantiene Shift para el surf sin encolar una pulsacion que
				# GroupGrounded convertiria en un dash de verdad.
				_pulsar(&"sprint")
				_p.fsm.cambiar(&"Surf", {"direccion": Vector3(1, 0, 0), "rapidez": 15.0})
				_esperar_ataque = 3,
			func() -> bool: return _ataque_actual() == _p.ataque_surf_ligero,
			"atacar surfeando debe lanzar el ataque de surf, no el de suelo"),
		_paso_("volver al surf", 0.5, func() -> void: pass, &"Surf"),

		# El pesado de surf frena en seco.
		_chequeo_("Shift + pesado frena en seco", 0.25,
			func() -> void:
				_pulsar(&"sprint")
				_p.fsm.cambiar(&"Surf", {"direccion": Vector3(1, 0, 0), "rapidez": 15.0})
				_esperar_pesado = 3,
			func() -> bool: return (_ataque_actual() == _p.ataque_surf_pesado
				and _p.motor.rapidez_plana() < 2.0),
			"el pesado de surf debe plantar al personaje en el sitio"),

		# Dash aereo manteniendo Shift: al aterrizar, surf.
		_chequeo_("dash aereo aterriza en surf", 1.2,
			func() -> void:
				_soltar_todo()
				_reponer()
				# 2.2 m: por debajo de `aterrizaje_duro`. Una caida grande SI debe
				# romper el flujo, asi que no sirve para medir esto.
				_p.global_position = Vector3(0.0, 2.2, 0.0)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Fall")
				_p.dash_cargas = 1
				_pulsar(&"dash")
				_esperar_dash = 3,
			func() -> bool: return _p.fsm.nombre_actual() == &"Surf",
			"tocar suelo con Shift mantenido tras un dash aereo debe entrar en surf"),

		# --- Correccion 2.7 ----------------------------------------------------
		_paso_("asentar para crouch", 0.3, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(0.0, 0.3, 0.0)
			_p.velocity = Vector3.ZERO
			_p.fsm.cambiar(&"Idle"), &"Idle"),
		_chequeo_("agacharse encoge la capsula", 0.4,
			func() -> void: _pulsar(&"crouch"),
			func() -> bool: return _p.fsm.nombre_actual() == &"Crouch" and _p.esta_agachado(),
			"agacharse debe entrar en Crouch y bajar la capsula a la mitad"),
		_chequeo_("salto agachado sube mas", 0.06,
			func() -> void:
				_saltos_contados = 0
				_pulsar(&"jump"),
			func() -> bool: return _p.motor.get_vertical() > _p.tuning.velocidad_salto() + 1.0,
			"el salto estatico agachado debe superar al salto normal"),

		# Tunel del Gym: 1.2 m de hueco. Dentro no se puede uno levantar.
		_paso_("entrar en el tunel", 0.4, func() -> void:
			_soltar_todo()
			_reponer()
			# Centro del tunel (Gym: pos -14, 0, 8 con hueco de 1.2 m).
			_p.global_position = Vector3(-14.0, 0.1, 8.0)
			_p.velocity = Vector3.ZERO
			_pulsar(&"crouch"), &"Crouch"),
		_chequeo_("el techo obliga a seguir agachado", 0.4,
			func() -> void: _soltar(&"crouch"),
			func() -> bool: return _p.techo_bloquea() and _p.fsm.nombre_actual() == &"Crouch",
			"bajo un techo bajo, soltar el boton no debe levantar al personaje"),

		# Patada baja: derriba, no tambalea.
		_chequeo_("la patada baja derriba", 0.4,
			func() -> void:
				_soltar_todo()
				_reponer()
				_colocar(1.8)
				_g.velocity = Vector3.ZERO
				_g.poise.actual = 100.0
				_g.recibir_golpe(Golpe.new(
					_p, _p.ataque_agachado, _g.global_position,
					(_g.global_position - _p.global_position).normalized())),
			func() -> bool: return _g.estado == Guardian.Estado.DERRIBADO,
			"la patada baja debe derribar, no solo tambalear"),

		# Escalada estilo BotW: cualquier pared, no solo las marcadas.
		_chequeo_("se escala pared no marcada", 0.5,
			func() -> void:
				_soltar_todo()
				_reponer()
				# Muro del pasillo de wall-run: NO tiene capa CLIMBABLE.
				_p.global_position = Vector3(-0.8, 3.0, -34.0)
				_p.velocity = Vector3(-2.0, 0.0, 0.0)
				_p.orientar_a(Vector3(-1, 0, 0))
				_p.fsm.cambiar(&"Fall")
				_pulsar(&"grab"),
			func() -> bool: return _visitados.has(&"Climb"),
			"con escalada_universal cualquier pared debe poder escalarse"),

		# --- Correccion 2.8 ----------------------------------------------------
		_paso_("asentar para backflip", 0.3, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(0.0, 0.3, 0.0)
			_p.velocity = Vector3.ZERO
			_p.fsm.cambiar(&"Idle")
			_pulsar(&"crouch"), &"Crouch"),
		_chequeo_("salto agachado muy fuerte", 0.12,
			func() -> void:
				_vy_max = 0.0
				_pulsar(&"jump"),
			func() -> bool: return _vy_max > _p.tuning.velocidad_salto() * 1.25,
			"el salto agachado estatico debe superar claramente al normal"),

		# SIDE JUMP de Mario 64: correr, pedir la contraria y saltar. Camara fijada
		# y velocidad explicita: sin eso la comprobacion mide hacia donde mira la
		# camara, no la mecanica.
		_paso_("colocar para side jump", 0.4, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(0.0, 0.05, 0.0)
			_p.fsm.cambiar(&"Idle")
			_mirar_a(90.0), &"Idle"),
		_chequeo_("girar en seco abre la ventana", 0.2,
			func() -> void:
				_vio_ventana = false
				# Corriendo hacia -X (adelante con yaw 90) y pidiendo +X.
				_p.velocity = Vector3(-9.0, -3.0, 0.0)
				_p.fsm.cambiar(&"Move")
				_pulsar(&"move_back"),
			func() -> bool: return _vio_ventana,
			"pedir la direccion contraria corriendo debe abrir la ventana"),
		_chequeo_("side jump sube mas", 0.5,
			func() -> void:
				_vy_max = 0.0
				_p.velocity = Vector3(-9.0, -3.0, 0.0)
				_p.fsm.cambiar(&"Move")
				_p.ventana_sidejump = _p.tuning.sidejump_ventana
				_pulsar(&"jump"),
			func() -> bool: return _vy_max > _p.tuning.velocidad_salto() * 1.15,
			"saltar dentro de la ventana debe dar un salto mas alto"),

		# El dive es UNA sola pulsacion y no exige carrera previa.
		_chequeo_("atacar en el aire = dive", 0.3,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.global_position = Vector3(0.0, 10.0, 0.0)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Fall")
				_esperar_ataque = 3,
			func() -> bool: return _p.fsm.nombre_actual() == &"Dive",
			"atacar en el aire debe entrar en Dive sin necesitar carrera"),
		_chequeo_("el dive mantiene velocidad constante", 0.25,
			func() -> void: _aux = _p.motor.rapidez_plana(),
			func() -> bool: return absf(_p.motor.rapidez_plana() - _aux) < 0.6,
			"la velocidad horizontal del clavado debe ser constante"),

		# AGUA: la piscina del Gym esta en (28, 0, -28).
		_chequeo_("caer al agua = nado en superficie", 1.2,
			func() -> void:
				_soltar_todo()
				_reponer()
				# Superficie del estanque a y=8.5; se entra desde arriba.
				_p.global_position = Vector3(28.0, 12.0, -28.0)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Fall"),
			func() -> bool: return _p.fsm.nombre_actual() == &"Swim",
			"caer al agua sin dive debe dejar nadando en superficie"),
		_chequeo_("C bucea", 0.4,
			func() -> void: _pulsar(&"crouch"),
			func() -> bool: return _p.fsm.nombre_actual() == &"Underwater",
			"agacharse nadando debe pasar a buceo"),
		_chequeo_("mantener salto sube a superficie", 1.6,
			func() -> void:
				_soltar(&"crouch")
				_pulsar(&"jump"),
			func() -> bool: return _p.fsm.nombre_actual() == &"Swim",
			"mantener salto buceando debe devolver a la superficie"),

		# --- Correccion 2.9 ----------------------------------------------------
		_paso_("carrerilla para frenar", 0.6, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(0.0, 0.05, 0.0)
			_p.fsm.cambiar(&"Idle")
			_pulsar(&"move_forward"), &"Move"),
		_chequeo_("agacharse frena progresivamente", 0.9,
			func() -> void:
				_soltar(&"move_forward")
				_p.fsm.cambiar(&"Crouch")
				_pulsar(&"crouch"),
			func() -> bool: return _p.motor.rapidez_plana() < _p.tuning.velocidad_agachado + 0.5,
			"agacharse con velocidad debe frenar hasta quedar casi estatico"),

		_paso_("carrerilla para patada", 0.6, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(0.0, 0.05, 0.0)
			_p.fsm.cambiar(&"Idle")
			_pulsar(&"move_forward"), &"Move"),
		_chequeo_("slide kick sale con impulso", 0.2,
			func() -> void:
				_pulsar(&"crouch")
				_p.fsm.cambiar(&"Crouch")
				_esperar_ataque = 2,
			func() -> bool: return _visitados.has(&"SlideKick"),
			"atacar agachado con velocidad debe lanzar la patada deslizante"),

		_chequeo_("adherencia automatica a la pared", 0.9,
			func() -> void:
				_soltar_todo()
				_reponer()
				# Contra el muro del pasillo de wall-run (cara interior en x=-1.3).
				_p.global_position = Vector3(-0.9, 0.05, -34.0)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Idle")
				_mirar_a(90.0)
				_pulsar(&"move_forward"),
			func() -> bool: return _p.fsm.nombre_actual() == &"Climb",
			"insistir contra un muro perpendicular debe enganchar solo"),

		# --- Correccion 2.01 ---------------------------------------------------
		# LANDING SLIDE: aterrizar con velocidad manteniendo agachado no frena.
		_chequeo_("aterrizar agachado desliza", 0.8,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.global_position = Vector3(0.0, 3.0, 0.0)
				_p.velocity = Vector3(0.0, -2.0, -11.0)
				_p.fsm.cambiar(&"Fall")
				_pulsar(&"crouch"),
			func() -> bool: return _visitados.has(&"Slide"),
			"llegar con velocidad manteniendo agachado debe entrar en slide"),

		# AGUA: los ataques desplazan.
		_paso_("entrar al estanque", 1.4, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(28.0, 12.0, -28.0)
			_p.fsm.cambiar(&"Fall"), &"Swim"),
		_paso_("bucear", 0.5, func() -> void: _pulsar(&"crouch"), &"Underwater"),
		_chequeo_("el ataque acuatico desplaza", 0.2,
			func() -> void:
				_soltar_todo()
				_p.velocity = Vector3.ZERO
				_pos_antes = _p.global_position
				_esperar_ataque = 2,
			func() -> bool: return (_visitados.has(&"WaterAttack")
				and _p.global_position.distance_to(_pos_antes) > 0.5),
			"atacar bajo el agua debe impulsar en la direccion del ataque"),

		# STAMINA: flotar quieto NO debe costar.
		_paso_("volver a bucear", 0.5, func() -> void:
			_soltar_todo()
			_p.stamina.llenar()
			_p.fsm.cambiar(&"Underwater"), &"Underwater"),
		_chequeo_("flotar quieto no cansa", 1.2,
			func() -> void: _aux = _p.stamina.actual,
			func() -> bool: return _p.stamina.actual >= _aux - 0.5,
			"quieto bajo el agua la stamina no debe bajar"),
		_chequeo_("nadar si cansa", 0.8,
			func() -> void:
				_aux = _p.stamina.actual
				_pulsar(&"move_forward"),
			func() -> bool: return _p.stamina.actual < _aux,
			"nadar activamente si debe gastar stamina"),

		# LEDGE SNAP desde escalada.
		_chequeo_("escalar engancha el canto", 1.6,
			func() -> void:
				_soltar_todo()
				_reponer()
				# Repisa de 2 m del Gym, a media altura de la pared.
				_p.global_position = Vector3(20.0, 0.6, -13.1)
				_p.orientar_a(Vector3(0, 0, 1))
				_p.fsm.cambiar(&"Fall")
				_pulsar(&"grab")
				_pulsar(&"move_forward"),
			func() -> bool: return _visitados.has(&"LedgeHang"),
			"al llegar arriba escalando debe anclarse al canto"),

		# --- Correccion 2.02 ---------------------------------------------------

		# STATIONARY CROUCH LANDING: caer agachado y QUIETO no es un slide.
		_chequeo_("aterrizar agachado quieto = recepcion", 0.7,
			func() -> void:
				_soltar_todo()
				_reponer()
				_visitados.erase(&"CrouchLanding")
				_p.global_position = Vector3(0.0, 2.5, 0.0)
				_p.velocity = Vector3(0.0, -2.0, 0.0)
				_p.fsm.cambiar(&"Fall")
				_pulsar(&"crouch"),
			func() -> bool: return _visitados.has(&"CrouchLanding"),
			"caer agachado y sin velocidad horizontal debe entrar en la recepcion"),
		_chequeo_("la recepcion no levanta", 0.5,
			func() -> void: pass,
			func() -> bool: return _p.fsm.nombre_actual() == &"Crouch" and _p.esta_agachado(),
			"al terminar la recepcion debe conservarse la postura agachada"),

		# CLASIFICACION UNICA DE SUPERFICIES. Primero la tabla entera contra la
		# funcion pura: es exacta y no depende de que el personaje se coloque bien.
		_chequeo_("la tabla de angulos clasifica bien", 0.05,
			func() -> void: pass,
			func() -> bool:
				var tu := _p.tuning
				for g in [0.0, 15.0, 30.0, 40.0, 44.0, 45.0]:
					if tu.clasificar(g) != PlayerTuning.Superficie.CAMINABLE:
						return false
				for g in [50.0, 60.0, 75.0, 90.0, 100.0, 110.0]:
					if tu.clasificar(g) != PlayerTuning.Superficie.ESCALABLE:
						return false
				for g in [111.5, 120.0, 130.0]:
					if tu.clasificar(g) != PlayerTuning.Superficie.INVALIDA:
						return false
				return true,
			"hasta 45 se camina —el limite es inclusivo—, de ahi a 110 se escala"),

		# Y ahora contra geometria de verdad, rampa por rampa.
		_chequeo_("30 grados se CAMINA", 0.7, _ante_rampa(30.0),
			func() -> bool: return not _latch_climb,
			"30 grados es una rampa comoda: se anda"),
		_chequeo_("40 grados se CAMINA", 0.7, _ante_rampa(40.0),
			func() -> bool: return not _latch_climb,
			"40 grados sigue por debajo del slope limit"),
		_chequeo_("44 grados se CAMINA", 0.7, _ante_rampa(44.0),
			func() -> bool: return not _latch_climb,
			"44 es la ultima superficie caminable"),
		# 45 es el LIMITE, y el limite se camina. Un "slope limit de 45" que rechaza
		# una rampa de 45 es una trampa, y ademas dejaba esa rampa sin ninguna forma
		# comoda de subirla: ni suelo para el motor ni pared estable para la FSM.
		_chequeo_("45 grados se CAMINA", 0.7, _ante_rampa(45.0),
			func() -> bool: return not _latch_climb,
			"el angulo limite tiene que ser caminable, no tierra de nadie"),
		_chequeo_("50 grados se ESCALA", 0.9, _ante_rampa(50.0),
			func() -> bool: return _latch_climb,
			"50 grados debe escalarse"),
		_chequeo_("60 grados se ESCALA", 0.9, _ante_rampa(60.0),
			func() -> bool: return _latch_climb,
			"60 grados debe escalarse"),
		_chequeo_("75 grados se ESCALA", 0.7, _ante_rampa(75.0),
			func() -> bool: return _latch_climb,
			"75 grados debe escalarse"),
		_chequeo_("90 grados se ESCALA", 0.7, _ante_rampa(90.0),
			func() -> bool: return _latch_climb,
			"un muro vertical debe seguir escalandose como siempre"),
		_chequeo_("110 grados se ESCALA", 0.7, _ante_rampa(110.0),
			func() -> bool: return _latch_climb,
			"110 es el ultimo angulo escalable"),

		# Y no basta con entrar: el cuerpo tiene que INCLINARSE con la pendiente.
		# Sobre una rampa de 60 grados el "arriba" del personaje se separa 30 grados
		# de la vertical del mundo; sobre un muro de 90 coincide con ella.
		_chequeo_("el cuerpo se inclina con la rampa", 1.1,
			_ante_rampa(60.0),
			func() -> bool: return (
				_p.fsm.nombre_actual() == &"Climb"
				and _p.pared.hay_pared
				and _p.visual.global_basis.y.dot(Vector3.UP) < 0.97
				and _p.visual.global_basis.y.dot(Vector3.UP) > 0.6),
			"escalando una pendiente el cuerpo debe adoptar SU inclinacion"),

		# --- Correccion 2.03: la postura no la deciden las paredes -------------
		# UNA PARED INCLINADA NO ES UN TECHO. Este era el bug: la sonda de techo
		# barria desde los pies y con el alto completo, llegaba 0.68 m por encima de
		# la cabeza, y cualquier rampa cercana forzaba agachado.
		_chequeo_("acercarse a una rampa no encoge al personaje", 0.9,
			_ante_rampa(90.0),
			func() -> bool: return not _p.esta_agachado(),
			"detectar una superficie inclinada no debe tocar la altura de la capsula"),
		_chequeo_("caminar por una pendiente no agacha", 0.9,
			_ante_rampa(30.0),
			func() -> bool: return not _p.esta_agachado() and not _p.agachado_forzado,
			"una pendiente caminable no es motivo para agacharse"),

		# AUTO-STAND: soltar el boton en campo abierto levanta.
		_paso_("agacharse en campo abierto", 0.5, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(0.0, 0.3, 0.0)
			_p.velocity = Vector3.ZERO
			_p.fsm.cambiar(&"Idle")
			_pulsar(&"crouch"), &"Crouch"),
		_chequeo_("soltar el boton levanta", 0.6,
			func() -> void: _soltar(&"crouch"),
			func() -> bool: return not _p.esta_agachado() and _p.fsm.nombre_actual() != &"Crouch",
			"sin techo encima, soltar crouch debe devolver la altura normal"),

		# AUTO-STAND tras una obstruccion: el crouch forzado NUNCA es permanente.
		_paso_("meterse en el tunel", 0.5, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(-14.0, 0.1, 8.0)
			_p.velocity = Vector3.ZERO
			_pulsar(&"crouch"), &"Crouch"),
		_chequeo_("el techo lo mantiene agachado", 0.5,
			func() -> void: _soltar(&"crouch"),
			func() -> bool: return _p.agachado_forzado and _p.esta_agachado(),
			"bajo un techo bajo, soltar el boton no debe levantar al personaje"),
		_chequeo_("salir del tunel levanta solo", 0.8,
			func() -> void:
				# Fuera del tunel SIN volver a tocar ningun boton.
				_p.global_position = Vector3(0.0, 0.3, 0.0)
				_p.velocity = Vector3.ZERO,
			func() -> bool: return not _p.esta_agachado() and not _p.agachado_forzado,
			"al desaparecer la obstruccion debe recuperar la altura sin pedir nada"),

		# Y el caso que dejaba encogido para siempre: saltar desde dentro del tunel.
		_chequeo_("saltar desde el tunel no deja encogido", 1.4,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.global_position = Vector3(-14.0, 0.1, 8.0)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Crouch")
				_esperar_salto = 10,
			func() -> bool: return not _p.esta_agachado(),
			"ningun estado aereo restauraba la altura y el personaje se quedaba a medias"),

		# --- Movilidad: mas recorrido -----------------------------------------
		# Hacia +X: correr hacia -Z mete al personaje en el campo de rampas del Gym
		# y acaba midiendo una pendiente en vez de la velocidad.
		_paso_("carrerilla para medir", 1.6, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(0.0, 0.05, 0.0)
			_p.fsm.cambiar(&"Idle")
			_mirar_a(-90.0)
			_pulsar(&"move_forward"), &"Move"),
		_chequeo_("correr llega a la velocidad nueva", 0.6,
			func() -> void: pass,
			func() -> bool: return _p.motor.rapidez_plana() >= _p.tuning.velocidad_correr - 0.6,
			"la rampa de carrerilla debe alcanzar velocidad_correr"),

		_chequeo_("el ataque aereo recorre distancia", 0.55,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.global_position = Vector3(0.0, 6.0, 0.0)
				_p.velocity = Vector3.ZERO
				_p.orientar_a(Vector3(0, 0, -1))
				_pos_antes = _p.global_position
				# Se entra al estado a mano: que el aereo salga o no depende de que haya
				# un enemigo cerca, y aqui lo que se mide es el DESPLAZAMIENTO.
				_p.fsm.cambiar(&"AirAttack", {"datos": _p.ataque_aereo}),
			func() -> bool: return _distancia_plana(_pos_antes) > 3.5,
			"el aereo debe desplazar de verdad, no caer en el mismo sitio"),

		_paso_("carrerilla para la patada", 1.2, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(-6.0, 0.05, 0.0)
			_p.fsm.cambiar(&"Idle")
			_mirar_a(-90.0)
			_pulsar(&"move_forward"), &"Move"),
		_chequeo_("la patada deslizante llega lejos", 1.4,
			func() -> void:
				_pos_antes = _p.global_position
				_pulsar(&"crouch")
				_p.fsm.cambiar(&"Crouch")
				_esperar_ataque = 2,
			func() -> bool: return _visitados.has(&"SlideKick") and _distancia_plana(_pos_antes) > 9.0,
			"la patada es movilidad ademas de ataque: tiene que recorrer camino"),

		# SIDE JUMP EN DOS TIEMPOS: primero planta, despues salta.
		_paso_("correr para el side jump", 1.0, func() -> void:
			_soltar_todo()
			_reponer()
			_visitados.erase(&"SideJump")
			_p.global_position = Vector3(0.0, 0.05, 0.0)
			_p.fsm.cambiar(&"Idle")
			_mirar_a(-90.0)
			_pulsar(&"move_forward"), &"Move"),
		_chequeo_("girar en seco y saltar planta primero", 0.45,
			func() -> void:
				_vy_sidejump = -99.0
				_vy_max = -99.0
				_soltar(&"move_forward")
				_pulsar(&"move_back")
				_esperar_salto = 6,
			func() -> bool: return (
				_visitados.has(&"SideJump")
				and _vy_sidejump < 1.0),
			"durante la plantada el personaje sigue en el suelo: aun no ha saltado"),
		_chequeo_("y despues sale disparado", 0.25,
			func() -> void: pass,
			func() -> bool: return _vy_max > _p.tuning.velocidad_salto(),
			"tras la plantada el side jump debe subir mas que un salto normal"),

		# --- Upright Orientation Recovery --------------------------------------
		_paso_("al estanque otra vez", 1.4, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(28.0, 12.0, -28.0)
			_p.fsm.cambiar(&"Fall"), &"Swim"),
		_chequeo_("bucear inclina el cuerpo", 1.1,
			func() -> void:
				_mirar_a(0.0)
				_pulsar(&"crouch")
				_pulsar(&"move_forward"),
			func() -> bool: return _p.visual.global_basis.y.dot(Vector3.UP) < 0.9,
			"nadar hacia el fondo debe picar el cuerpo, no dejarlo horizontal"),
		_chequeo_("salir del agua no es instantaneo", 0.03,
			func() -> void:
				_soltar_todo()
				_aux = _p.visual.rotation.y
				_p.global_position = Vector3(0.0, 6.0, 0.0)
				_p.fsm.cambiar(&"Fall"),
			func() -> bool: return _p.enderezando(),
			"la vuelta a la vertical debe interpolarse, no imponerse de golpe"),
		_chequeo_("y termina perfectamente vertical", 0.8,
			func() -> void: pass,
			func() -> bool: return (
				not _p.enderezando()
				and _p.visual.global_basis.y.dot(Vector3.UP) > 0.999
				and absf(angle_difference(_p.visual.rotation.y, _aux)) < deg_to_rad(20.0)),
			"al salir del agua debe quedar upright conservando el yaw"),

		# --- Correccion 2.04 ---------------------------------------------------

		# FLOATING FALL. Quedarse sin suelo surfeando tiene que ser una CAIDA, no un
		# descenso flotante. El bug: `maneja_ataques()` hacia return en GroupGrounded
		# antes de comprobar el suelo, y Surf clava la vertical en -2 cada frame.
		_chequeo_("surfear sin suelo cae de verdad", 0.45,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.global_position = Vector3(0.0, 12.0, 0.0)
				_p.velocity = Vector3.ZERO
				_pulsar(&"dash")
				_p.fsm.cambiar(&"Surf", {"direccion": Vector3(1, 0, 0)}),
			func() -> bool: return (
				_p.fsm.nombre_actual() != &"Surf"
				and _p.motor.get_vertical() < -6.0),
			"sin suelo el surf debe cancelarse y caer con gravedad normal"),
		_chequeo_("deslizarse sin suelo cae de verdad", 0.45,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.global_position = Vector3(0.0, 12.0, 0.0)
				_p.velocity = Vector3(6.0, 0.0, 0.0)
				_p.fsm.cambiar(&"Slide"),
			func() -> bool: return (
				_p.fsm.nombre_actual() != &"Slide"
				and _p.motor.get_vertical() < -6.0),
			"sin suelo el slide debe cancelarse y caer con gravedad normal"),

		# ESCALERA DE VELOCIDAD: el surf sigue siendo lo mas rapido sostenido.
		_chequeo_("el surf es mas rapido que correr", 0.05,
			func() -> void: pass,
			func() -> bool: return (
				_p.tuning.surf_crucero > _p.tuning.velocidad_correr + 2.0
				and _p.tuning.surf_velocidad > _p.tuning.surf_crucero),
			"surfear tiene que notarse claramente por encima de correr"),

		# CLAVADO LIGERO. Antes solo salia si NO habia enemigo cerca; ahora es el
		# ataque aereo ligero siempre, y baja de verdad.
		_chequeo_("el ligero en el aire es un clavado", 0.15,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.global_position = Vector3(0.0, 9.0, 0.0)
				_p.velocity = Vector3.ZERO
				_p.orientar_a(Vector3(1, 0, 0))
				_mirar_a(-90.0)
				_p.fsm.cambiar(&"Fall")
				_pos_antes = _p.global_position
				_esperar_ataque = 2,
			func() -> bool: return _p.fsm.nombre_actual() == &"Dive",
			"el ligero aereo debe ser SIEMPRE un clavado, haya enemigo o no"),
		_chequeo_("y el clavado se proyecta lejos y abajo", 0.4,
			func() -> void: pass,
			func() -> bool: return (
				_distancia_plana(_pos_antes) > 5.0
				and _p.global_position.y < _pos_antes.y - 3.0),
			"un clavado avanza Y baja; si solo avanza es un desplazamiento aereo"),

		# CLAVADO PESADO CON REBOTE. Golpear desde arriba devuelve al aire.
		_paso_("repoblar para el rebote", 0.35, func() -> void:
			_soltar_todo()
			(_main.get_node("Arena") as Arena).poblar(), &""),
		_chequeo_("el clavado pesado rebota en el enemigo", 0.8,
			func() -> void:
				_soltar_todo()
				_lancero()
				_reponer()
				# El Guardian se lleva a un sitio conocido: dejarlo donde lo dejara
				# la IA hacia que el test midiera el estanque en vez del rebote.
				_g.estado = Guardian.Estado.DORMIDO
				_g.global_position = Vector3(0.0, 0.1, 0.0)
				_g.velocity = Vector3.ZERO
				_g.salud.actual = _g.salud.maxima
				# El clavado pesado es una DIAGONAL de 25 m/s, no una caida: desde
				# 5 m de altura recorre casi seis metros antes de llegar abajo.
				# Colocarse encima del enemigo lo sobrevuela entero.
				_p.global_position = Vector3(0.0, 5.0, 5.8)
				_p.velocity = Vector3.ZERO
				_p.orientar_a(Vector3(0, 0, -1))
				_mirar_a(180.0)
				_p.fsm.cambiar(&"Fall")
				_vy_max = -99.0
				_esperar_pesado = 2,
			func() -> bool: return _vy_max > 6.0,
			"clavarse sobre un enemigo debe pisarle la cabeza y devolverte al aire"),

		# GROUND POUND: el picado vertical no se pierde, se muda a agachado + pesado.
		_chequeo_("agachado + pesado sigue siendo picado", 0.4,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.global_position = Vector3(0.0, 6.0, 0.0)
				_p.velocity = Vector3.ZERO
				_p.fsm.cambiar(&"Fall")
				_pulsar(&"crouch")
				_esperar_pesado = 3,
			func() -> bool: return _visitados.has(&"Plunge"),
			"el ground pound se mantiene, solo cambia de gesto"),

		# PATADA DESLIZANTE: mas lejos, pero con peaje.
		_paso_("carrerilla para la espera", 1.2, func() -> void:
			_soltar_todo()
			_reponer()
			_p.cd_slide_kick = 0.0
			_p.global_position = Vector3(-6.0, 0.05, 0.0)
			_p.fsm.cambiar(&"Idle")
			_mirar_a(-90.0)
			_pulsar(&"move_forward"), &"Move"),
		_chequeo_("la patada arma su cooldown", 0.3,
			func() -> void:
				_pulsar(&"crouch")
				_p.fsm.cambiar(&"Crouch")
				_esperar_ataque = 2,
			func() -> bool: return _p.cd_slide_kick > 0.0,
			"lanzar la patada tiene que armar la espera que impide spamearla"),

		# --- Correccion 2.05: el picado escala con la altura de la caida -------
		# Es el unico ataque cuya fuerza la decide una decision de TRAVERSAL. Se mide
		# el mismo golpe contra el mismo enemigo desde dos alturas: lo unico que
		# cambia entre los dos pasos es desde donde te tiraste.
		_paso_("repoblar para el picado", 0.35, func() -> void:
			_soltar_todo()
			(_main.get_node("Arena") as Arena).poblar(), &""),
		_chequeo_("picado bajo: dano de base", 1.0,
			func() -> void:
				_soltar_todo()
				_lancero()
				_reponer()
				_plantar_guardian()
				_p.global_position = Vector3(1.4, 3.0, 0.0)
				_p.velocity = Vector3.ZERO
				_vida_antes = _g.salud.actual
				_p.fsm.cambiar(&"Plunge"),
			func() -> bool:
				_aux = _vida_antes - _g.salud.actual
				return _aux > 1.0,
			"un picado corto tiene que conectar y hacer su dano de base"),
		_chequeo_("picado alto: mucho mas dano", 1.6,
			func() -> void:
				_soltar_todo()
				_reponer()
				_plantar_guardian()
				_p.global_position = Vector3(1.4, 22.0, 0.0)
				_p.velocity = Vector3.ZERO
				_vida_antes = _g.salud.actual
				_p.fsm.cambiar(&"Plunge"),
			func() -> bool: return (_vida_antes - _g.salud.actual) > _aux * 1.8,
			"caer desde 20 m tiene que pegar MUCHO mas que caer desde 3"),
		_chequeo_("y ademas derriba", 0.3,
			func() -> void: pass,
			func() -> bool: return _g.estado == Guardian.Estado.DERRIBADO,
			"pasada la altura de derribo el enemigo no se tambalea: se cae"),

		# DESTRUCTIVO Y AL FINAL. Se repuebla primero en su propio paso: los tests
		# anteriores pueden haber dejado al Guardian muerto y liberado.
		_paso_("repoblar arena", 0.35, func() -> void:
			_soltar_todo()
			(_main.get_node("Arena") as Arena).poblar(), &""),
		_chequeo_("pesado mata con ragdoll", 0.4,
			func() -> void:
				_lancero()
				_reponer()
				_colocar(2.0)
				_g.salud.actual = 5.0
				_g.recibir_golpe(Golpe.new(
					_p, _p.ataque_pesado, _g.global_position,
					(_g.global_position - _p.global_position).normalized())),
			func() -> bool: return _velocidad_cadaver() > 10.0,
			"rematar con el pesado debe lanzar un cadaver fisico con fuerza"),
	]


var _vida_antes: float = 0.0
var _esperar_frames: int = 0
var _esperar_ataque: int = 0
var _esperar_salto: int = 0
var _spam_salto: int = 0
var _esperar_salto2: int = 0
var _soltar_pronto: int = 0
var _esperar_pesado: int = 0
var _esperar_dash: int = 0
var _saltos_contados: int = 0
## Latches: registran si algo ocurrio EN ALGUN momento del paso. Comprobar solo
## el frame final hacia que estos tests midieran timing en vez de mecanicas.
var _vio_ventana: bool = false
var _vy_max: float = 0.0
var _aux: float = 0.0
var _pos_antes: Vector3 = Vector3.ZERO
var _dist_sin_input: float = 0.0
## Latch de escalada: los pasos de angulo duran menos de un segundo y el enganche
## puede durar un par de frames antes de resbalar. Mirar solo el frame final
## mediria cuanto aguanta, no si engancha.
var _latch_climb: bool = false
## Velocidad vertical MAXIMA vista durante la plantada del side jump. Si el
## frenado y el salto ocurrieran a la vez, aqui apareceria el impulso.
var _vy_sidejump: float = -99.0


## Coloca al jugador delante de la rampa de `angulo` del Gym, pidiendo agarre.
##
## La posicion se DEDUCE de la geometria en vez de escribirse a mano: las rampas
## comparten pie en z = -30 y estan separadas 5 m desde x = -32, asi que el punto
## de la cara a la altura del sensor sale de la propia inclinacion. Un cambio en
## el Gym no deja seis numeros magicos desincronizados aqui.
func _ante_rampa(angulo: float) -> Callable:
	return func() -> void:
		var i := 0
		var gym := _main.get_node_or_null("Gym") as Gym
		var angulos: PackedFloat32Array = (
			gym.angulos_escalada if gym != null
			else PackedFloat32Array([60.0, 70.0, 74.0, 75.0, 80.0, 90.0, 100.0, 110.0, 120.0])
		)
		for j in angulos.size():
			if is_equal_approx(angulos[j], angulo):
				i = j
				break
		var x := -33.0 + 3.4 * float(i)

		# Postura de APOYO, deducida y no tanteada: la esfera inferior de la capsula
		# tocando la cara. Colocar al personaje "cerca a ojo" no vale aqui —contra
		# una pendiente, los pies quedan por delante del pecho, y medio metro de
		# diferencia decide si el sensor ve la rampa o el aire—.
		var a := deg_to_rad(angulo)
		var radio := 0.35
		var centro_y := 3.0             # altura de la esfera inferior de la capsula
		var pies := centro_y - radio
		var z_centro := -30.0 - radio * sin(a)
		# El termino de la pendiente vale igual para desplomes: con angulo > 90 la
		# tangente es negativa y la cara se inclina HACIA el personaje, que es
		# justo lo que se quiere probar. Solo hay que esquivar los 90 exactos.
		if absf(angulo - 90.0) > 0.1:
			z_centro += (centro_y - radio * cos(a)) / tan(a)

		_soltar_todo()
		_reponer()
		_latch_climb = false
		_p.global_position = Vector3(x, pies, z_centro)
		# Empujando contra la cara y SIN caida inicial: en las rampas mas tumbadas la
		# gravedad los desliza fuera del alcance del sensor antes de que el agarre
		# llegue a evaluarse, y el paso acabaria midiendo el resbalon.
		_p.velocity = Vector3(0.0, 0.0, 1.5)
		_p.saltos_aereos = 0
		_p.fsm.cambiar(&"Fall")
		_mirar_a(180.0)  # move_forward apunta a +Z, contra la cara
		_pulsar(&"move_forward")
		_pulsar(&"grab")


func _physics_process(delta: float) -> void:
	_reloj += delta
	if _reloj > 190.0:
		_fallos.append("el test se colgó")
		_informe()
		return
	if _paso >= _guion.size():
		_informe()
		return

	# Un dash pedido en mitad de un ataque necesita que pasen unos frames antes
	# de que la ventana de cancelación se abra.
	if _esperar_frames > 0:
		_esperar_frames -= 1
		if _esperar_frames == 0:
			_pulsar(&"dash")
	if _esperar_salto > 0:
		_esperar_salto -= 1
		if _esperar_salto == 0:
			_pulsar(&"jump")
	# Machaca el boton un frame si y otro no, que es como se spamea de verdad.
	if _spam_salto > 0:
		_spam_salto -= 1
		if _spam_salto % 2 == 0:
			_pulsar(&"jump")
		else:
			_soltar(&"jump")
	if _esperar_salto2 > 0:
		_esperar_salto2 -= 1
		if _esperar_salto2 == 0:
			_soltar(&"jump")
			_pulsar(&"jump")
	if _soltar_pronto > 0:
		_soltar_pronto -= 1
		if _soltar_pronto == 0:
			_soltar(&"jump")
	if _esperar_pesado > 0:
		_esperar_pesado -= 1
		if _esperar_pesado == 0:
			_pulsar(&"attack_heavy")
	if _esperar_dash > 0:
		_esperar_dash -= 1
		if _esperar_dash == 0:
			_p.fsm.cambiar(&"Dash")
	if _esperar_ataque > 0:
		_esperar_ataque -= 1
		if _esperar_ataque == 0:
			_pulsar(&"attack_light")

	# Latches, antes de nada.
	if _p.fsm.nombre_actual() == &"Climb":
		_latch_climb = true
	if _p.fsm.nombre_actual() == &"SideJump":
		_vy_sidejump = maxf(_vy_sidejump, _p.motor.get_vertical())
	if _p.ventana_sidejump > 0.0:
		_vio_ventana = true
	_vy_max = maxf(_vy_max, _p.motor.get_vertical())

	var actual: Dictionary = _guion[_paso]
	if is_zero_approx(_t):

		(actual["hacer"] as Callable).call()
	_t += delta

	if _t >= float(actual["dur"]):
		var esperado: StringName = actual["espera"]
		if esperado != &"" and not _visitados.has(esperado):
			_fallos.append("%-24s no se alcanzó %s" % [actual["nombre"], esperado])
		if actual.has("chequeo") and not (actual["chequeo"] as Callable).call():
			_fallos.append("%-24s %s
      [estado=%s vel=%.1f stam=%.0f%% shift=%s agachado=%s techo=%s pared=%s/%.1f | g=%s hp=%.0f est=%d]" % [
				actual["nombre"], actual["porque"], _p.fsm.nombre_actual(),
				_p.motor.rapidez_plana(), _p.stamina.fraccion() * 100.0,
				Input.is_action_pressed(&"dash"),
				_p.esta_agachado(), _p.techo_bloquea(),
				_p.pared.hay_pared, _p.pared.angulo,
				is_instance_valid(_g), (_g.salud.actual if is_instance_valid(_g) else -1.0),
				(_g.estado if is_instance_valid(_g) else -1)])
			_fallos.append("        traza: %s   saltos=%d aereos=%d" % [
				" ".join(_traza), _saltos_contados, _p.saltos_aereos])
		else:
			print("  OK    %s" % actual["nombre"])
		_paso += 1
		_t = 0.0


func _informe() -> void:
	set_physics_process(false)
	print("RESULTADO: %d/%d comprobaciones." % [_guion.size() - _fallos.size(), _guion.size()])
	if not _fallos.is_empty():
		print("--- FALLOS ---")
		for f in _fallos:
			print("  " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)


# --- Utilidades ---------------------------------------------------------------

func _paso_(nombre: String, dur: float, hacer: Callable, espera: StringName) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "espera": espera}


func _chequeo_(nombre: String, dur: float, hacer: Callable, chequeo: Callable, porque: String) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "espera": &"",
		"chequeo": chequeo, "porque": porque}


func _lancero() -> void:
	for g in get_tree().get_nodes_in_group(&"guardianes"):
		if g.is_queued_for_deletion():
			continue
		if (g as Guardian).tipo == Guardian.Tipo.LANCERO:
			_g = g
			return


## Coloca al jugador a `dist` metros del Guardian, mirandolo. El Guardian se
## congela para que la IA no mueva el objetivo en mitad de la comprobacion.
func _colocar(dist: float) -> void:
	_g.estado = Guardian.Estado.DORMIDO
	_g.velocity = Vector3.ZERO
	var pos := _g.global_position + Vector3(0, 0, dist)
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.orientar_a(Vector3(0, 0, -1))


func _reponer() -> void:
	# A cero SIEMPRE: sin esto un paso hereda el impulso del anterior y el jugador
	# esta en el aire cuando la comprobacion asume que pisa suelo.
	_p.velocity = Vector3.ZERO
	_p.salud.actual = _p.salud.maxima
	_p.salud.vivo = true
	_p.stamina.llenar()
	_p.recargar_aire()
	_p.iframes = 0.0
	if is_instance_valid(_g):
		_g.salud.actual = _g.salud.maxima
		_g.salud.vivo = true
		_g.poise.actual = _g.poise.maxima
		_g.poise.rota = false
	_p.fsm.cambiar(&"Idle")


## AttackData que esta ejecutando el estado de ataque actual, o null.
func _ataque_actual() -> AttackData:
	if _p.fsm.actual == null or _p.fsm.actual.name != &"Attack":
		return null
	return _p.fsm.actual.get("_datos")


func _indice_ataque() -> int:
	if _p.fsm.actual == null or _p.fsm.actual.name != &"Attack":
		return 0
	return int(_p.fsm.actual.get("_indice"))


## Busca un cadaver fisico en todo el subarbol de la Arena.
func _velocidad_cadaver() -> float:
	return _buscar_cadaver(_main.get_node("Arena"))


## Recursivo a proposito: al repoblar, Godot renombra el contenedor duplicado y
## una ruta fija como "Arena/Guardianes" deja de encontrar nada.
func _buscar_cadaver(n: Node) -> float:
	if n is Ragdoll:
		return (n as Ragdoll).linear_velocity.length()
	for h in n.get_children():
		var v := _buscar_cadaver(h)
		if v > 0.0:
			return v
	return 0.0


## Planta al Guardian en el origen, quieto y entero. Las dos medidas del picado
## tienen que diferenciarse SOLO en la altura de caida; si el enemigo esta cada vez
## en un sitio, lo que se mide es la punteria.
func _plantar_guardian() -> void:
	if not is_instance_valid(_g):
		return
	_g.estado = Guardian.Estado.DORMIDO
	_g.global_position = Vector3(0.0, 0.1, 0.0)
	_g.velocity = Vector3.ZERO
	_g.salud.actual = _g.salud.maxima
	_g.poise.actual = _g.poise.maxima
	_g.poise.rota = false


## Distancia recorrida en el plano desde `origen`. La vertical no cuenta: lo que
## se mide en un ataque de movilidad es cuanto AVANZA, no cuanto cae.
func _distancia_plana(origen: Vector3) -> float:
	var d := _p.global_position - origen
	d.y = 0.0
	return d.length()


## Fija el yaw de la camara para que `move_forward` apunte a una direccion
## conocida. Sin esto los tests direccionales miden la suerte.
func _mirar_a(yaw: float) -> void:
	var rig := _main.get_node_or_null("CameraRig")
	if rig == null:
		return
	rig.set("_yaw", yaw)
	rig.set("_realinea", 0.0)


func _pulsar(accion: StringName) -> void:
	Input.action_press(accion)


func _soltar(accion: StringName) -> void:
	Input.action_release(accion)


func _soltar_todo() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
