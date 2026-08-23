extends Node
## Autoload. Señales globales del juego.
##
## Solo eventos que cruzan sistemas. Si dos nodos están en la misma escena y se
## conocen, que se conecten directo: el EventBus no es un vertedero.

# --- Jugador ----------------------------------------------------------------
signal player_spawned(player: Node3D)
signal player_state_changed(anterior: StringName, nuevo: StringName)
signal player_landed(velocidad_impacto: float, dura: bool)
signal player_jumped(numero_salto: int)
signal player_dashed(direccion: Vector3)
signal player_glide_toggled(activo: bool)
signal player_died(causa: StringName)
signal stamina_changed(actual: float, maxima: float)

# --- Superficie (la base de los colosos) ------------------------------------
signal surface_frame_changed(frame: Node3D)

# --- Combate ----------------------------------------------------------------
signal hit_landed(atacante: Node, receptor: Node, dano: float)
signal parry_success(perfecto: bool)
signal guard_broken(quien: Node)
signal hitstop_requested(duracion: float)

# --- Lanza y lazo -----------------------------------------------------------
signal spear_state_changed(estado: StringName)
signal spear_embedded(posicion: Vector3, frame: Node3D)
signal spear_recalled()
signal rope_attached(ancla: Node3D, modo: StringName)
signal rope_released()

# --- Coloso -----------------------------------------------------------------
signal colossus_awakened(coloso: Node3D)
signal colossus_phase_changed(coloso: Node3D, fase: StringName)
signal colossus_shake(intensidad: float, duracion: float)
signal weakpoint_hit(coloso: Node3D, punto: Node3D, restante: float)
signal colossus_died(coloso: Node3D)

# --- Sistema ----------------------------------------------------------------
## Pide a la camara ponerse detras de una direccion. fuerza 0..1.
signal camara_realinear(direccion: Vector3, fuerza: float)

signal palette_changed(palette: Palette)
signal tuning_reloaded()
signal debug_toggled(visible: bool)
