extends PlayerState
## Ataque en picado con AREA ESCALADA POR LA ALTURA DE LA CAIDA.
##
## Tres fases: te paras en el aire, caes a plomo, revientas el suelo en area.
## La pausa inicial no es adorno: es la telegrafia que le da peso al impacto y la
## que permite apuntar. Un plunge instantaneo se siente como caerse.
##
## Lo que lo hace distinto de los demas ataques es de donde sale su fuerza. No la
## decide un combo ni un recurso: la decide **desde donde te tiraste**. Cuanto mas
## alto, mas dano, mas radio, mas aturdimiento, y pasada cierta altura el enemigo
## ya no se tambalea, se cae al suelo.
##
## Esa es la razon de diseno: es el unico ataque que paga el traversal en moneda
## de combate. Sin el, subir una torre y bajar peleando son dos juegos distintos
## que comparten personaje.
##
## NOTA DE IMPLEMENTACION: no se instancia un Area3D. El proyecto golpea por
## CONSULTA DE FORMA (`Hitbox`) porque un Area3D se actualiza en el tick de fisica
## y llega un frame tarde, que en ventanas de 4 frames es un 25% de error. El
## `AttackData` se DUPLICA antes de escalarlo: el recurso original es compartido y
## mutarlo cambiaria el picado para siempre, no solo para este golpe.

enum { SUSPENDIDO, CAYENDO, IMPACTO }

var _datos: AttackData
var _fase: int = SUSPENDIDO
var _t_fase: float = 0.0
## Altura maxima alcanzada dentro del estado, medida a lo largo del `up` del
## SurfaceContext y no del eje Y del mundo: sobre un coloso, "arriba" no es (0,1,0).
var _altura_max: float = 0.0
## Caida efectiva del ultimo impacto. Solo para el debug.
var _caida: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_datos = player.ataque_plunge
	_fase = SUSPENDIDO
	_t_fase = 0.0
	_caida = 0.0
	_altura_max = _altura_actual()
	player.velocity = Vector3.ZERO
	player.hitbox.nuevo_swing()


func physics_update(delta: float) -> void:
	_t_fase += delta
	# La referencia se toma del punto MAS ALTO del estado, no del de entrada: si el
	# picado se pide todavia subiendo, la caida real empieza en el apice.
	_altura_max = maxf(_altura_max, _altura_actual())

	match _fase:
		SUSPENDIDO:
			player.velocity = Vector3.ZERO
			# Reorientar mientras flotas: es el momento de elegir donde caes.
			var entrada := sc.direccion_movimiento(buffer.move_vector(), player.camara())
			if not entrada.is_zero_approx():
				motor.impulso(entrada, 3.0)
			if _t_fase >= tuning.plunge_suspension:
				_fase = CAYENDO
				_t_fase = 0.0
		CAYENDO:
			motor.set_vertical(tuning.plunge_velocidad_caida)
			if player.is_on_floor():
				_impactar()
		IMPACTO:
			motor.frenar(tuning.frenado_suelo * 2.0, delta)
			motor.set_vertical(-2.0)
			# Cancelable con dash desde el primer frame: aterrizar no es castigo.
			if player.puede_dashear() and buffer.consume(InputActions.DASH):
				fsm.cambiar(&"Dash")
				return
			if _t_fase >= _datos.frames_a_seg(_datos.frames_recuperacion):
				fsm.cambiar(&"Move" if buffer.move_vector().length() > 0.2 else &"Idle")


func _impactar() -> void:
	_fase = IMPACTO
	_t_fase = 0.0
	_caida = maxf(_altura_max - _altura_actual(), 0.0)

	var escalados := _escalar(_datos, _caida)
	var fuerza := _fraccion(_caida)

	# Golpea en 360 grados: el plunge es el limpiapantallas del moveset.
	player.hitbox.nuevo_swing()
	var n := player.hitbox.golpear(escalados, player.direccion_frontal())

	# El feedback crece con el golpe. Un impacto el doble de fuerte que suena y se
	# ve igual que uno flojo le esta mintiendo al jugador sobre lo que acaba de
	# hacer, y la proxima vez no volvera a molestarse en subir.
	HitstopManager.golpe(escalados.hitstop, [player])
	EventBus.camara_shake.emit(escalados.shake * (1.6 if n > 0 else 0.8), 0.22 + 0.12 * fuerza)
	CombatFX.onda(
		player.get_parent(),
		player.global_position + Vector3.UP * 0.1,
		player.color_de(escalados.color_vfx),
		escalados.radio * 1.3
	)


## Cuanto del escalado se ha ganado, de 0 a 1. Por debajo de `plunge_altura_min`
## el picado vale lo que dice su AttackData; por encima de `plunge_altura_max` deja
## de crecer, porque sin techo una torre de 60 m seria un boton de borrar pantalla.
func _fraccion(caida: float) -> float:
	var lo := tuning.plunge_altura_min
	var hi := maxf(tuning.plunge_altura_max, lo + 0.01)
	return clampf((caida - lo) / (hi - lo), 0.0, 1.0)


## Copia del AttackData con dano, radio, aturdimiento y empuje escalados.
##
## DUPLICADO, nunca mutado: `player.ataque_plunge` es el mismo Resource para todos
## los picados de la partida. Escalarlo en sitio haria que el primer picado alto
## dejara el ataque potenciado para siempre.
func _escalar(base: AttackData, caida: float) -> AttackData:
	if base == null:
		return null
	var f := _fraccion(caida)
	var d: AttackData = base.duplicate()
	d.dano = base.dano * lerpf(1.0, tuning.plunge_dano_mult, f)
	d.dano_poise = base.dano_poise * lerpf(1.0, tuning.plunge_dano_mult, f)
	d.radio = base.radio * lerpf(1.0, tuning.plunge_radio_mult, f)
	d.stagger = maxf(base.stagger, 0.45) * lerpf(1.0, tuning.plunge_stagger_mult, f)
	d.empuje = base.empuje * lerpf(1.0, tuning.plunge_empuje_mult, f)
	d.lanzamiento = base.lanzamiento * lerpf(1.0, tuning.plunge_empuje_mult, f)
	d.hitstop = base.hitstop * lerpf(1.0, 1.5, f)
	d.shake = base.shake * lerpf(1.0, 1.5, f)
	# Pasada cierta altura el enemigo ya no se tambalea: se cae. Es el salto
	# cualitativo que hace que merezca la pena subir DEL TODO y no un poco.
	if caida >= tuning.plunge_derribo_desde:
		d.derribo = true
	return d


## Altura a lo largo del `up` del marco de referencia. Sobre suelo estatico es la
## Y del mundo; sobre un coloso, no.
func _altura_actual() -> float:
	return sc.up.dot(player.global_position)


func debug_line() -> String:
	match _fase:
		SUSPENDIDO: return "suspendido"
		CAYENDO: return "cayendo desde %.1f m" % (_altura_max - _altura_actual())
		_:
			return "impacto  caida %.1f m  x%.2f dano%s" % [
				_caida, lerpf(1.0, tuning.plunge_dano_mult, _fraccion(_caida)),
				"  DERRIBO" if _caida >= tuning.plunge_derribo_desde else "",
			]
