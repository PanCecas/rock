extends SpearState
## FLOTANDO. Se acabo el impulso y la bola se queda EXACTAMENTE donde se paro.
##
## Se pidio asi: *«que la lanza ya no sea lanza sino una bolita, y que flote, que
## no se caiga mas bien»*. Y las dos mitades del encargo son la misma cosa vista
## por los dos lados: un asta que se cae al suelo es un arma que hay que ir a
## recoger; una bola que se queda en el aire es un **punto que tu pones**.
##
## **Esto NO es el `Suspendida` del 4.02 con otro nombre**, y la diferencia
## importa porque aquel se retiro por una queja concreta. Aquel PARABA EN SECO a
## los 11 m: volaba a 34 m/s y al metro siguiente estaba quieta, y eso se
## reporto como *«que no se tire y se quede pausada»*. Aqui no hay parada: el
## frenado exponencial la va apagando, y esto empieza cuando ya casi no se mueve.
## Se ve venir, se ve frenar y se ve quedarse.
##
## **Y NO ES PLATAFORMA, a proposito.** La lanza clavada si lo es —`Embedded`— y
## esa mecanica se queda entera. Pero una plataforma que puedes dejar flotando
## donde quieras es una escalera al cielo: tirarla arriba, subirte, recuperarla,
## y volver a tirarla desde ahi no tiene techo. El proyecto ya rechazo justo eso
## en el 4.02 con estas palabras —«si se quedara flotando se podria subir por
## ella sin fin»— y el argumento no ha cambiado porque la malla sea redonda.
##
## Lo que SI es, y sigue siendo todo lo que era:
##
## · **Un ANCLA que tu colocas.** `esta_fuera()` la cuenta, asi que la Z se
##   engancha a ella como a cualquier otra. Es el verbo que se pidio en el 4.05.
## · **Una DIANA de pogo.** La hurtbox sigue armada: se le puede patear, y
##   patearla la manda volando otra vez —o sea que tambien es como se la
##   recoloca sin recuperarla—.
##
## **No caduca, y es seguro que no lo haga**: hay UNA sola bola en todo el juego.
## Dejarla puesta cuesta quedarse sin ella, y recuperarla es un boton. Esa
## escasez es el limite, no un reloj.

## Amplitud del vaiven, en metros. Solo VISUAL: la bola no se mueve, se mueve su
## malla. Un objeto perfectamente quieto en el aire se lee como un bug de fisica
## —es la mitad de lo que hacia feo al `Suspendida` del 4.02— y bastan cinco
## centimetros para que se lea como que flota.
const VAIVEN := 0.05
## Ciclos por segundo del vaiven. Lento: esto respira, no vibra.
const VAIVEN_HZ := 0.45


func enter(_msg: Dictionary = {}) -> void:
	# SE PARA DEL TODO. Sin esto el frenado exponencial nunca llega a cero y la
	# bola reptaria por el aire para siempre unos centimetros por segundo, que es
	# lo peor de los dos mundos: ni se mueve ni esta quieta.
	lanza.vuelo = Vector3.ZERO
	# NO se llama a `poner_plataforma()`. Ver la nota de arriba.
	lanza.soltar_plataforma()
	# PATEABLE. Es la diana de pogo, y ademas es como se recoloca: una patada la
	# manda volando otra vez sin tener que recuperarla primero.
	lanza.armar_hurtbox(true)


func exit(_siguiente: StringName) -> void:
	lanza.armar_hurtbox(false)
	# El vaiven se deshace al salir. Es un desfase LOCAL del visual, asi que
	# olvidarlo dejaria la malla descentrada del cuerpo para siempre — la misma
	# familia que el `enderezar()` de la regla dura #17.
	if lanza.visual != null:
		lanza.visual.position = Vector3.ZERO


func physics_update(_delta: float) -> void:
	# LA BOLA NO SE MUEVE; SE MUEVE SU MALLA. El cuerpo se queda clavado en el
	# sitio porque de el cuelgan el ancla y la hurtbox, y un punto de cuerda que
	# sube y baja cinco centimetros cambia el radio del arco cada frame.
	if lanza.visual == null:
		return
	lanza.visual.position = Vector3.UP * (
		VAIVEN * sin(TAU * VAIVEN_HZ * t))


func debug_line() -> String:
	return "FLOTANDO  (ancla + diana)"
