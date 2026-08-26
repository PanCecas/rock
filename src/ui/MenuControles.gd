extends CanvasLayer
## MENÚ DE CONTROLES. **Escape** lo abre y lo cierra; F1 hace lo mismo.
##
## Es la primera UI del proyecto (`src/ui/` estaba vacío), así que fija dos
## costumbres para las que vengan detrás:
##
## 1. **Se construye por código**, como el `DebugOverlay`. Nada de una escena que
##    haya que abrir en el editor para cambiarle una etiqueta.
## 2. **Los colores salen de la `Palette`**, nunca un hex a mano (regla dura #9).
##
## Y una decisión de fondo que es LA razón de que este archivo exista tal como es:
##
##   **Las teclas NO están escritas aquí. Se leen del InputMap.**
##
## Una lista de controles escrita a mano es una mentira esperando a ocurrir. La
## tabla de `CLAUDE.md` ya se desincronizó una vez —siguió anunciando la embestida
## en primera persona semanas después de que se retirara del código—, y una tabla
## en un documento que nadie ejecuta puede permitírselo. Un menú dentro del juego
## no: si dice "Espacio" y el salto está en otra tecla, el jugador prueba, no
## funciona, y concluye que el juego está roto.
##
## Aquí cada fila nombra ACCIONES, y el glifo lo pinta `_glifos()` preguntándole
## al InputMap qué tiene asignado ahora mismo. Cambiar un binding en
## `project.godot` cambia el menú sin tocar este archivo. Y si alguien renombra
## una acción, `_validar()` lo canta en rojo dentro del propio menú en vez de
## dejar una fila vacía que nadie mira.

## Acción que abre y cierra. Se declara aquí y se comprueba en `_validar()`.
##
## Hoy es **Escape**, con F1 de alias. Escape es la tecla que todo el mundo
## prueba primero, y mientras no haya nada más que abrir es suya.
##
## AVISO PARA CUANDO LO HAYA: en cuanto exista un menú de pausa de verdad
## —o un inventario— Escape va a estar disputado, y estos controles deberían
## dejar de ser una pantalla suelta para pasar a ser una PÁGINA dentro de él.
## No es un cambio grande si se hace entonces; sí lo es si para entonces hay
## tres pantallas peleándose por la misma tecla.
const ACCION_MENU := &"menu_controles"

var abierto: bool = false

var _raiz: Control
var _palette: Palette
var _fallos: PackedStringArray = []


func _ready() -> void:
	# ALWAYS porque el menú pausa el árbol: si se procesara como todo lo demás,
	# se congelaría a sí mismo y no habría forma de cerrarlo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_palette = GameState.palette
	_construir()
	visible = false


func _unhandled_input(evento: InputEvent) -> void:
	# Un solo camino. Escape estaba ademas cableado a mano aqui para cerrar,
	# porque la accion era solo F1; ahora Escape ES la accion y esa rama sobraba.
	# Dos caminos para el mismo gesto es como se llega a que uno de los dos se
	# quede sin actualizar.
	if InputMap.has_action(ACCION_MENU) and evento.is_action_pressed(ACCION_MENU):
		alternar()
		get_viewport().set_input_as_handled()


func alternar() -> void:
	abierto = not abierto
	visible = abierto
	# Pausa de verdad. Un menú de controles que se lee mientras te caes por un
	# barranco no sirve para lo que se abre: para PARARSE a mirarlo.
	GameState.set_pausa(abierto)
	# Soltar el ratón, o no se puede ni leer.
	Input.mouse_mode = (Input.MOUSE_MODE_VISIBLE if abierto
		else Input.MOUSE_MODE_CAPTURED)


# --- Contenido ----------------------------------------------------------------

