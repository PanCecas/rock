@tool
class_name PlayerTuning
extends Resource
## Todos los números del jugador. REGLA DURA (CLAUDE.md #1): si se toca para que
## "se sienta bien", vive aquí y no en un .gd.
##
## Valores iniciales de docs/03_ARQUITECTURA_MECANICAS.md §2.1.
## Se edita con el juego corriendo: el controlador relee el Resource cada frame.

# --- Salto ------------------------------------------------------------------
@export_group("Salto")
## Altura en METROS, no en fuerza. La velocidad se deriva de la gravedad de subida.
@export_range(0.5, 6.0, 0.05) var altura_salto: float = 2.2
## Gravedad asimétrica: subir flotante, caer contundente. Es medio game feel gratis.
@export_range(-60.0, -5.0, 0.5) var gravedad_subida: float = -22.0
@export_range(-90.0, -5.0, 0.5) var gravedad_caida: float = -38.0
## Multiplicador a la velocidad Y al soltar el botón durante la subida.
@export_range(0.0, 1.0, 0.01) var jump_cut: float = 0.45
## Perdón: puedes saltar durante este tiempo tras dejar el suelo.
@export_range(0.0, 0.4, 0.01) var coyote_time: float = 0.12
## Perdón: un salto pulsado antes de aterrizar se ejecuta al tocar suelo.
@export_range(0.0, 0.4, 0.01) var jump_buffer: float = 0.15
@export_range(-60.0, -1.0, 0.5) var velocidad_terminal: float = -45.0
@export var saltos_aereos: int = 1

# --- Locomoción -------------------------------------------------------------
@export_group("Locomoción")
@export_range(0.5, 12.0, 0.1) var velocidad_caminar: float = 3.2
@export_range(1.0, 20.0, 0.1) var velocidad_correr: float = 7.5
@export_range(1.0, 30.0, 0.1) var velocidad_sprint: float = 11.0
@export_range(1.0, 200.0, 1.0) var aceleracion_suelo: float = 60.0
@export_range(1.0, 200.0, 1.0) var aceleracion_aire: float = 25.0
@export_range(1.0, 200.0, 1.0) var frenado_suelo: float = 45.0
@export_range(0.0, 200.0, 1.0) var frenado_aire: float = 4.0
## Grados por segundo a los que el modelo gira hacia la dirección de movimiento.
@export_range(90.0, 2160.0, 10.0) var giro_grados_seg: float = 900.0
@export_range(0.0, 89.0, 1.0) var angulo_max_suelo: float = 50.0

# --- Dash -------------------------------------------------------------------
@export_group("Dash")
@export_range(1.0, 20.0, 0.1) var dash_distancia: float = 6.0
@export_range(0.05, 1.0, 0.01) var dash_duracion: float = 0.18
@export_range(0.0, 0.5, 0.01) var dash_iframes: float = 0.10
@export_range(0.0, 2.0, 0.01) var dash_recuperacion: float = 0.12
@export var dash_cargas_aire: int = 1
## Grados dentro de los que el dash se autoalinea al enemigo cercano.
@export_range(0.0, 90.0, 1.0) var dash_correccion_grados: float = 20.0

# --- Planeo -----------------------------------------------------------------
@export_group("Planeo")
@export_range(-20.0, 0.0, 0.1) var planeo_caida: float = -3.0
@export_range(1.0, 30.0, 0.1) var planeo_velocidad: float = 12.0
@export_range(1.0, 90.0, 1.0) var planeo_giro_grados_seg: float = 120.0
## Grados de alabeo visual al girar. La capa vende el planeo.
@export_range(0.0, 60.0, 1.0) var planeo_alabeo: float = 28.0
@export_range(0.0, 1.0, 0.01) var planeo_retardo_despliegue: float = 0.18

# --- Bordes y escalada ------------------------------------------------------
@export_group("Bordes y escalada")
## Perdón: si fallas el borde por menos de esto, se te concede el agarre.
@export_range(0.0, 1.5, 0.05) var ledge_assist: float = 0.4
@export_range(0.1, 3.0, 0.05) var ledge_alcance: float = 0.7
@export_range(0.1, 3.0, 0.05) var ledge_altura_max: float = 2.1
@export_range(0.1, 6.0, 0.1) var escalada_velocidad: float = 2.4
@export_range(0.1, 8.0, 0.1) var shimmy_velocidad: float = 1.6

# --- Combate ----------------------------------------------------------------
@export_group("Combate")
@export_range(0.02, 0.6, 0.01) var parry_ventana: float = 0.16
@export_range(0.01, 0.3, 0.01) var parry_ventana_perfecta: float = 0.06
@export_range(0.0, 2.0, 0.01) var parry_recuperacion_fallo: float = 0.4
@export_range(0.0, 0.5, 0.005) var hitstop_ligero: float = 0.05
@export_range(0.0, 0.5, 0.005) var hitstop_pesado: float = 0.09
@export_range(0.0, 0.5, 0.005) var hitstop_parry: float = 0.16
@export_range(0.0, 1.0, 0.005) var hitstop_punto_debil: float = 0.25
@export_range(0.0, 0.6, 0.01) var esquiva_iframes: float = 0.30

# --- Stamina ----------------------------------------------------------------
@export_group("Stamina")
## Barra única: escalar, planear, correr, dashear y aguantar sacudidas.
## Los ataques NO gastan stamina: esto no es un souls.
@export_range(10.0, 500.0, 1.0) var stamina_max: float = 100.0
@export_range(0.0, 100.0, 0.5) var stamina_escalar: float = 6.0
@export_range(0.0, 100.0, 0.5) var stamina_aguantar_sacudida: float = 24.0
@export_range(0.0, 100.0, 0.5) var stamina_planear: float = 4.0
@export_range(0.0, 100.0, 0.5) var stamina_sprint: float = 8.0
@export_range(0.0, 100.0, 0.5) var stamina_dash: float = 12.0
@export_range(0.0, 200.0, 1.0) var stamina_regen_suelo: float = 55.0
@export_range(0.0, 200.0, 1.0) var stamina_regen_colgado: float = 6.0
@export_range(0.0, 3.0, 0.05) var stamina_retardo_regen: float = 0.35

# --- Cámara -----------------------------------------------------------------
@export_group("Cámara")
@export_range(1.0, 20.0, 0.1) var camara_distancia: float = 6.5
@export_range(0.0, 4.0, 0.05) var camara_altura_objetivo: float = 1.35
@export_range(0.01, 1.0, 0.01) var camara_sensibilidad: float = 0.28
@export_range(-89.0, 0.0, 1.0) var camara_pitch_min: float = -65.0
@export_range(0.0, 89.0, 1.0) var camara_pitch_max: float = 55.0
@export_range(0.01, 1.0, 0.01) var camara_suavizado: float = 0.12
@export_range(20.0, 110.0, 1.0) var camara_fov: float = 62.0


## Velocidad inicial de salto derivada de la altura y la gravedad de subida.
## v = sqrt(2 * g * h)
func velocidad_salto() -> float:
	return sqrt(2.0 * absf(gravedad_subida) * altura_salto)


## Velocidad del dash derivada de distancia y duración.
func velocidad_dash() -> float:
	return dash_distancia / maxf(dash_duracion, 0.001)
