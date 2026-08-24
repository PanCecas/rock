extends PlayerState
## STATIONARY CROUCH LANDING: caer agachado y casi parado.
##
## Es el hueco que faltaba en el aterrizaje. Habia dos respuestas —el aterrizaje
## normal, que te deja de pie, y el landing slide, que convierte la caida en
## deslizamiento— y las dos asumian que llegabas con velocidad. Caer en vertical
## manteniendo agachado se resolvia poniendote de pie, que es justo lo contrario
## de lo que pide el gesto.
##
## Quien decide no es el boton, es la VELOCIDAD HORIZONTAL REAL:
##
##   >= landing_slide_min  -> Slide: la caida se convierte en linea.
##   <  landing_crouch_max -> aqui:  la caida se absorbe en cuclillas.
##   entre medias          -> aterrizaje de siempre.
##
## Y no se levanta al terminar: cede a `Crouch`, que es quien decide cuando el
## personaje vuelve a estar de pie. Aire -> recepcion -> agachado es una sola
## postura sostenida, no tres transiciones encadenadas.

var _duracion: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	# La capsula ya baja interpolada (`agachado_transicion`), asi que el cambio de
	# altura no se ve como un salto: es la misma rampa que usa el agachado normal.
	player.set_altura_colision(tuning.agachado_altura)
	player.wallrun_disponible = true
	player.recargar_aire()

	# Una caida mas larga hunde mas la recepcion. Es lo unico que distingue dejarse
	# caer un metro de tirarse desde una torre cuando las dos acaban quietas.
	var impacto: float = float(msg.get("impacto", 0.0))
	var exceso: float = (impacto - tuning.aterrizaje_duro) / 20.0
	_duracion = tuning.landing_crouch_duracion * clampf(1.0 + exceso, 1.0, 2.0)

	motor.impulso(motor.direccion_plana(), 0.0)
	EventBus.camara_shake.emit(clampf(impacto / 40.0, 0.05, 0.4), 0.12)


func exit(siguiente: StringName = &"") -> void:
	# Solo se recupera la altura si NO se sigue agachado. Levantarse aqui para que
	# `Crouch` volviera a agacharse en el mismo frame era el chasquido a evitar.
	if siguiente != &"Crouch" and siguiente != &"Slide" and not player.techo_bloquea():
		player.set_altura_colision(1.0)


func physics_update(delta: float) -> void:
	# Frenar del todo: lo poco que quedaba de velocidad se va aqui.
	motor.frenar(tuning.crouch_friccion * 1.5, delta)
	motor.set_vertical(-2.0)

	# Cancelar la recepcion saltando: estas en cuclillas, asi que sale el salto
	# FUERTE de agachado. Es la maniobra que premia caer con intencion.
	if player.consumir_salto():
		motor.set_vertical(tuning.velocidad_salto_agachado())
		EventBus.camara_shake.emit(0.35, 0.14)
		CombatFX.onda(
			player.get_parent(), player.global_position + Vector3.UP * 0.1,
			player.color_de(&"crema_bruma"), 1.5
		)
		fsm.cambiar(&"Jump", {"numero": 1, "conservar_vertical": true, "sin_corte": true}, true)
		return

	if t < _duracion:
		return

	# Se acabo la recepcion. Se CONSERVA la postura: quien decide levantarse es el
	# agachado, comprobando el boton y el techo.
	if buffer.is_held(InputActions.CROUCH) or player.techo_bloquea():
		fsm.cambiar(&"Crouch")
	else:
		fsm.cambiar(&"Move" if buffer.move_vector().length() > 0.2 else &"Idle")


## El salto es SUYO. Estas en cuclillas, asi que saltar tiene que dar el salto
## fuerte de agachado y no el generico del grupo. Ver regla dura #13 de CLAUDE.md:
## sin reclamarlo, `GroupGrounded` se come la pulsacion antes de llegar aqui.
func maneja_salto() -> bool:
	return true


func debug_line() -> String:
	return "recepcion %.0f%%" % (100.0 * t / maxf(_duracion, 0.001))