## Las secciones siguen los mismos grupos que `InputActions` declara —Movimiento,
## Traversal, Combate, Sistema— y no un orden inventado: si el código agrupa así,
## el menú agrupa así, y añadir una acción tiene un sitio obvio donde ponerse.
##
## `cuando` es la mitad que el InputMap NO puede saber. Media docena de verbos de
## este juego no son un binding sino un GESTO —la misma tecla significa cosas
## distintas según lo que estés haciendo—, y eso hay que decirlo con palabras.
func _secciones() -> Array:
	return [
		{"titulo": "MOVERSE", "filas": [
			{"nombre": "Caminar · trotar · correr", "acciones": [InputActions.MOVE_FORWARD],
				"cuando": "la velocidad sube sola manteniendo la dirección"},
			{"nombre": "Dash / esquiva", "acciones": [InputActions.DASH],
				"cuando": "un toque esquiva; mantenido, surfea"},
			{"nombre": "Surf", "acciones": [InputActions.DASH],
				"cuando": "mantener — no caduca, lo limita la stamina"},
			{"nombre": "Agacharse / deslizarse", "acciones": [InputActions.CROUCH]},
			{"nombre": "Fijar objetivo", "acciones": [InputActions.LOCK_ON]},
			{"nombre": "Apuntar", "acciones": [InputActions.AIM]},
		]},

		{"titulo": "SALTAR Y TREPAR", "filas": [
			{"nombre": "Saltar · doble salto", "acciones": [InputActions.JUMP]},
			{"nombre": "Planear", "acciones": [InputActions.GLIDE], "cuando": "mantener"},
			{"nombre": "Agarrarse / escalar", "acciones": [InputActions.GRAB],
				"cuando": "o insiste contra el muro y se agarra solo"},
			{"nombre": "Impulso de escalada", "acciones": [InputActions.DASH],
				"cuando": "escalando — cuesta stamina de golpe"},
			{"nombre": "Salto fuerte", "acciones": [InputActions.CROUCH, InputActions.JUMP], "cuando": "quieto"},
			{"nombre": "Long jump", "acciones": [InputActions.DASH, InputActions.CROUCH, InputActions.JUMP]},
			{"nombre": "Side jump", "acciones": [InputActions.JUMP],
				"cuando": "corriendo, girar en seco y saltar"},
			{"nombre": "Wall jump", "acciones": [InputActions.JUMP], "cuando": "junto a una pared"},
			{"nombre": "Subir desde un canto", "acciones": [InputActions.MOVE_FORWARD], "cuando": "colgado"},
		]},

		{"titulo": "PELEAR", "filas": [
			{"nombre": "Ataque ligero · cadena", "acciones": [InputActions.ATTACK_LIGHT]},
			{"nombre": "Ataque pesado", "acciones": [InputActions.ATTACK_HEAVY]},
			{"nombre": "Parry", "acciones": [InputActions.PARRY],
				"cuando": "justo antes del golpe es parry perfecto"},
			{"nombre": "Estocada de dash", "acciones": [InputActions.ATTACK_LIGHT], "cuando": "durante el dash"},
			{"nombre": "Estocada de surf", "acciones": [InputActions.DASH, InputActions.ATTACK_LIGHT]},
			{"nombre": "Frenazo de surf", "acciones": [InputActions.DASH, InputActions.ATTACK_HEAVY]},
			{"nombre": "Patada baja — derriba", "acciones": [InputActions.CROUCH, InputActions.ATTACK_LIGHT]},
			{"nombre": "Slide kick", "acciones": [InputActions.CROUCH, InputActions.ATTACK_LIGHT], "cuando": "con velocidad"},
		]},

		{"titulo": "EN EL AIRE", "filas": [
			{"nombre": "Clavado ligero — REBOTA en cabezas", "acciones": [InputActions.ATTACK_LIGHT],
				"cuando": "rebotar NO devuelve el doble salto"},
			{"nombre": "Clavado pesado — LEVANTA al enemigo", "acciones": [InputActions.ATTACK_HEAVY],
				"cuando": "no rebota: se planta"},
			{"nombre": "Picado vertical", "acciones": [InputActions.CROUCH, InputActions.ATTACK_HEAVY],
				"cuando": "área y daño crecen con la altura de caída"},
		]},

		{"titulo": "EN EL AGUA", "filas": [
			{"nombre": "Bucear", "acciones": [InputActions.CROUCH]},
			{"nombre": "Subir", "acciones": [InputActions.JUMP], "cuando": "mantener"},
			{"nombre": "Nadar rápido", "acciones": [InputActions.DASH]},
			{"nombre": "Ataque acuático", "acciones": [InputActions.ATTACK_LIGHT],
				"cuando": "bajo el agua un golpe es un impulso"},
		]},

		{"titulo": "DEPURACIÓN", "filas": [
			{"nombre": "Panel de debug", "acciones": [InputActions.DEBUG_TOGGLE]},
			{"nombre": "Respawnear la arena", "acciones": [InputActions.DEBUG_RESET]},
			{"nombre": "Este menú", "acciones": [ACCION_MENU]},
		]},
	]


# --- Construcción -------------------------------------------------------------

