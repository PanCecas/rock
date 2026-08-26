extends SpearState
## EN VUELO. El estado con sustancia.
##
## Tres cosas que no son obvias y que definen la mecánica:
##
## 1. **ATRAVIESA los cuerpos.** Un enemigo alcanzado recibe daño y la lanza NO
##    se para. Sale casi gratis: `Hitbox` ya lleva la lista de tocados del swing,
##    así que cada cuerpo se lleva un golpe y solo uno. Lo único que hace falta
##    es no destruirla al impactar, que es justo lo que hace `Proyectil`.
## 2. **Se para EN SECO contra geometría.** La piedra no se atraviesa: se clava.
##    Esa asimetría —los cuerpos sí, el mundo no— es la que convierte la lanza en
##    herramienta de posición y no solo en un arma.
## 3. **Rayo del tramo recorrido**, no consulta puntual. A 34 m/s recorre 57 cm
##    por frame, y una consulta por frame se salta una pared fina entera.

var _recorrido: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	_recorrido = 0.0
	var dir: Vector3 = msg.get("direccion", Vector3.ZERO)
	if dir.is_zero_approx():
		dir = -lanza.global_basis.z
	lanza.direccion = _imantar(dir.normalized())
	lanza.soltar_plataforma()
	lanza.apuntar_a(lanza.direccion)
	if lanza.hitbox != null:
		lanza.hitbox.nuevo_swing()
	EventBus.camara_shake.emit(0.18, 0.08)


func physics_update(delta: float) -> void:
	var paso := tuning.velocidad * delta
	var desde := lanza.global_position
	var hasta := desde + lanza.direccion * paso

	# La geometría se comprueba PRIMERO. Si hay muro a mitad del tramo, la lanza
	# se clava ahí y no llega a hacer daño más allá: no puede atravesar piedra
	# para alcanzar a alguien que está detrás.
	var golpe := _barrer(desde, hasta)
	if not golpe.is_empty():
		var punto: Vector3 = golpe["position"]
		lanza.global_position = punto + lanza.direccion * tuning.hundimiento
		fsm.cambiar(&"Embedded", {"punto": punto, "normal": golpe["normal"]})
		return

	lanza.global_position = hasta
	_recorrido += paso

	# Daño en tránsito, y la lanza SIGUE. Eso es atravesar.
	if lanza.ataque != null and lanza.hitbox != null:
		if lanza.hitbox.golpear(lanza.ataque, lanza.direccion) > 0:
			CombatFX.impacto(lanza.get_parent(), lanza.global_position,
				lanza.color_de(&"carmesi"), 0.9)

	if t >= tuning.vida_vuelo or _recorrido >= tuning.alcance_maximo:
		fsm.cambiar(&"Grounded")


## Barrido del tramo de ESTE frame contra las superficies clavables.
func _barrer(desde: Vector3, hasta: Vector3) -> Dictionary:
	var espacio := lanza.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(desde, hasta, lanza.capas_clavado)
	if lanza.dueno is CollisionObject3D:
		q.exclude = [(lanza.dueno as CollisionObject3D).get_rid()]
	return espacio.intersect_ray(q)


## Corrección hacia el objetivo, acotada a `imantado_grados` (8 por defecto).
##
## Ocho grados perdonan un error de puntería y no apuntan por ti. Subirlo
## convierte la lanza en un misil teledirigido y acertar deja de significar nada:
## fallar tiene que seguir siendo posible.
func _imantar(dir: Vector3) -> Vector3:
	var d := lanza.dueno
	if d == null or tuning.imantado_grados <= 0.0:
		return dir
	var sistema: Variant = d.get("targeting")
	if sistema == null:
		return dir
	# `direccion_3d()` existe desde el 3.05 y apunta de verdad en tres
	# dimensiones. La plana no vale aquí: media gracia de la lanza es tirarla
	# hacia arriba.
	var hacia: Vector3 = sistema.direccion_3d()
	if hacia.is_zero_approx() or sistema.distancia_3d() > tuning.imantado_alcance:
		return dir
	var separacion := rad_to_deg(dir.angle_to(hacia))
	if separacion <= 0.001:
		return dir
	var eje := dir.cross(hacia)
	if eje.is_zero_approx():
		return dir
	var techo: float = minf(tuning.imantado_grados, separacion)
	return dir.rotated(eje.normalized(), deg_to_rad(techo))


func debug_line() -> String:
	return "VUELO  %.0f/%.0f m" % [_recorrido, tuning.alcance_maximo]
