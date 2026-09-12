class_name CriaturaTela
extends Node3D
## UNA CRIATURA DE TELA. Su ciclo de oscilador, hecho visible.
##
## **NO ROTA. NUNCA.** Es la restricción del encargo y ordena todo lo demás: sin
## giro, un cuerpo solo puede expresarse con *dónde está*, *cuánto ocupa* y *de
## qué color es*. Eso resulta ser una ventaja, no un límite —
##
##   · el vaivén se lee como respiración y no como un objeto orientándose;
##   · sin frente, la criatura no "mira", así que no parece un enemigo;
##   · y quita de en medio el eje que más ruido mete al leer un enjambre: doce
##     cuerpos girando a la vez son ilegibles, doce latiendo no.
##
## `_process` lo comprueba cada frame en modo debug: la base se reafirma a
## identidad. Un `look_at()` colado en el futuro no rompe nada en silencio.
##
## ---
##
## Todo cuelga de UN número: `Enjambre.ciclo_de(i)`, de 0 a 1. Color, opacidad,
## escala, altura del vaivén y destello salen del mismo sitio, y por eso el
## conjunto se lee como una sola cosa viva en vez de cinco efectos sueltos.
##
## Y de un segundo: `desvio_de(i)`, cuánto se aparta del enjambre. Es lo que hace
## VISIBLE la sincronización sin un número en pantalla — dispersas son colores
## corridos, al unísono son un solo color latiendo.

@export var enjambre_path: NodePath = ^".."
## Índice dentro del enjambre. Lo escribe quien la crea.
@export var indice: int = 0
## Sitio de reposo. La criatura oscila ALREDEDOR de este punto y no se va nunca.
@export var ancla: Vector3 = Vector3.ZERO
## Dirección del vaivén. Cada criatura la suya, para que el enjambre no se mueva
## como un bloque.
@export var eje: Vector3 = Vector3.UP
## Segunda dirección, perpendicular. Es la que cierra la figura; ver `_recorrido()`.
## A cero se calcula una cualquiera perpendicular al eje.
@export var eje_lateral: Vector3 = Vector3.ZERO

@onready var visual: MeshInstance3D = $Visual
@onready var cola: Estela = $Cola

var enjambre: Enjambre
var _mat: StandardMaterial3D
var _tuning: EnjambreTuning
## Base de color de esta criatura, tomada de la Palette al nacer.
var _color_calma: Color = Color.WHITE
var _color_pico: Color = Color.WHITE


func _ready() -> void:
	enjambre = get_node_or_null(enjambre_path) as Enjambre
	if enjambre == null:
		return
	_tuning = enjambre.tuning
	# En su sitio ANTES de preparar nada: la cola nace donde este el cuerpo, y si
	# el cuerpo todavia esta en el origen su primer frame es un latigazo cruzando
	# la escena. Aqui `_physics_process` aun no ha corrido.
	global_position = ancla
	_preparar()


func _physics_process(_delta: float) -> void:
	if enjambre == null or _tuning == null:
		return

	var c := enjambre.ciclo_de(indice)
	var d := enjambre.desvio_de(indice)

	# 1) DÓNDE. Traslación pura alrededor del ancla, sin tocar un solo ángulo.
	global_position = ancla + _recorrido(enjambre.fase_de(indice))

	# 2) CUÁNTO OCUPA. Respira con el ciclo. Es lo más parecido a un latido que
	#    se puede hacer sin rotar ni deformar.
	var s := 1.0 + (c * 2.0 - 1.0) * _tuning.respiracion
	visual.scale = Vector3(s, s, s)

	# 3) DE QUÉ COLOR. Ver `_pintar`.
	_pintar(c, d)

	# LA COLA no se le dice a dónde ir: persigue. Solo se le pasa la cabeza.
	if cola != null:
		cola.seguir(global_position)


func _process(_delta: float) -> void:
	# EL GUARDIA DE LA RESTRICCIÓN. Cuesta cero apagado y caza en el acto un
	# `look_at()` o un `rotation.y +=` colado en el futuro, que si no se leería
	# como "el enjambre se ve raro" sin que nadie sepa por qué.
	if DebugDraw.activo and not basis.is_equal_approx(Basis.IDENTITY):
		DebugDraw.esfera(global_position, 0.6, GameState.palette.carmesi)
	basis = Basis.IDENTITY


