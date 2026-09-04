class_name Enjambre
extends Node3D
## EL ENJAMBRE. N osciladores de Kuramoto acoplados, y nada más.
##
## Las dos fórmulas son las que `project.md §5` ya tenía escritas, copiadas tal
## cual porque son el modelo estándar y reinterpretarlas solo puede empeorarlas:
##
##     dθᵢ/dt = ωᵢ + (K/N) · Σⱼ sin(θⱼ − θᵢ)
##     r = | (1/N) · Σⱼ e^{iθⱼ} |          r = 0 disperso · r = 1 al unísono
##
## **Este nodo no dibuja ni suena.** Solo lleva las fases y publica valores. Lo
## que se ve lo pone `CriaturaTela`, y el sonido es externo por encargo: aquí se
## exponen `pitch` y `amplitud` por agente y por frame, y quien quiera hacerlos
## sonar los lee.
##
## Esa separación no es ceremonia. El modelo es determinista y se puede medir con
## un test —r sube, r baja, una perturbación lo tira—; el render y el audio no.
## Mezclados, no habría forma de comprobar que el sistema hace lo que dice.
##
## ---
##
## **LA INESTABILIDAD ES UNA SOLA REGLA, y es la que da vida al sistema.**
##
## El acoplamiento `K` no es constante: lo realimenta el propio orden. Disperso,
## `K` sube y las criaturas se buscan. Al llegar al unísono, `K` baja y se
## deshacen. El sistema respira entre caos y orden y no termina nunca, en vez de
## converger una vez y quedarse quieto, que es lo que hace un Kuramoto normal.
##
## La histéresis —`orden_saciedad` arriba, `orden_hambre` abajo— existe para que
## respire en vez de vibrar en el umbral.

## Se emite cada frame de física con los valores del ciclo, listos para audio.
## `pitches` y `amplitudes` tienen un elemento por agente.
signal ciclo(pitches: PackedFloat32Array, amplitudes: PackedFloat32Array, orden: float)
## Alguien ha perturbado a una criatura. Lo escucha el VFX y el audio.
signal perturbado(indice: int)

## EL ENJAMBRE HA LLEGADO AL ACUERDO Y SE CANSA, una vez por respiracion.
##
## Es el unico hito de ESTRUCTURA que el modelo genera solo: no hay compas, no hay
## barra, no hay reloj — hay un grupo que converge y se deshace. Publicarlo permite
## colgar de ahi cosas que necesitan una escala de tiempo larga sin inventarse un
## temporizador que competiria con el modelo.
signal respiro(numero: int)

@export var tuning: EnjambreTuning
@export var palette: Palette
## Semitonos que el usuario suma al pitch base. Es el único mando que se le da.
@export_range(-36.0, 36.0, 0.5) var pitch_usuario: float = 0.0

## Fase de cada oscilador, en radianes.
var fases: PackedFloat32Array = []
## Frecuencia propia de cada uno. **Es la personalidad y no cambia nunca.**
var omegas: PackedFloat32Array = []
## Acoplamiento actual. Sube y baja solo; ver la cabecera.
var k: float = 0.0
## Parámetro de orden del último frame, de 0 a 1.
var orden: float = 0.0
## Fase media del enjambre, en radianes. Es el "director" invisible.
var fase_media: float = 0.0

## --- EL MARCAPASOS: un oscilador EXTERNO que tira de quien tenga cerca. -------
##
## Es la ley de Kuramoto con forzamiento, y su gracia es el criterio de enganche,
## que sale solo de la ecuación. En el marco que gira con el marcapasos:
##
##     dφ/dt = (ωᵢ − Ω) − A·sin(φ)        con φ = θᵢ − ψ
##
## y eso tiene punto fijo —o sea, el agente se queda enganchado— **si y solo si**
##
##     |ωᵢ − Ω| ≤ A
##
## O sea: **enganchan los que PUEDEN seguirle el ritmo, y no los demás.** Como la
## frecuencia propia es la personalidad y no cambia nunca, siempre son unos pocos
## y siempre los mismos, sin una lista, sin un contador y sin un dado. "Algunas,
## no todas" no es una regla que haya que escribir: es lo que hace la fórmula.
##
## Fase del marcapasos, en radianes.
var marcapasos_fase: float = 0.0
## Su frecuencia propia, en rad/s. **Es la Ω de arriba: decide QUIÉN puede
## seguirle.** Cerca de `frecuencia_base` engancha a los del centro de la banda;
## en un extremo, a los raros.
var marcapasos_omega: float = 0.0
## Tirón que se le pide para cada agente ESTE frame. Es la A de arriba.
var _tiron: PackedFloat32Array = []
## Cuánto lleva enganchado cada uno, de 0 a 1. Suavizado: entrar y salir de la
## escolta tiene que verse, no chasquear.
var _enganche: PackedFloat32Array = []

