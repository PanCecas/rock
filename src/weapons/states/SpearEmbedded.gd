extends SpearState
## CLAVADA. La mecánica clave (`docs/03 §4.3`).
##
## Al clavarse aparece una plataforma sobre la que el jugador se puede quedar DE
## PIE. No es un extra: tirarla a lo alto, subir y pararse encima es el bucle de
## progresión vertical del juego. Sin la plataforma, la lanza es solo un arma que
## luego hay que recoger.
##
## Se queda quieta en el mundo y NO se reparenta a nada. Colgarla de un cuerpo
## que se mueve es trabajo de la Fase 4 y pasa por `SurfaceContext` (regla dura
## #18): un solo mecanismo mueve las cosas con una superficie móvil.

func enter(msg: Dictionary = {}) -> void:
	lanza.punto_clavado = msg.get("punto", lanza.global_position)
	lanza.normal_clavado = msg.get("normal", Vector3.UP)
	lanza.cuerpo_clavado = msg.get("cuerpo", null) as Node3D
	lanza.poner_plataforma()
	# FUERA de la pared, sobre el trozo de asta que sobresale. El origen de la
	# lanza queda hundido dentro de la superficie, asi que dejar la plataforma
	# ahi la entierra y el jugador la atraviesa al caer encima.
	lanza.colocar_plataforma(lanza.punto_clavado
		+ lanza.normal_clavado * tuning.plataforma_salida)
	# Clavada CONTRA la superficie: el asta apunta hacia dentro.
	lanza.apuntar_a(-lanza.normal_clavado)
	EventBus.camara_shake.emit(0.35, 0.12)
	CombatFX.impacto(lanza.get_parent(), lanza.punto_clavado,
		lanza.color_de(&"oro_palido"), 1.1)
	lanza.clavada.emit(lanza.punto_clavado, lanza.normal_clavado)


func exit(_siguiente: StringName) -> void:
	lanza.soltar_plataforma()


func debug_line() -> String:
	var n := lanza.normal_clavado
	return "CLAVADA  n=%.1f,%.1f,%.1f" % [n.x, n.y, n.z]