## EL RECORRIDO: un ocho, hecho solo de traslación.
##
##     a lo largo del eje    sinθ
##     a lo ancho            sin2θ · onda_lateral
##
## Que el segundo eje vaya al DOBLE de frecuencia es lo que cierra la curva en vez
## de dejar una elipse. Y una figura cerrada importa por algo muy concreto: la
## criatura casi nunca vuelve sobre su propio camino, así que la cola siempre
## tiene sitio detrás. Por una recta iría y volvería pisando su rastro, y la
## estela se leería como un adorno pegado al cuerpo.
##
## Sigue sin haber rotación: los dos ejes son fijos y lo único que cambia es el
## punto. Un ocho recorrido sin girar es exactamente el "movimiento ondulatorio"
## del encargo.
func _recorrido(theta: float) -> Vector3:
	var v := eje.normalized() if not eje.is_zero_approx() else Vector3.UP
	var w := eje_lateral
	if w.is_zero_approx():
		# Cualquiera perpendicular sirve; se elige por el eje del mundo con el que
		# el eje principal está MENOS alineado, que es lo que evita el caso
		# degenerado de un producto vectorial entre paralelos.
		var aux := Vector3.UP if absf(v.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		w = v.cross(aux)
	w = w.normalized()
	var a := _tuning.onda_amplitud
	return v * (sin(theta) * a) + w * (sin(theta * 2.0) * a * _tuning.onda_lateral)


## EL COLOR ES LA FASE. `project.md §5` lo pide así y la razón es que el color ya
## es el canal de estado del juego (`Enemigo._actualizar_color()`).
##
## Tres capas, de más a menos:
##
##   · **la rampa del ciclo** — de calma a pico, dos colores de la Palette. Esto
##     es el latido.
##   · **el desvío desatura** — una criatura fuera del grupo pierde color. Al
##     converger, el enjambre entero se satura de golpe: la sincronización se VE
##     sin un número.
##   · **la deriva de tono**, sutil por encargo. Nueve grados, no una rueda: un
##     giro completo sería un arcoíris y se llevaría por delante la regla dura #8,
##     que reserva los azules y los rojos.
func _pintar(c: float, d: float) -> void:
	if _mat == null:
		return
	var col := _color_calma.lerp(_color_pico, c)

	# El desvío desatura hacia el gris de piedra de la paleta, no hacia el gris
	# puro: en este juego no hay neutros muertos (regla dura #8).
	var apagado := GameState.palette.piedra_media if GameState.palette != null else Color(0.6, 0.6, 0.6)
	col = col.lerp(apagado, d * 0.7)

	# Deriva de tono con la fase. `h` se mueve poco y `s`/`v` no se tocan aquí:
	# lo que tiene que cambiar es el matiz, no el brillo.
	var h := fposmod(col.h + (c - 0.5) * (_tuning.hue_deriva / 360.0), 1.0)
	col = Color.from_hsv(h, col.s, col.v, col.a)

	# OPACIDAD con el ciclo: la criatura casi se desvanece en el valle. Es lo que
	# la hace de TELA y no de piedra.
	_mat.albedo_color = Color(col.r, col.g, col.b,
		lerpf(_tuning.opacidad_min, _tuning.opacidad_max, c))

	# DESTELLO solo en la cresta, y estrecho. `pow` con exponente alto deja el
	# brillo casi a cero en todo el ciclo menos en el pico: lo que se lee es el
	# PULSO, no un objeto luminoso.
	var pico: float = pow(c, _tuning.destello_dureza)
	_mat.emission_enabled = true
	_mat.emission = col
	_mat.emission_energy_multiplier = pico * _tuning.destello * (1.0 - d * 0.5)

	if cola != null:
		cola.color = Color(col.r, col.g, col.b, _mat.albedo_color.a * 0.8)


func _preparar() -> void:
	var p := enjambre.palette
	if p == null:
		return
	# Dos colores de la Palette por criatura, elegidos por su ÍNDICE y no al azar:
	# el enjambre tiene que verse igual en dos arranques, o comparar capturas es
	# imposible. Todos salen de la familia vegetación + neutros, que es la que la
	# regla dura #8 deja libre —los azules y los rojos están reservados—.
	var calmas := [p.musgo_medio, p.pasto_medio, p.lavanda_profundo, p.piedra_sombra]
	var picos := [p.pasto_sol, p.hierba_highlight, p.crema_bruma, p.caliza_sol]
	_color_calma = calmas[indice % calmas.size()]
	_color_pico = picos[indice % picos.size()]

	if visual != null:
		_mat = StandardMaterial3D.new()
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.roughness = 0.85
		visual.material_override = _mat
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if cola != null:
		# Tendida a lo largo de su propio eje de vaivén: es por donde va a viajar,
		# así que arranca ya alineada con el camino que va a dibujar.
		cola.configurar(_tuning, global_position, -eje.normalized())


func debug_line() -> String:
	return "#%d  ciclo %.2f  desvio %.2f" % [
		indice, enjambre.ciclo_de(indice), enjambre.desvio_de(indice)]