## Segundos que le quedan de sordera a cada agente tras una perturbación.
var _sordera: PackedFloat32Array = []
## ¿Está el sistema tirando hacia el orden, o deshaciéndose? Es la histéresis.
var _buscando_orden: bool = true
## Cuantas veces ha respirado el enjambre desde que arranco.
var respiros: int = 0


func _ready() -> void:
	if tuning == null:
		tuning = EnjambreTuning.new()
	if palette == null:
		palette = GameState.palette
	reiniciar()


## Reparte fases y personalidades. Determinista: dos arranques dan lo mismo.
##
## Las fases iniciales se esparcen por el círculo con el ángulo áureo en vez de
## uniformemente. Repartidas uniformes, el sistema arranca en una configuración
## SIMÉTRICA y perfectamente dispersa, que es un punto de equilibrio del modelo:
## se queda ahí y no sincroniza nunca. El áureo llena el círculo sin cerrarlo.
func reiniciar() -> void:
	var n := tuning.agentes
	fases.resize(n)
	omegas.resize(n)
	_sordera.resize(n)
	_tiron.resize(n)
	_enganche.resize(n)
	const AUREO := PI * (3.0 - sqrt(5.0))
	for i in n:
		fases[i] = fposmod(float(i) * AUREO, TAU)
		omegas[i] = tuning.omega(i, n)
		_sordera[i] = 0.0
		_tiron[i] = 0.0
		_enganche[i] = 0.0
	k = tuning.k_min
	_buscando_orden = true
	_medir_orden()


func _physics_process(delta: float) -> void:
	if fases.is_empty():
		return
	_avanzar_acoplamiento(delta)
	marcapasos_fase = fposmod(marcapasos_fase + marcapasos_omega * delta, TAU)
	_integrar(delta)
	_medir_orden()
	_medir_enganche(delta)
	_publicar()
	# EL TIRÓN CADUCA, igual que `PlayerController.pedir_postura()`. Es una
	# petición por frame y no un estado: quien quiera escolta la pide cada frame, y
	# el día que deje de pedirla la bandada se suelta sola. Un tirón que se queda
	# puesto es un enemigo que sigue llamando después de morirse.
	for i in _tiron.size():
		_tiron[i] = 0.0


