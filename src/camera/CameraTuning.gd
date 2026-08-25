class_name CameraTuning
extends Resource
## Todos los parámetros de la cámara, editables desde el inspector.
##
## Vive aparte de `PlayerTuning` porque la cámara no es el jugador: se ajusta en
## otra sesión, con otros ojos y casi siempre después. Mezclarlas obligaba a
## bajar 500 líneas de exports de movimiento para tocar un FOV.
##
## Tres tipos de mando, y la diferencia importa:
##
##   VALORES     — el número, sin más. `distancia`, `fov`, `altura`.
##   INFLUENCIAS — un multiplicador de 0 a 1 sobre un efecto ya definido. Poner
##                 una a cero APAGA ese efecto sin borrar sus otros ajustes, así
##                 que se puede probar "sin esto" y volver sin perder nada.
##   CURVAS      — la FORMA de una respuesta. Un `Curve` en el inspector deja
##                 dibujar cómo crece el FOV con la velocidad: lineal, con codo,
##                 con techo. Un número solo puede decir cuánto; una curva dice
##                 cuándo. Si se deja vacía se usa una rampa lineal.
##
## Las curvas se muestrean con el eje X normalizado de 0 a 1: 0 es "parado" y 1
## es `velocidad_referencia`. Así la curva no hay que redibujarla cada vez que se
## cambia la velocidad del personaje.

# --- Encuadre base ------------------------------------------------------------
@export_group("Encuadre")
## Distancia del brazo en el modo de exploración. El resto de modos la escalan.
@export_range(1.0, 20.0, 0.1) var distancia: float = 6.5
## Altura del punto que la cámara mira, medida desde los pies del personaje.
@export_range(0.0, 4.0, 0.05) var altura_objetivo: float = 1.35
@export_range(20.0, 110.0, 1.0) var fov: float = 62.0
## Desplazamiento lateral del encuadre. Positivo = el personaje se va a la
## izquierda y deja ver hacia dónde va. Sutil: 0.4 ya se nota.
@export_range(-3.0, 3.0, 0.05) var desplazamiento_lateral: float = 0.0

# --- Respuesta ----------------------------------------------------------------
@export_group("Respuesta")
## Constante de tiempo del seguimiento, en segundos. Bajo = pegada y seca; alto =
## flotante. Es el parámetro que más cambia la personalidad de la cámara.
@export_range(0.01, 1.0, 0.01) var suavizado: float = 0.12
@export_range(0.01, 1.0, 0.01) var sensibilidad: float = 0.28
@export_range(-89.0, 0.0, 1.0) var pitch_min: float = -65.0
@export_range(0.0, 89.0, 1.0) var pitch_max: float = 55.0

# --- Velocidad ----------------------------------------------------------------
@export_group("Reacción a la velocidad")
## Velocidad a la que la respuesta llega a su máximo. Es el 1.0 del eje X de las
## curvas de abajo.
@export_range(1.0, 40.0, 0.5) var velocidad_referencia: float = 16.0
## Cuánto FOV se suma como máximo. La CURVA dice cómo se reparte por el camino.
@export_range(0.0, 30.0, 0.5) var fov_extra_max: float = 9.0
## Forma de esa respuesta. Vacía = rampa lineal. Una curva con codo al final da
## el clásico "no pasa nada hasta que corres de verdad".
@export var curva_fov: Curve
## Cuánto se aleja la cámara a máxima velocidad, en metros.
@export_range(0.0, 8.0, 0.1) var distancia_extra_max: float = 0.9
@export var curva_distancia: Curve
## Apaga toda la reacción a la velocidad sin perder los valores de arriba.
@export_range(0.0, 1.0, 0.05) var influencia_velocidad: float = 1.0

# --- Vida ---------------------------------------------------------------------
@export_group("Vida (ruido de cámara)")
## RUIDO SUTIL. Una cámara perfectamente quieta se lee como un trípode, no como
## una mirada. Esto es lo que la hace parecer sostenida por alguien.
##
## El listón: si al mirarlo piensas "se está moviendo la cámara", es demasiado.
## Tiene que notarse solo cuando lo apagas.
@export_range(0.0, 1.0, 0.05) var ruido_influencia: float = 0.35
## Amplitud en grados. Por encima de 1.5 deja de ser sutil y empieza a marear.
@export_range(0.0, 5.0, 0.05) var ruido_grados: float = 0.55
## Oscilaciones por segundo. Bajo = respiración; alto = temblor de mano.
@export_range(0.05, 8.0, 0.05) var ruido_frecuencia: float = 0.55
## Cuánto crece el ruido con la velocidad. A 0 el ruido es constante; a 1 la
## cámara se agita al correr y se calma al pararse, que es lo que la hace sentir
## viva en vez de solo temblorosa.
@export_range(0.0, 1.0, 0.05) var ruido_por_velocidad: float = 0.6

# --- Modos --------------------------------------------------------------------
@export_group("Modos")
## Cada modo es un MULTIPLICADOR sobre el encuadre base, no un valor absoluto:
## así cambiar `distancia` reajusta los cuatro modos a la vez y no hay que
## acordarse de tocar tres sitios.
@export_range(0.1, 2.0, 0.01) var explorar_dist: float = 1.0
@export_range(0.1, 2.0, 0.01) var explorar_altura: float = 1.0
@export_range(0.1, 2.0, 0.01) var escalar_dist: float = 0.62
@export_range(0.1, 2.0, 0.01) var escalar_altura: float = 1.25
@export_range(0.1, 2.0, 0.01) var combate_dist: float = 0.88
@export_range(0.1, 2.0, 0.01) var combate_altura: float = 1.15
@export_range(0.1, 2.0, 0.01) var combate_fov: float = 1.06
## Segundos que tarda en pasar de un modo a otro.
@export_range(0.01, 2.0, 0.01) var transicion_modo: float = 0.22

# --- Sacudida -----------------------------------------------------------------
@export_group("Sacudida de impacto")
## Multiplicador global del screen shake. A 0 se apaga todo el shake del juego
## sin tocar ni un `.tres` de ataque.
@export_range(0.0, 3.0, 0.05) var shake_influencia: float = 1.0
@export_range(0.5, 20.0, 0.5) var shake_decaimiento: float = 6.0


## Evalúa una curva con el eje X normalizado. Sin curva, rampa lineal — que es el
## comportamiento que había antes de existir este recurso, para que dejarla vacía
## no cambie nada.
func muestrear(curva: Curve, t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	if curva == null:
		return x
	return curva.sample_baked(x)


## Fracción de velocidad respecto a la referencia, de 0 a 1. Es el eje X de todas
## las curvas de este recurso.
func fraccion_velocidad(rapidez: float) -> float:
	return clampf(rapidez / maxf(velocidad_referencia, 0.01), 0.0, 1.0)
