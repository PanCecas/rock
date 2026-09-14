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
var _cabecera: Rejilla
var _instrumentos: Rejilla
var _compas: Label
var _tono: Label
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

	# LOS DOS MANDOS. El compas es el unico numero de la estacion que se juzga a
	# oido, y el tono el unico que cambia como suena sin cambiar lo escrito: la
	# hoja dice QUIEN toca y CUANDO, no en que altura, asi que subir de tono no
	# estropea nada de lo que ya habias puesto.
	var mandos := HBoxContainer.new()
	mandos.add_theme_constant_override("separation", 6)
	col.add_child(mandos)
	mandos.add_child(_rotulo("COMPAS"))
	mandos.add_child(_boton("−", func() -> void: _mover_compas(0.15)))
	_compas = _rotulo("")
	mandos.add_child(_compas)
	mandos.add_child(_boton("+", func() -> void: _mover_compas(-0.15)))
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(28.0, 0.0)
	mandos.add_child(sep)
	mandos.add_child(_rotulo("TONO"))
	mandos.add_child(_boton("<", func() -> void: _mover_tono(-1)))
	_tono = _rotulo("")
	mandos.add_child(_tono)
	mandos.add_child(_boton(">", func() -> void: _mover_tono(1)))

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
	# EL NOMBRE DE LA NOTA EN CADA TECLA, en solfeo. Sin esto la rejilla es bonita
	# y muda: se pulsa a ciegas y no hay forma de volver a encontrar la nota que
	# gusto. Con los nombres, el teclado se puede leer.
	_teclado.etiqueta = func(c: int, f: int) -> String:
		return estacion.nombre_de_nota(
			estacion.nota_de_tecla(f * EstacionJam.TECLAS_COL + c))
	_teclado.pulsada.connect(_tecla)
	izq.add_child(_teclado)
	izq.add_child(_rotulo("suena y no escribe"))

	# --- La hoja, a la derecha ---
	var der := VBoxContainer.new()
	der.add_theme_constant_override("separation", 8)
	fila.add_child(der)
	der.add_child(_rotulo("ESCRIBIR — una columna por musico"))
	# QUE INSTRUMENTO ES CADA COLUMNA. Con tres timbres en el corro, saber que la
	# columna 3 es el viento es tan util como saber que nota da: se escribe distinto
	# para un pulso de guitarra que para una nota sostenida.
	_instrumentos = Rejilla.new()
	_instrumentos.preparar(_palette, estacion.asientos, 1, 38.0, 6.0)
	_instrumentos.solo_texto = true
	_instrumentos.etiqueta = func(c: int, _f: int) -> String:
		return estacion.nombre_de_familia(c)
	# Y SE PUEDE CAMBIAR: un clic en la cabecera pasa ese puesto al siguiente
	# instrumento. El reparto de fabrica alterna los tres, pero es un punto de
	# partida — media banda de vientos es una configuracion legitima, y decidirlo
	# es parte de tocar esto.
	_instrumentos.pulsada.connect(func(c: int, _f: int) -> void:
		estacion.ciclar_familia(c)
		_instrumentos.queue_redraw())
	der.add_child(_instrumentos)
	# CABECERA: la nota RAIZ de cada columna, que es la identidad del musico. La
	# nota que toca sube y baja con su ciclo; esta no cambia, y es la que permite
	# decir "la columna del SOL2".
	_cabecera = Rejilla.new()
	_cabecera.preparar(_palette, estacion.asientos, 1, 38.0, 6.0)
	_cabecera.solo_texto = true
	_cabecera.etiqueta = func(c: int, _f: int) -> String:
		return estacion.nombre_de_nota(estacion.nota_raiz_de(c))
	der.add_child(_cabecera)
	var lienzo := ScrollContainer.new()
	lienzo.custom_minimum_size = Vector2(360.0, 330.0)
	lienzo.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	der.add_child(lienzo)
	_hoja = Rejilla.new()
	_hoja.preparar(_palette, estacion.asientos, estacion.pasos, 38.0, 6.0)
	_hoja.es_pilar = func(c: int, _f: int) -> bool:
		return PILARES.has(estacion.grado_de(c))
	_hoja.encendida = func(c: int, f: int) -> bool: return estacion.celda(f, c)
	_hoja.cabezal = func() -> int: return estacion.paso_actual()
	_hoja.pulsada.connect(_celda)
	lienzo.add_child(_hoja)


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