## LA ECUACIÓN. Un paso de Euler por frame.
##
## Euler y no Runge-Kutta a propósito: esto no es una simulación que tenga que
## conservar nada —a diferencia del péndulo, donde la regla dura #16 obliga a
## cuidar la energía—. Es un sistema disipativo que TIENDE a un atractor, y el
## error de Euler se lo come el propio acoplamiento. Un integrador caro aquí
## compraría precisión que nadie puede ver.
##
## **Y EN CAMPO MEDIO, QUE NO ES UNA APROXIMACIÓN: ES LA MISMA SUMA.**
##
##     (1/N) · Σⱼ sin(θⱼ − θᵢ)  ≡  r · sin(ψ − θᵢ)
##
## Sale de desarrollar el seno y reconocer que Σcos θⱼ y Σsin θⱼ son las dos
## componentes del número complejo cuyo módulo es `r` y cuyo argumento es `ψ` —los
## dos que `_medir_orden()` ya calcula—. El término j = i vale sin(0) = 0, así que
## incluirlo o excluirlo da lo mismo y la identidad es exacta, no un promedio.
##
## Importa porque el coste pasa de **O(N²) a O(N)**. Con las 9 Criaturas de Tela
## daba igual —81 senos—; con las 180 luciérnagas del mundo son 32.400 senos por
## frame en GDScript contra 180. Es lo que permite que el mismo modelo, ya medido
## y probado, mueva un enjambre de cientos sin tocar una línea de su física.
func _integrar(delta: float) -> void:
	var n := fases.size()
	var nuevas := fases.duplicate()
	for i in n:
		# La sordera de una perturbación reciente le baja el acoplamiento SOLO a
		# ella. Sin esto vuelve a engancharse tan rápido que perturbar no se ve.
		var sordo: float = 1.0
		if _sordera[i] > 0.0:
			_sordera[i] = maxf(0.0, _sordera[i] - delta)
			var f := _sordera[i] / tuning.perturbacion_duracion
			sordo = 1.0 - tuning.perturbacion_sordera * f
		var tiron := k * orden * sin(fase_media - fases[i]) * sordo
		# EL FORZAMIENTO EXTERNO, sumado al del grupo. La sordera lo apaga
		# también: una criatura recién perturbada no oye a nadie, ni al grupo ni
		# al marcapasos, y esa es justo la ventana en la que se la ve suelta.
		var externo := _tiron[i] * sin(marcapasos_fase - fases[i]) * sordo
		nuevas[i] = fposmod(fases[i] + (omegas[i] + tiron + externo) * delta, TAU)
	fases = nuevas


## `r = |(1/N) Σ e^{iθ}|`, y de paso la fase media, que es el argumento del mismo
## número complejo. Se calculan juntas porque son la misma suma.
## QUIEN SE HA IDO NO CUENTA PARA EL GRUPO.
##
## Cada agente pesa `1 − enganche`: el que se ha ido con el marcapasos deja de
## contar en la media del enjambre. Sin esto, el grupo persigue a sus propias
## escoltas —su fase media se va detras de ellas— y en cuanto una engancha se van
## todas. Con el peso, la bandada que se queda mantiene su fase y sigue siendo una
## bandada.
##
## No toca al modelo cuando no hay marcapasos: sin tiron, `enganche` vale 0, los
## pesos valen 1 y esto es exactamente la formula de siempre. `TestEnjambre` sigue
## dando los mismos 9.6 / 19.6 / 7.3 s.
func _medir_orden() -> void:
	var n := fases.size()
	if n == 0:
		return
	var sx := 0.0
	var sy := 0.0
	var peso_total := 0.0
	for i in n:
		var w: float = 1.0 - (_enganche[i] if i < _enganche.size() else 0.0)
		sx += cos(fases[i]) * w
		sy += sin(fases[i]) * w
		peso_total += w
	# Si se han ido TODAS, no queda bandada de la que medir el orden. Se conserva
	# la ultima fase media y el orden cae a cero, que es lo que de verdad pasa.
	if peso_total < 0.001:
		orden = 0.0
		return
	sx /= peso_total
	sy /= peso_total
	orden = sqrt(sx * sx + sy * sy)
	fase_media = atan2(sy, sx)


## El acoplamiento persigue al orden, con histéresis. Ver la cabecera.
func _avanzar_acoplamiento(delta: float) -> void:
	if _buscando_orden and orden >= tuning.orden_saciedad:
		_buscando_orden = false
		# LA RESPIRACION SE ANUNCIA. El enjambre llega al acuerdo y se cansa: ese
		# instante es el unico hito que el modelo produce por si solo, y por eso
		# vale como pulso de ESTRUCTURA. La estacion de jam lo usa para mover el
		# centro armonico — la armonia cambia cuando el grupo se pone de acuerdo,
		# no cuando lo dice un temporizador.
		respiro.emit(respiros)
		respiros += 1
	elif not _buscando_orden and orden <= tuning.orden_hambre:
		_buscando_orden = true

	if _buscando_orden:
		k = minf(k + tuning.k_subida * delta, tuning.k_max)
	else:
		k = maxf(k - tuning.k_bajada * delta, tuning.k_min)


