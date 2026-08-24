@tool
class_name Circuito
extends Node3D
## La carrera de obstáculos del Hito 1.
##
## No es decoración: es el test que decide si el proyecto sigue. Está diseñada para
## que NO se pueda terminar sin encadenar los seis verbos, y para que cada tramo
## tenga una línea buena y una mala. Si apetece repetirla para bajar el tiempo,
## la Fase 1 está aprobada. Ver docs/04_ROADMAP.md.
##
## Tramos: sprint · salto+dash · slide en rampa · planeo · wall-run · borde · escalada

@export var palette: Palette:
	set(v):
		palette = v
		if is_inside_tree():
			construir()

@export var origen: Vector3 = Vector3(-70.0, 0.0, -10.0)

var _raiz: Node3D
var _mat: StandardMaterial3D
var _mat_osc: StandardMaterial3D
var _mat_marca: StandardMaterial3D
var _mat_escalable: StandardMaterial3D

var _corriendo: bool = false
var _tiempo: float = 0.0
var _mejor: float = -1.0
var _checkpoints: int = 0
var _total_checkpoints: int = 0
var _hud: Label


func _ready() -> void:
	if not Engine.is_editor_hint() and palette == null:
		palette = GameState.palette
	construir()
	if not Engine.is_editor_hint():
		_crear_hud()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _corriendo:
		return
	_tiempo += delta
	_actualizar_hud()


func construir() -> void:
	if palette == null:
		return
	if _raiz != null and is_instance_valid(_raiz):
		_raiz.queue_free()
	_raiz = Node3D.new()
	_raiz.name = "Trazado"
	add_child(_raiz)

	_mat = _material(palette.piedra_media, 0.86)
	_mat_osc = _material(palette.piedra_sombra, 0.9)
	_mat_marca = _material(palette.oro_palido, 0.7)
	_mat_escalable = _material(palette.musgo_medio, 0.95)

	_checkpoints = 0
	_total_checkpoints = 0

	_tramo_salida()
	_tramo_salto_dash()
	_tramo_slide()
	_tramo_planeo()
	_tramo_wallrun()
	_tramo_borde()
	_tramo_escalada()
	_tramo_meta()


# --- Tramos ------------------------------------------------------------------

func _tramo_salida() -> void:
	# Recta de aceleración: sin sprint no se llega al primer hueco.
	_bloque("Salida", Vector3(8, 1, 26), Vector3(0, -0.5, 0), _mat_marca)
	_etiqueta("SALIDA — sprint", Vector3(0, 0.06, -10))
	_disparador("Inicio", Vector3(0, 1.5, -10), Vector3(7, 3, 2), _on_inicio)


func _tramo_salto_dash() -> void:
	# 9 m: imposible de un salto, trivial con salto + dash aéreo.
	_bloque("Dash_Llegada", Vector3(7, 1, 8), Vector3(0, -0.5, 26.0), _mat)
	_etiqueta("9 m — salto + dash", Vector3(0, 0.06, 20.0))
	_checkpoint(Vector3(0, 1.5, 26.0))


func _tramo_slide() -> void:
	# Rampa descendente larga: el slide gana velocidad y la conserva al saltar.
	var rampa := _bloque("Slide_Rampa", Vector3(7, 1, 20), Vector3(0, -2.4, 40.0), _mat)
	rampa.rotation_degrees.x = 14.0
	_etiqueta("agáchate corriendo", Vector3(0, 0.06, 31.0))
	_bloque("Slide_Trampolin", Vector3(7, 1, 4), Vector3(0, -5.0, 52.0), _mat_marca)
	_checkpoint(Vector3(0, -3.5, 52.0))


func _tramo_planeo() -> void:
	# 26 m de vacío desde altura: solo se cruza planeando.
	_bloque("Planeo_Llegada", Vector3(10, 1, 10), Vector3(0, -12.0, 80.0), _mat)
	_etiqueta("26 m — planea", Vector3(0, -11.44, 74.0))
	# Un pilar en medio castiga la línea perezosa: hay que picar y remontar.
	_bloque("Planeo_Obstaculo", Vector3(3, 14, 3), Vector3(0, -5.0, 66.0), _mat_osc)
	_checkpoint(Vector3(0, -10.5, 80.0))


func _tramo_wallrun() -> void:
	# Pasillo sin suelo: solo se cruza corriendo por las paredes y alternando.
	for i in 2:
		var lado := -1.0 if i == 0 else 1.0
		_bloque("Wallrun_Muro_%d" % i, Vector3(1, 10, 26),
			Vector3(lado * 2.4, -8.0, 98.0), _mat_osc)
	_etiqueta("wall-run", Vector3(0, -11.44, 87.0))
	_bloque("Wallrun_Llegada", Vector3(8, 1, 6), Vector3(0, -12.0, 114.0), _mat)
	_checkpoint(Vector3(0, -10.5, 114.0))


