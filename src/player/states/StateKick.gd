extends PlayerState
## LA PATADA. El único movimiento ofensivo, y es traversal.
##
## Sustituye a los seis estados de combate del jugador y a sus 25 `AttackData`
## —la cadena ligera, el pesado con su combo, los dos clavados, el picado, el
## slide kick, la patada baja, la estocada de dash, los dos de surf, los dos de
## agua y el moveset entero de la lanza empuñada—. Y no por simplificar: porque
## con doce entradas de combate el botón se machaca, y machacar un botón no es
## una decisión.
##
## Lo que queda es UN gesto con dos usos a la vez, y ahí está todo el diseño:
##
##   · **Cruza huecos.** 0.25 s a 18 m/s son 4.5 m en línea recta, sin gravedad.
##     Funciona igual de bien contra el aire que contra un enemigo, así que es una
##     herramienta de movimiento antes que un ataque.
##   · **Si conecta, derrota Y RECARGA** la cuerda y la propia patada. Eso
##     convierte a un enemigo en una plataforma: golpearle es una forma de SEGUIR
##     moviéndote, no una interrupción del movimiento.
##
## **Velocidad constante y gravedad cero.** Es la física de Mario 64 y la razón de
## que la trayectoria se pueda leer antes de pulsar: sale recta, llega recta y
## termina donde se veía que iba a terminar. Un gesto que se curva es un gesto que
## hay que ensayar.
##
## **Una por tiempo de vuelo.** Se gasta al entrar —no al salir, o quedaría
## abierta la ventana de encadenar dos dentro del mismo gesto— y la devuelve el
## contacto: suelo, pared o enemigo. Ver `PlayerController.recargar_moveset()`.

## Dirección de viaje, horizontal. Se redirige con el stick, nunca se recalcula.
var _dir: Vector3 = Vector3.ZERO
var _conectado: bool = false


func enter(msg: Dictionary = {}) -> void:
	_conectado = false
	player.enderezar()

	# La dirección la pide el stick. Sin stick, hacia donde miras: pulsar sin tocar
	# nada tiene que hacer algo, y ese algo es "hacia delante".
	var pedida: Vector3 = msg.get("direccion", Vector3.ZERO)
	if pedida.is_zero_approx():
		pedida = sc.direccion_movimiento(buffer.move_vector(), player.camara())
	if pedida.is_zero_approx():
		pedida = player.direccion_frontal()
	_dir = sc.plano(pedida).normalized()
	if _dir.is_zero_approx():
		_dir = player.direccion_frontal()

	player.patada_disponible = false
	player.hitbox.nuevo_swing()
	player.orientar_a(_dir)
	player.set_alabeo(0.0)
	_aplicar_vuelo()
	EventBus.camara_shake.emit(0.3, 0.12)
	CombatFX.arco(player.get_parent(), player.global_position + Vector3.UP * 0.9,
		_dir, player.color_de(&"azul_claro"), 2.0)


func physics_update(delta: float) -> void:
	# 1) EL GESTO CADUCA. Va lo primero, igual que en la cuerda: es la ley que
	#    define el movimiento (regla dura #27) y una ley comprobada después de las
	#    excepciones no es una ley.
	if t >= tuning.patada_duracion:
		_terminar()
		return

	# 2) AUTORIDAD DIRECCIONAL, todo el rato. Se rota la dirección, no la
	#    velocidad: un `slerp` sobre un unitario es un giro con radio, que es lo que
	#    se quiere aquí. Sobre un vector de velocidad sería un error —pasaría por
	#    cero— y por eso la regla dura #24 lo prohíbe AHÍ y no aquí.
	var entrada := buffer.move_vector()
	if entrada.length() > 0.2:
		var deseada := sc.plano(sc.direccion_movimiento(entrada, player.camara()))
		if not deseada.is_zero_approx():
			var peso: float = clampf(
				deg_to_rad(tuning.patada_giro_grados_seg) * delta, 0.0, 1.0)
			_dir = _dir.slerp(deseada.normalized(), peso).normalized()
			player.orientar_a(_dir)

	_aplicar_vuelo()

	# 3) LA HITBOX VIVE TODO EL TRAYECTO. No hay ventana activa que acertar: no es
	#    un golpe con anticipación, es un proyectil que eres tú. `nuevo_swing()` se
	#    abrió una sola vez al entrar, así que cada cuerpo se lleva UN impacto por
	#    patada y no uno por frame.
	var datos := player.ataque_patada
	if datos != null and player.hitbox.golpear(datos, _dir) > 0:
		_al_conectar(datos)


## Velocidad CONSTANTE y vertical a cero. Se reescribe cada frame a propósito:
## nada —ni la gravedad, ni un roce con una pared, ni el control aéreo— puede
## tocar la línea mientras dura el gesto.
func _aplicar_vuelo() -> void:
	motor.impulso(_dir, tuning.patada_velocidad)
	motor.set_vertical(0.0)


## CONECTAR ES SEGUIR MOVIÉNDOTE. Esto es la mecánica entera, no un extra.
##
## Un enemigo pasa a ser una plataforma: llegar a él te devuelve la cuerda y la
## patada, así que la cadena cuerda → patada → enemigo → cuerda existe y no toca
## el suelo. Sin la recarga, golpear sería el final de una línea en vez de un
## eslabón, y entonces el combate volvería a ser una interrupción del movimiento.
func _al_conectar(datos: AttackData) -> void:
	if _conectado:
		return
	_conectado = true
	player.recargar_moveset()
	HitstopManager.golpe(datos.hitstop, [player])
	EventBus.camara_shake.emit(datos.shake, 0.16)
	var pos := player.global_position + Vector3.UP * 0.9
	CombatFX.impacto(player.get_parent(), pos, player.color_de(datos.color_vfx), 1.4)
	CombatFX.onda(player.get_parent(), pos, player.color_de(&"oro_palido"), 2.0)


## SE SALE CONSERVANDO LA VELOCIDAD, y sin tocarla.
##
## La patada termina a `patada_velocidad` y ahí se queda: el estado que recibe se
## la encuentra puesta. No hay multiplicador —como en la cuerda— porque aquí no
## hay nada que cronometrar: la velocidad no depende del momento en que sueltas,
## es la misma siempre. Premiar una salida que no tiene decisión dentro sería
## regalar velocidad, y eso es justo lo contrario de lo que pide el diseño.
func _terminar() -> void:
	if player.agua.en_agua:
		fsm.cambiar(&"Swim")
	elif player.is_on_floor():
		fsm.cambiar(&"Move" if buffer.move_vector().length() > 0.2 else &"Idle")
	else:
		fsm.cambiar(&"Fall")


## El estado se queda la pulsación de ataque: el grupo corre ANTES que la hoja, y
## sin esto machacar el botón reentraría en la patada cada frame y la actual no
## llegaría a terminar nunca. Regla dura #13 — y es literalmente el spam que este
## rediseño venía a quitar.
func maneja_ataques() -> bool:
	return true


## NADA DE AGARRE AUTOMÁTICO A MEDIA PATADA. Regla dura #20: el agarre automático
## es para quien CAMINA contra un muro. Llegar a 18 m/s no es insistir, es cruzar,
## y engancharse ahí dejaría al jugador pegado a la geometría con la velocidad a
## cero justo cuando acaba de pagar una carga por tenerla.
func adherencia_automatica() -> bool:
	return false


func debug_line() -> String:
	return "PATADA  %.2fs%s" % [
		maxf(0.0, tuning.patada_duracion - t), "  CONECTA" if _conectado else ""]
