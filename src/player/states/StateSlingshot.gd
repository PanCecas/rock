extends PlayerState
## LA RESORTERA. Colgado de DOS anclajes, tiras hacia atrás y sales disparado.
##
## Es el hermano de `SpearSwing` y la diferencia es de topología, no de números:
##
##   UN punto  -> péndulo. Caes en arco alrededor de él y bombeas con el stick.
##   DOS puntos -> elástico. No hay arco: hay un punto de reposo entre los dos, y
##                todo lo que te alejes de él vuelve como velocidad.
##
## Y por eso no se puede sacar del balanceo cambiándole un número: un péndulo
## CONSERVA energía —la restricción no hace trabajo, solo gira la velocidad— y una
## resortera la ALMACENA y la devuelve de golpe. Son dos sistemas distintos.
##
## **Las cuerdas se estiran, y eso es la mecánica.** En el balanceo la cuerda es
## inextensible: pasarte del radio te devuelve a él. Aquí no, porque si no hubiera
## nada que estirar no habría nada que tensar. Cada cuerda es un muelle: tira de
## vuelta con fuerza proporcional a lo estirada que esté (`resortera_rigidez`), y
## el disparo es la suma de las dos.
##
## **La dirección del disparo es la suma vectorial, no el punto medio.** Cada
## banda empuja hacia SU anclaje con fuerza proporcional a su estiramiento, así
## que el disparo sale por donde sale la suma. Con las dos igual de tensas eso es
## la bisectriz —lo que uno espera de un tirachinas—, pero con una más tensa que
## la otra el tiro se ladea hacia ella, que es también lo que uno espera. Usar el
## punto medio daría siempre la bisectriz y perdería justo la mitad del control.
##
## **Gravedad propia y simétrica**, por la regla dura #16: la del juego es
## asimétrica y cualquier cosa que almacene y devuelva energía se rompe con ella.

## Los dos anclajes, releídos cada frame: en la Fase 4 se moverán con el coloso.
var _a: Vector3 = Vector3.ZERO
var _b: Vector3 = Vector3.ZERO
## Largo de reposo de cada cuerda. Se fija al engancharse.
var _largo_a: float = 0.0
var _largo_b: float = 0.0
## Tensión acumulada este frame, en m/s de disparo. Solo para el HUD y el debug.
var _tension: float = 0.0
## Se dispara al soltar; sin esto, salir del estado por cualquier otro motivo
## —perder un anclaje, aterrizar— también catapultaría.
var _disparado: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_disparado = false
	_tension = 0.0
	player.enderezar()
	_a = _punto_lanza()
	_b = _punto_anclaje()
	# El largo de reposo es la distancia a la que te enganchaste. Acotado por
	# arriba: engancharse desde cincuenta metros dejaría las dos cuerdas flojas y
	# no habría nada que tensar hasta cruzar medio mapa.
	_largo_a = minf(player.global_position.distance_to(_a), tuning.resortera_largo_max)
	_largo_b = minf(player.global_position.distance_to(_b), tuning.resortera_largo_max)
	EventBus.camara_shake.emit(0.25, 0.1)


