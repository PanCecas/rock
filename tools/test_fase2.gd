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
		_chequeo_("picado golpea en área", 1.2,
			func() -> void:
				_soltar_todo()
				_reponer()
				_colocar(1.5)
				_p.global_position += Vector3.UP * 3.0
				_p.fsm.cambiar(&"Fall")
				_vida_antes = _g.salud.actual
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
		_chequeo_("backflip: doble altura y hacia atras", 0.06,
			func() -> void: _pulsar(&"jump"),
			func() -> bool: return (
				_p.motor.get_vertical() > _p.tuning.velocidad_salto() * 1.7
				and _p.motor.rapidez_plana() > 3.0),
			"el backflip debe subir el doble y retroceder"),

		_paso_("asentar para side hop", 0.35, func() -> void:
			_soltar_todo()
			_reponer()
			_p.global_position = Vector3(0.0, 0.3, 0.0)
			_p.velocity = Vector3.ZERO
			_p.fsm.cambiar(&"Idle")
			_pulsar(&"crouch")
			# El lateral se pulsa YA: necesita registrarse en el buffer antes de
			# que llegue el salto, o el side hop se lee como salto normal.
			_pulsar(&"move_right"), &"Crouch"),
		_chequeo_("side hop: lateral y bajo", 0.08,
			func() -> void: _pulsar(&"jump"),
			func() -> bool: return (
				_p.motor.rapidez_plana() > 7.0
				and _p.motor.get_vertical() < _p.tuning.velocidad_salto()),
			"el side hop debe salir lateral y con poca altura"),

		# DIVE: atacar en el aire llevando carrera.
		_chequeo_("dive desde carrera", 0.3,
			func() -> void:
				_soltar_todo()
				_reponer()
				_p.global_position = Vector3(0.0, 8.0, 0.0)
				_p.velocity = Vector3(0.0, 2.0, -12.0)
				_p.fsm.cambiar(&"Fall")
				_esperar_pesado = 3,
			func() -> bool: return _visitados.has(&"Dive"),
			"atacar en el aire con velocidad debe entrar en Dive"),
		_chequeo_("segunda pulsacion = DiveAttack", 0.2,
			func() -> void: _esperar_ataque = 2,
			func() -> bool: return _visitados.has(&"DiveAttack"),
			"volver a atacar durante el dive debe armarlo"),

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
var _aux: float = 0.0
var _pos_antes: Vector3 = Vector3.ZERO
var _dist_sin_input: float = 0.0


func _physics_process(delta: float) -> void:
	_reloj += delta
	if _reloj > 45.0:
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
      [estado=%s vel=%.1f stam=%.0f%% shift=%s | g=%s hp=%.0f est=%d]" % [
				actual["nombre"], actual["porque"], _p.fsm.nombre_actual(),
				_p.motor.rapidez_plana(), _p.stamina.fraccion() * 100.0,
				Input.is_action_pressed(&"dash"),
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


func _pulsar(accion: StringName) -> void:
	Input.action_press(accion)


func _soltar(accion: StringName) -> void:
	Input.action_release(accion)


func _soltar_todo() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_p.buffer.clear()
