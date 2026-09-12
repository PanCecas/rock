extends PlayerStateGroup
## Estados de combate. El grupo aporta poco a propósito: durante un ataque el
## jugador NO debe caerse a otro estado por accidente, o los combos se rompen solos.
##
## Lo que sí centraliza son las REGLAS DE CANCELACIÓN por defecto, que es donde
## vive la sensación estilizada. Ver docs/03_ARQUITECTURA_MECANICAS.md §3.3.

## Frames de recuperación durante los que sigue abierto el parry.
const PARRY_TRAS_ATAQUE := 6


func shared_update(delta: float) -> void:
	# Los ataques NO gastan stamina: esto no es un souls. Pero tampoco regenera a
	# tope mientras peleas, o el sprint infinito trivializaría el reposicionamiento.
	if player.is_on_floor():
		player.stamina.regenerar(tuning.stamina_regen_suelo * 0.35, delta)


## ¿Se puede cancelar el ataque `datos` con la acción `tipo` en este frame?
##
## Si el .tres declara una ventana explícita, manda. Si no, estas son las reglas
## por defecto, y son las que hacen que el combate se sienta cancelable en vez de
## comprometido:
##   · dash  — SIEMPRE desde que se abre la ventana activa. Es la vía de escape.
##   · salto — solo si el golpe CONECTÓ. Fallar tiene que costar.
##   · parry — en los primeros frames de la recuperación.
##   · ataque— desde `frame_cadena`.
func puede_cancelar(tipo: StringName, datos: AttackData, frame: int, conectado: bool) -> bool:
	if datos == null:
		return true
	if not datos.cancelaciones.is_empty() and datos.cancelaciones.has(tipo):
		return datos.cancelable(tipo, frame)

	match tipo:
		&"dash":
			return frame >= datos.frames_windup
		&"jump":
			return conectado and frame >= datos.frames_windup
		&"parry":
			var inicio := datos.frames_windup + datos.frames_activo
			return frame >= inicio and frame < inicio + PARRY_TRAS_ATAQUE
		&"attack":
			return frame >= datos.frame_cadena
	return false
