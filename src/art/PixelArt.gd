@tool
class_name PixelArt
extends Node
## EL FILTRO DE PIXEL: renderiza el juego a baja resolucion y lo amplia sin
## suavizar.
##
## **Esto es TODO lo que significa "3D pixel art".** No hay un shader de
## pixelado: lo que hacen los juegos de esa familia es rendear el mundo 3D a una
## resolucion pequena y estirarlo con vecino mas cercano. El resto —las bandas
## duras de color, las siluetas limpias— es direccion de arte que ya se pone en
## los materiales; el filtro solo la revela.
##
## Se hace con `content_scale` de la `Window` y no con un `SubViewport`:
##
##   · un `SubViewport` obliga a colgar la escena entera de el, y aqui eso
##     significaria reestructurar `Main.tscn` y romper la camara y los tests;
##   · `content_scale` lo hace el motor, cuesta cero, y se apaga y enciende en
##     caliente, que es justo lo que hace falta para juzgarlo.
##
## `CONTENT_SCALE_STRETCH_INTEGER` es obligatorio y no un detalle: con escalado
## FRACCIONARIO un pixel del render ocupa 3.7 pixeles de pantalla, asi que unos
## salen de 3 y otros de 4 y la imagen entera hierve al mover la camara. Con
## entero todos miden lo mismo.
##
## Y APAGA EL ANTIALIASING, porque las dos cosas se pelean por definicion: MSAA y
## FXAA existen para suavizar el borde de escalera, y el borde de escalera es
## exactamente lo que se busca.

## Encendido o apagado. **Apagado por defecto a proposito**: es un cambio de
## direccion de arte de todo el juego —contradice `docs/01_DIRECCION_ARTE.md`, que
## pide un look de ilustracion pintada— y ademas reescribe las 14 referencias del
## screenshot test de una vez. Esa decision es del proyecto, no de este nodo.
@export var activo: bool = false:
	set(v):
		activo = v
		_aplicar()
## Altura interna del render, en pixeles. El ancho sale del aspecto de la ventana.
##
##   270  -> pixel grueso, estilo consola de 16 bits
##   360  -> el equilibrio: se lee el pixel y se distingue una silueta a 30 m
##   540  -> apenas se nota; sirve para comparar
@export_range(90, 1080, 10) var alto_interno: int = 360:
	set(v):
		alto_interno = v
		_aplicar()

## Lo que habia antes, para poder volver. Sin esto, apagar el filtro dejaria la
## ventana en el ultimo estado que le pusimos en vez de en el suyo.
var _antes: Dictionary = {}


func _ready() -> void:
	_aplicar()


## F8 LO ENCIENDE Y LO APAGA EN CALIENTE.
##
## Es la unica forma de juzgarlo: un filtro de pixel no se decide mirando dos
## capturas, se decide alternando mientras te mueves. Vive con las demas teclas de
## debug —F3 panel, F5 tuning, F6 paleta, F7 gizmos— y como ellas no existe fuera
## del editor de este proyecto.
func _unhandled_input(evento: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if evento is InputEventKey and evento.is_pressed() and not evento.is_echo():
		if (evento as InputEventKey).keycode == KEY_F8:
			activo = not activo
			DebugOverlay.set_line("pixel art",
				"%s  %s" % ["ON" if activo else "off", str(resolucion())])


func _aplicar() -> void:
	if not is_inside_tree():
		return
	var w := get_window()
	if w == null:
		return
	# APAGADO Y NUNCA ENCENDIDO = NO SE TOCA NADA.
	#
	# La primera version reescribia la ventana con los valores que acababa de leer
	# —lo mismo por lo mismo, aparentemente inofensivo— y **puso intermitente a
	# `TestLanza`**: 2 de cada 5 pasadas fallaban la pertiga, y solo aparecia con
	# este nodo en la escena. Escribir `content_scale_*` fuerza una reconfiguracion
	# del viewport aunque el valor no cambie, y eso basta para mover el primer
	# frame lo suficiente como para que un salto medido contra reloj no llegue.
	#
	# La leccion es mas general que este nodo: **un componente apagado tiene que
	# ser inerte de verdad**, no escribir el estado que ya habia. "Escribo lo
	# mismo" y "no escribo" no son la misma cosa cuando lo que escribes tiene
	# efectos secundarios.
	if not activo and _antes.is_empty():
		return

	if _antes.is_empty():
		_antes = {
			"modo": w.content_scale_mode,
			"aspecto": w.content_scale_aspect,
			"estirado": w.content_scale_stretch,
			"tam": w.content_scale_size,
			"msaa": get_viewport().msaa_3d,
			"fxaa": get_viewport().screen_space_aa,
		}

	if not activo:
		w.content_scale_mode = _antes["modo"]
		w.content_scale_aspect = _antes["aspecto"]
		w.content_scale_stretch = _antes["estirado"]
		w.content_scale_size = _antes["tam"]
		get_viewport().msaa_3d = _antes["msaa"]
		get_viewport().screen_space_aa = _antes["fxaa"]
		return

	var aspecto: float = 16.0 / 9.0
	var tam := w.get_size()
	if tam.y > 0:
		aspecto = float(tam.x) / float(tam.y)
	w.content_scale_size = Vector2i(int(round(float(alto_interno) * aspecto)), alto_interno)
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	w.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED


## La resolucion a la que se esta rendeando de verdad. Para el HUD de debug: es el
## unico numero que dice si el filtro esta puesto.
func resolucion() -> Vector2i:
	if not activo or not is_inside_tree():
		return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2i.ZERO
	return get_window().content_scale_size
