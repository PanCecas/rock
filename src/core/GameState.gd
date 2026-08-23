extends Node
## Autoload. Estado global y acceso a los Resources de configuración.
##
## La Palette y el PlayerTuning viven aquí para que cualquier sistema los lea sin
## tener que arrastrarlos por el árbol de escena, y para poder recargarlos en
## caliente mientras el juego corre (F5 recarga tuning, F6 recarga paleta).

const RUTA_PALETTE := "res://content/data/default_palette.tres"
const RUTA_TUNING := "res://content/data/default_tuning.tres"

var palette: Palette
var tuning: PlayerTuning

var player: Node3D = null
var en_pausa: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	recargar_palette()
	recargar_tuning()
	EventBus.player_spawned.connect(_on_player_spawned)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_F5:
			recargar_tuning()
		KEY_F6:
			recargar_palette()


## Recarga PlayerTuning desde disco, saltándose la caché. Con el juego corriendo.
func recargar_tuning() -> void:
	var res := ResourceLoader.load(RUTA_TUNING, "PlayerTuning", ResourceLoader.CACHE_MODE_IGNORE)
	if res is PlayerTuning:
		tuning = res
		EventBus.tuning_reloaded.emit()
	elif tuning == null:
		push_warning("No se encontró %s; usando valores por defecto." % RUTA_TUNING)
		tuning = PlayerTuning.new()


## Recarga la Palette desde disco. Los materiales que escuchan palette_changed se repintan.
func recargar_palette() -> void:
	var res := ResourceLoader.load(RUTA_PALETTE, "Palette", ResourceLoader.CACHE_MODE_IGNORE)
	if res is Palette:
		palette = res
		var fallos := palette.validar()
		for f in fallos:
			push_warning("Paleta: %s" % f)
		EventBus.palette_changed.emit(palette)
	elif palette == null:
		push_warning("No se encontró %s; usando valores por defecto." % RUTA_PALETTE)
		palette = Palette.new()


func set_pausa(valor: bool) -> void:
	en_pausa = valor
	get_tree().paused = valor


func _on_player_spawned(nodo: Node3D) -> void:
	player = nodo
