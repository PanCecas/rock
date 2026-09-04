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

@export_group("Anclaje")
## Numeros del ANCLAJE, la segunda cuerda. Viven aqui y no en un Resource propio
## porque son cuatro y describen lo mismo —algo que se tira y se clava—: un
## tercer archivo de tuning para cuatro numeros hace mas dificil encontrarlos, no
## mas facil.
##
## Vuela mas rapido que la lanza y llega menos lejos, y las dos cosas van juntas:
## el anclaje no es informacion —no hay que verlo viajar para leer a donde va—,
## es la segunda mitad de un gesto que ya has empezado.
@export_range(5.0, 140.0, 0.5) var anclaje_velocidad: float = 46.0
@export_range(5.0, 200.0, 1.0) var anclaje_alcance: float = 32.0
## Segundos que vuela antes de rendirse y volver.
@export_range(0.5, 20.0, 0.1) var anclaje_vida: float = 2.5
@export_range(0.05, 1.0, 0.01) var anclaje_radio: float = 0.16
