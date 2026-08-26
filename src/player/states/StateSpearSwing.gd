extends PlayerState
## BALANCEO colgado de la lanza clavada. El péndulo.
##
## **Restricción analítica, no un joint de física.** El jugador es un
## `CharacterBody3D`: cinemático. Los joints de Godot restringen dinámicas de
## `RigidBody3D` y atados a un cuerpo cinemático no hacen nada — no es una
## preferencia de estilo, es que el nodo no reacciona. `docs/03 §5` ya lo dejaba
## escrito: *"no uses un joint de física para el jugador. Restricción analítica"*.
##
## El algoritmo entero cabe en tres frases:
##
##   1. Cae con gravedad. Un péndulo sin gravedad es un radio fijo, no un péndulo.
##   2. El stick empuja a lo largo del ARCO, no contra la cuerda. Eso es bombear:
##      es como se gana altura en un columpio de verdad.
##   3. Si te alejas más que el largo de cuerda, se te devuelve al radio y se te
##      quita **solo la componente que se aleja** de la velocidad. La que va por
##      el arco se conserva entera, y esa es toda la magia: la energía no se
##      pierde al tensar, se convierte en giro.
##
## Soltarse conserva la inercia. Si al soltar te frenaras, el balanceo no serviría
## para desplazarse, y entonces no serviría para nada.

var _ancla: Vector3 = Vector3.ZERO
var _largo: float = 0.0
var _soltado_a_mano: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_soltado_a_mano = false
	player.enderezar()
	_ancla = _punto_ancla()
	# El largo es la distancia a la que te enganchaste, no un valor fijo: engancharse
	# de cerca da un arco corto y rápido, de lejos uno largo y amplio. Que el jugador
	# elija el radio con la posición desde la que se cuelga es control gratis.
	_largo = clampf(player.global_position.distance_to(_ancla), 1.0, tuning.swing_largo_max)
	# Y ademas: LA CUERDA SE ACORTA para que el fondo del arco no quede bajo
	# tierra. Colgarse de un ancla a 5 m con 7 m de cuerda pone el punto bajo dos
	# metros por debajo del suelo, asi que te estrellas en el primer cuarto de arco
	# y parece que el balanceo esta roto. Es lo que haria cualquiera con una cuerda
	# de verdad: agarrarla mas arriba.
	var libre := _ancla.y - _suelo_bajo(_ancla) - tuning.swing_altura_minima
	if libre > 1.0:
		_largo = minf(_largo, libre)
	EventBus.camara_shake.emit(0.2, 0.1)


func physics_update(delta: float) -> void:
	if not _colgable():
		_soltar()
		return

	# SALTAR SUELTA LA CUERDA. Es el gesto que cualquiera prueba: el balanceo se
	# usa para LLEGAR a algun sitio, y llegar termina en un salto.
	#
	# Va aqui y no en un `handle_input()`: esa funcion aparece en la documentacion
	# pero la FSM de este proyecto no la llama nunca, asi que ponerla ahi habria
	# sido escribir codigo que no se ejecuta jamas. Todos los estados usan
	# `physics_update`.
	if player.consumir_salto():
		_soltado_a_mano = true
		fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true}, true)
		return

	_ancla = _punto_ancla()
	player.stamina.drenar(tuning.swing_stamina, delta)

	# 1) GRAVEDAD, y SIMÉTRICA. El motor del péndulo.
	#
	# No se usa `motor.aplicar_gravedad()` a propósito: la del juego es asimétrica
	# —-38 cayendo, -22 subiendo—, que es medio game feel gratis en un salto y
	# **rompe un péndulo**. Subes con menos peso del que caíste, así que cada
	# pasada devuelve más energía de la que costó: medido, el arco salía 6 m por
	# ENCIMA de donde empezó. Un columpio que sube solo no es un columpio.
	player.velocity += sc.gravedad_actual(tuning.swing_gravedad) * delta

	# 2) BOMBEO. La entrada se proyecta sobre el plano perpendicular a la cuerda:
	#    empujar hacia el ancla o hacia fuera no haría nada —la restricción lo
	#    deshace— así que solo cuenta lo que va por el arco.
	var entrada := buffer.move_vector()
	if entrada.length() > 0.2:
		var deseada := sc.direccion_movimiento(entrada, player.camara())
		var radial := (player.global_position - _ancla).normalized()
		var tangente := deseada - radial * deseada.dot(radial)
		if not tangente.is_zero_approx():
			player.velocity += tangente.normalized() * tuning.swing_bombeo * delta

	# 3) LA RESTRICCIÓN.
	_tensar()

	# Pérdida: un péndulo sin rozamiento es perpetuo y se siente a máquina.
	player.velocity *= 1.0 - tuning.swing_perdida * delta

	# Mirando hacia donde vas, no hacia el ancla: lo que importa es el arco.
	var avance := sc.plano(player.velocity)
	if avance.length() > 1.0:
		player.orientar_a(avance)

	# Aterrizar suelta la cuerda, pero NO en el primer instante: `is_on_floor()`
	# refleja el ultimo `move_and_slide`, o sea el frame ANTERIOR, asi que al
	# engancharse desde el borde de una plataforma seguia diciendo "hay suelo" y
	# el balanceo se cortaba antes de empezar. Nadie aterriza en la primera
	# decima de un columpio que acaba de empezar.
	if t > 0.12 and player.is_on_floor() and sc.vertical(player.velocity) <= 0.0:
		_soltar()


