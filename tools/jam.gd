extends Node3D
## LA JAM: el banco de la estacion de musica.
##
##   godot --path . --resolution 960x540 tools/Jam.tscn
##
## Lo que el Jardin es al modelo y el Claro a la capa atmosferica, esto es al
## audio: ocho puestos en corro tocando el mismo Kuramoto que ya movia todo lo
## demas. Se escucha y se toca, sin abrir una partida.
##
## QUE PROBAR — y es un banco de OIDO, no de vista:
##   · ESPERA SIN HACER NADA. El corro respira solo: los ocho se van juntando
##     hasta tocar a la vez, se cansan, se deshacen y vuelven. No hay guion —es la
##     histeresis del acoplamiento, los mismos 9.6 / 19.6 / 7.3 segundos que mide
##     `TestEnjambre`.
##   · ACERCATE AL CORRO. Tu eres el marcapasos: unos cuantos te cogen el compas y
##     otros no. Los que pueden son los de tempo medio —`|ωᵢ − Ω| ≤ A`— y siempre
##     son los mismos, asi que se aprende a reconocerlos.
##   · MIRA EL COLOR. El que va con el grupo se enciende y el que va a su aire se
##     apaga. Cuando convergen, el corro entero es un solo color latiendo.
##   · **1..8** golpea un puesto a mano, para oir su registro suelto.
##   · **R** devuelve el enjambre al caos. **F7** dibuja el orden y quien te sigue.

const ESTACION := preload("res://src/world/EstacionJam.gd")

## Donde se planta, en coordenadas de mundo.
@export var centro: Vector3 = Vector3(-16.0, 0.0, 14.0)
## ¿Monta tambien el mundo alrededor —el Gym con su jugador y su camara—?
## Mismo interruptor que el Claro y el Jardin, y por lo mismo: en falso queda solo
## la estacion, para poder soltarla dentro de otra escena sin cargar un segundo
## `Main.tscn` dentro del primero.
@export var autonomo: bool = true

var estacion: EstacionJam
var _mundo: Node
var _jugador: Node3D


func _ready() -> void:
	if autonomo:
		_mundo = load("res://content/levels/Main.tscn").instantiate()
		add_child(_mundo)
		_jugador = _mundo.get_node_or_null("Player") as Node3D

	estacion = ESTACION.new()
	estacion.name = "EstacionJam"
	add_child(estacion)
	estacion.global_position = centro
	if _jugador != null:
		estacion.seguir(_jugador)
		var p := _jugador as Node3D
		# A las puertas del corro, no dentro: lo primero que hay que poder hacer es
		# ACERCARSE y oir como cambia.
		p.global_position = centro + Vector3(0.0, 0.3, 14.0)

	DebugOverlay.set_line("banco", "JAM — acercate al corro · 1..8 golpea · R caos")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var k := (event as InputEventKey).keycode
	if k == KEY_R:
		estacion.enjambre.reiniciar()
		return
	if k >= KEY_1 and k <= KEY_8:
		estacion.tocar(k - KEY_1)


func _process(_delta: float) -> void:
	if estacion == null or estacion.enjambre == null:
		return
	DebugOverlay.set_line("jam", estacion.debug_line())
	if not DebugDraw.activo:
		return
	# EL ORDEN, como anillo: el radio dice cuanto han convergido. Mismo gizmo que
	# el Jardin usa para la rueda de fases, porque es la misma magnitud.
	DebugDraw.esfera(estacion.global_position + Vector3.UP * 2.4,
		0.3 + estacion.enjambre.orden * 1.6, estacion.palette.oro_palido)
	for i in estacion.asientos:
		var enganche := estacion.enjambre.enganche_de(i)
		if enganche > 0.5 and _jugador != null:
			DebugDraw.linea(estacion.sitio(i), _jugador.global_position,
				estacion.palette.carmesi)
