extends PlayerState
## LA PATADA. El único movimiento ofensivo, y es traversal antes que ataque.
##
## Sustituye a los seis estados de combate del jugador y a sus 25 `AttackData`.
## Lo que queda es UN gesto con dos usos a la vez, y ahí está todo el diseño:
## cruza huecos aunque no haya nada que golpear, y si golpea, te devuelve al aire
## para seguir.
##
## **Cuatro cosas la definen, y las cuatro se escribieron en la segunda pasada:**
## la primera versión medía bien sobre el papel y se sentía mal, y el banco
## (`tools/MedirPatada.tscn`) dijo por qué en cinco líneas.
##
##   1. **LA VELOCIDAD ES UN SUELO, NO UN VALOR.** Antes escribía 18 m/s cada
##      frame, así que entrar lanzado a 29.8 y patear te dejaba a 18.0: la patada
##      te quitaba **11.8 m/s por usar tu propio moveset**. Ahora garantiza 18 y no
##      resta nada — llegas a 30, sales a 30, y el gesto cubre más terreno porque
##      venías más rápido.
##   2. **LA GRAVEDAD SE SUSPENDE Y SE DEVUELVE.** Antes ponía la vertical a cero y
##      te soltaba a cero: caías a plomo desde parado. Ahora flota durante el gesto
##      y al salir te devuelve `max(la que traías, patada_salida_vertical)` —
##      patear subiendo no te frena, patear cayendo te salva la caída.
##   3. **SE PUEDE SALIR DE ELLA.** Saltar o tirar de la cuerda la cortan en el
##      acto. Antes eran quince frames sin poder actuar, y quince frames es mucho
##      rato no siendo el dueño del personaje.
##   4. **ACERTAR REBOTA.** Antes conectar solo recargaba y seguías de largo, a
##      vertical cero. Ahora sales despedido hacia arriba con un instante de
##      gravedad cero, y el gesto TERMINA ahí para que puedas elegir lo siguiente.
##      Eso es lo que convierte a un enemigo en plataforma.
##
## **Una por tiempo de vuelo** (`patada_cargas`). Se gasta al entrar —no al salir,
## o quedaría abierta la ventana de encadenar dos dentro del mismo gesto— y la
## devuelve el contacto: suelo, pared o enemigo.

## Dirección de viaje, horizontal. Se redirige con el stick, nunca se recalcula.
var _dir: Vector3 = Vector3.ZERO
## Rapidez del gesto. SUELO: `max(la que traías, patada_velocidad)`. Ver la nota 1.
var _rapidez: float = 0.0
## La vertical con la que entraste, para devolvértela al salir. Ver la nota 2.
var _vy_entrada: float = 0.0
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

	# EL SUELO DE VELOCIDAD, y el techo que hace falta para que signifique algo:
	# sin `techo_velocidad()` el clamp global (22) recortaría lo heredado en el
	# mismo frame, en silencio y solo en horizontal.
	_rapidez = maxf(motor.rapidez_plana(), tuning.patada_velocidad)
	_vy_entrada = motor.get_vertical()

	player.patada_cargas -= 1
	player.hitbox.nuevo_swing()
	player.orientar_a(_dir)
	player.set_alabeo(0.0)
	_aplicar_vuelo()
	EventBus.camara_shake.emit(0.3, 0.12)
	CombatFX.arco(player.get_parent(), player.global_position + Vector3.UP * 0.9,
		_dir, player.color_de(&"azul_claro"), 2.0)


