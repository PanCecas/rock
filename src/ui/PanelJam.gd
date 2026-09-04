class_name PanelJam
extends CanvasLayer
## LA HOJA DE NOTAS de la estacion de jam. La rejilla que se toca.
##
## Es la interfaz de la referencia, y se dibuja entera con `_draw()` en vez de
## montar 143 nodos `Button`: son celdas de dos formas, un fondo redondeado y un
## resalte, y eso es mas barato y mas exacto pintado a mano que peleado con
## `StyleBox`. Ademas el cabezal repinta cada paso, y repintar un `Control` es una
## llamada; mover el `modulate` de 128 botones son 128.
##
## DOS REJILLAS, y cada una hace una cosa distinta:
##
##   TECLADO (5x3)   -> suena AHORA. Es la audicion: pruebas una nota y ya. No
##                      escribe nada, asi que se puede trastear encima de lo que
##                      esta sonando sin romperlo.
##   HOJA (8 x 16)   -> se ESCRIBE. Una columna por musico y una fila por paso,
##                      asi que marcar una celda es decirle a ESE de los ocho que
##                      ataque en ESE momento. Es lo que pedia el encargo: que se
##                      interactue con los agentes, no con un instrumento abstracto.
##
## Y el cabezal no lo lleva un temporizador de la interfaz: lo lleva la fase media
## del enjambre (`EstacionJam._revisar_hoja()`). La rejilla solo PINTA por donde
## va. Un segundo reloj aqui se desincronizaria del corro en cuanto uno de los dos
## perdiera un frame.
##
## ROMBO O CIRCULO no es decoracion: el rombo marca las columnas cuyo musico cae
## en un grado PILAR de la pentatonica —la tonica o la quinta— y el circulo las
## demas. Sin eso son quince cuadrados iguales y no hay forma de orientarse en la
## rejilla; con eso, la vista encuentra sola donde estan los apoyos del acorde.

const PILARES := [0, 3]

var estacion: EstacionJam

var _palette: Palette
var _teclado: Rejilla
var _hoja: Rejilla
var _raiz: Control
var _titulo: Label


func _init(quien: EstacionJam) -> void:
	estacion = quien


func _ready() -> void:
	layer = 80
	# NO PAUSA EL ARBOL, y es lo contrario que `MenuControles`. Un menu de controles
	# se abre para PARARSE a leerlo; esto se abre para escuchar, y con el juego
	# congelado el corro dejaria de sonar justo cuando lo estas escribiendo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_palette = GameState.palette
	_construir()
	visible = false


func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	var caja := PanelContainer.new()
	caja.set_anchors_preset(Control.PRESET_CENTER)
	caja.custom_minimum_size = Vector2(720.0, 470.0)
	caja.position = Vector2(-360.0, -235.0)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(_palette.verde_negro, 0.88)
	fondo.set_corner_radius_all(18)
	fondo.set_content_margin_all(18)
	fondo.border_color = Color(_palette.piedra_sombra, 0.7)
	fondo.set_border_width_all(2)
	caja.add_theme_stylebox_override("panel", fondo)
	_raiz.add_child(caja)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	caja.add_child(col)

	var cabecera := HBoxContainer.new()
	col.add_child(cabecera)
	_titulo = Label.new()
	_titulo.text = "HOJA DE NOTAS"
	_titulo.add_theme_color_override("font_color", _palette.crema_bruma)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(_titulo)
	cabecera.add_child(_boton("BORRAR", borrar))
	cabecera.add_child(_boton("CERRAR  [E]", cerrar))

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 20)
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fila)

	# --- El teclado, a la izquierda ---
	var izq := VBoxContainer.new()
	izq.add_theme_constant_override("separation", 8)
	fila.add_child(izq)
	izq.add_child(_rotulo("TOCAR"))
	_teclado = Rejilla.new()
	_teclado.preparar(_palette, EstacionJam.TECLAS_COL, EstacionJam.TECLAS_FIL, 52.0, 8.0)
	_teclado.es_pilar = func(c: int, f: int) -> bool:
		return PILARES.has((f * EstacionJam.TECLAS_COL + c) % 5)
	_teclado.encendida = func(_c: int, _f: int) -> bool: return false
	_teclado.pulsada.connect(_tecla)
	izq.add_child(_teclado)
	izq.add_child(_rotulo("suena y no escribe"))

	# --- La hoja, a la derecha ---
	var der := VBoxContainer.new()
	der.add_theme_constant_override("separation", 8)
	fila.add_child(der)
	der.add_child(_rotulo("ESCRIBIR — una columna por musico"))
	var lienzo := ScrollContainer.new()
	lienzo.custom_minimum_size = Vector2(360.0, 330.0)
	lienzo.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	der.add_child(lienzo)
	_hoja = Rejilla.new()
	_hoja.preparar(_palette, estacion.asientos, estacion.pasos, 38.0, 6.0)
	_hoja.es_pilar = func(c: int, _f: int) -> bool:
		return PILARES.has(_grado_de_asiento(c))
	_hoja.encendida = func(c: int, f: int) -> bool: return estacion.celda(f, c)
	_hoja.cabezal = func() -> int: return estacion.paso_actual()
	_hoja.pulsada.connect(_celda)
	lienzo.add_child(_hoja)


