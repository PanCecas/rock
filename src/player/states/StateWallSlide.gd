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

	# PEGARSE AL MURO SIN BORRAR LA LINEA.
	#
	# Aqui habia un `motor.impulso(-normal, 1.2)`, y `impulso()` con `conservar =
	# false` REEMPLAZA el vector horizontal entero: llegar rozando a 30 m/s te
	# dejaba a 1.2 yendo hacia la pared. La intencion del numero era "no
	# despegarse solo" y lo que hacia era quitarte todo lo que llevabas.
	#
	# Lo correcto es partir la velocidad en dos y tratarlas distinto: la que va
	# CONTRA el muro se sustituye por el pegado —esa la ibas a perder de todas
	# formas, la pared esta ahi—, y la que va A LO LARGO se conserva y se le aplica
	# rozamiento. Eso es lo que deja que un roce siga siendo un roce.
	var normal := sc.plano(player.pared.normal).normalized()
	var plano := sc.plano(player.velocity)
	var a_lo_largo := plano - normal * plano.dot(normal)
	a_lo_largo *= maxf(0.0, 1.0 - tuning.wallslide_friccion * delta)
	player.velocity = (a_lo_largo - normal * tuning.wallslide_pegado
		+ sc.up * motor.get_vertical())

	var vy := motor.get_vertical()
	motor.set_vertical(maxf(lerpf(vy, -tuning.wallslide_caida, 1.0 - exp(-8.0 * delta)), -tuning.wallslide_caida))

	# El salto NO se gestiona aqui: lo resuelve GroupAirborne para que funcione
	# igual desde WallSlide, desde Fall y desde el coyote de pared. Una sola
	# maniobra, un solo sitio.


func debug_line() -> String:
	return "vy %.1f" % motor.get_vertical()
