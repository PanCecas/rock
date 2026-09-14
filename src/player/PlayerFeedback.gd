class_name PlayerFeedback
extends Node3D
## EL 40% DEL FEEL QUE NO ESTÁ EN LA FÍSICA.
##
## Es la frase literal del documento de movimiento, y en este proyecto era cierta
## de la peor manera: el moveset está medido hasta el frame y **no había una sola
## partícula en todo `src/`**, ni aplastado al aterrizar, ni estela, ni viento. La
## física decía 30 m/s y la pantalla decía lo mismo a 30 que a 8.
##
## Aquí vive la lista de la sección 5.10 del documento, ordenada como ella la
## ordena —por impacto entre coste—, y nada más. Este nodo **no decide nada del
## juego**: lee estado y dibuja. Si se borra entero, el jugador se mueve igual.
##
## **Y no escribe la escala del visual, la PIDE.** `PlayerController` es el único
## que toca `visual.scale` —ya la usa para la postura agachada— así que un segundo
## escritor sería el bug de siempre con otro nombre: dos sitios peleándose por un
## número y ganando el último que corra. Este expone `escala()` y el controlador
## la compone, igual que un estado PIDE postura con `pedir_postura()` (regla dura
## #14).
##
## Lo que SÍ decide: nada de screenshake en movimiento continuo. Solo en eventos
## discretos —aterrizar fuerte, conectar una patada—, que es la única nota al pie
## que el documento pone en negrita en esta sección.

## Dueño. Por `NodePath` y no por tipo (regla dura #10).
@export var jugador_path: NodePath = ^".."

var _p: PlayerController = null
var _tuning: PlayerTuning = null

## Aplastado actual, en fracción. 0 = de pie, 0.35 = bien chafado.
var _squash: float = 0.0
## Estirado actual, de subir rápido. Va aparte del aplastado porque los dos
## pueden pedirse en el mismo frame —aterrizar y rebotar— y sumarlos daría cero
## justo en el frame que más se ve.
var _estirado: float = 0.0

var _polvo: CPUParticles3D = null
## Fantasmas de la estela, con su tiempo de vida restante.
var _estela: Array[Dictionary] = []
var _t_estela: float = 0.0
var _malla_fantasma: Mesh = null
var _tocaba: bool = false


func _ready() -> void:
	_p = get_node_or_null(jugador_path) as PlayerController
	if _p == null:
		push_warning("PlayerFeedback sin jugador en %s" % jugador_path)
		return
	_tuning = _p.tuning
	# Fuera de la interpolación: esto se mueve por código en `_process` igual que
	# el `CameraRig` y el `Cordon`, y dentro se interpolaría dos veces (#21bis).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_montar_particulas()
	EventBus.player_landed.connect(_al_aterrizar)


# --- LO QUE PIDE ---------------------------------------------------------------

## ESCALA EXTRA DEL VISUAL. La compone `PlayerController`, que es su único
## escritor. Devuelve (ancho, alto, ancho): el volumen se reparte, no se infla.
func escala() -> Vector3:
	var alto := 1.0 - _squash + _estirado
	# Lo que se quita de alto se pone de ancho y al revés. Un aplastado que
	# además encoge parece que el personaje se aleja; conservando el volumen
	# parece que pesa, que es lo que se busca.
	var ancho := 1.0 + _squash * 0.6 - _estirado * 0.45
	return Vector3(ancho, alto, ancho)


# --- LO QUE HACE ---------------------------------------------------------------

## TODO ESTO CORRE EN EL RELOJ DE LA FISICA, no en el de render.
##
## El suavizado exponencial es independiente del framerate por construccion, asi
## que en `_process` seria «correcto»… y aun asi inservible: la captura salio a
## 7 fps —142 ms por frame— y el aplastado, que dura 0.12 s, se habia recuperado
## entero antes de que se tomara la foto. Un efecto que DISPARA un evento de
## fisica tiene que apagarse con el mismo reloj que lo encendio, o su duracion
## depende de lo que le cueste dibujar a la maquina.
func _physics_process(delta: float) -> void:
	if _p == null or _tuning == null:
		return
	_recuperar(delta)
	_estirar()
	_arrastrar(delta)


