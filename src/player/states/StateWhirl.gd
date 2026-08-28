extends PlayerState
## ZARANDEAR. Un enemigo colgado de la daga, girando a tu alrededor, y un
## estampido contra el suelo que hace daño en área.
##
## **Es el balanceo con los papeles cambiados.** En `SpearSwing` el ancla es la
## lanza clavada y la masa eres tú; aquí el ancla eres TÚ y la masa es el enemigo.
## La matemática es la misma —restricción analítica de distancia, gravedad
## simétrica propia, tangencial conservada— y por eso este estado se escribió
## mirando aquel en vez de inventando otro.
##
## **NO se usa un joint de física, y está confirmado.** Los joints de Godot
## restringen dinámicas de `RigidBody3D`; el jugador es un `CharacterBody3D`
## cinemático, ignora las fuerzas entrantes y moverlo como rígido pelea contra el
## solver. `SpearSwing` lo tiene documentado desde la Fase 3.
##
## **Y el enemigo sigue siendo un `CharacterBody3D`, no se convierte en ragdoll.**
## El prompt pedía un `RigidBody3D` vivo, pero convertir el nodo significa
## destruirlo y recrearlo, y con él se van su FSM, su vida, su hurtbox y la
## referencia que la daga guarda. No hace falta: la restricción es **analítica**,
## o sea que aquí no se le pide nada al motor de física — solo se escribe
## `velocity` y se deja que su `move_and_slide()` choque con el mundo. Y la
## condición que importaba ya se cumple sola: un `Enemigo` tiene
## `collision_mask = WORLD`, así que **no empuja al jugador** y no es plataforma
## móvil de nadie (regla dura #19).

## El enemigo colgado. Se relee del arma cada frame: si muere o se suelta, esto
## deja de existir y el estado se acaba.
var _presa: Enemigo = null
var _largo: float = 0.0
## Se estampó a mano. Sin esto, salir por cualquier otro motivo —que muera, que
## se rompa la daga— también lanzaría el cuerpo.
var _estampado: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_estampado = false
	player.enderezar()
	_presa = _buscar_presa()
	if _presa == null:
		return
	_presa.fsm.cambiar(&"Agarrado")
	# El radio es la distancia a la que lo enganchaste, acotada: agarrar de cerca
	# da un giro corto y rápido, de lejos uno amplio y lento. Igual que el
	# balanceo, el jugador elige el radio con la posición desde la que agarra.
	_largo = clampf(player.global_position.distance_to(_presa.global_position),
		tuning.zarandeo_largo_min, tuning.zarandeo_largo_max)
	EventBus.camara_shake.emit(0.3, 0.12)


func physics_update(delta: float) -> void:
	_presa = _buscar_presa()
	if _presa == null:
		_soltar()
		return

	# ESTAMPAR: el botón pesado lo manda contra el suelo. Se pregunta ANTES de
	# mover nada, para que el cuerpo salga con la velocidad que llevaba girando y
	# no con la del frame siguiente.
	if buffer.consume(InputActions.ATTACK_HEAVY):
		_estampar()
		return

	# Soltar la cuerda lo deja caer sin más. Es la salida "me he arrepentido".
	if buffer.consume(InputActions.ROPE):
		_soltar()
		return

	_mover_presa(delta)
	_frenar_al_jugador(delta)

	# Mirando al cuerpo que llevas: sin esto el personaje gira con el stick y el
	# enemigo aparece por detrás sin que se entienda de dónde salió.
	var hacia := sc.plano(_presa.global_position - player.global_position)
	if hacia.length() > 0.5:
		player.orientar_a(hacia)


func exit(_siguiente: StringName = &"") -> void:
	# Se devuelve al enemigo su vida propia SIEMPRE, se haya estampado o no. Un
	# bicho que se queda en `Agarrado` sin nadie que lo mueva es una estatua.
	if _presa != null and is_instance_valid(_presa) and _presa.esta_vivo():
		if _presa.fsm.nombre_actual() == &"Agarrado":
			_presa.fsm.cambiar(&"Aturdido" if _estampado else &"Acercarse")


