extends Node3D
## EL JARDÍN: monta el enjambre y deja mirarlo.
##
##   godot --path . --resolution 960x540 tools/Jardin.tscn
##
## No es parte del juego. Es el banco donde se afina el sistema generativo, igual
## que el Gym lo es del movimiento: se toca `EnjambreTuning` y se mira, sin abrir
## una partida.
##
## Controles:
##   · **clic izquierdo** sobre una criatura → la perturba. Se le va la fase y el
##     enjambre entero la arrastra de vuelta. Eso es toda la interacción.
##   · **rueda / flechas arriba y abajo** → el pitch del conjunto, en semitonos.
##   · **R** → reinicia el sistema al caos.
##   · **F7** → gizmos, incluida la rueda de fases.

const CRIATURA := preload("res://src/generative/CriaturaTela.tscn")

@export var tuning: EnjambreTuning
## Radio del anillo en el que se colocan. Un círculo y no una rejilla: en rejilla
## la sincronización se lee como filas encendiéndose, y lo que hay que ver es un
## grupo, no una matriz.
@export_range(1.0, 30.0, 0.5) var radio: float = 4.2
## Dónde se planta el anillo, en coordenadas de mundo.
@export var centro: Vector3 = Vector3.ZERO
## ¿Monta también suelo, luz, entorno y cámara?
##
## En falso se queda solo el enjambre, para poder soltarlo dentro de otra escena
## —el screenshot test lo mete en el mundo del Gym—. Sin este interruptor su
## `WorldEnvironment` reemplazaría al del anfitrión y su cámara le robaría el
## viewport, y las dos cosas se llevarían por delante las TOMAS SIGUIENTES, que es
## la peor forma de romper un test: falla otro sitio.
@export var autonomo: bool = true

var enjambre: Enjambre
var _cam: Camera3D


func _ready() -> void:
	if tuning == null:
		tuning = EnjambreTuning.new()

	if autonomo:
		_fondo()

	enjambre = Enjambre.new()
	enjambre.name = "Enjambre"
	enjambre.tuning = tuning
	enjambre.palette = GameState.palette
	add_child(enjambre)

	for i in tuning.agentes:
		var c := CRIATURA.instantiate() as CriaturaTela
		c.name = "Criatura%d" % i
		c.indice = i
		c.enjambre_path = ^".."
		# En anillo, y cada una con su EJE de vaivén apuntando hacia fuera. Con
		# todas oscilando en vertical el enjambre sube y baja como un bloque y la
		# fase de cada una deja de distinguirse.
		var a := TAU * float(i) / float(tuning.agentes)
		var fuera := Vector3(cos(a), 0.0, sin(a))
		c.ancla = centro + fuera * radio + Vector3.UP * 1.6
		c.eje = (Vector3.UP * 1.6 + fuera).normalized()
		# Y el segundo eje, la TANGENTE del anillo: así la figura de cada una se
		# abre a lo largo del círculo en vez de hacia el centro, donde las nueve
		# colas se cruzarían en un nudo.
		c.eje_lateral = Vector3(-sin(a), 0.0, cos(a))
		enjambre.add_child(c)

	if autonomo:
		_camara()


func _process(_delta: float) -> void:
	if not autonomo:
		return
	DebugOverlay.set_line("enjambre", enjambre.debug_line())
	DebugOverlay.set_line("pitch", "usuario %+.1f semitonos" % enjambre.pitch_usuario)
	_gizmos()


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
		var mb := evento as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_perturbar_bajo_raton(mb.position)
			MOUSE_BUTTON_WHEEL_UP:
				_mover_pitch(1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_mover_pitch(-1.0)
	elif evento is InputEventKey and (evento as InputEventKey).pressed and not evento.is_echo():
		match (evento as InputEventKey).keycode:
			KEY_UP: _mover_pitch(1.0)
			KEY_DOWN: _mover_pitch(-1.0)
			KEY_R: enjambre.reiniciar()


## Perturba la criatura que hay bajo el ratón.
##
## Por proyección de rayo desde la cámara y comparando distancias en pantalla, no
## por colisión: las criaturas no tienen cuerpo físico —son manifestación pura— y
## darles uno solo para poder clicarlas seria inventar una capa entera.
func _perturbar_bajo_raton(pantalla: Vector2) -> void:
	if _cam == null:
		return
	var mejor := -1
	var mejor_d := 60.0
	for hijo in enjambre.get_children():
		var c := hijo as CriaturaTela
		if c == null or _cam.is_position_behind(c.global_position):
			continue
		var d := _cam.unproject_position(c.global_position).distance_to(pantalla)
		if d < mejor_d:
			mejor_d = d
			mejor = c.indice
	if mejor >= 0:
		enjambre.perturbar(mejor)


func _mover_pitch(semitonos: float) -> void:
	enjambre.pitch_usuario = clampf(
		enjambre.pitch_usuario + semitonos, -tuning.pitch_usuario, tuning.pitch_usuario)


## LA RUEDA DE FASES (F7). Cada criatura, un punto en el círculo unidad; el radio
## del grupo es `r`. Es el sistema entero en un dibujo: disperso, los puntos
## rodean el círculo; al unísono, se juntan en uno.
func _gizmos() -> void:
	if not DebugDraw.activo:
		return
	var p := GameState.palette
	var eje_rueda := centro + Vector3(0, 5.5, 0)
	var radio_rueda := 1.4
	for i in enjambre.fases.size():
		var f: float = enjambre.fases[i]
		DebugDraw.punto(eje_rueda + Vector3(cos(f), sin(f), 0.0) * radio_rueda, 0.09, p.oro_palido)
	# El vector de orden: apunta a la fase media y su LARGO es r.
	DebugDraw.linea(eje_rueda,
		eje_rueda + Vector3(cos(enjambre.fase_media), sin(enjambre.fase_media), 0.0)
			* radio_rueda * enjambre.orden, p.carmesi)


func _fondo() -> void:
	var suelo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(40, 40)
	var m := StandardMaterial3D.new()
	m.albedo_color = GameState.palette.verde_negro
	m.roughness = 1.0
	plano.material = m
	suelo.mesh = plano
	add_child(suelo)

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-52, -35, 0)
	luz.light_energy = 0.85
	luz.light_color = GameState.palette.luz_solar
	add_child(luz)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = GameState.palette.verde_negro
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = GameState.palette.lavanda_profundo
	e.ambient_light_energy = 0.45
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_bloom = 0.15
	env.environment = e
	add_child(env)


func _camara() -> void:
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 4.6, 11.5)
	_cam.rotation_degrees = Vector3(-12, 0, 0)
	_cam.fov = 55.0
	add_child(_cam)
	_cam.make_current()