## En que grado de la escala cae el musico `i`. Es lo que decide su forma, y sale
## del MISMO reparto que usa `EstacionJam.nota_de()`: si alguien cambia el
## registro, la rejilla cambia con el en vez de mentir.
func _grado_de_asiento(i: int) -> int:
	if estacion.asientos <= 1 or estacion.escala.is_empty():
		return 0
	var paso: int = int(roundf(
		float(estacion.registro_grados) * float(i) / float(estacion.asientos - 1)))
	return posmod(paso, estacion.escala.size())


func _rotulo(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(_palette.lavanda_gris, 0.75))
	return l


func _boton(texto: String, que: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.flat = true
	b.add_theme_color_override("font_color", _palette.crema_bruma)
	b.pressed.connect(que)
	return b


func _tecla(columna: int, fila: int) -> void:
	estacion.pulsar_tecla(fila * EstacionJam.TECLAS_COL + columna)


func _celda(columna: int, fila: int) -> void:
	estacion.alternar_celda(fila, columna)
	# Al encender una celda suena su musico: escribir sin oir lo que escribes es
	# componer a ciegas.
	if estacion.celda(fila, columna):
		estacion.tocar(columna)
	_hoja.queue_redraw()
	_refrescar_titulo()


func borrar() -> void:
	estacion.borrar_hoja()
	_hoja.queue_redraw()
	_refrescar_titulo()


func abrir() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refrescar_titulo()


func cerrar() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func alternar() -> void:
	if visible:
		cerrar()
	else:
		abrir()


func _refrescar_titulo() -> void:
	var n := estacion.notas_escritas()
	_titulo.text = ("HOJA DE NOTAS — vacia: los ocho improvisan" if n == 0
		else "HOJA DE NOTAS — %d notas escritas" % n)


func _process(_d: float) -> void:
	if visible:
		# El cabezal se mueve solo con el corro, asi que la rejilla se repinta
		# entera cada frame. Es UN `_draw()`, no 128 nodos moviendose.
		_hoja.queue_redraw()


## UNA REJILLA DE CELDAS, pintada a mano.
##
## Vive aqui dentro y no en su propio fichero porque no tiene vida fuera de este
## panel: es la forma de la interfaz, no un componente.
class Rejilla:
	extends Control

	signal pulsada(columna: int, fila: int)

	var columnas: int = 8
	var filas: int = 16
	var lado: float = 38.0
	var hueco: float = 6.0
	var es_pilar: Callable
	var encendida: Callable
	var cabezal: Callable

	var _paleta: Palette
	var _sobre := Vector2i(-1, -1)

	func preparar(p: Palette, cols: int, fils: int, tam: float, sep: float) -> void:
		_paleta = p
		columnas = cols
		filas = fils
		lado = tam
		hueco = sep
		custom_minimum_size = Vector2(
			float(columnas) * (lado + hueco) + hueco,
			float(filas) * (lado + hueco) + hueco)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _celda_en(punto: Vector2) -> Vector2i:
		var c := int((punto.x - hueco) / (lado + hueco))
		var f := int((punto.y - hueco) / (lado + hueco))
		if c < 0 or c >= columnas or f < 0 or f >= filas:
			return Vector2i(-1, -1)
		return Vector2i(c, f)

	func _gui_input(evento: InputEvent) -> void:
		if evento is InputEventMouseMotion:
			var nuevo := _celda_en((evento as InputEventMouseMotion).position)
			if nuevo != _sobre:
				_sobre = nuevo
				queue_redraw()
			return
		if evento is InputEventMouseButton:
			var mb := evento as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				var c := _celda_en(mb.position)
				if c.x >= 0:
					pulsada.emit(c.x, c.y)
					queue_redraw()

	func _draw() -> void:
		var paso := int(cabezal.call()) if cabezal.is_valid() else -1
		for f in filas:
			for c in columnas:
				var r := Rect2(
					hueco + float(c) * (lado + hueco),
					hueco + float(f) * (lado + hueco),
					lado, lado)
				var viva: bool = encendida.call(c, f) if encendida.is_valid() else false
				var en_cabezal: bool = (f == paso)

				# EL FONDO de la celda: apagada, en el cabezal, o encendida.
				var fondo := Color(_paleta.piedra_sombra, 0.22)
				if en_cabezal:
					fondo = Color(_paleta.lavanda_gris, 0.34)
				if viva:
					fondo = Color(_paleta.crema_bruma, 0.92)
				if _sobre == Vector2i(c, f):
					fondo = fondo.lightened(0.18)
				draw_rect(r.grow(-1.0), fondo, true)

				# LA FORMA: rombo en los grados pilares, circulo en los demas.
				var pilar: bool = es_pilar.call(c, f) if es_pilar.is_valid() else false
				var tinta := (Color(_paleta.verde_negro, 0.9) if viva
					else Color(_paleta.crema_bruma, 0.62))
				var centro := r.get_center()
				var radio := lado * 0.27
				if pilar:
					var rombo := PackedVector2Array([
						centro + Vector2(0.0, -radio), centro + Vector2(radio, 0.0),
						centro + Vector2(0.0, radio), centro + Vector2(-radio, 0.0),
						centro + Vector2(0.0, -radio)])
					draw_polyline(rombo, tinta, 2.0, true)
				else:
					draw_arc(centro, radio, 0.0, TAU, 24, tinta, 2.0, true)
