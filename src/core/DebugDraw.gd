extends Node
## Autoload. **GIZMOS 3D**: dibuja en el mundo lo que los sistemas deciden.
##
## `DebugOverlay` ya dice el QUÉ en texto —"Attack f12/46 ACTIVO"—, y eso llega
## hasta cierto punto: puedes leer que la hitbox estaba abierta y seguir sin saber
## **dónde** estaba, ni por qué no tocó a nadie. Esto dibuja el dónde.
##
## Modo inmediato, como el `DebugDraw` de cualquier motor: se pide una forma y se
## dibuja este frame. No hay que crear nodos, ni acordarse de borrarlos, ni que
## cada sistema se invente su propia malla.
##
##   DebugDraw.esfera(punto, 1.2, Color.RED)          # un frame
##   DebugDraw.linea(a, b, Color.YELLOW, 2.0)         # dos segundos
##
## **Cuesta cero cuando está apagado**, y eso es la mitad del diseño: cada entrada
## sale por `if not activo: return` antes de calcular nada. Un sistema de depuración
## que hay que quitar para medir el rendimiento no sirve para medir el rendimiento.
##
## Se enciende con **F7**. La tecla se lee cruda, igual que hace `GameState` con
## F5 y F6: la regla dura #4 —input solo por `InputBuffer`— es para los estados
## del jugador, no para las teclas de desarrollo, que tienen que funcionar aunque
## la FSM esté rota. Que es justo cuando hacen falta.

## Segmentos de la circunferencia de una esfera o un cono. Doce se lee como un
## círculo y cuesta la mitad que veinticuatro.
const SEGMENTOS := 12

var activo: bool = false

## Cada entrada: {a, b, color, t}. `t` es lo que le queda de vida en segundos;
## cero significa "solo este frame".
var _lineas: Array[Dictionary] = []
var _malla: ImmediateMesh
var _nodo: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()


func _construir() -> void:
	_malla = ImmediateMesh.new()
	_nodo = MeshInstance3D.new()
	_nodo.name = "GizmosDebug"
	_nodo.mesh = _malla
	_nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Nunca se recorta: los gizmos no viven en una posición, viven en el mundo, y
	# un AABB pequeño alrededor del origen los haría desaparecer al mirar a otro
	# lado.
	_nodo.extra_cull_margin = 16384.0
	# Fuera de la interpolación de física (regla dura #21bis): estos vértices se
	# escriben en coordenadas de mundo cada frame, no los mueve la física.
	_nodo.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_nodo.visible = false

	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# SIN test de profundidad, a propósito. Un gizmo que se esconde detrás de la
	# geometría no sirve para depurar: la mitad de las preguntas son justamente
	# "¿qué hay ahí dentro?".
	_mat.no_depth_test = true
	_mat.disable_fog = true
	_nodo.material_override = _mat

	add_child(_nodo)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	if (event as InputEventKey).keycode == KEY_F7:
		alternar()


func alternar() -> void:
	activo = not activo
	_nodo.visible = activo
	if not activo:
		_lineas.clear()
		_malla.clear_surfaces()
	DebugOverlay.set_line("gizmos", "F7  gizmos %s" % ("ON" if activo else "off"))


func _process(delta: float) -> void:
	if not activo:
		return
	_dibujar()
	# Se envejece DESPUÉS de dibujar para que una forma pedida con duración 0 se
	# vea un frame entero. Pidiéndola y borrándola antes de pintar, no se vería
	# nunca — y "duración 0" es el caso más común de todos.
	var vivas: Array[Dictionary] = []
	for l in _lineas:
		l["t"] = float(l["t"]) - delta
		if float(l["t"]) > 0.0:
			vivas.append(l)
	_lineas = vivas


# --- Primitivas ---------------------------------------------------------------

func linea(desde: Vector3, hasta: Vector3, color: Color, duracion: float = 0.0) -> void:
	if not activo:
		return
	_lineas.append({"a": desde, "b": hasta, "color": color, "t": duracion})


