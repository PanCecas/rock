class_name EnjambreTuning
extends Resource
## Todos los números del enjambre. Ninguno vive en un `.gd` (regla dura #1).
##
## El sistema entero son dos fórmulas —`project.md §5` las tiene escritas— y estos
## parámetros. Lo que se afina aquí es el CARÁCTER: cuánto tarda en engancharse,
## cuánto dura el orden antes de romperse, y cuánto se nota una fase en pantalla.

@export_group("El modelo")
## Cuántas criaturas. Kuramoto es un modelo de N cuerpos: con dos no hay
## sincronización que ver, y por encima de una docena el ojo deja de seguir a
## cada una y solo lee la masa.
@export_range(2, 64, 1) var agentes: int = 9
## Dispersión de frecuencias propias, en rad/s. **Es la personalidad.**
##
## Cada criatura nace con su `ωᵢ` y no cambia nunca: es lo único que la distingue
## de las demás de verdad. Con dispersión cero todas son la misma y sincronizan al
## instante, que no es un sistema, es un metrónomo.
@export_range(0.0, 6.0, 0.05) var dispersion: float = 1.35
## Frecuencia base, en rad/s. El pulso alrededor del que orbitan todas.
@export_range(0.1, 12.0, 0.05) var frecuencia_base: float = 2.1

@export_group("Acoplamiento — la respiración caos↔orden")
## `K` mínimo y máximo. Por debajo del acoplamiento crítico cada una va a su
## ritmo; por encima se enganchan solas.
@export_range(0.0, 20.0, 0.05) var k_min: float = 0.15
@export_range(0.0, 40.0, 0.05) var k_max: float = 6.5
## A qué velocidad SUBE `K` mientras el sistema está disperso, en 1/s.
@export_range(0.01, 10.0, 0.01) var k_subida: float = 0.55
## A qué velocidad BAJA cuando ya está ordenado. Más lento que subir: el orden
## tiene que durar lo bastante para verse antes de deshacerse.
@export_range(0.01, 10.0, 0.01) var k_bajada: float = 0.22
## Orden a partir del cual el sistema "se cansa" del unísono y `K` empieza a caer.
##
## **Esto es lo que lo hace INESTABLE, y es una sola regla.** El parámetro de
## orden realimenta el acoplamiento: disperso, tira de engancharse; enganchado,
## afloja. El resultado es una respiración lenta entre caos y orden que no
## termina nunca, en vez de un transitorio que converge una vez y se queda.
@export_range(0.1, 1.0, 0.01) var orden_saciedad: float = 0.86
## Orden por debajo del cual vuelve a tirar hacia el orden. La histéresis evita
## que el sistema vibre en el umbral en vez de respirar.
@export_range(0.0, 1.0, 0.01) var orden_hambre: float = 0.35

@export_group("Perturbación")
## Cuánto se desplaza la fase de una criatura perturbada, en radianes.
## PI la manda justo al lado opuesto del círculo, que es el desorden máximo.
@export_range(0.0, 6.3, 0.05) var perturbacion_fase: float = 2.4
## Cuánto se debilita su acoplamiento justo después de la perturbación, de 0 a 1.
## Sin esto vuelve a engancharse tan rápido que la perturbación no se ve.
@export_range(0.0, 1.0, 0.05) var perturbacion_sordera: float = 0.85
## Segundos que tarda esa sordera en pasársele. Es el tiempo de RESINCRONIZACIÓN
## que el usuario percibe como "la he despeinado y se está recomponiendo".
@export_range(0.05, 8.0, 0.05) var perturbacion_duracion: float = 1.6

