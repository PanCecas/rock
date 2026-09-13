extends PlayerState
## LA CUERDA: UN ARCO, Y SE ACABÓ.
##
## Sustituye a los cuatro verbos de cuerda del 3.16 —balanceo, zip, resortera y
## zarandeo— y no por simplificar: porque los cuatro eran MODOS y esto es un
## MOVIMIENTO. La diferencia está en quién decide cuándo termina. Un modo lo
## decide el jugador soltándolo, así que mientras lo sostenga el juego es otro
## juego; un movimiento termina solo, y encadenarlo es la habilidad.
##
## Tres cosas lo definen y ninguna se negocia:
##
##   1. **Empieza en el frame en que se pulsa.** Cero anticipación, cero viaje. El
##      ancla la pone el nivel y ya está ahí: no hay que tirar nada ni acertar.
##   2. **Dura `cuerda_arco_max` y se suelta sola.** Con el arco abierto sin
##      límite se puede bombear pasada tras pasada y ganar altura indefinidamente,
##      y entonces el nivel deja de importar. Con un arco solo hay una decisión —
##      CUÁNDO SUELTAS— y esa sí es habilidad.
##   3. **El stick manda durante todo el arco.** Aceleración tangencial: abre el
##      giro, lo cierra, lo inclina. Lo único que no puede hacer es tirar de la
##      cuerda, porque la restricción lo deshace.
##
## **La física es una RESTRICCIÓN DE DISTANCIA, no una fuerza hacia el ancla.**
## Es toda la diferencia entre que se sienta cuerda y que se sienta imán: una
## fuerza te atrae y te deja oscilando radialmente; una restricción te deja el
## radio quieto y la velocidad tangencial intacta, así que el arco ACELERA al
## bajar en vez de pelearse consigo mismo.
##
## Y no se usa un joint de física: los joints de Godot restringen dinámicas de
## `RigidBody3D` y el jugador es un `CharacterBody3D` cinemático. Atado a él, un
## joint no hace absolutamente nada. `docs/03 §5` ya lo dejaba escrito.

## El ancla de la que colgamos. Se relee cada frame: si la destruyen a media
## pasada, el arco se acaba en vez de quedarse colgando de un punto fantasma.
var _ancla: Ancla = null
var _punto: Vector3 = Vector3.ZERO
## Radio del arco. Se fija AL ENGANCHAR y no se toca más. Ver `_elegir_largo()`.
var _largo: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	player.enderezar()
	var a: Variant = msg.get("ancla")
	_ancla = a as Ancla
	if _ancla == null or not is_instance_valid(_ancla):
		# Sin ancla no hay arco. No debería pasar —`intentar_cuerda()` no cambia de
		# estado sin una— pero un estado que se cuelga en silencio es peor que uno
		# que se cae al suelo.
		fsm.cambiar(&"Fall")
		return
	_punto = _ancla.global_position
	_largo = _elegir_largo()
	# LA CARGA SE GASTA AQUÍ, al entrar, y no al soltar. Una carga que se cobra a
	# la salida deja abierta la ventana de volver a engancharse durante el propio
	# arco, y eso es cuerda infinita con pasos extra.
	player.cuerda_disponible = false
	EventBus.camara_shake.emit(0.2, 0.1)


