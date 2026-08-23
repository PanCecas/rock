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

var sol: DirectionalLight3D


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

	# --- Cielo: una lavada plana de crema, no un degradado de postal ---------
	var cielo_mat := ProceduralSkyMaterial.new()
	cielo_mat.sky_top_color = palette.crema_medio.lerp(palette.lavanda_gris, 0.35)
	cielo_mat.sky_horizon_color = palette.crema_bruma
	cielo_mat.sky_curve = 0.18
	cielo_mat.sky_energy_multiplier = 1.0
	cielo_mat.ground_bottom_color = palette.musgo_sombra
	cielo_mat.ground_horizon_color = palette.crema_bruma
	cielo_mat.ground_curve = 0.04
	cielo_mat.sun_angle_max = 25.0
	cielo_mat.sun_curve = 0.12

	var cielo := Sky.new()
	cielo.sky_material = cielo_mat
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
	env.fog_height = -12.0
	env.fog_height_density = 0.06

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
