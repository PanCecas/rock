@tool
class_name WorldMood
extends WorldEnvironment
## Construye el Environment entero desde una Palette. Ningún color a mano.
##
## Es lo que hace que un Gym de cubos grises ya se parezca a la ilustración de
## referencia: niebla crema (nunca gris), perspectiva aérea alta para que el
## horizonte se disuelva, y sombras tintadas de lavanda en vez de oscurecidas.
## Ver docs/01_DIRECCION_ARTE.md §4.

@export var palette: Palette:
	set(v):
		palette = v
		_reconstruir()

## El sol de la escena. Se configura desde la misma paleta.
## NodePath y no Node: un export tipado se resuelve DESPUÉS de _ready y el sol
## se quedaba sin configurar, en blanco puro y con la energía por defecto.
@export var sol_path: NodePath = ^"../Sol":
	set(v):
		sol_path = v
		_reconstruir()

@export_group("Nubes")
## Cuanto cielo tapan. 0 despejado, 1 cubierto.
@export_range(0.0, 1.0, 0.01) var nubes_cobertura: float = 0.46:
	set(v):
		nubes_cobertura = v
		_reconstruir()
## ESCALONES del borde. 1 es una silueta de recorte; 4 casi un degradado. Es el
## mando que decide si el cielo parece pintado o renderizado.
@export_range(1, 8, 1) var nubes_bandas: int = 3:
	set(v):
		nubes_bandas = v
		_reconstruir()
## Tamano. Mas alto = nubes mas pequenas y mas numerosas.
@export_range(0.1, 12.0, 0.1) var nubes_escala: float = 1.9:
	set(v):
		nubes_escala = v
		_reconstruir()
## Deriva. Muy lenta a proposito: una nube que se ve moverse deja de ser fondo.
@export_range(0.0, 0.5, 0.001) var nubes_velocidad: float = 0.014:
	set(v):
		nubes_velocidad = v
		_reconstruir()

var sol: DirectionalLight3D
var _cielo_mat: ShaderMaterial


## Congela las nubes en una fase fija, o las suelta con un valor negativo.
##
## Mismo gancho que `ZonaAgua.congelar_olas()` y `Cordon.asentar()`, y por la misma
## razon: una superficie animada nunca es una referencia estable si cada pasada la
## fotografia en otro momento.
func congelar_nubes(t: float) -> void:
	if _cielo_mat != null:
		_cielo_mat.set_shader_parameter(&"tiempo_fijo", t)


func _ready() -> void:
	if not Engine.is_editor_hint():
		if palette == null and GameState.palette != null:
			palette = GameState.palette
		EventBus.palette_changed.connect(func(p: Palette) -> void: palette = p)
	_reconstruir()


func _reconstruir() -> void:
	if palette == null:
		return

	var env := Environment.new()

	# --- Cielo: nubes pintadas, no un degradado de postal --------------------
	#
	# `ProceduralSkyMaterial` solo sabe hacer un degradado: correcto y vacio. Las
	# nubes son parte del cielo y se mueven solas, y salen EN BANDAS por la misma
	# razon que todo lo demas —§1 del doc de shaders—: un cielo suave debajo de un
	# mundo cuantizado se lee como dos juegos pegados.
	var cielo_mat := ShaderMaterial.new()
	cielo_mat.shader = load("res://src/art/shaders/cielo.gdshader")
	# UNA NUBE BLANCA SOBRE UN CIELO CREMA ES UNA NUBE INVISIBLE, y es la tercera
	# vez que este proyecto tropieza con lo mismo: `blanco_tiza` (#F2F0E6) contra
	# `crema_bruma` (#EFE8D8) es el mismo color, igual que le pasaba a la bandada.
	# El cenit tira a lavanda para que la nube tenga contra que recortarse; el
	# horizonte se queda en crema, que es donde la niebla lo va a fundir de todas
	# formas.
	cielo_mat.set_shader_parameter(
		&"color_cenit", palette.lavanda_profundo.lerp(palette.lavanda_gris, 0.28))
	cielo_mat.set_shader_parameter(&"color_horizonte", palette.crema_bruma)
	cielo_mat.set_shader_parameter(&"color_nube", palette.blanco_tiza)
	cielo_mat.set_shader_parameter(
		&"color_nube_sombra", palette.lavanda_gris.lerp(palette.lavanda_profundo, 0.5))
	cielo_mat.set_shader_parameter(&"color_sol", palette.luz_solar)
	cielo_mat.set_shader_parameter(&"cobertura", nubes_cobertura)
	cielo_mat.set_shader_parameter(&"bandas", float(nubes_bandas))
	cielo_mat.set_shader_parameter(&"escala", nubes_escala)
	cielo_mat.set_shader_parameter(&"velocidad", nubes_velocidad)

	var cielo := Sky.new()
	cielo.sky_material = cielo_mat
	_cielo_mat = cielo_mat
	env.background_mode = Environment.BG_SKY
	env.sky = cielo

	# --- Ambiente: la luz rebotada es fría y lavanda -------------------------
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = palette.luz_ambiente.lerp(palette.lavanda_gris, 0.4)
	env.ambient_light_sky_contribution = 0.75
	env.ambient_light_energy = palette.energia_ambiente

	# --- Niebla: EL efecto. Perspectiva aérea extrema ------------------------
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = palette.crema_bruma
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.12
	env.fog_density = palette.densidad_niebla
	env.fog_aerial_perspective = palette.perspectiva_aerea
	env.fog_sky_affect = palette.niebla_afecta_cielo
	# La niebla de altura se hundía sobre el circuito, que baja hasta y=-12.
	env.fog_height = -45.0
	env.fog_height_density = 0.02

	# --- Tonemap: ligeramente sobreexpuesto, blancos lavados -----------------
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 3.2

	# --- Glow: halo ancho y suave, nunca bloom de anime ----------------------
	env.glow_enabled = true
	env.glow_intensity = 0.42
	env.glow_strength = 1.0
	env.glow_bloom = 0.06
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.05
	env.set("glow_levels/3", 0.6)
	env.set("glow_levels/5", 0.9)
	env.set("glow_levels/7", 0.5)

	# --- Oclusión: sutil, y tintada al mezclarse con el ambiente lavanda -----
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.1
	env.ssao_power = 1.4
	env.ssil_enabled = false

	# --- Ajuste final: bajar la saturación global refuerza el 60/30/10 ------
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.02
	env.adjustment_saturation = 0.92

	environment = env
	_configurar_sol()


func _configurar_sol() -> void:
	if palette == null or not is_inside_tree():
		return
	sol = get_node_or_null(sol_path) as DirectionalLight3D
	if sol == null:
		return
	sol.light_color = palette.luz_solar
	sol.light_energy = palette.energia_solar
	sol.light_angular_distance = 1.2          # sombras de borde suave
	sol.shadow_enabled = true
	sol.shadow_bias = 0.04
	sol.shadow_normal_bias = 1.4
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sol.directional_shadow_max_distance = 220.0
	sol.directional_shadow_blend_splits = true
	# Sombra tintada, no oscurecida: es la regla §2.4 del doc de arte.
	sol.shadow_opacity = 0.86
	sol.rotation_degrees = Vector3(palette.elevacion_solar, palette.azimut_solar, 0.0)