func physics_update(delta: float) -> void:
	# 1) SOLTAR EL BOTÓN TE SUELTA, y el tope sigue existiendo por encima.
	#
	#    Los dos, en este orden. El primero es el gesto —mantienes y te quedas
	#    colgado, sueltas y sales— y es lo que convierte el arco en un rango
	#    continuo de intenciones en vez de en un temporizador que hay que esperar:
	#    un toque da un gancho corto, mantener da el arco entero. Es el mismo
	#    perdón que el jump cut le hace al salto.
	#
	#    El segundo ya no es la mecánica, es el techo: colgarse no puede ser
	#    eterno. Lo que impide BOMBEAR no es este reloj —es `cuerda_perdida`.
	if t >= tuning.cuerda_arco_min and not buffer.is_held(InputActions.ROPE):
		_soltar()
		return
	if t >= tuning.cuerda_arco_max:
		_soltar()
		return

	# 2) El ancla tiene que seguir existiendo.
	if _ancla == null or not is_instance_valid(_ancla):
		_soltar()
		return
	_punto = _ancla.global_position

	# 3) SALTAR TAMBIÉN SUELTA, y es el otro gesto natural: el arco sirve para
	#    LLEGAR a algún sitio, y llegar termina en un salto. Conserva la velocidad
	#    igual que soltar el botón; ver `exit()`.
	if player.consumir_salto():
		fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true}, true)
		return

	# 4) GRAVEDAD, y SIMÉTRICA. Sin ella el arco no es un arco: llegarías al radio
	#    sin nada tangencial y te quedarías colgado. Regla dura #16 para el porqué
	#    de no usar `motor.aplicar_gravedad()`.
	player.velocity += sc.gravedad_actual(tuning.cuerda_gravedad) * delta

	# 5) EL STICK, PROYECTADO SOBRE EL ARCO. Se le quita la componente radial
	#    porque la restricción se la comería de todas formas: dejarla dentro haría
	#    que empujar hacia el ancla se sintiera como un botón muerto en vez de
	#    como lo que es —una dirección que esta mecánica no tiene—.
	var entrada := buffer.move_vector()
	if entrada.length() > 0.2:
		var deseada := sc.direccion_movimiento(entrada, player.camara())
		var radial := (player.global_position - _punto).normalized()
		var tangente := deseada - radial * deseada.dot(radial)
		if not tangente.is_zero_approx():
			player.velocity += tangente.normalized() * tuning.cuerda_tangencial * delta

	# 6) PÉRDIDA. Un péndulo sin rozamiento es perpetuo, y con el stick metiendo
	#    tangencial cada frame no es perpetuo: es creciente. Esto es lo que impide
	#    bombear ahora que el arco se puede mantener, y por eso no es un adorno.
	player.velocity *= 1.0 - tuning.cuerda_perdida * delta

	# 7) Mirando hacia donde vas, no hacia el ancla: lo que se lee es el arco.
	var avance := sc.plano(player.velocity)
	if avance.length() > 1.0:
		player.orientar_a(avance)


## LA RESTRICCIÓN, y corre DESPUÉS de `move_and_slide()`.
##
## Ese orden importa y es el que no tenía la versión anterior. Reproyectar antes
## de mover significa restringir una posición que el motor todavía va a cambiar:
## el jugador termina el frame fuera de la esfera y la corrección del frame
## siguiente hereda el error. Después de mover, la posición que se corrige es la
## definitiva y la de colisión, que es la única contra la que la cuerda tiene algo
## que decir.
##
## `maxf(..., 0.0)` es el detalle que hace que sea una cuerda: solo se quita la
## componente que se ALEJA. Acercarse al ancla es libre, porque una cuerda tira
## pero no empuja — quitar también la que se acerca la convertiría en una barra.
func post_move(_delta: float) -> void:
	var hacia := player.global_position - _punto
	var dist := hacia.length()
	if dist <= _largo or dist < 0.001:
		return
	var radial := hacia / dist
	# La corrección de POSICIÓN va acotada: escribir `global_position` salta por
	# encima de las colisiones, y un tirón grande metería al jugador dentro de la
	# geometría. Con tope, la mayor parte del trabajo la hace la velocidad.
	var correccion: float = minf(dist - _largo, tuning.cuerda_correccion_max)
	var desplazamiento := -radial * correccion
	player.global_position += desplazamiento
	player.velocity -= radial * maxf(player.velocity.dot(radial), 0.0)

	# Y SE PAGA LA ALTURA QUE REGALA LA CORRECCIÓN.
	#
	# Moverse en línea recta un frame deja al jugador un pelín FUERA de la esfera
	# —la cuerda del arco es más corta que el arco—, así que cada frame hay que
	# recogerlo. En el fondo del arco "hacia el ancla" es hacia ARRIBA, o sea que
	# esa corrección levanta al jugador contra la gravedad: trabajo gratis. Medido
	# en el 3.08 sin esto, el balanceo daba vueltas a altura constante acelerando
	# solo de 10 a 19 m/s.
	#
	# No contradice la regla de conservar velocidad: esto no le QUITA al jugador
	# nada que hubiera puesto él, devuelve lo que le puso el motor. `v' = √(v² −
	# 2·g·Δh)` es la conversión exacta de altura ganada a velocidad perdida.
	var subida := desplazamiento.dot(sc.up)
	if subida > 0.0:
		var v2 := player.velocity.length_squared() - 2.0 * tuning.cuerda_gravedad * subida
		var v := player.velocity.length()
		if v > 0.001:
			player.velocity *= sqrt(maxf(v2, 0.0)) / v


