extends Node3D
## EL CLARO: el banco del mundo vivo.
##
##   godot --path . --resolution 960x540 tools/Claro.tscn
##
## Lo que el Gym es al movimiento y el Jardin al sistema generativo, esto es a la
## capa atmosferica: hierba con viento e interaccion, luciernagas que parpadean al
## unisono y una bandada de criaturas de tela planeando encima. Se toca y se mira,
## sin abrir una partida.
##
## Los tres comparten una idea y por eso viven juntos: **nada de esto esta
## guionizado.** La hierba responde a un campo de viento que es una formula; las
## luciernagas y la bandada, al mismo modelo de Kuramoto que ya movia las Criaturas
## de Tela. Ninguno tiene un temporizador ni una animacion.
##
## Que probar:
##   · CORRE POR LA HIERBA. Se aplasta al pasar y deja un rastro que se levanta
##     solo en unos segundos.
##   · MIRA DE LEJOS. Las ondas de viento cruzan el campo entero; es lo que
##     `docs/01_DIRECCION_ARTE.md §4.5` pide ver desde lejos.
##   · ESPERA. El enjambre respira: la bandada se junta y se deshace, y las
##     luciernagas pasan de centellear en desorden a parpadear todas a la vez.
##   · **F7** dibuja el orden de los dos enjambres y el rastro de la hierba.

const PASTO := preload("res://src/world/Pasto.gd")
const LUCIERNAGAS := preload("res://src/world/Luciernagas.gd")
const BANDADA := preload("res://src/world/Bandada.gd")

## Donde se planta, en coordenadas de mundo.
@export var centro: Vector3 = Vector3(-9.0, 0.0, -30.0)
## ¿Monta tambien el mundo alrededor —el Gym con su jugador y su camara—?
##
## En falso queda solo el claro, para poder soltarlo dentro de otra escena. El
## screenshot test lo mete en el mundo del Gym a 200 m de altura, igual que hace
## con el Jardin: sin este interruptor cargaria un segundo `Main.tscn` dentro del
## primero.
@export var autonomo: bool = true
## ¿Se trae su propio suelo? En el banco no hace falta —crece sobre el del Gym—;
## colgado en el aire para una toma, si.
@export var con_suelo: bool = false
@export var lado: float = 22.0

var pasto: Pasto
var luciernagas: Luciernagas
var bandada: Bandada
var _mundo: Node
var _jugador: Node3D


func _ready() -> void:
	if autonomo:
		_mundo = load("res://content/levels/Main.tscn").instantiate()
		add_child(_mundo)
		_jugador = _mundo.get_node_or_null("Player") as Node3D

	if con_suelo:
		_suelo()

	pasto = PASTO.new()
	pasto.name = "Pasto"
	pasto.area = Vector2(lado, lado)
	add_child(pasto)
	pasto.global_position = centro

	luciernagas = LUCIERNAGAS.new()
	luciernagas.name = "Luciernagas"
	luciernagas.area = Vector3(lado * 0.9, 4.5, lado * 0.9)
	add_child(luciernagas)
	luciernagas.global_position = centro + Vector3.UP * 0.6

	bandada = BANDADA.new()
	bandada.name = "Bandada"
	# Un circuito que quepa sobre el claro. Los valores de fabrica de `Bandada`
	# son para cielo abierto —26 m de radio—; aqui se ve mejor cerca.
	bandada.criaturas = 14
	bandada.radio = 9.5
	bandada.vaiven = 3.6
	bandada.dispersion_tubo = 2.3
	bandada.largo = 2.0
	bandada.ancho = 0.34
	add_child(bandada)
	bandada.global_position = centro + Vector3.UP * 10.0

	if autonomo and _jugador != null:
		# Al borde del claro, no en medio: entrar corriendo y ver como se abre el
		# rastro es la mitad de la demostracion.
		_jugador.global_position = centro + Vector3(0.0, 1.2, lado * 0.5 + 3.0)
		_jugador.call(&"reset_physics_interpolation")


func _process(_delta: float) -> void:
	if not autonomo:
		return
	DebugOverlay.set_line("pasto", pasto.debug_line())
	DebugOverlay.set_line("luciernagas", luciernagas.debug_line())
	DebugOverlay.set_line("bandada", bandada.debug_line())
	_gizmos()


## Lo que los tres sistemas DECIDEN, dibujado.
##
## El orden de cada enjambre como una barra, y el rastro de la hierba como las
## esferas que el shader esta leyendo de verdad. Es la unica forma de saber si un
## aplastado que no se ve es "el shader no lo dibuja" o "la huella no ha llegado".
func _gizmos() -> void:
	if not DebugDraw.activo:
		return
	var p := GameState.palette
	for h in pasto.rastro():
		if h.w <= 0.001:
			continue
		DebugDraw.esfera(Vector3(h.x, h.y, h.z), 0.35 * h.w, p.oro_palido)
	_barra(centro + Vector3(0.0, 6.0, 0.0), luciernagas.enjambre.orden, p.oro_palido)
	_barra(centro + Vector3(1.2, 6.0, 0.0), bandada.enjambre.orden, p.blanco_tiza)


func _barra(base: Vector3, valor: float, color: Color) -> void:
	DebugDraw.linea(base, base + Vector3.UP * (3.0 * valor), color)


## Suelo propio, para cuando el claro cuelga en el aire. Capa WORLD, que es donde
## `Pasto` busca para pegar cada brizna.
func _suelo() -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "SueloClaro"
	cuerpo.collision_layer = Layers.WORLD
	cuerpo.collision_mask = 0
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(lado + 8.0, 1.0, lado + 8.0)
	forma.shape = caja
	cuerpo.add_child(forma)

	var visual := MeshInstance3D.new()
	var malla := BoxMesh.new()
	malla.size = caja.size
	var m := StandardMaterial3D.new()
	m.albedo_color = GameState.palette.musgo_sombra
	m.roughness = 1.0
	malla.material = m
	visual.mesh = malla
	cuerpo.add_child(visual)

	add_child(cuerpo)
	cuerpo.global_position = centro - Vector3.UP * 0.5