func _tramo_borde() -> void:
	# Repisas escalonadas fuera del alcance de un salto: hay que agarrarse.
	var y := -11.0
	for i in 3:
		y += 2.6
		_bloque("Borde_%d" % i, Vector3(6, 1.6, 3), Vector3(0, y, 120.0 + float(i) * 3.2), _mat)
		_bloque("Canto_%d" % i, Vector3(6, 0.06, 0.3),
			Vector3(0, y + 0.83, 118.6 + float(i) * 3.2), _mat_marca)
	_etiqueta("agarra el canto", Vector3(0, -10.44, 118.0))
	_checkpoint(Vector3(0, y + 2.0, 126.4))


func _tramo_escalada() -> void:
	# Pared escalable de 11 m con la stamina justa: no se puede parar a media pared.
	var pared := _bloque("Escalada", Vector3(10, 11, 1), Vector3(0, -1.0, 132.0), _mat_escalable)
	pared.set_collision_layer_value(4, true)  # CLIMBABLE
	_etiqueta("mantén agarrar", Vector3(0, -3.44, 130.0))
	_bloque("Escalada_Cima", Vector3(8, 1, 5), Vector3(0, 4.0, 135.0), _mat)
	_checkpoint(Vector3(0, 5.5, 135.0))


func _tramo_meta() -> void:
	_bloque("Meta", Vector3(10, 1, 8), Vector3(0, 4.0, 142.0), _mat_marca)
	_etiqueta("META", Vector3(0, 4.56, 142.0))
	_disparador("Fin", Vector3(0, 6.0, 142.0), Vector3(9, 4, 2), _on_meta)


# --- Cronómetro ---------------------------------------------------------------

func _on_inicio(cuerpo: Node3D) -> void:
	if not (cuerpo is PlayerController):
		return
	_corriendo = true
	_tiempo = 0.0
	_checkpoints = 0
	_actualizar_hud()


func _on_meta(cuerpo: Node3D) -> void:
	if not (cuerpo is PlayerController) or not _corriendo:
		return
	# Cortar por el aire saltándose tramos no cuenta como vuelta.
	if _checkpoints < _total_checkpoints:
		return
	_corriendo = false
	if _mejor < 0.0 or _tiempo < _mejor:
		_mejor = _tiempo
	_actualizar_hud()


func _on_checkpoint(cuerpo: Node3D, indice: int) -> void:
	if not (cuerpo is PlayerController) or not _corriendo:
		return
	_checkpoints = maxi(_checkpoints, indice)


func _crear_hud() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 90
	add_child(capa)
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margen.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margen.add_theme_constant_override("margin_right", 18)
	margen.add_theme_constant_override("margin_top", 14)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(margen)

	_hud = Label.new()
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_theme_font_size_override("font_size", 22)
	_hud.add_theme_color_override("font_color", palette.crema_bruma)
	_hud.add_theme_color_override("font_outline_color", palette.verde_negro)
	_hud.add_theme_constant_override("outline_size", 8)
	margen.add_child(_hud)
	_actualizar_hud()


func _actualizar_hud() -> void:
	if _hud == null:
		return
	var lineas := PackedStringArray()
	if _corriendo:
		lineas.append("%.2f s   ·   %d/%d" % [_tiempo, _checkpoints, _total_checkpoints])
	elif _mejor >= 0.0:
		lineas.append("último %.2f s" % _tiempo)
	else:
		lineas.append("cruza la SALIDA")
	if _mejor >= 0.0:
		lineas.append("mejor %.2f s" % _mejor)
	_hud.text = "\n".join(lineas)


# --- Utilidades ---------------------------------------------------------------

func _material(color: Color, rugosidad: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugosidad
	m.metallic = 0.0
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


func _disparador(nombre: String, pos: Vector3, tam: Vector3, cb: Callable) -> Area3D:
	var area := Area3D.new()
	area.name = nombre
	area.position = origen + pos
	area.collision_layer = 0
	area.collision_mask = Layers.PLAYER
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = tam
	col.shape = forma
	area.add_child(col)
	_raiz.add_child(area)
	if not Engine.is_editor_hint():
		area.body_entered.connect(cb)
	return area


func _checkpoint(pos: Vector3) -> void:
	_total_checkpoints += 1
	var indice := _total_checkpoints
	_disparador("Check_%d" % indice, pos, Vector3(9, 5, 2),
		func(c: Node3D) -> void: _on_checkpoint(c, indice))


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
