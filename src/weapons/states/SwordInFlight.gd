extends SwordState
## LA IDA. Se aleja frenando y, al llegar a `alcance`, DA LA VUELTA.
##
## **No se clava en nada y no se cae al suelo**, y las dos cosas son a proposito:
## clavarse es el trabajo de la lanza y caerse convertiria cada tirada en un
## paseo a recogerla. Chocar contra piedra no la para en seco: adelanta el
## retorno, que es lo unico que puede pasarle a un bumeran.
##
## Tres cosas que definen el tramo:
##
## 1. **Atraviesa los cuerpos.** Igual que la lanza, y sale gratis: `Hitbox` ya
##    lleva la lista de tocados del swing, asi que cada enemigo se lleva un golpe
##    de la ida y —porque `Returning` abre swing nuevo— otro de la vuelta.
## 2. **Rayo del tramo recorrido**, no consulta puntual. A 26 m/s son 43 cm por
##    frame, y una consulta por frame se salta una pared fina entera.
## 3. **Gravedad casi nula.** La lanza CAE y esa es su lectura; esta gira sobre si
##    misma y planea. Dos proyectiles que describen la misma curva son el mismo
##    proyectil.

var _recorrido: float = 0.0
var _origen: Vector3 = Vector3.ZERO


func enter(msg: Dictionary = {}) -> void:
	_recorrido = 0.0
	_origen = espada.global_position
	espada.objetivo = null

	var dir: Vector3 = msg.get("direccion", Vector3.ZERO)
	if dir.is_zero_approx():
		dir = espada.direccion
	if dir.is_zero_approx():
		dir = -espada.global_basis.z
	espada.direccion = dir.normalized()
	# La velocidad la puede pedir quien entra: una patada sin enemigo a la vista
	# reentra aqui con la suya, que es mas alta que la de un tiro normal.
	var rapidez: float = msg.get("velocidad", tuning.velocidad)
	espada.vuelo = espada.direccion * rapidez

	if espada.hitbox != null:
		espada.hitbox.nuevo_swing()
	# PATEABLE EN VUELO. Es lo que la convierte en diana de pogo.
	espada.armar_hurtbox(true)
	espada.apuntar_a(espada.direccion)
	espada.lanzada.emit(espada.direccion)
	EventBus.camara_shake.emit(0.15, 0.07)


func exit(siguiente: StringName) -> void:
	# La hurtbox se queda encendida mientras siga FUERA: la vuelta y la busqueda
	# tambien se dejan patear, y eso es media mecanica —cada tirada da dos
	# pasadas—. Solo se apaga al volver a la mano.
	if siguiente == &"Wielded" or siguiente == &"Swing":
		espada.armar_hurtbox(false)


func physics_update(delta: float) -> void:
	espada.vuelo *= exp(-tuning.frenado * delta)
	espada.vuelo += Vector3.DOWN * tuning.gravedad_vuelo * delta
	var rapidez := espada.vuelo.length()
	if rapidez < 0.01:
		fsm.cambiar(&"Returning")
		return
	espada.direccion = espada.vuelo / rapidez

	var paso := rapidez * delta
	var desde := espada.global_position
	var hasta := desde + espada.direccion * paso

	# LA PIEDRA NO SE ATRAVIESA, pero tampoco la para: la espada se queda en el
	# punto de contacto y vuelve. Sin el retroceso de un radio, el retorno
	# arrancaria con el arma medio metida en el muro.
	var choque := _barrer(desde, hasta)
	if not choque.is_empty():
		espada.global_position = (choque["position"] as Vector3) \
			- espada.direccion * tuning.radio_atrape * 0.5
		CombatFX.impacto(espada.get_parent(), espada.global_position,
			espada.color_de(&"caliza_sol"), 0.8)
		fsm.cambiar(&"Returning")
		return

	espada.global_position = hasta
	_recorrido += paso
	espada.girar_en_vuelo(delta)

	# Daño en transito, y la espada SIGUE. Eso es atravesar.
	if espada.ataque_vuelo != null and espada.hitbox != null:
		if espada.hitbox.golpear(espada.ataque_vuelo, espada.direccion) > 0:
			CombatFX.impacto(espada.get_parent(), espada.global_position,
				espada.color_de(&"carmesi"), 0.9)

	# Y DA LA VUELTA. `alcance` se mide desde donde salio y no desde la mano: si
	# se midiera desde la mano, correr detras de la espada la mantendria fuera
	# para siempre y el bumeran dejaria de volver.
	if _recorrido >= tuning.alcance or t >= tuning.vida_vuelo:
		fsm.cambiar(&"Returning")


## Barrido del tramo de ESTE frame contra la geometria solida.
func _barrer(desde: Vector3, hasta: Vector3) -> Dictionary:
	var espacio := espada.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(desde, hasta, espada.capas_rebote)
	if espada.dueno is CollisionObject3D:
		q.exclude = [(espada.dueno as CollisionObject3D).get_rid()]
	return espacio.intersect_ray(q)


func debug_line() -> String:
	return "IDA  %.0f/%.0f m" % [_recorrido, tuning.alcance]
