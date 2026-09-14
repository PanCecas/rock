extends SwordState
## EL CORTE. El ataque de mano, y el unico gesto ofensivo que NO te mueve.
##
## **Vive en la FSM del ARMA y no en la del jugador, y esa es la decision.** La
## patada es un movimiento —te lleva 0.25 s por el aire con su propia fisica— y
## por eso es un estado del jugador. Un corte no: sigues corriendo, deslizando,
## cayendo o colgado del arco mientras lo das. Meterlo en la FSM del jugador
## habria obligado a declararlo en los tres grupos con su guardia
## (`maneja_ataques()`), que es el fallo que mas veces ha aparecido en este
## proyecto — y aqui no hace falta ninguno, porque no hay transicion que robar.
##
## **Startup CERO** (ley 1 del 4.00): la ventana activa se abre en el primer
## frame si el `.tres` dice `frames_windup = 0`, y lo dice. Lo que queda detras
## es la RECUPERACION, que es lo unico que impide que machacar el boton sea un
## zumbido continuo: mientras dura, `cortar()` contesta que no porque la espada
## no esta en `Wielded`.
##
## El arco no se recalcula a mitad: lo que decide a donde corta es hacia donde
## mirabas al pulsar. Un corte que persigue la camara mientras dura es un corte
## que nunca falla, y fallar tiene que seguir siendo posible.

## Hacia donde corta, en mundo. Se fija al entrar.
var _dir: Vector3 = Vector3.FORWARD
## Frames desde el inicio del gesto. En la misma unidad que el `AttackData`.
var _frame: int = 0
## Ventanas activas ya abiertas. `AttackData.golpes` puede pedir varias.
var _swing_abierto: int = -1
var _conectados: int = 0


func enter(msg: Dictionary = {}) -> void:
	_frame = 0
	_swing_abierto = -1
	_conectados = 0
	_dir = msg.get("direccion", espada.direccion)
	if _dir.is_zero_approx():
		_dir = Vector3.FORWARD
	_dir = _dir.normalized()
	espada.direccion = _dir
	espada.corte.emit()
	EventBus.camara_shake.emit(0.12, 0.06)
	var datos := espada.ataque
	if datos != null:
		CombatFX.arco(espada.get_parent(), espada.punto_de_mano(), _dir,
			espada.color_de(datos.color_vfx), datos.alcance)


func physics_update(delta: float) -> void:
	# LA ESPADA SIGUE EN LA MANO MIENTRAS CORTA. Se coloca antes de golpear
	# porque la hitbox se centra en el DUEÑO de la hitbox, que es la espada: si
	# se pregunta desde la posicion del frame anterior, el corte sale del sitio
	# donde estabas y no de donde estas, y a 20 m/s eso son 33 cm de error.
	if espada.dueno != null and is_instance_valid(espada.dueno):
		espada.global_position = espada.punto_de_mano()
	espada.apuntar_a(_dir)

	var datos := espada.ataque
	if datos == null:
		fsm.cambiar(&"Wielded")
		return

	# LA VENTANA ACTIVA, leida del `.tres` en frames. `indice_golpe()` ya sabe de
	# ataques de varios impactos, asi que un mandoble de dos tajos sale de poner
	# `golpes = 2` en el recurso y de nada mas.
	var indice := datos.indice_golpe(_frame)
	if indice >= 0:
		if indice != _swing_abierto:
			_swing_abierto = indice
			espada.hitbox.nuevo_swing()
		if espada.hitbox.golpear(datos, _dir) > 0:
			_al_conectar(datos)

	_frame += 1

	# TERMINA SOLO (regla dura #27). El techo de `corte_max` esta ademas de la
	# duracion del `.tres` y no en su lugar: un recurso con tiempos absurdos no
	# puede dejar al jugador sin arma.
	if _frame >= datos.total_frames() or t >= tuning.corte_max:
		fsm.cambiar(&"Wielded")


## CONECTAR PARA EL MUNDO, y a los dos.
##
## Mismo tratamiento que la patada y por la misma razon escrita alli: congelar
## solo al que pega no se lee como un impacto, se lee como que te ha pasado algo
## a ti. Aqui pesa mas todavia porque el corte NO te empuja: si el golpe no para
## el mundo, no queda nada en pantalla que diga que hubo golpe.
func _al_conectar(datos: AttackData) -> void:
	_conectados += 1
	var golpe: Golpe = espada.hitbox.ultimo
	if golpe == null:
		return
	var participantes: Array[Node] = []
	if espada.dueno != null and is_instance_valid(espada.dueno):
		participantes.append(espada.dueno)
	if golpe.victima != null and is_instance_valid(golpe.victima):
		participantes.append(golpe.victima)
	HitstopManager.golpe(datos.hitstop, participantes)
	EventBus.camara_shake.emit(datos.shake, 0.14)
	CombatFX.impacto(espada.get_parent(), golpe.punto,
		espada.color_de(datos.color_vfx), 1.6)


func debug_line() -> String:
	var datos := espada.ataque
	var total: int = datos.total_frames() if datos != null else 0
	return "CORTE  %d/%d fr%s" % [_frame, total, "  CONECTA" if _conectados > 0 else ""]