func physics_update(delta: float) -> void:
	# 1) EL GESTO CADUCA. Va lo primero, igual que en la cuerda: es la ley que
	#    define el movimiento (regla dura #27).
	if t >= tuning.patada_duracion:
		_terminar()
		return

	# 2) SE PUEDE SALIR DE ELLA. Saltar y tirar de la cuerda la cortan.
	#
	#    Se mira con `peek()` y NO se consume: terminar aquí y dejar la pulsación
	#    viva hace que el frame siguiente la resuelva quien sabe hacerlo —
	#    `GroupAirborne`, con su wall-jump, su doble salto y su coyote— en vez de
	#    duplicar aquí media docena de reglas que ya existen. Cuesta un frame y
	#    ahorra un segundo sitio donde equivocarse.
	if buffer.peek(InputActions.JUMP) or buffer.peek(InputActions.ROPE):
		_terminar()
		return

	# 3) AUTORIDAD DIRECCIONAL, todo el rato. Se rota la dirección, no la
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

	# 4) LA HITBOX VIVE TODO EL TRAYECTO. No hay ventana activa que acertar: no es
	#    un golpe con anticipación, es un proyectil que eres tú. `nuevo_swing()` se
	#    abrió una sola vez al entrar, así que cada cuerpo se lleva UN impacto por
	#    patada y no uno por frame.
	var datos := player.ataque_patada
	if datos != null and player.hitbox.golpear(datos, _dir) > 0:
		_al_conectar(datos)


## Rapidez constante y vertical suspendida. Se reescribe cada frame a propósito:
## nada —ni la gravedad, ni un roce con una pared, ni el control aéreo— puede
## tocar la línea mientras dura el gesto.
func _aplicar_vuelo() -> void:
	motor.impulso(_dir, _rapidez)
	motor.set_vertical(0.0)


## CONECTAR ES SEGUIR MOVIÉNDOTE. Esto es la mecánica entera, no un extra.
##
## Un enemigo pasa a ser una plataforma: llegar a él te devuelve las cargas Y te
## devuelve ARRIBA. Sin el rebote, golpear era el final de una línea en vez de un
## eslabón — medido en la primera pasada: conectar te dejaba a vy 0.0 y cayendo.
##
## Y el gesto termina AQUÍ, no cuando se le acabe el tiempo: lo que hace que la
## cadena exista es poder elegir el siguiente objetivo mientras subes.
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

	motor.set_vertical(tuning.patada_rebote)
	# HANG TIME: gravedad cero un instante. Sin esto el rebote es un empujón y ya;
	# con esto hay una pausa en la que se elige la siguiente cabeza.
	player.iniciar_hangtime(tuning.patada_hangtime)
	fsm.cambiar(&"Fall")


## LA SALIDA DEVUELVE EL AIRE, y no lo regala.
##
## `maxf` y no una asignación: patear subiendo no te frena y patear cayendo te
## salva la caída, pero nunca sales con más vertical de la que traías salvo por
## `patada_salida_vertical`, que es un respiro y no un salto. Una vez por tiempo
## de vuelo.
##
## **Y el respiro es SOLO PARA EL AIRE.** Si empezaste pisando no perdiste ningún
## aire que devolver, y dárselo igualmente reabre el spam por la puerta de atrás:
## el pop te despega del suelo un instante, el contacto se rompe y se rearma, el
## flanco de recarga dispara, y machacar el botón vuelve a ser un dash continuo
## con un saltito entre patada y patada. Lo cazó `TestPatada` en la primera
## pasada con el respiro puesto.
func _terminar() -> void:
	if player.is_on_floor():
		motor.set_vertical(_vy_entrada)
	else:
		motor.set_vertical(maxf(_vy_entrada, tuning.patada_salida_vertical))
	if player.agua.en_agua:
		fsm.cambiar(&"Swim")
	elif player.is_on_floor():
		fsm.cambiar(&"Move" if buffer.move_vector().length() > 0.2 else &"Idle")
	else:
		fsm.cambiar(&"Fall")


## El techo de la patada es su propia rapidez. Ver `patada_velocidad`: el clamp
## global no le sirve de techo a un gesto que hereda momentum, le sirve de peaje.
func techo_velocidad() -> float:
	return maxf(_rapidez, tuning.patada_velocidad)


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
	return "PATADA  %.1f m/s  %.2fs%s" % [
		_rapidez, maxf(0.0, tuning.patada_duracion - t),
		"  CONECTA" if _conectado else ""]