func rayo(origen: Vector3, direccion: Vector3, largo: float, color: Color,
		duracion: float = 0.0) -> void:
	if not activo or direccion.is_zero_approx():
		return
	linea(origen, origen + direccion.normalized() * largo, color, duracion)


## Esfera de alambre: tres círculos, uno por plano. Con uno solo no se distingue
## de un anillo y no se lee el volumen.
func esfera(centro: Vector3, radio: float, color: Color, duracion: float = 0.0) -> void:
	if not activo:
		return
	_circulo(centro, radio, Vector3.RIGHT, Vector3.FORWARD, color, duracion)
	_circulo(centro, radio, Vector3.RIGHT, Vector3.UP, color, duracion)
	_circulo(centro, radio, Vector3.FORWARD, Vector3.UP, color, duracion)


func caja(centro: Vector3, tam: Vector3, color: Color, duracion: float = 0.0) -> void:
	if not activo:
		return
	var h := tam * 0.5
	var v: Array[Vector3] = []
	for i in 8:
		v.append(centro + Vector3(
			h.x if (i & 1) else -h.x,
			h.y if (i & 2) else -h.y,
			h.z if (i & 4) else -h.z))
	for par in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7],
			[0, 4], [1, 5], [2, 6], [3, 7]]:
		linea(v[par[0]], v[par[1]], color, duracion)


## CONO DE VISIÓN. Es la forma que más falta hacía: un enemigo que "no te ve"
## es indistinguible de un enemigo roto hasta que ves su cono.
func cono(origen: Vector3, direccion: Vector3, semiangulo_grados: float,
		largo: float, color: Color, duracion: float = 0.0) -> void:
	if not activo or direccion.is_zero_approx():
		return
	var eje := direccion.normalized()
	var arriba := Vector3.UP if absf(eje.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	var lado := eje.cross(arriba).normalized()
	var alto := lado.cross(eje).normalized()
	var r := largo * tan(deg_to_rad(clampf(semiangulo_grados, 0.1, 89.0)))
	var centro := origen + eje * largo

	for i in SEGMENTOS:
		var a := TAU * float(i) / float(SEGMENTOS)
		var b := TAU * float(i + 1) / float(SEGMENTOS)
		var pa := centro + (lado * cos(a) + alto * sin(a)) * r
		var pb := centro + (lado * cos(b) + alto * sin(b)) * r
		linea(pa, pb, color, duracion)
		# Solo cuatro generatrices, no doce: con todas el cono se vuelve una
		# mancha opaca y tapa justo lo que se quiere ver dentro.
		if i % (SEGMENTOS / 4) == 0:
			linea(origen, pa, color, duracion)


## Cruz de tres ejes. Para marcar un punto sin sugerir un volumen que no existe.
func punto(centro: Vector3, tam: float, color: Color, duracion: float = 0.0) -> void:
	if not activo:
		return
	linea(centro - Vector3.RIGHT * tam, centro + Vector3.RIGHT * tam, color, duracion)
	linea(centro - Vector3.UP * tam, centro + Vector3.UP * tam, color, duracion)
	linea(centro - Vector3.FORWARD * tam, centro + Vector3.FORWARD * tam, color, duracion)


func _circulo(centro: Vector3, radio: float, u: Vector3, v: Vector3,
		color: Color, duracion: float) -> void:
	for i in SEGMENTOS:
		var a := TAU * float(i) / float(SEGMENTOS)
		var b := TAU * float(i + 1) / float(SEGMENTOS)
		linea(centro + (u * cos(a) + v * sin(a)) * radio,
			centro + (u * cos(b) + v * sin(b)) * radio, color, duracion)


func _dibujar() -> void:
	_malla.clear_surfaces()
	if _lineas.is_empty():
		return
	_malla.surface_begin(Mesh.PRIMITIVE_LINES, _mat)
	for l in _lineas:
		var c: Color = l["color"]
		_malla.surface_set_color(c)
		_malla.surface_add_vertex(l["a"])
		_malla.surface_set_color(c)
		_malla.surface_add_vertex(l["b"])
	_malla.surface_end()
