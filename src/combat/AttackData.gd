@tool
class_name AttackData
extends Resource
## Un ataque = un archivo .tres. REGLA DURA: nadie escribe combate en código.
##
## Los tiempos van en FRAMES a 60 Hz (el tick de física del proyecto) porque es la
## unidad en la que se piensa el combate y en la que se comparan los juegos de
## referencia. `frames_a_seg()` hace la conversión.
##
## Ver docs/03_ARQUITECTURA_MECANICAS.md §3.1.

const FPS := 60.0

@export_group("Identidad")
## Clip de animación que tocará en la Fase 6. Hoy solo documenta la intención.
@export var anim: StringName = &""
@export var nombre: String = ""

@export_group("Tiempos (frames a 60 Hz)")
## Anticipación: el enemigo puede leerte. Corto = rápido pero ilegible.
@export var frames_windup: int = 6
## Ventana en la que la hitbox hace daño.
@export var frames_activo: int = 4
## Recuperación. Es lo que castiga fallar, y donde viven las cancelaciones.
@export var frames_recuperacion: int = 12

@export_group("Daño")
@export var dano: float = 10.0
## Daño a la postura. Al agotarla el enemigo entra en GuardBreak.
@export var dano_poise: float = 12.0
## Empuje que recibe la víctima, en espacio local del atacante (Z = hacia delante).
@export var empuje: Vector3 = Vector3(0.0, 0.0, 4.0)
## Si es > 0, levanta a la víctima: la base de los juggles.
@export var lanzamiento: float = 0.0
## Ignora la guardia frontal del Escudo.
@export var rompe_guardia: bool = false

@export_group("Hitbox")
## Alcance desde el centro del atacante, en metros.
@export var alcance: float = 2.0
@export var radio: float = 1.1
## Altura del centro de la hitbox sobre los pies.
@export var altura: float = 1.0
## Semiángulo del arco de golpeo. 180 = golpea en todas direcciones.
@export_range(10.0, 180.0, 1.0) var arco_grados: float = 70.0
## Cuántos objetivos distintos puede tocar el mismo swing.
@export var max_objetivos: int = 4

@export_group("Movimiento")
## Empuje del atacante hacia delante durante el ataque. Sin esto los combos se
## quedan cortos y hay que perseguir al enemigo entre golpe y golpe.
@export var avance: float = 3.5
## Cómo se reparte ese avance a lo largo del ataque (X = 0..1 del total).
@export var curva_avance: Curve
## El ataque encara al objetivo cercano al empezar.
@export var autoencarar: bool = true

@export_group("Feedback")
@export_range(0.0, 0.5, 0.005) var hitstop: float = 0.05
@export_range(0.0, 3.0, 0.05) var shake: float = 0.35
## Color del destello de impacto. Se resuelve contra la Palette por nombre.
@export var color_vfx: StringName = &"blanco_tiza"

@export_group("Cadena y cancelaciones")
## Siguiente golpe de la cadena ligera. Null = es el finisher.
@export var siguiente: AttackData
## Frame (desde el inicio del ataque) a partir del cual se puede encadenar.
@export var frame_cadena: int = 10
## Ventanas de cancelación en frames: {"dash": Vector2i(inicio, fin), ...}
## Vacío significa "usa las reglas por defecto de GroupCombat".
@export var cancelaciones: Dictionary = {}


func total_frames() -> int:
	return frames_windup + frames_activo + frames_recuperacion


func duracion() -> float:
	return float(total_frames()) / FPS


func frames_a_seg(frames: int) -> float:
	return float(frames) / FPS


## ¿Estamos dentro de la ventana activa, medido en frames desde el inicio?
func activo_en(frame: int) -> bool:
	return frame >= frames_windup and frame < frames_windup + frames_activo


## ¿La cancelación `tipo` está abierta en este frame?
## Sin ventana declarada, la respuesta la da GroupCombat con sus reglas por defecto.
func cancelable(tipo: StringName, frame: int) -> bool:
	if not cancelaciones.has(tipo):
		return false
	var v: Vector2i = cancelaciones[tipo]
	return frame >= v.x and frame <= v.y


## Fracción de avance aplicada en este punto del ataque (0..1).
func avance_en(progreso: float) -> float:
	if curva_avance != null:
		return curva_avance.sample_baked(clampf(progreso, 0.0, 1.0))
	# Sin curva: casi todo el empuje al principio, como un paso adelante.
	return maxf(0.0, 1.0 - progreso * 2.2)
