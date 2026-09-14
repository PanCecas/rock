class_name SpearTuning
extends Resource
## Todos los números de la lanza. Ninguno vive en un `.gd` (regla dura #1).
##
## Va aparte de `PlayerTuning` a propósito: la lanza es un sistema con su propia
## máquina de estados —`docs/03 §4`— y mezclar sus ajustes con los doscientos del
## jugador haría imposible encontrar ninguno de los dos.

@export_group("Vuelo")
## Velocidad de crucero. Rápida, pero no tanto como para que no se vea volar: la
## lanza en el aire es información —dónde va a clavarse— y una bala no informa.
@export_range(5.0, 120.0, 0.5) var velocidad: float = 34.0
## Segundos que vuela antes de caer al suelo por su cuenta.
@export_range(0.5, 20.0, 0.1) var vida_vuelo: float = 4.0
## Distancia máxima a la que se aleja antes de caer. El cordón tiene un largo.
@export_range(5.0, 200.0, 1.0) var alcance_maximo: float = 45.0

@export_group("Suspension")
## A CUANTOS METROS SE PARA A FLOTAR. Es el numero que convierte la lanza en una
## DIANA DE POGO: se tira corto, se queda ahi, y se patea.
##
## Corto a proposito. Un proyectil que cruza media sala es un arma; uno que se
## planta unos metros por delante es un escalon que te fabricas donde no hay
## nada — y con `suspension_duracion` en 2.5 s, once metros se cruzan de sobra
## dentro de la misma ventana yendo a cualquier velocidad de este juego.
##
## **Empezo en 8 y lo subio un test, con razon.** `TestLanza` comprueba que la
## lanza ATRAVIESA a los enemigos en vez de pararse en el primero, y lo mide
## tirandola contra uno que esta a 7 m: parandose a 8 el margen era de un metro y
## la comprobacion dejaba de distinguir "paso de largo" de "se paro justo
## despues". No es que el numero tuviera que ser 11: es que 8 era tan corto que
## la lanza dejaba de ser un proyectil.
@export_range(2.0, 40.0, 0.5) var suspension_distancia: float = 11.0
## Cuanto aguanta flotando, en segundos. Es la ventana para llegar.
@export_range(0.2, 10.0, 0.1) var suspension_duracion: float = 2.5
## Periodo del bamboleo, en segundos. Una lanza absolutamente quieta en el aire
## se lee como un objeto que el motor se ha dejado olvidado.
@export_range(0.2, 6.0, 0.05) var suspension_bamboleo: float = 1.4
## Empuje que se lleva al recibir la patada, en m/s. **Una lanzada, un pogo**: si
## se quedara flotando se podria subir por ella sin fin, y eso es una escalera al
## cielo con pasos extra (regla dura #27).
@export_range(0.0, 40.0, 0.5) var suspension_empuje: float = 9.0

@export_group("Imantado")
## Corrección máxima hacia el objetivo, en grados. `docs/03 §4.2` fija 8: es
## suficiente para perdonar un error de puntería y demasiado poco para apuntar
## por ti. Subirlo convierte la lanza en un misil y tirarla deja de tener mérito.
@export_range(0.0, 45.0, 0.5) var imantado_grados: float = 8.0
## Distancia máxima a la que el imantado busca objetivo.
@export_range(0.0, 60.0, 1.0) var imantado_alcance: float = 30.0

@export_group("Clavado")
## Profundidad a la que se hunde en la superficie al clavarse.
@export_range(0.0, 1.5, 0.05) var hundimiento: float = 0.35
## Lado de la plataforma cuadrada que aparece al clavarse. `docs/03 §4.3` fija
## 0.4 m: cabe una cápsula de pie y no tanto como para caminar por encima.
@export_range(0.1, 2.0, 0.05) var plataforma_lado: float = 0.4
## Cuanto SALE la plataforma de la superficie, a lo largo de la normal.
##
## Existe porque la lanza se hunde `hundimiento` metros al clavarse, asi que su
## origen queda DENTRO de la pared. Colgar ahi la plataforma la entierra: el
## jugador cae encima y la atraviesa porque el muro esta en medio. Se pisa el
## ASTA, que es lo que sobresale, no el punto de impacto.
@export_range(0.0, 2.0, 0.05) var plataforma_salida: float = 0.45
## Grosor de esa plataforma. Fina, para que se lea como "estoy sobre la lanza" y
## no como "hay un bloque flotando".
@export_range(0.02, 0.5, 0.01) var plataforma_grosor: float = 0.12

@export_group("Recuperacion")
## Velocidad a la que vuelve a la mano.
@export_range(5.0, 120.0, 0.5) var velocidad_retorno: float = 40.0
## Cuánto se arquea el retorno. Volver en línea recta se ve mucho peor, y esto
## no es un capricho: la curva es lo que hace legible que la lanza VUELVE en vez
## de aparecer. `docs/03 §4.4`.
@export_range(0.0, 6.0, 0.1) var arco_retorno: float = 1.8
## A qué distancia de la mano se considera atrapada.
@export_range(0.1, 3.0, 0.05) var radio_atrape: float = 0.9

@export_group("Presentacion")
@export_range(0.2, 4.0, 0.05) var largo: float = 1.9
@export_range(0.01, 0.5, 0.01) var grosor: float = 0.07
