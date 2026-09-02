
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
## Mueve al jugador a un lado durante la carga: sin eso, "no persigue" no se puede
## comprobar —una carga contra un objetivo quieto va recta pase lo que pase—.
var _apartar: bool = false
## Pulsaciones simuladas. La regla dura #4 dice que el input va por el buffer, y
## esta es la forma de simular una pulsacion desde un test.
var _cuerda: int = 0
var _atk_pes: int = 0


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

		# --- EMBESTIDOR: la carga va HACIA TI ---------------------------------
		# EL BUG DE LA 3.08, y el que el usuario describio como "la logica esta
		# invertida". `encarar()` dejaba `+basis.z` mirando al objetivo mientras
		# TODO lo demas leia `-basis.z` como el morro: el bicho te daba la espalda
		# y cargaba HUYENDO.
		#
		# Este chequeo existia y estaba en verde con el bug, porque medía
		# `absf(position.z)` —el modulo— y la fuga tambien recorre metros en Z. Un
		# valor absoluto no distingue "va hacia ti" de "se va de ti", y esa es
		# justo la unica diferencia que habia. Ahora se mide con SIGNO: se compara
		# la distancia al punto donde estaba el jugador antes y despues.
		_chequeo_("la carga va HACIA el jugador", 2.2,
			func() -> void:
				# Enemigo NUEVO. Reusar el anterior lo dejaba a media anticipacion
				# —`cambiar` al mismo estado no reinicia el reloj— y fijaba el
				# rumbo con el giro sin terminar, o sea de lado.
				_crear(EMBESTIDOR, Vector3(0, 0.2, 0), "res://content/data/attacks/embestida.tres")
				_e.rotation.y = 0.0
				_p.global_position = Vector3(0, 0.05, 8.0)
				_e.objetivo = _p
				_e.fsm.cambiar(&"Anticipar")
				_pos = _p.global_position
				_aux = 0.0,
			func() -> bool:
				# Ha llegado a menos de la mitad de donde apuntaba.
				return _visto.has(&"Embestir") and _e.global_position.distance_to(_pos) < 4.0,
			"tiene que CERRAR distancia contra el sitio al que apunto, no alejarse de el"),

		# --- EMBESTIDOR: y NO persigue ---------------------------------------
		# Es LA propiedad que la hace esquivable. Si corrigiera el rumbo seria un
		# misil teledirigido y la unica respuesta posible seria correr.
		#
		# Se mide con el jugador APARTANDOSE de verdad (lo mueve `_apartar`): que
		# la carga siga recta con el objetivo quieto no prueba nada.
		_chequeo_("y NO persigue: el rumbo queda fijo", 2.4,
			func() -> void:
				_crear(EMBESTIDOR, Vector3(0, 0.2, 0), "res://content/data/attacks/embestida.tres")
				_e.rotation.y = 0.0
				_p.global_position = Vector3(0, 0.05, 8.0)
				_e.objetivo = _p
				_e.fsm.cambiar(&"Anticipar")
				_apartar = true
				_aux = 0.0,
			func() -> bool:
				_apartar = false
				# Se aparto 10 m en X y la carga no se ha desviado ni 1.5.
				return _visto.has(&"Embestir") and absf(_e.global_position.x) < 1.5,
			"con `giro_en_carga` a 0 la carga no puede corregir hacia el jugador"),

		# --- PATRULLA (3.09) --------------------------------------------------
		# Sin ruta, DORMIDO. Es el comportamiento historico de los seis enemigos y
		# tiene que seguir siendo el defecto: un componente nuevo que cambia lo que
		# ya funcionaba sin que nadie lo pida no es una mejora.
		_chequeo_("sin ruta se queda quieto, como siempre", 0.6,
			func() -> void:
				_crear(EMBESTIDOR, Vector3(0, 0.2, 0), "res://content/data/attacks/embestida.tres")
				_e.rotation.y = 0.0
				_e.ruta = PackedVector3Array()
				_p.global_position = Vector3(0, 0.05, 40.0)
				_pos = _e.global_position,
			func() -> bool: return (_e.fsm.nombre_actual() == &"Dormido"
				and _e.global_position.distance_to(_pos) < 0.5),
			"la patrulla es opcional: sin ruta, nada cambia"),

		_chequeo_("con ruta, RONDA", 2.5,
			func() -> void:
				_crear(EMBESTIDOR, Vector3(0, 0.2, 0), "res://content/data/attacks/embestida.tres")
				_e.rotation.y = 0.0
				_e.espera_en_punto = 0.0
				_e.ruta = PackedVector3Array([
					Vector3(0, 0.2, 0), Vector3(8.0, 0.2, 0), Vector3(8.0, 0.2, 8.0)])
				# Lejisimos: lo que se mide es que RONDA, no que persiga.
				_p.global_position = Vector3(0, 0.05, 60.0)
				_pos = _e.global_position,
			func() -> bool: return (_visto.has(&"Patrulla")
				and _e.global_position.distance_to(_pos) > 2.0),
			"un enemigo parado es un obstaculo; uno que ronda es un habitante"),

		# Y SIGUE VIGILANDO MIENTRAS ANDA. Una patrulla que no detecta es un
		# salvapantallas: la mitad del valor de la ronda es que te obliga a
		# cronometrar por donde pasas.
		_chequeo_("y deja la ronda al verte", 1.2,
			func() -> void:
				_visto.clear()
				# DELANTE DE SU CARA, y su cara mira a donde CAMINA: patrullando ya no
				# esta en rotation.y = 0. Colocar al jugador en -Z a ciegas lo dejaba
				# fuera del cono y el test medía que no le veia, que es otra cosa.
				var delante: Vector3 = _e.global_position + _e.frente() * 5.0
				_p.global_position = Vector3(delante.x, 0.05, delante.z),
			func() -> bool: return _e.fsm.nombre_actual() != &"Patrulla",
			"patrullar no puede apagar la deteccion"),

		# --- ARQUETIPO A DISTANCIA --------------------------------------------
		# Es la mitad que lo separa del cuerpo a cuerpo: sin linea de vision NO
		# dispara. Un enemigo a distancia que atraviesa columnas convierte la
		# cobertura en decorado.
		_chequeo_("el arquetipo a distancia declara que necesita verte", 0.3,
			func() -> void:
				_crear(VOLADOR, Vector3(0, 6.0, 0), "res://content/data/attacks/volador_disparo.tres")
				(_e as Volador).proyectil = PROYECTIL,
			func() -> bool: return _e.necesita_linea_de_vision(),
			"el volador dispara: la cobertura tiene que servirle de algo al jugador"),

		_chequeo_("y el cuerpo a cuerpo NO", 0.3,
			func() -> void:
				_crear(EMBESTIDOR, Vector3(0, 0.2, 0), "res://content/data/attacks/embestida.tres"),
			func() -> bool: return not _e.necesita_linea_de_vision(),
			"quien pega de cerca ya tiene que llegar hasta ti: exigirle ademas un rayo limpio lo deja clavado en cualquier saliente"),

		# NAVEGACION: sin agente ni navmesh, LINEA RECTA. Es el fallback, y es lo
		# que hace que el componente pueda ser opcional de verdad.
		_chequeo_("sin agente de navegacion, rumbo recto", 0.3,
			func() -> void: pass,
			func() -> bool:
				var destino := _e.global_position + Vector3(10.0, 0.0, 4.0)
				var r: Vector3 = _e.rumbo_hacia(destino)
				return _e.nav == null and r.normalized().is_equal_approx(
					Vector3(10.0, 0.0, 4.0).normalized()),
			"la navegacion es una MEJORA opcional: sin ella se va recto, como hasta ahora"),

		# --- LA LANZA CLAVADA VIAJA CON EL CUERPO (3.10) ----------------------
		# Reportado: "la daga y la lanza no se adhieren al enemigo cuando se mueve,
		# se quedan flotando en el espacio". Pasa con el ColosoMediano, que esta en
		# `COLOSSUS_SURFACE` —capa clavable— y se mueve.
		#
		# `SpearEmbedded` decia literalmente "se queda quieta en el mundo y NO se
		# reparenta a nada; colgarla de un cuerpo que se mueve es trabajo de la
		# Fase 4". El aplazamiento vencio en cuanto el coloso existio.
		_chequeo_("la lanza clavada se mueve CON el coloso", 1.2,
			func() -> void:
				_crear(COLOSO, Vector3(0, 3.6, 0), "")
				var l: Spear = _p.lanza
				l.global_position = _e.global_position + Vector3(0, 0.5, 2.0)
				l.fsm.cambiar(&"Embedded", {
					"punto": l.global_position, "normal": Vector3.BACK, "cuerpo": _e})
				# Se anota la separacion: es lo que tiene que MANTENERSE.
				_aux = l.global_position.distance_to(_e.global_position)
				_pos = _e.global_position,
			func() -> bool:
				var l: Spear = _p.lanza
				# El coloso se ha movido de verdad...
				if _e.global_position.distance_to(_pos) < 0.5:
					_e.global_position += Vector3(3.0, 0.0, 0.0)
					return false
				# ...y la lanza conserva su sitio RELATIVO a el.
				return absf(l.global_position.distance_to(_e.global_position) - _aux) < 0.5,
			"una lanza clavada en algo que anda tiene que andar con ello, no quedarse flotando"),

		# --- AGARRAR Y ZARANDEAR (3.11) ---------------------------------------
		# El defecto NO cambia: un enemigo que no declara `agarrable` no se
		# engancha. Igual que `WeakPoint.llave`, quien se deja agarrar lo dice el
		# enemigo, y el coloso dice que no.
		_chequeo_("el coloso NO es agarrable", 0.3,
			func() -> void: _crear(COLOSO, Vector3(0, 3.6, 0), ""),
			func() -> bool: return not _e.agarrable,
			"zarandear algo de siete metros no es creible: el punto debil ya tiene su verbo"),

		_chequeo_("el embestidor SI", 0.3,
			func() -> void:
				_crear(EMBESTIDOR, Vector3(0, 0.2, 0), "res://content/data/attacks/embestida.tres"),
			func() -> bool: return _e.agarrable,
			"los bichos pequenos son la presa: es lo que hace del zarandeo una respuesta"),

		# EL CAMINO COMPLETO, SIN FORZAR NADA (3.10). La version anterior de este
		# chequeo colocaba la daga a mano —`estado = CLAVADO`, `cuerpo_clavado =
		# _e`— y por eso daba verde mientras el usuario reportaba que **la mecanica
		# no funcionaba ni siquiera**. Es exactamente la leccion que `CLAUDE.md` ya
		# tenia escrita del balanceo: un test que fuerza el estado no prueba que se
		# pueda LLEGAR a el.
		#
		# Ahora se TIRA la daga de verdad y se comprueba que se clava sola.
		_chequeo_("la daga se clava en el enemigo, tirandola", 1.2,
			func() -> void:
				_p.global_position = _e.global_position + Vector3(0, 0.05, 6.0)
				_p.velocity = Vector3.ZERO
				_p.call("orientar_a", Vector3(0, 0, -1))
				var d: Anclaje = _p.dagas[0]
				d.lanzar(d.punto_de_mano(), Vector3(0, 0, -1)),
			func() -> bool:
				var d: Anclaje = _p.dagas[0]
				# En carne SI, y por tanto NO cuenta como punto de resortera: un
				# ancla que anda rompe la conservacion de energia del elastico.
				return d.en_carne() and _p.daga_en_mundo() == null and _p.arma_en_carne() == d,
			"la lanza es del MUNDO y la daga de la CARNE: ese es el reparto"),

		# EL BUG QUE EL USUARIO REPORTO: "la mecanica de por si no funciona ni
		# siquiera". `intentar_cuerda()` abortaba entero si la LANZA no estaba
		# fuera —el guardia que arreglo el bug de la Z—, asi que para zarandear con
		# la daga habia que haber tirado antes la lanza a cualquier parte.
		#
		# Este chequeo lo fija: con la lanza GUARDADA y la daga en carne, la Z
		# tiene que zarandear igual.
		_chequeo_("y zarandea aunque la lanza siga GUARDADA", 1.0,
			func() -> void:
				_p.lanza.fsm.cambiar(&"Holstered")
				_p.stamina.llenar()
				_p.fsm.cambiar(&"Idle")
				_visto.clear()
				_cuerda = 3,
			func() -> bool: return _visto.has(&"Whirl"),
			"el guardia de la lanza es de los verbos de la lanza: el zarandeo no depende de ella"),

		# EL CAMINO DE ENTRADA REAL: pulsando la tecla, no con `fsm.cambiar()`.
		# Leccion ya escrita en CLAUDE.md — un test que fuerza el estado no prueba
		# que se pueda LLEGAR a el, y por eso el balanceo estuvo verde sin
		# funcionar.
		_chequeo_("con la daga en carne, la Z zarandea", 1.0,
			func() -> void:
				_p.global_position = _e.global_position + Vector3(0, 0.05, 3.0)
				_p.velocity = Vector3.ZERO
				_p.stamina.llenar()
				_p.fsm.cambiar(&"Idle")
				_visto.clear()
				_cuerda = 3,
			func() -> bool:
				return (_visto.has(&"Whirl")
					and _e.fsm.nombre_actual() == &"Agarrado"),
			"una daga clavada en un bicho agarrable no admite otra lectura"),

		# EL CUERPO MANTIENE LA DISTANCIA. Es la restriccion analitica, la misma
		# del balanceo con los papeles invertidos.
		_chequeo_("y el cuerpo se queda a su radio", 0.9,
			func() -> void: _aux = 0.0,
			func() -> bool:
				var dist := _p.global_position.distance_to(_e.global_position)
				# El radio se acota entre `zarandeo_largo_min` y `_max`; basta con
				# que no se escape ni se meta dentro del jugador.
				return dist > 0.5 and dist < _p.tuning.zarandeo_largo_max + 1.5,
			"si el cuerpo se aleja sin limite no cuelga de nada: es la restriccion"),

		# ESTAMPAR. El pesado lo manda contra el suelo, y al llegar hace dano en
		# area escalado por la velocidad que traia.
		_chequeo_("el pesado lo estampa", 1.6,
			func() -> void:
				_visto.clear()
				_atk_pes = 3,
			func() -> bool:
				return (_visto.has(&"Estampado")
					and _p.fsm.nombre_actual() != &"Whirl"),
			"girar antes de estampar tiene que servir de algo, y ese algo es el impacto"),

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

	if _cuerda > 0:
		Input.action_press(&"rope")
		_cuerda -= 1
		if _cuerda == 0:
			Input.action_release(&"rope")
	if _atk_pes > 0:
		Input.action_press(&"attack_heavy")
		_atk_pes -= 1
		if _atk_pes == 0:
			Input.action_release(&"attack_heavy")
	_visto[_p.fsm.nombre_actual()] = true

	# Latches, antes de nada.
	if _e != null and is_instance_valid(_e):
		_visto[_e.fsm.nombre_actual()] = true
		if _e.fsm.nombre_actual() == &"Embestir":
			_aux = maxf(_aux, _e.global_position.length())
			# EL JUGADOR SE APARTA DE VERDAD. Un test de "no persigue" con el
			# objetivo quieto no prueba nada: la carga iria recta igual.
			if _apartar:
				_p.global_position = _p.global_position.move_toward(
					Vector3(10.0, 0.05, 8.0), 14.0 * delta)
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