## MEDIR EL ENGANCHE. Cuánto va cada agente al paso del marcapasos, de 0 a 1.
##
## Se mide con `max(0, cos(θᵢ − ψ))` promediado en el tiempo, y las dos mitades
## importan:
##
##   · el COSENO porque es 1 cuando van a la vez y baja solo; un umbral duro sobre
##     la diferencia de fase daría un booleano que parpadea en el borde.
##   · el PROMEDIO porque un agente suelto pasa por delante del marcapasos una vez
##     por vuelta y, en ese instante, es indistinguible de uno enganchado. Lo que
##     separa la coincidencia del enganche es cuánto DURA — la misma lección que el
##     control sin acoplamiento de `TestEnjambre`.
##
## Medido: enganchado tiende a ~1.0; suelto se queda en ~0.32, que es la media de
## `max(0, cos)` sobre una fase uniforme (1/π). Separación de sobra.
##
## Y sin tirón, cero: el enganche no es "voy en fase por casualidad", es "me están
## llevando".
func _medir_enganche(delta: float) -> void:
	var peso: float = 1.0 - exp(-delta / maxf(tuning.enganche_suavizado, 0.01))
	for i in _enganche.size():
		var objetivo := 0.0
		if _tiron[i] > 0.0001:
			objetivo = maxf(0.0, cos(fases[i] - marcapasos_fase))
		_enganche[i] = lerpf(_enganche[i], objetivo, peso)


## Pide que el marcapasos tire del agente `i` con fuerza `A` ESTE frame.
##
## Es la A de la condición de enganche: por encima de `|ωᵢ − Ω|` se lo lleva, por
## debajo no. Quien la pide decide con qué criterio —la distancia al jugador, la
## cercanía a un altar, lo que sea—; el modelo solo aplica la ecuación.
func pedir_tiron(i: int, fuerza: float) -> void:
	if i < 0 or i >= _tiron.size():
		return
	_tiron[i] = maxf(_tiron[i], maxf(fuerza, 0.0))


## Cuánto va el agente `i` al paso del marcapasos, de 0 a 1.
func enganche_de(i: int) -> float:
	return _enganche[i] if i >= 0 and i < _enganche.size() else 0.0


## Cuántos van enganchados ahora mismo. Es la medida honesta de "algunas, no
## todas": si esto sale 0 o sale N, el marcapasos está mal afinado.
func enganchados(umbral: float = 0.6) -> int:
	var n := 0
	for e in _enganche:
		if e >= umbral:
			n += 1
	return n


## PERTURBAR una criatura: le mueve la fase y la deja sorda un rato.
##
## Es la interacción entera. El usuario no controla a nadie: **desordena**, y el
## sistema se recompone solo. Que la recomposición sea visible es todo el efecto,
## y por eso la sordera dura `perturbacion_duracion` en vez de ser instantánea.
func perturbar(indice: int) -> void:
	if indice < 0 or indice >= fases.size():
		return
	fases[indice] = fposmod(fases[indice] + tuning.perturbacion_fase, TAU)
	_sordera[indice] = tuning.perturbacion_duracion
	_medir_orden()
	perturbado.emit(indice)


## Perturba a la criatura más cercana a un punto del mundo. Es lo que usa el
## observador: señala, no elige un índice.
func perturbar_cerca(punto: Vector3, radio: float = 3.0) -> int:
	var mejor := -1
	var mejor_d := radio * radio
	for i in get_child_count():
		var c := get_child(i) as CriaturaTela
		if c == null:
			continue
		var d := c.global_position.distance_squared_to(punto)
		if d < mejor_d:
			mejor_d = d
			mejor = c.indice
	if mejor >= 0:
		perturbar(mejor)
	return mejor


# --- Lo que leen la manifestación visual y el audio ---------------------------

## Valor del ciclo de la criatura `i`, de 0 a 1. Es `(sin(θ)+1)/2`: lo que sube y
## baja con la fase, y de lo que cuelga TODA la manifestación —color, opacidad,
## escala, pitch—. Un solo número por agente y por frame.
func ciclo_de(i: int) -> float:
	if i < 0 or i >= fases.size():
		return 0.0
	return (sin(fases[i]) + 1.0) * 0.5


