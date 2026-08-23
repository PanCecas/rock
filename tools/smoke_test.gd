extends SceneTree

var _main: Node
var _frames := 0
var _pos_inicial := Vector3.ZERO

func _initialize() -> void:
	_main = load("res://content/levels/Main.tscn").instantiate()
	root.add_child(_main)
	print("Autoloads: EventBus=%s GameState=%s Hitstop=%s Debug=%s" % [
		root.has_node("EventBus"), root.has_node("GameState"),
		root.has_node("HitstopManager"), root.has_node("DebugOverlay")])
	print("Acciones en el input map: %d" % InputMap.get_actions().size())

func _physics_process(_d: float) -> bool:
	_frames += 1
	if _frames < 90:
		return false
	var p := _main.get_node("Player") as CharacterBody3D
	var gym := _main.get_node("Gym")
	var cuerpos := gym.get_node("Geometria").get_children().filter(func(n): return n is StaticBody3D)
	var env: Environment = (_main.get_node("WorldMood") as WorldEnvironment).environment
	print("Gym: %d cuerpos estáticos generados" % cuerpos.size())
	print("Niebla: activa=%s color=%s aerial=%.2f" % [env.fog_enabled, env.fog_light_color.to_html(false), env.fog_aerial_perspective])
	print("Sol: %s energía=%.2f" % [(_main.get_node("Sol") as DirectionalLight3D).light_color.to_html(false), (_main.get_node("Sol") as DirectionalLight3D).light_energy])
	print("Jugador: y=%.2f  en_suelo=%s" % [p.global_position.y, p.is_on_floor()])
	print("Tuning: salto %.1fm -> v=%.2f m/s | dash %.1fm en %.2fs -> v=%.1f m/s" % [
		_gs().tuning.altura_salto, _gs().tuning.velocidad_salto(),
		_gs().tuning.dash_distancia, _gs().tuning.dash_duracion, _gs().tuning.velocidad_dash()])
	print("Paleta: %d infracciones" % _gs().palette.validar().size())
	quit()
	return true

func _gs() -> Node:
	return root.get_node("GameState")
