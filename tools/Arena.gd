@tool
class_name Arena
extends Node3D
## Patio de combate para el Hito 2: 30 segundos de combo contra tres cápsulas.
##
## Está cerrado por muros bajos a propósito. El combate del juego vive en recintos
## (§ decisión de alcance de docs/02): el mundo abierto se queda en silencio, y así
## el tono contemplativo de SotC sobrevive a un combate flashy.
##
## F4 respawnea a los tres Guardianes sin reiniciar la partida.

const GUARDIAN := preload("res://src/enemies/Guardian.tscn")

@export var palette: Palette:
	set(v):
		palette = v
		if is_inside_tree():
			construir()

@export var origen: Vector3 = Vector3(45.0, 0.0, -45.0)
@export var radio: float = 16.0

var _raiz: Node3D
var _enemigos: Node3D


func _ready() -> void:
	if not Engine.is_editor_hint() and palette == null:
		palette = GameState.palette
	construir()
	if not Engine.is_editor_hint():
		poblar()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed(InputActions.DEBUG_RESET):
		poblar()
		get_viewport().set_input_as_handled()


func construir() -> void:
	if palette == null:
		return
	if _raiz != null and is_instance_valid(_raiz):
		_raiz.queue_free()
	_raiz = Node3D.new()
	_raiz.name = "Recinto"
	add_child(_raiz)

	var suelo := _material(palette.piedra_media, 0.9)
	var muro := _material(palette.piedra_sombra, 0.92)

	_bloque("Suelo", Vector3(radio * 2.0, 1.0, radio * 2.0), Vector3(0, -0.5, 0), suelo)
	# Muros bajos: encierran el combate sin tapar la vista de la cámara.
	for i in 4:
		var a := float(i) * PI * 0.5
		var d := Vector3(sin(a), 0.0, cos(a)) * radio
		var tam := Vector3(radio * 2.0, 2.4, 1.0) if i % 2 == 0 else Vector3(1.0, 2.4, radio * 2.0)
		_bloque("Muro_%d" % i, tam, d + Vector3.UP * 1.2, muro)

	# Una plataforma alta: sin altura no hay combate aéreo que practicar.
	_bloque("Repisa", Vector3(6, 1, 6), Vector3(-radio * 0.45, 3.0, -radio * 0.45), suelo)
	_bloque("Rampa", Vector3(4, 1, 8), Vector3(-radio * 0.45, 1.5, -radio * 0.05), suelo).rotation_degrees.x = -22.0

	_etiqueta("ARENA — F4 respawnea", Vector3(0, 0.06, radio * 0.62))


## Crea los tres arquetipos. Uno de cada: el objetivo es entrenar tres lecturas
## distintas, no aguantar una horda.
func poblar() -> void:
	if _enemigos != null and is_instance_valid(_enemigos):
		_enemigos.queue_free()
	_enemigos = Node3D.new()
	_enemigos.name = "Guardianes"
	add_child(_enemigos)

	_spawn(Guardian.Tipo.LANCERO, Vector3(4.0, 0.2, -3.0), "res://content/data/attacks/guardian_lancero.tres")
	_spawn(Guardian.Tipo.ESCUDO, Vector3(-4.0, 0.2, -4.0), "res://content/data/attacks/guardian_escudo.tres")
	_spawn(Guardian.Tipo.VIGIA, Vector3(0.0, 0.2, -8.0), "res://content/data/attacks/guardian_vigia.tres")


func _spawn(tipo: int, pos: Vector3, ruta_ataque: String) -> void:
	var g := GUARDIAN.instantiate() as Guardian
	g.name = ["Lancero", "Escudo", "Vigia"][tipo]
	g.tipo = tipo
	g.ataque = load(ruta_ataque)
	g.palette = palette
	_enemigos.add_child(g)
	g.global_position = origen + pos


# --- Utilidades ---------------------------------------------------------------

func _material(color: Color, rugosidad: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugosidad
	return m


func _bloque(nombre: String, tam: Vector3, pos: Vector3, material: Material) -> StaticBody3D:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = nombre
	cuerpo.position = origen + pos
	cuerpo.collision_layer = 1

	var malla := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	malla.mesh = caja
	malla.material_override = material
	cuerpo.add_child(malla)

	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = tam
	col.shape = forma
	cuerpo.add_child(col)

	_raiz.add_child(cuerpo)
	return cuerpo


func _etiqueta(texto: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = texto
	l.position = origen + pos
	l.rotation_degrees.x = -90.0
	l.font_size = 72
	l.pixel_size = 0.006
	l.modulate = palette.crema_bruma
	l.outline_modulate = palette.verde_negro
	l.outline_size = 16
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.double_sided = true
	_raiz.add_child(l)