## El aplastado vuelve solo. Exponencial e independiente del framerate: a 144 Hz
## un `lerp` con factor fijo se recuperaría más del doble de rápido que a 60, y el
## aplastado duraría la mitad sin que nadie tocara su número.
func _recuperar(delta: float) -> void:
	var k := 1.0 - exp(-delta / maxf(_tuning.feedback_squash_duracion, 0.001))
	_squash = lerpf(_squash, 0.0, k)
	if _squash < 0.002:
		_squash = 0.0


## ESTIRARSE AL SUBIR. No es un evento: es continuo mientras subas fuerte, y por
## eso no se apaga solo como el aplastado.
func _estirar() -> void:
	var vy: float = _p.superficie.vertical(_p.velocity)
	var t: float = clampf(vy / maxf(_tuning.velocidad_salto(), 0.001), 0.0, 1.0)
	_estirado = t * _tuning.feedback_estirado


## NO HAY VIENTO, Y NO POR OLVIDO.
##
## El documento pide «lineas de velocidad / viento por encima de ~12 m/s» y se
## intento dos veces con particulas: cremas primero —invisibles contra un cielo
## crema, que es el bug de la bandada del 3.13 otra vez— y despues oscuras,
## grandes y en espacio de mundo. La foto de las dos dice lo mismo: a distancia
## de tercera persona son cuatro motas flotando, no velocidad.
##
## **Y una raya de velocidad no es un objeto del mundo: es un efecto de PANTALLA.**
## Puesta en 3D alrededor del personaje, la camara la ve de canto la mitad del
## tiempo y a dos metros el resto. Su sitio es el post-proceso, que es de
## `docs/07_SHADERS.md`, y ahi entrara con la Fase 5.
##
## Mientras tanto la velocidad SI tiene su canal y funciona: el FOV dinamico
## (`camara_fov_por_ms`), que es justo el primero de la lista del documento.
## Dejar puestas unas particulas que no se ven seria peor que no tenerlas: daria
## el problema por resuelto.
## LA ESTELA. Cápsulas fantasma que se desvanecen, y solo durante los verbos que
## son un GESTO —dash y patada—, nunca en la locomoción normal.
##
## Fantasmas y no una cinta: con cápsulas grises una silueta repetida se lee como
## velocidad sin necesidad de una malla generada, y además enseña la TRAYECTORIA,
## que es justo lo que un dash o una patada te piden leer.
func _arrastrar(delta: float) -> void:
	for f in _estela:
		f["t"] = float(f["t"]) - delta
		var nodo: MeshInstance3D = f["nodo"]
		if not is_instance_valid(nodo):
			continue
		var q: float = clampf(float(f["t"]) / maxf(_tuning.feedback_estela_vida, 0.001), 0.0, 1.0)
		var mat := nodo.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = q * 0.5
		nodo.scale = Vector3.ONE * (0.6 + 0.4 * q)
	var vivos: Array[Dictionary] = []
	for f in _estela:
		if float(f["t"]) > 0.0:
			vivos.append(f)
		elif is_instance_valid(f["nodo"]):
			(f["nodo"] as Node).queue_free()
	_estela = vivos

	if not _deja_estela():
		_t_estela = 0.0
		return
	_t_estela -= delta
	if _t_estela <= 0.0:
		_t_estela = _tuning.feedback_estela_paso
		_soltar_fantasma()


func _deja_estela() -> bool:
	if _p.fsm == null or _p.fsm.actual == null:
		return false
	var n := _p.fsm.nombre_actual()
	return n == &"Dash" or n == &"Kick"