## LOS SIETE NATURALES, en semitonos desde el DO. Solo los naturales y no los
## doce: lo que se pidio es "do re mi fa sol", y una lista de doce con sostenidos
## convierte un mando de dos clics en un menu.
const NATURALES := [0, 2, 4, 5, 7, 9, 11]


func _mover_compas(delta: float) -> void:
	estacion.cambiar_compas(estacion.compas_segundos + delta)
	_refrescar_mandos()


## Sube o baja al siguiente natural, conservando la octava.
func _mover_tono(pasos: int) -> void:
	var midi: int = int(roundf(69.0 + 12.0 * log(estacion.tonica / 440.0) / log(2.0)))
	var clase: int = posmod(midi, 12)
	var i := 0
	for k in NATURALES.size():
		if NATURALES[k] <= clase:
			i = k
	i = posmod(i + pasos, NATURALES.size())
	var octava: int = midi / 12
	# Al dar la vuelta por arriba se sube de octava, y al reves por abajo: si no,
	# pasar de SI a DO baja una octava entera y suena como un error.
	if pasos > 0 and NATURALES[i] < clase:
		octava += 1
	elif pasos < 0 and NATURALES[i] > clase:
		octava -= 1
	var nuevo: int = clampi(octava * 12 + NATURALES[i], 36, 84)
	estacion.tonica = 440.0 * pow(2.0, float(nuevo - 69) / 12.0)
	_refrescar_mandos()
	_teclado.queue_redraw()
	_cabecera.queue_redraw()


func _refrescar_mandos() -> void:
	_compas.text = "%.2f s" % estacion.compas_segundos
	_tono.text = estacion.nombre_de_nota(estacion.tonica)


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


## ABRIR NO PAUSA, PERO SI DESCONECTA AL JUGADOR.
##
## Son dos cosas distintas y hacen falta las dos separadas: el mundo tiene que
## seguir corriendo —la hoja se abre para ESCUCHAR el corro— pero el jugador no
## puede estar corriendo, saltando o atacando mientras escribe. `interfaz_modal`
## lo dice una vez y se enteran el `InputBuffer` y la camara.
func abrir() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.interfaz_modal.emit(true)
	_refrescar_titulo()
	_refrescar_mandos()


func cerrar() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.interfaz_modal.emit(false)


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
	var etiqueta: Callable
	## Solo el nombre, sin celda ni forma: es la cabecera de la hoja.
	var solo_texto: bool = false

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
				if solo_texto:
					_texto(r, c, f, Color(_paleta.lavanda_gris, 0.9), true)
					continue
				var pilar: bool = es_pilar.call(c, f) if es_pilar.is_valid() else false
				var tinta := (Color(_paleta.verde_negro, 0.9) if viva
					else Color(_paleta.crema_bruma, 0.62))
				var centro := r.get_center() - Vector2(0.0, lado * 0.10)
				var radio := lado * 0.24
				if pilar:
					var rombo := PackedVector2Array([
						centro + Vector2(0.0, -radio), centro + Vector2(radio, 0.0),
						centro + Vector2(0.0, radio), centro + Vector2(-radio, 0.0),
						centro + Vector2(0.0, -radio)])
					draw_polyline(rombo, tinta, 2.0, true)
				else:
					draw_arc(centro, radio, 0.0, TAU, 24, tinta, 2.0, true)
				_texto(r, c, f, tinta, false)

	## El nombre de la nota, centrado bajo la forma.
	func _texto(r: Rect2, c: int, f: int, tinta: Color, centrado: bool) -> void:
		if not etiqueta.is_valid():
			return
		var s: String = etiqueta.call(c, f)
		if s.is_empty():
			return
		var fuente := ThemeDB.fallback_font
		var tam := 11
		var ancho := fuente.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam).x
		var y: float = r.get_center().y + (4.0 if centrado else r.size.y * 0.40)
		draw_string(fuente, Vector2(r.get_center().x - ancho * 0.5, y),
			s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam, tinta)