func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_raiz)

	var velo := ColorRect.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.color = Color(_color(&"verde_negro"), 0.88)
	_raiz.add_child(velo)

	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 28)
	_raiz.add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 14)
	margen.add_child(columna)

	columna.add_child(_titulo())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columna.add_child(scroll)

	# Dos columnas de secciones. Con una sola, la lista no cabe en pantalla y hay
	# que hacer scroll para ver los controles de combate, que son los que más se
	# consultan.
	var rejilla := HBoxContainer.new()
	rejilla.add_theme_constant_override("separation", 40)
	rejilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rejilla)

	var izq := VBoxContainer.new()
	izq.add_theme_constant_override("separation", 20)
	izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var der := VBoxContainer.new()
	der.add_theme_constant_override("separation", 20)
	der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rejilla.add_child(izq)
	rejilla.add_child(der)

	# El reparto va por FILAS y no por numero de secciones: las secciones no miden
	# lo mismo —"saltar y trepar" tiene nueve controles y "en el aire" tres— y
	# partirlas por la mitad dejaba la columna izquierda al doble de larga, con las
	# ultimas filas fuera de pantalla.
	var secciones := _secciones()
	var total := 0
	for s in secciones:
		total += (s["filas"] as Array).size()

	# Se decide por el PUNTO MEDIO de la seccion, no por donde empieza: mirando
	# solo el principio, una seccion de ocho filas que arranca justo antes de la
	# mitad se iba entera a la izquierda y la dejaba al doble de larga.
	var puestas := 0
	for s in secciones:
		var n: int = (s["filas"] as Array).size()
		var destino := izq if (puestas * 2 + n) <= total else der
		destino.add_child(_seccion(s))
		puestas += n

	_validar()
	columna.add_child(_pie())


func _titulo() -> Control:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)

	var t := Label.new()
	t.text = "CONTROLES"
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", _color(&"crema_bruma"))
	caja.add_child(t)

	var sub := Label.new()
	sub.text = "Las teclas se leen del mapa de entrada, así que esto no puede mentir."
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", _color(&"piedra_media"))
	caja.add_child(sub)

	return caja


func _seccion(datos: Dictionary) -> Control:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 5)

	var t := Label.new()
	t.text = String(datos["titulo"])
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", _color(&"oro_palido"))
	caja.add_child(t)

	var linea := ColorRect.new()
	linea.color = Color(_color(&"oro_palido"), 0.35)
	linea.custom_minimum_size = Vector2(0, 1)
	caja.add_child(linea)

	for fila in datos["filas"]:
		caja.add_child(_fila(fila))

	return caja


func _fila(datos: Dictionary) -> Control:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 0)

	var linea := HBoxContainer.new()
	linea.add_theme_constant_override("separation", 10)
	caja.add_child(linea)

	var nombre := Label.new()
	nombre.text = String(datos["nombre"])
	nombre.add_theme_font_size_override("font_size", 13)
	nombre.add_theme_color_override("font_color", _color(&"crema_medio"))
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linea.add_child(nombre)

	var teclas := Label.new()
	teclas.text = _glifos(datos["acciones"])
	teclas.add_theme_font_size_override("font_size", 13)
	teclas.add_theme_color_override("font_color", _color(&"blanco_tiza"))
	teclas.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	linea.add_child(teclas)

	if datos.has("cuando"):
		var nota := Label.new()
		nota.text = String(datos["cuando"])
		nota.add_theme_font_size_override("font_size", 11)
		nota.add_theme_color_override("font_color", _color(&"lavanda_gris"))
		caja.add_child(nota)

	return caja


func _pie() -> Control:
	var t := Label.new()
	if _fallos.is_empty():
		t.text = "Cerrar: la misma tecla, o Escape."
		t.add_theme_color_override("font_color", _color(&"piedra_media"))
	else:
		# Ruidoso a propósito. Una acción que se renombra y deja una fila muda es
		# justo el fallo que este menú existe para no tener.
		t.text = "ACCIONES QUE NO EXISTEN EN EL MAPA DE ENTRADA: %s" % ", ".join(_fallos)
		t.add_theme_color_override("font_color", _color(&"carmesi"))
	t.add_theme_font_size_override("font_size", 11)
	return t


# --- Lectura del InputMap -----------------------------------------------------

## El glifo de una o varias acciones, tal y como estén asignadas AHORA.
func _glifos(acciones: Array) -> String:
	var partes: PackedStringArray = []
	for a in acciones:
		var g := _glifo(a as StringName)
		if not g.is_empty():
			partes.append(g)
	return "  +  ".join(partes)


