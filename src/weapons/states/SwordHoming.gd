extends SwordState
## LA ESPADA PATEADA: va al enemigo mas cercano.
##
## **Es el verbo que se pidio literalmente** —*«crea una espada para esto que al
## patearla vaya al enemigo mas cercano»*— y lo que lo hace valer la pena es que
## no inventa nada: la patada ya tenia momentum y ya sabia rebotar contra algo
## que sobrevive al golpe. Lo unico nuevo es a donde va lo pateado.
##
## **Y GIRA, no se teletransporta.** Clavarle el rumbo al objetivo en el frame de
## la patada seria un salto en la imagen; con `busqueda_giro` la espada traza una
## curva y el jugador ve a donde va antes de que llegue — que es lo que le deja
## decidir lo siguiente mientras sube del rebote.
##
## Termina de tres formas, y las tres devuelven el arma: acertar, quedarse sin
## objetivo, o cumplir `busqueda_vida`. Un verbo que puede no terminar es un modo
## (regla dura #27).

var _recorrido: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	_recorrido = 0.0
	var quien: Variant = msg.get("objetivo")
	espada.objetivo = quien as Enemigo if quien != null else null

	var rapidez: float = maxf(espada.vuelo.length(), tuning.busqueda_velocidad)
	var dir := _hacia_objetivo()
	if dir.is_zero_approx():
		dir = espada.direccion
	espada.direccion = dir.normalized()
	espada.vuelo = espada.direccion * rapidez

	# SWING NUEVO: la espada llega como un golpe nuevo, asi que un enemigo ya
	# tocado en la ida se vuelve a llevar lo suyo. Sin esto, patearla hacia quien
	# ya habias rozado no haria absolutamente nada y pareceria que falla.
	if espada.hitbox != null:
		espada.hitbox.nuevo_swing()
	espada.armar_hurtbox(true)
	espada.apuntar_a(espada.direccion)


func exit(siguiente: StringName) -> void:
	espada.objetivo = null
	if siguiente == &"Wielded" or siguiente == &"Swing":
		espada.armar_hurtbox(false)


func physics_update(delta: float) -> void:
	# SIN OBJETIVO VIVO NO HAY PERSECUCION. Se comprueba cada frame porque el
	# objetivo se puede morir por el camino —de hecho es lo normal: la espada
	# llega la segunda, despues de la patada— y perseguir un cadaver es lo que
	# convierte un misil en un bicho dando vueltas.
	var presa := espada.objetivo
	if presa == null or not is_instance_valid(presa) or not presa.esta_vivo():
		fsm.cambiar(&"Returning")
		return

	var deseada := _hacia_objetivo()
	if not deseada.is_zero_approx():
		var peso: float = clampf(deg_to_rad(tuning.busqueda_giro) * delta, 0.0, 1.0)
		espada.direccion = espada.direccion.slerp(deseada.normalized(), peso).normalized()
	espada.vuelo = espada.direccion * tuning.busqueda_velocidad

	var paso := tuning.busqueda_velocidad * delta
	espada.global_position += espada.direccion * paso
	_recorrido += paso
	espada.apuntar_a(espada.direccion)

	if espada.ataque_vuelo != null and espada.hitbox != null:
		if espada.hitbox.golpear(espada.ataque_vuelo, espada.direccion) > 0:
			_al_conectar()
			return

	if t >= tuning.busqueda_vida:
		fsm.cambiar(&"Returning")


## Del arma al PECHO del objetivo, no a sus pies. Apuntar al origen del cuerpo
## manda la espada al suelo cuando el enemigo esta cerca, y ahi la hitbox —que
## aplasta la Y para el arco pero no para el radio— se queda corta.
func _hacia_objetivo() -> Vector3:
	var presa := espada.objetivo
	if presa == null or not is_instance_valid(presa):
		return Vector3.ZERO
	return (presa.global_position + Vector3.UP * 0.9) - espada.global_position


func _al_conectar() -> void:
	var golpe: Golpe = espada.hitbox.ultimo
	var datos := espada.ataque_vuelo
	if golpe != null and datos != null:
		var participantes: Array[Node] = []
		if espada.dueno != null and is_instance_valid(espada.dueno):
			participantes.append(espada.dueno)
		if golpe.victima != null and is_instance_valid(golpe.victima):
			participantes.append(golpe.victima)
		HitstopManager.golpe(datos.hitstop, participantes)
		CombatFX.impacto(espada.get_parent(), golpe.punto,
			espada.color_de(&"oro_palido"), 2.0)
		EventBus.camara_shake.emit(datos.shake, 0.14)
	# Acertar TERMINA la busqueda. Seguir de largo buscando al siguiente seria un
	# arma que limpia una sala sola, y entonces el jugador sobra.
	fsm.cambiar(&"Returning")


func debug_line() -> String:
	var quien := "?"
	if espada.objetivo != null and is_instance_valid(espada.objetivo):
		quien = "%s a %.1f m" % [
			espada.objetivo.name,
			espada.global_position.distance_to(espada.objetivo.global_position)]
	return "BUSCA  %s" % quien
