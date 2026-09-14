class_name SwordTuning
extends Resource
## Todos los numeros de la espada. Ninguno vive en un `.gd` (regla dura #1).
##
## Va aparte de `SpearTuning` porque son dos armas con dos trabajos distintos, y
## eso hay que poder leerlo en los numeros: la lanza SE QUEDA donde la clavas
## —plataforma, ancla, herramienta de posicion— y la espada SIEMPRE VUELVE. Una
## se tira para dejarla puesta; la otra se tira y se recoge.

@export_group("Corte")
## Cuanto dura el gesto de cortar, EN SEGUNDOS, de principio a fin.
##
## No sale de aqui: lo dice el `AttackData` en frames, que es la unidad del
## combate de este proyecto. Esto es el techo de seguridad por si alguien deja un
## `.tres` con tiempos absurdos, y el numero que impide que machacar el boton
## convierta el corte en un zumbido continuo.
@export_range(0.05, 2.0, 0.01) var corte_max: float = 1.0

@export_group("Vuelo")
## Velocidad a la que sale de la mano. Mas lenta que la lanza (34) a proposito:
## la espada hay que ALCANZARLA en el aire para patearla, y un proyectil que se
## te escapa no es una diana, es una despedida.
@export_range(5.0, 120.0, 0.5) var velocidad: float = 26.0
## Fraccion de velocidad que pierde por segundo mientras se aleja.
@export_range(0.0, 8.0, 0.1) var frenado: float = 1.0
## A que distancia del punto de salida da la vuelta.
##
## **Este es el numero que define el arma.** La espada no se clava ni se cae: se
## aleja hasta aqui y vuelve sola. Con 14 m el viaje entero dura algo mas de un
## segundo, que es el rato que hace falta para verla ir, decidir, y llegar a
## patearla.
@export_range(2.0, 60.0, 0.5) var alcance: float = 14.0
## Techo de seguridad del tramo de ida, en segundos.
@export_range(0.2, 10.0, 0.1) var vida_vuelo: float = 2.5
## Gravedad del vuelo, en m/s². Baja: la espada gira sobre si misma y planea, no
## es un proyectil balistico. La lanza si cae —esa es su lectura— y esta no.
@export_range(0.0, 40.0, 0.5) var gravedad_vuelo: float = 2.0

@export_group("Retorno")
## Velocidad a la que vuelve a la mano. Mas rapida que la ida: lo interesante del
## viaje es la ida, y la vuelta no puede ser una espera.
@export_range(5.0, 120.0, 0.5) var velocidad_retorno: float = 30.0
## Cuanto gira por segundo persiguiendo la mano. Alto: la espada te busca a ti, y
## fallar el reencuentro no es una mecanica, es un bug.
@export_range(30.0, 1440.0, 5.0) var giro_retorno: float = 540.0
## A que distancia de la mano se considera atrapada.
@export_range(0.1, 3.0, 0.05) var radio_atrape: float = 1.0
## Techo de seguridad del retorno, en segundos. Si se cumple, vuelve a la mano de
## golpe: quedarse sin arma para siempre por una esquina rara no es un castigo
## interesante, es una partida rota.
@export_range(0.5, 20.0, 0.5) var retorno_max: float = 4.0

@export_group("Patada")
## A que distancia busca enemigo la espada pateada.
##
## **Es la mitad del verbo que se pidio**: *«al patearla vaya al enemigo mas
## cercano»*. Se mide desde la ESPADA y no desde el jugador, y a efectos
## practicos es lo mismo: para patearla hay que alcanzarla, o sea que en el frame
## de la patada los dos estan a menos de tres metros.
@export_range(2.0, 80.0, 1.0) var busqueda_rango: float = 22.0
## Velocidad de la espada guiada. Sube respecto al vuelo normal porque una
## estocada teledirigida que va mas lenta que el tiro que la origino se lee como
## un error.
@export_range(5.0, 150.0, 0.5) var busqueda_velocidad: float = 34.0
## Cuanto gira por segundo persiguiendo al enemigo.
##
## **No es un teletransporte y por eso hay un numero.** Clavarle el rumbo al
## objetivo de golpe seria un salto en la imagen; asi la espada traza la curva y
## el jugador ve a donde va antes de que llegue, que es lo que le deja encadenar.
@export_range(30.0, 1440.0, 5.0) var busqueda_giro: float = 420.0
## Segundos que persigue antes de rendirse y volver.
@export_range(0.2, 10.0, 0.1) var busqueda_vida: float = 2.5
## Rapidez que le imprime una patada CUANDO NO HAY A QUIEN IR.
##
## La patada nunca se queda sin contestar: sin enemigo cerca, la espada se
## comporta como la lanza y sale disparada hacia donde pateaste. Un boton que a
## veces no hace nada es un boton que se deja de pulsar.
@export_range(5.0, 120.0, 0.5) var patada_empuje: float = 40.0

@export_group("Presentacion")
@export_range(0.2, 3.0, 0.05) var largo: float = 1.1
@export_range(0.02, 0.6, 0.01) var ancho: float = 0.11
@export_range(0.01, 0.3, 0.01) var grosor: float = 0.035
## Vueltas por segundo que da sobre si misma mientras vuela. Es lo unico que
## distingue de un vistazo «la espada va volando» de «la espada esta quieta».
@export_range(0.0, 12.0, 0.1) var giro_vuelo: float = 4.0