func physics_update(delta: float) -> void:
	if not _colgable():
		_soltar()
		return

	_a = _punto_lanza()
	_b = _punto_anclaje()

	# SOLTAR DISPARA. El botón de la cuerda es el gatillo: se entra manteniéndolo
	# y se sale soltándolo, que es literalmente el gesto de un tirachinas. Saltar
	# también dispara, porque es lo que prueba cualquiera.
	if not buffer.is_held(InputActions.ROPE) or buffer.consume(InputActions.JUMP):
		_disparar()
		return

	# 1) GRAVEDAD propia y simétrica (regla dura #16).
	player.velocity += sc.gravedad_actual(tuning.swing_gravedad) * delta

	# 2) EL STICK TENSA. No te desplaza: te aleja del punto de reposo contra dos
	#    elásticos que tiran de vuelta cada vez más fuerte. Alejarte cuesta, y ese
	#    coste creciente ES la sensación de estar cargando el tiro.
	var entrada := buffer.move_vector()
	if entrada.length() > 0.2:
		var deseada := sc.direccion_movimiento(entrada, player.camara())
		if not deseada.is_zero_approx():
			player.velocity += deseada.normalized() * tuning.resortera_empuje * delta

	# 3) LAS DOS BANDAS. Cada una tira hacia su anclaje con fuerza proporcional a
	#    lo estirada que está, y la suma de las dos es lo que se dispara luego.
	var fuerza := _tirar(_a, _largo_a, delta) + _tirar(_b, _largo_b, delta)
	_tension = minf(fuerza.length() * tuning.resortera_multiplicador,
		tuning.resortera_fuerza_max)

	# 4) Rozamiento. Sin él el elástico devuelve toda la energía y te quedas
	#    rebotando entre los dos puntos sin poder apuntar a ningún sitio.
	player.velocity *= 1.0 - tuning.resortera_rozamiento * delta

	# 5) TOPE DURO de cada cuerda. Es lo que impide que tirar hacia atrás sin
	#    parar dé un disparo infinito: pasado el tope no se estira más, se acabó.
	_limitar(_a, _largo_a)
	_limitar(_b, _largo_b)

	# Mirando hacia donde vas a salir: el jugador tiene que ver a dónde apunta
	# ANTES de soltar, o disparar es adivinar.
	var apunta := _direccion_de_disparo()
	if not apunta.is_zero_approx():
		player.orientar_a(sc.plano(apunta))


func exit(_siguiente: StringName = &"") -> void:
	pass


## ¿Siguen los dos puntos donde estaban? Basta con que caiga uno para que esto
## deje de ser una resortera y pase a ser, como mucho, un péndulo.
func _colgable() -> bool:
	var l: Spear = player.lanza
	if l == null or not is_instance_valid(l) or not l.clavada_en_algo():
		return false
	# La daga tiene que seguir clavada en MUNDO. Ver `_resortera_lista()`.
	return player.daga_en_mundo() != null


func _punto_lanza() -> Vector3:
	var l: Spear = player.lanza
	return l.global_position if l != null and is_instance_valid(l) else _a


func _punto_anclaje() -> Vector3:
	var an: Anclaje = player.daga_en_mundo()
	return an.global_position if an != null and is_instance_valid(an) else _b


## Una banda: acelera al jugador hacia su anclaje según lo estirada que esté, y
## devuelve el vector de fuerza (dirección × metros estirados) para el disparo.
##
## Sin estirar no hace NADA: una cuerda floja no empuja, ni hacia dentro ni hacia
## fuera. Ese `maxf(..., 0.0)` es lo que separa una cuerda de una barra rígida.
func _tirar(ancla: Vector3, largo: float, delta: float) -> Vector3:
	var hacia := ancla - player.global_position
	var dist := hacia.length()
	var estirado := maxf(dist - largo, 0.0)
	if estirado <= 0.0 or dist < 0.001:
		return Vector3.ZERO
	var dir := hacia / dist
	player.velocity += dir * (estirado * tuning.resortera_rigidez) * delta
	return dir * estirado


## Tope duro de estiramiento. Se corrige la POSICIÓN y se quita la componente de
## velocidad que se aleja, igual que en el balanceo: es el mismo problema —una
## cuerda que no da más de sí— resuelto de la misma forma.
func _limitar(ancla: Vector3, largo: float) -> void:
	var maximo := largo + tuning.resortera_estirado_max
	var hacia := player.global_position - ancla
	var dist := hacia.length()
	if dist <= maximo or dist < 0.001:
		return
	var radial := hacia / dist
	# Acotada por frame, por lo mismo que en `SpearSwing._tensar()`: escribir la
	# posición se salta las colisiones, y un tirón grande te mete en la geometría.
	var correccion: float = minf(dist - maximo, tuning.swing_correccion_max)
	player.global_position -= radial * correccion
	player.velocity -= radial * maxf(player.velocity.dot(radial), 0.0)


