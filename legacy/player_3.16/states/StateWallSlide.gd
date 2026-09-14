extends PlayerState
## Resbalar por una pared. Caída frenada y salto de rebote.
## Existe sobre todo para dar una segunda oportunidad: chocar contra un muro en
## mitad de un salto largo deja de ser un fracaso total.


func enter(_msg: Dictionary = {}) -> void:
	# Amortiguar la subida, no matarla: llegar a una pared subiendo y quedarte
	# clavado en seco se siente como pegamento.
	var vy := motor.get_vertical()
	if vy > 0.0:
		motor.set_vertical(vy * 0.45)
	player.orientar_a(-sc.plano(player.pared.normal))


func physics_update(delta: float) -> void:
	if not player.pared.hay_pared:
		fsm.cambiar(&"Fall")
		return

	# Pegarse ligeramente a la pared para no despegarse solo.
	motor.impulso(-sc.plano(player.pared.normal), 1.2)
	var vy := motor.get_vertical()
	motor.set_vertical(maxf(lerpf(vy, -tuning.wallslide_caida, 1.0 - exp(-8.0 * delta)), -tuning.wallslide_caida))

	# El salto NO se gestiona aqui: lo resuelve GroupAirborne para que funcione
	# igual desde WallSlide, desde Fall y desde el coyote de pared. Una sola
	# maniobra, un solo sitio.


func debug_line() -> String:
	return "vy %.1f" % motor.get_vertical()
