extends PlayerState
## Ataque en picado. Tres fases: te paras en el aire, caes a plomo, revientas el
## suelo en área.
##
## La pausa inicial no es adorno: es la telegrafía que le da peso al impacto y la
## que permite apuntar. Un plunge instantáneo se siente como caerse.

enum { SUSPENDIDO, CAYENDO, IMPACTO }

const SUSPENSION := 0.16
const VELOCIDAD_CAIDA := -34.0

var _datos: AttackData
var _fase: int = SUSPENDIDO
var _t_fase: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_datos = player.ataque_plunge
	_fase = SUSPENDIDO
	_t_fase = 0.0
	player.velocity = Vector3.ZERO
	player.hitbox.nuevo_swing()


func physics_update(delta: float) -> void:
	_t_fase += delta
	match _fase:
		SUSPENDIDO:
			player.velocity = Vector3.ZERO
			# Reorientar mientras flotas: es el momento de elegir dónde caes.
			var entrada := sc.direccion_movimiento(buffer.move_vector(), player.camara())
			if not entrada.is_zero_approx():
				motor.impulso(entrada, 3.0)
			if _t_fase >= SUSPENSION:
				_fase = CAYENDO
				_t_fase = 0.0
		CAYENDO:
			motor.set_vertical(VELOCIDAD_CAIDA)
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
	# Golpea en 360°: el plunge es el limpiapantallas del moveset.
	player.hitbox.nuevo_swing()
	var n := player.hitbox.golpear(_datos, player.direccion_frontal())

	HitstopManager.golpe(_datos.hitstop, [player])
	EventBus.camara_shake.emit(_datos.shake * (1.6 if n > 0 else 0.8), 0.22)
	CombatFX.onda(
		player.get_parent(),
		player.global_position + Vector3.UP * 0.1,
		player.color_de(_datos.color_vfx),
		_datos.alcance * 1.3
	)


func debug_line() -> String:
	match _fase:
		SUSPENDIDO: return "suspendido"
		CAYENDO: return "cayendo"
		_: return "impacto"