@export_group("Manifestación visual")
## Amplitud del vaivén, en metros. **No hay rotación**: el movimiento es
## traslación pura y respiración de escala.
@export_range(0.0, 4.0, 0.01) var onda_amplitud: float = 0.62
## Apertura del SEGUNDO eje, en fracción del primero. Es lo que convierte el
## vaivén en una figura.
##
## A cero la criatura desliza por una recta, y una recta se recorre de ida y de
## vuelta: el cuerpo adelanta a su propia cola en cada viaje de regreso y la
## estela deja de leerse como estela. Medido: yendo y viniendo por un solo eje, la
## cola quedaba detrás 119 frames y delante 138 —una moneda al aire—.
##
## Con el segundo eje a doble frecuencia el recorrido es un ocho: la criatura casi
## nunca vuelve por donde vino, la cola siempre tiene sitio detrás, y de paso sale
## el "movimiento ondulatorio" del encargo sin rotar nada.
@export_range(0.0, 2.0, 0.01) var onda_lateral: float = 0.55
## Cuánto se estira y encoge con el ciclo, en fracción de su tamaño.
@export_range(0.0, 1.0, 0.01) var respiracion: float = 0.16
## Opacidad mínima y máxima a lo largo del ciclo.
@export_range(0.0, 1.0, 0.01) var opacidad_min: float = 0.35
@export_range(0.0, 1.0, 0.01) var opacidad_max: float = 0.95
## Desplazamiento de tono a lo largo del ciclo, en grados. **Sutil por encargo.**
## Un giro de tono completo convierte el enjambre en un arcoíris y se lleva por
## delante la regla dura #8.
@export_range(0.0, 60.0, 0.5) var hue_deriva: float = 9.0
## Fuerza del destello en la cresta del ciclo. También sutil: lo que tiene que
## leerse es el PULSO, no un flash.
@export_range(0.0, 3.0, 0.01) var destello: float = 0.55
## Cómo de estrecha es la cresta que destella. Alto = un parpadeo corto en el pico.
@export_range(1.0, 32.0, 0.5) var destello_dureza: float = 7.0

@export_group("La cola")
## Nudos de la línea. Pocos: la cola es un trazo, no una cuerda.
@export_range(2, 64, 1) var cola_nudos: int = 22
## Separación de reposo entre nudos, en metros.
##
## **El largo de la cola tiene que parecerse al RECORRIDO de la criatura**, y ese
## recorrido es `onda_amplitud * 2`. Con nudos*paso muy por encima, la cola abarca
## más de un ciclo entero de vaivén y se enrolla sobre sí misma: deja de leerse
## como el camino que ha hecho y pasa a ser una maraña quieta. Medido: 14 x 0.16 =
## 2.24 m de cola sobre 0.84 m de recorrido.
##
## Hoy el recorrido es un ocho de unos 3.5 m de perímetro y la cola mide 2.1: la
## criatura dibuja algo más de la mitad de su propia órbita y esa es la lectura
## que se busca. Con 1.17 m medía lo mismo que el cuerpo y salía un ganchito
## escondido dentro de él.
@export_range(0.02, 2.0, 0.01) var cola_paso: float = 0.10
## Cuánto persigue cada nudo al de delante, por segundo. Bajo = cola perezosa que
## se queda atrás y dibuja el recorrido; alto = cola rígida pegada al cuerpo.
@export_range(0.5, 60.0, 0.5) var cola_seguimiento: float = 14.0
## Grosor del trazo en la base. Se afila hasta cero en la punta.
@export_range(0.005, 0.4, 0.005) var cola_grosor: float = 0.075

@export_group("Marcapasos")
## Constante de tiempo del enganche, en segundos. Es lo que tarda una criatura en
## reconocerse como escolta y en dejar de serlo. Bajo = chasquea al entrar y al
## salir; alto = sigue orbitando cuando el jugador ya se fue.
@export_range(0.1, 10.0, 0.1) var enganche_suavizado: float = 1.4

@export_group("Audio — solo valores, el sonido es externo")
## Pitch base en Hz, y cuánto lo mueve la fase arriba y abajo.
@export_range(20.0, 2000.0, 1.0) var pitch_base: float = 174.6
@export_range(0.0, 2.0, 0.01) var pitch_rango: float = 0.28
## Cuánto puede moverlo el usuario, en semitonos arriba y abajo.
@export_range(0.0, 36.0, 0.5) var pitch_usuario: float = 12.0