## Por dónde sale el tiro: la SUMA de las dos bandas, no el punto medio.
func _direccion_de_disparo() -> Vector3:
	var f := _fuerza_actual()
	if not f.is_zero_approx():
		return f.normalized()
	# Sin tensión no hay dirección que dar. Se cae al punto medio, que es lo
	# único con sentido cuando cuelgas quieto entre los dos.
	var medio := (_a + _b) * 0.5 - player.global_position
	return medio.normalized() if not medio.is_zero_approx() else Vector3.ZERO


## Vector de fuerza de las dos bandas, en metros estirados. Se recalcula en vez de
## guardarse del frame anterior: el disparo tiene que usar la tensión que hay al
## soltar, no la que había un frame antes.
func _fuerza_actual() -> Vector3:
	var f := Vector3.ZERO
	for par in [[_a, _largo_a], [_b, _largo_b]]:
		var hacia: Vector3 = (par[0] as Vector3) - player.global_position
		var dist := hacia.length()
		var estirado: float = maxf(dist - float(par[1]), 0.0)
		if estirado > 0.0 and dist > 0.001:
			f += (hacia / dist) * estirado
	return f


## EL DISPARO. Toda la tensión acumulada se convierte en velocidad de golpe.
##
## Se SUMA a la velocidad que llevas en vez de escribirla: al soltar ya vienes
## moviéndote hacia dentro —los elásticos te están empujando—, y borrar eso para
## poner un número limpio le quitaría al disparo justo la parte que el jugador ha
## construido tirando.
func _disparar() -> void:
	_disparado = true
	var f := _fuerza_actual()
	var estirado := f.length()

	if estirado < tuning.resortera_estirado_min:
		# Soltar sin haber tensado no catapulta. Tenía que ser explícito: sin este
		# suelo, rozar el botón te lanzaba un metro y se leía como un fallo.
		_salir()
		return

	var salida: float = minf(estirado * tuning.resortera_multiplicador,
		tuning.resortera_fuerza_max)
	player.velocity += f.normalized() * salida + sc.up * tuning.resortera_subida
	# PERMISO DE VELOCIDAD. Sin esto el clamp global (22 m/s) se come el disparo
	# entero en el mismo frame, en silencio y solo en horizontal.
	player.momentum_libre = tuning.resortera_libertad
	EventBus.camara_shake.emit(0.9, 0.22)
	CombatFX.onda(player.get_parent(), player.global_position,
		player.color_de(&"blanco_tiza"), 2.4)

	# UN DISPARO SIEMPRE SALE A `Fall`, aunque estuvieras pisando suelo al soltar.
	# Con `_salir()` se caia en `Idle`, y la friccion de suelo se comia el tiro en
	# tres frames: tensabas de pie, salias disparado y te frenabas en el sitio.
	# El empujon vertical de `resortera_subida` es lo que hace que `GroupAirborne`
	# no te aterrice en el acto.
	fsm.cambiar(&"Fall")


func _soltar() -> void:
	_salir()


func _salir() -> void:
	if player.is_on_floor():
		fsm.cambiar(&"Idle")
	else:
		fsm.cambiar(&"Fall")


## Igual que el balanceo: colgarse no cuesta stamina, y por tanto quedarse a cero
## tampoco puede soltarte. Ver `SpearSwing.resiste_agotamiento()`.
func resiste_agotamiento() -> bool:
	return true


## El techo mientras tensas es el del disparo, no el global. Tirar hacia atrás
## contra dos elásticos no pasa de unos pocos m/s, pero el retroceso al soltar el
## stick sí, y recortarlo ahí le robaría tensión al tiro antes de dispararlo.
func techo_velocidad() -> float:
	return tuning.resortera_velocidad_max


## El estado se queda el salto: si no, el grupo lo consume ANTES —corre primero—
## y disparar con salto no llegaría a existir nunca. Regla dura #13.
func maneja_salto() -> bool:
	return true


## Y LA CUERDA, que aqui es la mecanica entera: la resortera TENSA mientras
## mantienes la Z y dispara al SOLTARLA. Sin este guardia el grupo consumiria la
## pulsacion cada frame, el estado se rearmaria desde cero y no dispararia jamas.
func maneja_cuerda() -> bool:
	return true


func debug_line() -> String:
	return "RESORTERA  tension %.1f m/s%s" % [_tension, "  DISPARADO" if _disparado else ""]
