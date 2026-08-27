extends Node
## Test del menu de controles.
##
##   godot --headless --path . tools/TestMenu.tscn
##
## Comprueba lo unico que puede romperse en silencio: que TODAS las acciones que
## el menu nombra existen de verdad en el mapa de entrada. Una accion renombrada
## deja una fila con un guion, y una lista de controles que miente es peor que no
## tener lista.

var _fallos: PackedStringArray = []


func _ready() -> void:
	var m: Node = get_node_or_null("/root/MenuControles")
	if m == null:
		print("RESULTADO MENU: 0/4 — el autoload MenuControles no existe.")
		get_tree().quit(1)
		return

	var total := 0
	var ok := 0

	# 1) Cada accion nombrada existe.
	total += 1
	var declaradas: PackedStringArray = m.acciones_declaradas()
	var ausentes: PackedStringArray = []
	for a in declaradas:
		if not InputMap.has_action(a):
			ausentes.append(a)
	if ausentes.is_empty():
		ok += 1
		print("  OK    las %d acciones del menu existen en el mapa" % declaradas.size())
	else:
		_fallos.append("acciones que el menu nombra y no existen: %s" % ", ".join(ausentes))

	# 2) Y el propio menu lo detecta por su cuenta.
	total += 1
	if not m.hay_fallos():
		ok += 1
		print("  OK    el menu no reporta fallos propios")
	else:
		_fallos.append("el menu reporta fallos internos")

	# 3) Cada accion tiene ALGO asignado. Una accion que existe pero esta vacia
	#    sale como "sin asignar" y es igual de inutil para el jugador.
	total += 1
	var vacias: PackedStringArray = []
	for a in declaradas:
		if InputMap.has_action(a) and InputMap.action_get_events(a).is_empty():
			vacias.append(a)
	if vacias.is_empty():
		ok += 1
		print("  OK    ninguna accion del menu esta sin asignar")
	else:
		_fallos.append("acciones sin ninguna tecla: %s" % ", ".join(vacias))

	# 4) Abrir el menu PAUSA. Un menu de controles que se lee mientras te caes no
	#    sirve para lo que se abre.
	total += 1
	m.alternar()
	var pauso: bool = get_tree().paused and m.abierto
	m.alternar()
	var reanudo: bool = not get_tree().paused and not m.abierto
	if pauso and reanudo:
		ok += 1
		print("  OK    abrir pausa y cerrar reanuda")
	else:
		_fallos.append("pausa: al abrir=%s al cerrar=%s" % [pauso, reanudo])

	print("RESULTADO MENU: %d/%d comprobaciones." % [ok, total])
	if not _fallos.is_empty():
		print("--- FALLOS ---")
		for f in _fallos:
			print("  " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)