## Frecuencia propia de la criatura `i` de `n`, en rad/s.
##
## Se reparten de forma DETERMINISTA y simétrica alrededor de la base, no al azar:
## con `randf()` cada arranque daría un sistema distinto y comparar dos ejecuciones
## —o escribir un test— sería imposible. La personalidad tiene que ser estable.
func omega(i: int, n: int) -> float:
	if n <= 1:
		return frecuencia_base
	var u := float(i) / float(n - 1) * 2.0 - 1.0   # -1 .. 1
	return frecuencia_base + u * dispersion


## CURIOSIDAD del agente `i`: cuanto le llama lo de fuera, de 0 a 1.
##
## Es el SEGUNDO rasgo fijo de la personalidad, al lado de la frecuencia propia, y
## como aquella no cambia nunca: el mismo bicho es siempre el curioso.
##
## Existe porque sin el, "algunas y no todas" no se sostiene. Medido: con el tiron
## igual para todas, el marcapasos capturaba a unas pocas, el acoplamiento del
## grupo arrastraba al resto detras de ellas y a los treinta segundos escoltaban
## **las catorce**. Es fisica correcta —un enjambre muy acoplado se mueve como una
## cosa— y es justo lo contrario de lo que se busca.
##
## Reparto por el conjugado del angulo aureo: uniforme en [0,1) y NO monotono con
## el indice, que es lo que impide que las escoltas sean "las cinco primeras" y se
## lea como un patron.
func curiosidad(i: int, _n: int) -> float:
	return fposmod(float(i) * 0.6180339887498949, 1.0)


## Una COPIA de esta afinacion con el RELOJ del sistema multiplicado por `factor`.
##
## Existe porque el mismo modelo tiene que servir para tres cosas que van a
## velocidades muy distintas: las Criaturas de Tela laten cada tres segundos, una
## bandada da una vuelta al circuito en veinte, y una luciernaga parpadea a su
## aire. Reafinar cada una a mano seria repetir el trabajo de medicion tres veces
## y quedarse con tres sistemas que se parecen y no son iguales.
##
## **Escala TODO lo que tiene unidades de 1/tiempo y nada mas.** `ω` y `K` son las
## dos frecuencias angulares de la ecuacion, asi que multiplicarlas por el mismo
## numero es exactamente un cambio de variable `t' = t·factor`: el sistema
## resultante hace lo mismo, punto por punto, mas rapido o mas despacio. Los
## umbrales de la histeresis son adimensionales —fracciones de `r`— y no se tocan;
## `perturbacion_fase` son radianes y tampoco; `perturbacion_duracion` son
## segundos, asi que se DIVIDE.
##
## Lo que se conserva y por eso funciona: la razon `K/dispersion`, que es la que
## decide si el enjambre puede sincronizar o no. Bajar solo `ω` dejaria un
## acoplamiento gigante al lado de una dispersion diminuta, y el sistema se
## quedaria enganchado para siempre sin volver a deshacerse.
##
## **Y CADA COSA POR SU POTENCIA DE `f`, que no todas son 1/s.** `ω` y `K` son
## frecuencias —1/s, factor `f`—, pero `k_subida` y `k_bajada` son la VELOCIDAD a
## la que crece el acoplamiento: 1/s², factor `f²`. Escalarlas por `f` a secas es
## el fallo natural, no da error y se ve en la primera medida: el sistema a mitad
## de reloj sincronizaba en 8.6 s en vez de en 19.2 —ANTES que el normal—, porque
## su K subia el doble de rapido de lo que le tocaba. Lo cazo `TestMundoVivo`.
func a_ritmo(factor: float) -> EnjambreTuning:
	var f: float = maxf(factor, 0.001)
	var t: EnjambreTuning = duplicate() as EnjambreTuning
	# 1/s
	t.frecuencia_base *= f
	t.dispersion *= f
	t.k_min *= f
	t.k_max *= f
	# 1/s²
	t.k_subida *= f * f
	t.k_bajada *= f * f
	# s
	t.perturbacion_duracion /= f
	t.enganche_suavizado /= f
	return t
