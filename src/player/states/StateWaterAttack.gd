extends PlayerState
## Ataque acuático. Bajo el agua un golpe ES un desplazamiento: no hay suelo del
## que empujar, así que atacar sin moverse no se lee como un golpe, se lee como
## que el botón no hace nada.
##
## Por eso ligero y pesado son el mismo verbo con distinto peso: un impulso corto
## en la dirección a la que apuntas, con la hitbox viva durante el trayecto.
##   · ligero -> rápido y largo, para cerrar distancia
##   · pesado -> más lento y más corto, pero pega mucho más
##
## Es la Fase 2 del agua que estaba documentada en project.md, ya construida.

var _datos: AttackData
var _dir: Vector3 = Vector3.ZERO
var _duracion: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	_datos = msg.get("datos", player.ataque_agua_ligero)
	var impulso: float = float(msg.get("impulso", tuning.agua_ataque_ligero_impulso))
	_dir = msg.get("direccion", Vector3.ZERO)
	if _dir.is_zero_approx():
		_dir = player.direccion_nado()

	_duracion = _datos.duracion() if _datos != null else 0.25
	player.velocity = _dir * impulso
	player.hitbox.nuevo_swing()
	player.stamina.gastar(tuning.agua_stamina_ataque)
	EventBus.camara_shake.emit(0.3, 0.12)
	CombatFX.arco(
		player.get_parent(), player.global_position + Vector3.UP * 0.9, _dir,
		player.color_de(&"cian_cielo"), 1.8
	)


## Misma regla que el buceo: la verticalidad se recupera al salir del agua, no al
## cambiar de estado dentro de ella.
func exit(siguiente: StringName = &"") -> void:
	if not fsm.es_categoria(siguiente, &"Water"):
		player.enderezar()


func physics_update(delta: float) -> void:
	# El agua frena sola: no hace falta cortar el ataque, se apaga.
	player.velocity = player.velocity.lerp(
		Vector3.ZERO, 1.0 - exp(-tuning.agua_rozamiento * 0.6 * delta)
	)
	player.orientar_a_3d(_dir, delta)

	if _datos != null and player.hitbox.golpear(_datos, _dir) > 0:
		HitstopManager.golpe(_datos.hitstop, [player])
		EventBus.camara_shake.emit(_datos.shake, 0.14)
		CombatFX.impacto(
			player.get_parent(), player.global_position + Vector3.UP * 0.9,
			player.color_de(_datos.color_vfx), 1.2
		)

	if not player.agua.en_agua:
		fsm.cambiar(&"Fall")
		return

	if t >= _duracion:
		fsm.cambiar(&"Underwater" if player.agua.sumergido() else &"Swim")


func debug_line() -> String:
	return "%s  %.1f m/s" % [_datos.nombre if _datos else "?", player.velocity.length()]