## TODA SALIDA CONSERVA LA VELOCIDAD, y además la premia.
##
## No hay salida "buena" y salida "mala": el multiplicador se aplica igual si
## sueltas tú, si caduca el arco o si te vas por un dash. Lo que cambia entre una
## salida y otra es CUÁNTA velocidad hay que multiplicar, y eso ya lo decide el
## jugador eligiendo el momento — un arco va más rápido abajo que arriba. Premiar
## además el gesto sería pagar dos veces por la misma decisión.
func exit(_siguiente: StringName = &"") -> void:
	# NO HACE FALTA PEDIR PERMISO. Aquí había un `momentum_libre`: el multiplicador
	# se paga en este frame y se vuela en `Fall`, y con el clamp DURO el tope de 22
	# se lo comía entero en el mismo frame, en silencio y solo en horizontal.
	#
	# Desde que el tope es un objetivo y no un corte (`velocidad_drag`), la
	# velocidad heredada sobrevive sola el tiempo que le da el drag. El parche
	# sobraba en cuanto se arregló la causa.
	player.velocity *= tuning.cuerda_salida_mult


## EL RADIO SE ELIGE AL ENGANCHAR: es la distancia a la que estabas.
##
## Así el enganche es INSTANTÁNEO de verdad —empiezas exactamente sobre la esfera,
## sin tirón que corregir— y además el jugador elige el arco con su posición:
## engancharse de cerca da un giro corto y rápido, de lejos uno largo y amplio.
## Eso es control gratis y no hay que explicarlo.
##
## Y aquí acaba todo lo que la cuerda hace con su largo. **No se acorta ni se
## alarga en vuelo**: eso sería otra mecánica, con su propio botón y su propia
## curva de aprendizaje, y el arco de un segundo no da tiempo a usarla.
func _elegir_largo() -> float:
	var d := player.global_position.distance_to(_punto)
	return clampf(d, tuning.cuerda_largo_min, tuning.cuerda_rango)


func _soltar() -> void:
	fsm.cambiar(&"Fall" if not player.is_on_floor() else &"Idle")


## El techo del arco, no el global. Ver `cuerda_velocidad_max`: para un péndulo el
## clamp de 22 no es un techo, es un impuesto cobrado justo en el punto más rápido.
func techo_velocidad() -> float:
	return tuning.cuerda_velocidad_max


## Colgarse no cuesta stamina, así que quedarse a cero no puede soltarte.
func resiste_agotamiento() -> bool:
	return true


## NADA DE AGARRE AUTOMÁTICO A MEDIO ARCO. Regla dura #20: el agarre automático es
## para quien CAMINA contra un muro. Pasar rozando una pared a 30 m/s no es
## insistir, es el arco haciendo su trabajo — y engancharse ahí dejaría al jugador
## pegado a la geometría con la velocidad a cero, que es justo el bug que la regla
## documenta desde el 3.12.
func adherencia_automatica() -> bool:
	return false


## El estado se queda el salto y la cuerda: los dos son sus gestos de salida y el
## grupo corre ANTES que la hoja, así que sin reclamarlos se los quedaría él y
## soltar no llegaría a existir nunca. Regla dura #13.
func maneja_salto() -> bool:
	return true


func maneja_cuerda() -> bool:
	return true


## ¿De dónde cuelga el cordón? Lo pregunta el controlador para dibujarlo.
func punto_cuerda() -> Vector3:
	return _punto


func debug_line() -> String:
	return "CUERDA  r=%.1f  v=%.1f  quedan %.2fs" % [
		_largo, player.velocity.length(), maxf(0.0, tuning.cuerda_arco_max - t)]