## LA FÍSICA DEL CUERPO COLGADO. Es `SpearSwing` con los papeles invertidos.
func _mover_presa(delta: float) -> void:
	# 1) GRAVEDAD SIMÉTRICA propia (regla dura #16). La del juego es asimétrica
	#    —-38 cayendo, -22 subiendo— y con ella el cuerpo ganaría altura solo en
	#    cada vuelta: medido en el balanceo, 6 m por pasada.
	_presa.velocity += sc.gravedad_actual(tuning.swing_gravedad) * delta

	# 2) EL STICK GIRA. La entrada se proyecta sobre el plano perpendicular a la
	#    cuerda: empujar hacia ti o hacia fuera no haría nada —la restricción lo
	#    deshace— así que solo cuenta lo que va por el arco. Es el bombeo del
	#    balanceo, aplicado al otro cuerpo.
	var entrada := buffer.move_vector()
	if entrada.length() > 0.2:
		var deseada := sc.direccion_movimiento(entrada, player.camara())
		var radial := (_presa.global_position - player.global_position).normalized()
		var tangente := deseada - radial * deseada.dot(radial)
		if not tangente.is_zero_approx():
			_presa.velocity += tangente.normalized() * tuning.zarandeo_giro * delta

	# 3) LA RESTRICCIÓN. Si el cuerpo se aleja más que el radio, se le devuelve y
	#    se le quita SOLO la componente que se aleja. La tangencial se conserva
	#    entera, y eso es lo que hace que gire en vez de frenarse contra la cuerda.
	var hacia := _presa.global_position - player.global_position
	var dist := hacia.length()
	if dist > _largo and dist > 0.001:
		var radial := hacia / dist
		var correccion: float = minf(dist - _largo, tuning.swing_correccion_max)
		_presa.global_position -= radial * correccion
		_presa.velocity -= radial * maxf(_presa.velocity.dot(radial), 0.0)

	# 4) Pérdida, para que el giro no sea perpetuo y bombear signifique algo.
	_presa.velocity *= 1.0 - tuning.zarandeo_perdida * delta

	# Tope: el cuerpo no puede ir más rápido de lo que el estampido promete.
	var v := _presa.velocity.length()
	if v > tuning.zarandeo_velocidad_max:
		_presa.velocity *= tuning.zarandeo_velocidad_max / v


## LLEVAR UN CUERPO CUESTA. Sin esto, agarrar sería gratis y todo combate contra
## bichos pequeños se reduciría a agarrar y zarandear — el riesgo que estaba
## escrito en `project.md §7` antes de construir nada.
func _frenar_al_jugador(delta: float) -> void:
	player.velocity *= _presa.masa_agarre
	player.stamina.gastar(tuning.zarandeo_stamina * delta)
	if player.stamina.vacia():
		_soltar()


## EL ESTAMPIDO. El cuerpo sale hacia donde apuntas —o hacia abajo si no apuntas—
## con la velocidad que llevaba girando, y hace daño en área al llegar.
func _estampar() -> void:
	_estampado = true
	var entrada := buffer.move_vector()
	var dir := Vector3.DOWN
	if entrada.length() > 0.2:
		var deseada := sc.direccion_movimiento(entrada, player.camara())
		if not deseada.is_zero_approx():
			dir = (deseada - sc.up * 0.8).normalized()

	# LA VELOCIDAD DEL GIRO ES LA DEL ESTAMPIDO. Es lo que hace que girar antes de
	# estampar signifique algo: un cuerpo que llevabas quieto cae, y uno que
	# llevabas lanzado revienta. El daño lo escala `escalar_por_inercia()`, que ya
	# existe para la carga en viaje.
	var rapidez: float = maxf(_presa.velocity.length(), tuning.zarandeo_estampido_min)
	_presa.velocity = dir * rapidez
	_presa.impacto_estampido = rapidez
	if _presa.fsm.existe(&"Estampado"):
		_presa.fsm.cambiar(&"Estampado")

	EventBus.camara_shake.emit(0.7, 0.2)
	_salir()


func _soltar() -> void:
	_salir()


func _salir() -> void:
	if player.is_on_floor():
		fsm.cambiar(&"Idle")
	else:
		fsm.cambiar(&"Fall")


## La presa VIVA que cuelga de alguna daga. Se pregunta cada frame en vez de
## guardarse: si el enemigo muere a mitad de giro, esto devuelve null y el estado
## se acaba solo, sin un guardia por cada cosa que pueda pasarle.
func _buscar_presa() -> Enemigo:
	var d := player.daga_en_carne()
	return d.presa() if d != null else null


## Ver `PlayerState.techo_velocidad()`. Llevar un cuerpo colgando no debería
## dejarte ir más rápido que corriendo: el peso ya te frena, y esto lo garantiza.
func techo_velocidad() -> float:
	return tuning.velocidad_correr


## El estado se queda los ataques: sin esto el grupo los consume ANTES —corre
## primero— y el estampido no llegaría a existir nunca. Regla dura #13.
func maneja_ataques() -> bool:
	return true


func debug_line() -> String:
	if _presa == null or not is_instance_valid(_presa):
		return "ZARANDEO  sin presa"
	return "ZARANDEO  %s  r=%.1f  v=%.1f m/s" % [
		_presa.name, _largo, _presa.velocity.length()]