func _glifo(accion: StringName) -> String:
	if not InputMap.has_action(accion):
		return "—"
	var teclado := ""
	var mando := ""
	for e in InputMap.action_get_events(accion):
		if teclado.is_empty():
			if e is InputEventKey:
				teclado = _nombre_tecla(e as InputEventKey)
			elif e is InputEventMouseButton:
				teclado = _nombre_raton(e as InputEventMouseButton)
		if mando.is_empty():
			if e is InputEventJoypadButton:
				mando = _nombre_mando(e as InputEventJoypadButton)
			elif e is InputEventJoypadMotion:
				# Los GATILLOS son ejes, no botones. Sin esta rama, el pesado y el
				# parry salian sin boton de mando —parecia que no estaban
				# asignados— cuando lo que pasaba es que este menu no sabia leer un
				# eje. Lo canto el propio menu la primera vez que se abrio.
				mando = _nombre_eje(e as InputEventJoypadMotion)
	if teclado.is_empty() and mando.is_empty():
		return "sin asignar"
	if mando.is_empty():
		return teclado
	if teclado.is_empty():
		return mando
	return "%s / %s" % [teclado, mando]


func _nombre_tecla(e: InputEventKey) -> String:
	var codigo := e.physical_keycode if e.physical_keycode != 0 else e.keycode
	var texto := OS.get_keycode_string(codigo)
	# Los nombres que Godot devuelve en inglés y que aquí se leen raro.
	match texto:
		"Space": return "Espacio"
		"Shift": return "Shift"
		"Ctrl": return "Ctrl"
		"Escape": return "Esc"
		"Left": return "←"
		"Right": return "→"
		"Up": return "↑"
		"Down": return "↓"
	return texto


func _nombre_raton(e: InputEventMouseButton) -> String:
	match e.button_index:
		MOUSE_BUTTON_LEFT: return "Clic izq."
		MOUSE_BUTTON_RIGHT: return "Clic der."
		MOUSE_BUTTON_MIDDLE: return "Rueda"
		MOUSE_BUTTON_WHEEL_UP: return "Rueda ↑"
		MOUSE_BUTTON_WHEEL_DOWN: return "Rueda ↓"
		MOUSE_BUTTON_XBUTTON1: return "Ratón 4"
		MOUSE_BUTTON_XBUTTON2: return "Ratón 5"
	return "Ratón %d" % e.button_index


func _nombre_eje(e: InputEventJoypadMotion) -> String:
	match e.axis:
		JOY_AXIS_TRIGGER_LEFT: return "LT"
		JOY_AXIS_TRIGGER_RIGHT: return "RT"
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y: return "Stick izq."
		JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y: return "Stick der."
	return "Eje %d" % e.axis


func _nombre_mando(e: InputEventJoypadButton) -> String:
	match e.button_index:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_BACK: return "Back"
		JOY_BUTTON_DPAD_UP: return "D-pad ↑"
		JOY_BUTTON_DPAD_DOWN: return "D-pad ↓"
		JOY_BUTTON_DPAD_LEFT: return "D-pad ←"
		JOY_BUTTON_DPAD_RIGHT: return "D-pad →"
	return "Botón %d" % e.button_index


## Comprueba que TODAS las acciones nombradas existen de verdad. Sin esto,
## renombrar una acción deja una fila con un guión y nadie se entera.
func _validar() -> void:
	_fallos.clear()
	for seccion in _secciones():
		for fila in seccion["filas"]:
			for a in fila["acciones"]:
				var nombre := String(a)
				if not InputMap.has_action(a) and not _fallos.has(nombre):
					_fallos.append(nombre)
	if not _fallos.is_empty():
		push_error("MenuControles: acciones inexistentes -> %s" % ", ".join(_fallos))


## Lista de acciones que el menú declara. La usa el test.
func acciones_declaradas() -> PackedStringArray:
	var todas: PackedStringArray = []
	for seccion in _secciones():
		for fila in seccion["filas"]:
			for a in fila["acciones"]:
				if not todas.has(String(a)):
					todas.append(String(a))
	return todas


func hay_fallos() -> bool:
	return not _fallos.is_empty()


func _color(nombre: StringName) -> Color:
	if _palette == null:
		_palette = GameState.palette
	if _palette == null:
		return Color.WHITE
	var v: Variant = _palette.get(nombre)
	return v if v is Color else Color.WHITE