func _soltar_fantasma() -> void:
	if _malla_fantasma == null:
		return
	var m := MeshInstance3D.new()
	m.mesh = _malla_fantasma
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = _p.color_de(&"azul_claro")
	mat.albedo_color.a = 0.5
	m.material_override = mat
	get_tree().current_scene.add_child(m)
	m.global_position = _p.global_position + Vector3.UP * 0.9
	if _p.visual != null:
		m.global_rotation = _p.visual.global_rotation
	_estela.append({"nodo": m, "t": _tuning.feedback_estela_vida})


# --- EVENTOS DISCRETOS ---------------------------------------------------------

## ATERRIZAR. Aplasta, levanta polvo y —solo si fue duro— sacude la cámara.
##
## **El screenshake va aquí y no en el movimiento**, que es la única cosa que el
## documento subraya de esta seccion: sacudir de forma continua no comunica
## velocidad, comunica que algo va mal con la cámara.
func _al_aterrizar(velocidad_impacto: float, dura: bool) -> void:
	var v := absf(velocidad_impacto)
	var t: float = clampf(
		inverse_lerp(_tuning.feedback_squash_desde, _tuning.aterrizaje_duro, v), 0.0, 1.0)
	if t <= 0.0:
		return
	_squash = maxf(_squash, t * _tuning.feedback_squash_max)
	_reventar_polvo(t)
	if dura:
		EventBus.camara_shake.emit(_tuning.feedback_shake_impacto, 0.14)


## Polvo a los pies. `t` es cuánto: un aterrizaje suave levanta una nube pequeña.
func _reventar_polvo(t: float) -> void:
	if _polvo == null:
		return
	_polvo.global_position = _p.global_position
	# Aqui SI se puede tocar `amount`: es `one_shot` y se va a reiniciar de todas
	# formas, asi que el reinicio que provoca no corta nada.
	_polvo.amount = int(lerpf(6.0, 20.0, clampf(t, 0.0, 1.0)))
	_polvo.restart()


## Lo llaman los verbos que raspan el suelo: el slide y la patada a ras.
func polvo(fuerza: float = 1.0) -> void:
	_reventar_polvo(clampf(fuerza, 0.0, 1.0))


# --- MONTAJE -------------------------------------------------------------------

func _montar_particulas() -> void:
	var p: Palette = GameState.palette

	_polvo = CPUParticles3D.new()
	_polvo.name = "Polvo"
	_polvo.emitting = false
	_polvo.one_shot = true
	_polvo.explosiveness = 0.9
	_polvo.amount = 18
	_polvo.lifetime = 0.55
	_polvo.direction = Vector3.UP
	_polvo.spread = 75.0
	_polvo.initial_velocity_min = 1.4
	_polvo.initial_velocity_max = 3.6
	_polvo.gravity = Vector3.UP * -3.0
	_polvo.scale_amount_min = 0.12
	_polvo.scale_amount_max = 0.3
	_polvo.color = p.caliza_sol if p != null else Color(0.85, 0.83, 0.75)
	_polvo.mesh = _quad(0.3)
	# EN EL MUNDO Y NO COLGANDO DEL JUGADOR: una nube de polvo se queda donde se
	# levanto. Pegada al padre viajaria contigo, que es exactamente lo contrario
	# de lo que dice una nube de polvo.
	_polvo.top_level = true
	add_child(_polvo)

	var capsula := CapsuleMesh.new()
	capsula.radius = 0.4
	capsula.height = 1.8
	capsula.radial_segments = 8
	capsula.rings = 3
	_malla_fantasma = capsula


## Un quad CON MATERIAL. Sin el, `CPUParticles3D.color` no pinta nada: el color de
## particula viaja como color de VERTICE, y hace falta un material que lo lea.
## Con la malla pelada las particulas salian blancas y opacas.
func _quad(lado: float) -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(lado, lado)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = mat
	return q


func debug_line() -> String:
	return "squash %.2f  estira %.2f  estela %d" % [
		_squash, _estirado, _estela.size()]