## Fase cruda de la criatura `i`, en radianes.
##
## `ciclo_de()` es `(sinθ+1)/2` y sirve para todo lo que sube y baja una vez por
## vuelta —color, opacidad, escala, pitch—. Pero una TRAYECTORIA necesita el
## ángulo entero: con solo el ciclo, dos puntos distintos del recorrido que
## comparten altura son indistinguibles, y el movimiento sale de ida y vuelta por
## la misma línea en vez de cerrar una figura.
func fase_de(i: int) -> float:
	if i < 0 or i >= fases.size():
		return 0.0
	return fases[i]


## Cuánto se DESVÍA esta criatura del enjambre, de 0 a 1. Cero = va con el grupo.
##
## Es lo que hace legible la sincronización sin números: una criatura desviada se
## pinta distinto de las demás, y cuando todas convergen el enjambre se vuelve un
## solo color. `project.md §5` lo pide así —"fase → color"— y por la misma razón
## que `Enemigo._actualizar_color()`: el color ya es el canal de estado del juego.
func desvio_de(i: int) -> float:
	if i < 0 or i >= fases.size():
		return 0.0
	var d := absf(wrapf(fases[i] - fase_media, -PI, PI))
	return d / PI


## Pitch de la criatura `i`, en Hz. Sube y baja con su ciclo, y el usuario
## desplaza el conjunto en semitonos.
func pitch_de(i: int) -> float:
	var semitonos := (ciclo_de(i) * 2.0 - 1.0) * tuning.pitch_rango * 12.0 + pitch_usuario
	return tuning.pitch_base * pow(2.0, semitonos / 12.0)


## Amplitud de la criatura `i`, de 0 a 1. **Las desviadas cantan más flojo.**
##
## Es lo que convierte el orden en volumen: dispersas se oye un murmullo de voces
## sueltas, al unísono se oye un acorde. Sin esto, el caos y el orden suenan igual
## de fuerte y la transición no se oye.
func amplitud_de(i: int) -> float:
	return ciclo_de(i) * (1.0 - desvio_de(i) * 0.65)


## --- Para capturas y medidas ---------------------------------------------------

## Deja el MODELO quieto. Las criaturas siguen vivas: con las fases congeladas no
## se mueven, pero siguen redibujándose —y la cola se orienta a la cámara, así
## que tiene que poder rehacerse cuando el encuadre cambie.
func congelar() -> void:
	set_physics_process(false)


## Avanza el sistema ENTERO —modelo, criaturas y colas— un tiempo EXACTO, a pasos
## de dt fijo.
##
## Existe por el screenshot test. Una captura se dispara contando frames de
## RENDER, y entre dos de esos caben un número variable de frames de física según
## lo que tarde la máquina: dejar que el enjambre corra solo hasta la foto da una
## fase distinta en cada pasada. Es el mismo fallo que tuvo la toma del agua y se
## arregla igual —ahí con `tiempo_fijo` en el shader, aquí con esto—.
##
## Pisa a las criaturas a mano en vez de esperar sus callbacks porque avanzar solo
## el modelo las dejaría saltando de su posición inicial a la final de una vez, y
## la cola dibujaría ese salto como un latigazo.
func avanzar(segundos: float, dt: float = 1.0 / 60.0) -> void:
	for _i in int(segundos / dt):
		_physics_process(dt)
		for h in get_children():
			var c := h as CriaturaTela
			if c != null:
				c._physics_process(dt)


func _publicar() -> void:
	var n := fases.size()
	var p := PackedFloat32Array()
	var a := PackedFloat32Array()
	p.resize(n)
	a.resize(n)
	for i in n:
		p[i] = pitch_de(i)
		a[i] = amplitud_de(i)
	ciclo.emit(p, a, orden)


func debug_line() -> String:
	return "r=%.2f  K=%.2f  %s" % [orden, k, "buscando" if _buscando_orden else "soltando"]
