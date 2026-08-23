extends CanvasLayer
## Autoload. Panel de depuración. F3 lo enseña y lo esconde.
##
## Cualquier sistema publica una línea con set_line("clave", "texto") y esta
## desaparece sola si deja de actualizarse. Cuesta un día construirlo y ahorra
## semanas: sin esto se depura el game feel a ciegas.

const CADUCIDAD := 0.4  ## Segundos sin actualizar tras los que una línea se borra.

var visible_panel: bool = true

var _lineas: Dictionary = {}      # clave -> {texto, orden, t}
var _orden_siguiente: int = 0
var _t: float = 0.0

var _panel: PanelContainer
var _label: RichTextLabel
var _fps: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_construir()


func _construir() -> void:
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margen.add_theme_constant_override("margin_left", 12)
	margen.add_theme_constant_override("margin_top", 12)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margen)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.07, 0.094, 0.059, 0.72)   # verde_negro translúcido
	estilo.set_content_margin_all(10)
	estilo.set_corner_radius_all(2)
	estilo.border_color = Color(0.18, 0.306, 0.561, 0.5) # cobalto
	estilo.border_width_left = 2
	_panel.add_theme_stylebox_override("panel", estilo)
	margen.add_child(_panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(caja)

	_fps = Label.new()
	_fps.add_theme_font_size_override("font_size", 13)
	_fps.add_theme_color_override("font_color", Color(0.91, 0.784, 0.416)) # oro_palido
	caja.add_child(_fps)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.custom_minimum_size = Vector2(340, 0)
	_label.add_theme_font_size_override("normal_font_size", 13)
	_label.add_theme_color_override("default_color", Color(0.863, 0.827, 0.753)) # crema_medio
	caja.add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.DEBUG_TOGGLE):
		visible_panel = not visible_panel
		_panel.visible = visible_panel
		EventBus.debug_toggled.emit(visible_panel)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	if not visible_panel:
		return

	_fps.text = "%d fps   ·   %.1f ms" % [
		Engine.get_frames_per_second(),
		1000.0 / maxf(1.0, float(Engine.get_frames_per_second()))
	]

	var claves := _lineas.keys()
	claves.sort_custom(func(a, b): return int(_lineas[a]["orden"]) < int(_lineas[b]["orden"]))

	var salida := PackedStringArray()
	for clave in claves:
		var e: Dictionary = _lineas[clave]
		if _t - float(e["t"]) > CADUCIDAD:
			_lineas.erase(clave)
			continue
		salida.append("[color=#8E88A0]%s[/color]  %s" % [clave, e["texto"]])
	_label.text = "\n".join(salida)


## Publica o actualiza una línea. Se borra sola si dejas de llamarla.
func set_line(clave: String, texto: Variant) -> void:
	if not _lineas.has(clave):
		_lineas[clave] = {"orden": _orden_siguiente, "texto": "", "t": 0.0}
		_orden_siguiente += 1
	_lineas[clave]["texto"] = str(texto)
	_lineas[clave]["t"] = _t


## Separador visual entre bloques de líneas.
func set_header(texto: String) -> void:
	set_line("§" + texto, "[color=#2E4E8F]────────[/color]")


func clear() -> void:
	_lineas.clear()
