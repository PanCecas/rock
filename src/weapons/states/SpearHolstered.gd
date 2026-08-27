extends SpearState
## Guardada. No existe para nadie: ni se ve, ni golpea, ni estorba.

func enter(_msg: Dictionary = {}) -> void:
	lanza.visible = false
	lanza.soltar_plataforma()


func exit(_siguiente: StringName) -> void:
	lanza.visible = true
