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
## Cuántos IMPACTOS hace el gesto. Un ataque giratorio golpea dos veces con una
## sola animación, y eso no es lo mismo que dos ataques encadenados: no hay
## decisión del jugador entre medias, no se puede cancelar entre ellos, y quien
## está dentro del arco se lleva los dos.
##
## Cada impacto reabre el swing de la hitbox, así que el MISMO enemigo se lleva
## los dos golpes. Sin eso, la lista de `_tocados` se lo comería el segundo y un
## "ataque de dos hits" haría exactamente el daño de uno.
@export_range(1, 5, 1) var golpes: int = 1
## Frames entre el fin de una ventana activa y el principio de la siguiente.
@export_range(0, 60, 1) var frames_entre_golpes: int = 8

@export_group("Daño")
@export var dano: float = 10.0
## Daño a la postura. Al agotarla el enemigo entra en GuardBreak.
@export var dano_poise: float = 12.0
## Empuje que recibe la víctima, en espacio local del atacante (Z = hacia delante).
@export var empuje: Vector3 = Vector3(0.0, 0.0, 4.0)
## Si es > 0, levanta a la víctima. Reservado a golpes que ABREN el juego aéreo:
## un pesado que manda a todo el mundo por los aires convierte cada intercambio
## en un malabar y se come la lectura del combate en suelo.
@export var lanzamiento: float = 0.0
## Segundos que la víctima queda tambaleándose. Es el castigo "terrestre", la
## alternativa a lanzar por los aires.
@export_range(0.0, 3.0, 0.05) var stagger: float = 0.0
## Velocidad (m/s) con la que sale despedido el cadáver si ESTE golpe es el que
## mata. 0 = el enemigo cae en el sitio.
@export_range(0.0, 60.0, 0.5) var fuerza_muerte: float = 0.0
@export_range(0.0, 30.0, 0.5) var torque_muerte: float = 6.0
## Ignora la guardia frontal del Escudo.
@export var rompe_guardia: bool = false

## QUE ES este ataque, en etiquetas. `&"perforante"`, `&"contundente"`…
##
## Existe para que un `WeakPoint` pueda decir QUE LO ABRE sin nombrar un arma.
## La alternativa —`if arma is Lanza`— obliga a tocar el coloso cada vez que se
## anade un arma, y el coloso es lo ultimo que uno quiere tocar.
@export var etiquetas: Array[StringName] = []

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
## ESTOCADA: en vez de un empujón al arrancar que se apaga enseguida, el atacante
## MANTIENE esta velocidad hacia delante durante toda la anticipación y la ventana
## activa, y solo la suelta en la recuperación.
##
## Es la diferencia entre un golpe que te frena en seco y uno que atraviesa. Un
## ataque lanzado desde una carrera tiene que conservar la carrera.
@export var estocada: bool = false
@export_range(0.0, 40.0, 0.5) var estocada_velocidad: float = 12.0
## OVERSHOOT: empujon extra al cerrarse la ventana activa. Convierte la estocada
## en un CORTE que atraviesa al objetivo y te deja al otro lado, en vez de
## quedarte clavado delante de el.
@export_range(0.0, 40.0, 0.5) var overshoot: float = 0.0
## FRENAZO: el atacante para en seco al iniciar el golpe y no avanza nada. Es lo
## contrario de la estocada, y lo que hace que un golpe pesado se sienta plantado.
@export var frenazo: bool = false
## DERRIBO: tumba al enemigo en vez de solo tambalearlo. Abre una ventana larga
## para rematar. Es lo que hace que agacharse tenga una razon ofensiva.
@export var derribo: bool = false
@export_range(0.0, 6.0, 0.1) var derribo_duracion: float = 1.6
## Al terminar, si se sigue manteniendo Shift y hay suelo, se vuelve al surf en vez
## de a la locomocion normal. Mantiene la forma fluida entre golpe y golpe.
@export var vuelve_a_surf: bool = false
## El ataque encara al objetivo cercano al empezar.
@export var autoencarar: bool = true
## Cuánta velocidad de carrera conserva el jugador MIENTRAS ataca, de 0 a 1.
## Con 0 el personaje se queda clavado en cada golpe, que es lo que hace que un
## combo se sienta como una animación en vez de como una pelea.
@export_range(0.0, 1.0, 0.05) var movilidad: float = 0.45

@export_group("Feedback")
@export_range(0.0, 0.5, 0.005) var hitstop: float = 0.05
@export_range(0.0, 3.0, 0.05) var shake: float = 0.35
## Color del destello de impacto. Se resuelve contra la Palette por nombre.
@export var color_vfx: StringName = &"blanco_tiza"

@export_group("Cadena y cancelaciones")
## Siguiente golpe de la cadena. Null = es el finisher.
@export var siguiente: AttackData
## CON QUE BOTON se encadena al siguiente.
##
## Existe porque el pesado tiene su propia cadena —giro y remate— y con un solo
## botón de encadenar habría que elegir: o el pesado se continúa con el ligero
## (que rompe la lectura: los dos botones significan cosas distintas y deben
## seguir significándolas) o el ligero deja de encadenar.
##
## 0 = Ligero, 1 = Pesado. Ligero es el defecto, así que los `.tres` que ya
## existían no cambian de comportamiento por existir este campo.
@export_enum("Ligero", "Pesado") var boton_cadena: int = 0
## Frame (desde el inicio del ataque) a partir del cual se puede encadenar.
@export var frame_cadena: int = 10
## Ventanas de cancelación en frames: {"dash": Vector2i(inicio, fin), ...}
## Vacío significa "usa las reglas por defecto de GroupCombat".
@export var cancelaciones: Dictionary = {}


func total_frames() -> int:
	return frames_windup + frames_activos_totales() + frames_recuperacion


## Lo que ocupan TODAS las ventanas activas y los huecos entre ellas. Con
## `golpes = 1` es exactamente `frames_activo`, que es como estaba antes.
func frames_activos_totales() -> int:
	return golpes * frames_activo + (golpes - 1) * frames_entre_golpes


func duracion() -> float:
	return float(total_frames()) / FPS


func frames_a_seg(frames: int) -> float:
	return float(frames) / FPS


## ¿Estamos dentro de UNA ventana activa, medido en frames desde el inicio?
func activo_en(frame: int) -> bool:
	return indice_golpe(frame) >= 0


## Qué impacto está abierto en este frame, de 0 a `golpes - 1`. Devuelve -1 si
## ninguno.
##
## Es lo que permite al estado saber que ha empezado un impacto NUEVO y reabrir
## el swing. Preguntar solo "¿estoy activo?" no distingue el segundo golpe del
## primero, y ahí es donde un ataque de dos hits acaba haciendo uno.
func indice_golpe(frame: int) -> int:
	if frame < frames_windup:
		return -1
	var desde := frame - frames_windup
	var ciclo := frames_activo + frames_entre_golpes
	if ciclo <= 0:
		return -1
	var i := desde / ciclo
	if i >= golpes:
		return -1
	return i if desde % ciclo < frames_activo else -1


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


## ¿Lleva esta etiqueta? Un ataque sin etiquetas no abre ningun punto debil, que
## es el defecto correcto: abrir un punto debil es un privilegio, no lo normal.
func tiene(etiqueta: StringName) -> bool:
	return etiquetas.has(etiqueta)