func exit(_siguiente: StringName = &"") -> void:
	# CONSERVA LA INERCIA, siempre. Frenar al soltar convertiría el balanceo en un
	# adorno: llegarías al final del arco con la velocidad que traías y te
	# quedarías ahí colgado en el aire.
	if _soltado_a_mano:
		player.velocity += sc.up * tuning.swing_salida


## Solo se cuelga uno de una lanza CLAVADA. De una en vuelo no hay nada que
## sostenga el peso, y de una en la mano menos.
func _colgable() -> bool:
	var l: Spear = player.lanza
	if l == null or not is_instance_valid(l):
		return false
	return l.clavada_en_algo()


## Y del suelo bajo un punto. Si no encuentra nada, se queda con la del propio
## punto: sin suelo debajo no hay contra que estrellarse.
func _suelo_bajo(punto: Vector3) -> float:
	var espacio := player.get_world_3d().direct_space_state
	var desde := punto + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(
		desde, desde + Vector3.DOWN * (tuning.swing_largo_max + 10.0), Layers.SUELO_JUGADOR)
	q.exclude = [player.get_rid()]
	var r := espacio.intersect_ray(q)
	return (r.position as Vector3).y if not r.is_empty() else punto.y


func _punto_ancla() -> Vector3:
	var l: Spear = player.lanza
	return l.global_position if l != null and is_instance_valid(l) else _ancla


## La restricción de distancia, que es todo el péndulo.
##
## Si estás más lejos que el largo: te devuelve al radio y te quita la componente
## de velocidad que se ALEJA. La tangencial no se toca, y por eso el balanceo
## acelera al bajar en vez de frenarse contra la cuerda.
##
## `maxf(..., 0.0)` importa: acercarse al ancla es libre. Una cuerda tira, no
## empuja, y quitar también la componente que se acerca convertiría la cuerda en
## una barra rígida.
func _tensar() -> void:
	var hacia := player.global_position - _ancla
	var dist := hacia.length()
	if dist <= _largo or dist < 0.001:
		return
	var radial := hacia / dist
	player.global_position = _ancla + radial * _largo
	player.velocity -= radial * maxf(player.velocity.dot(radial), 0.0)


func _soltar() -> void:
	if player.is_on_floor():
		fsm.cambiar(&"Idle")
	else:
		fsm.cambiar(&"Fall")


## Ver `PlayerState.techo_velocidad()`: medido, no inventado. Con el clamp global
## de 22 el arco perdia altura en cada pasada porque se le quitaba energia justo
## abajo, que es donde el pendulo es horizontal.
func techo_velocidad() -> float:
	return tuning.swing_velocidad_max


func maneja_salto() -> bool:
	return true


func debug_line() -> String:
	return "SWING  r=%.1f/%.1f  v=%.1f" % [
		player.global_position.distance_to(_ancla), _largo, player.velocity.length()]
