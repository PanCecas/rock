extends SpearState
## Guardada. No existe para nadie: ni se ve, ni golpea, ni estorba.
##
## **Pero SIGUE a la mano igualmente**, aunque no se vea. Antes se quedaba con la
## transformada de la ultima vez, y una posicion rancia en un objeto invisible es
## una trampa: cualquiera que la lea sin comprobar el estado apunta al sitio
## equivocado sin que nada avise. Eso fue el bug de la Z con la lanza guardada,
## que mandaba al jugador de vuelta al spawn desde la cima del coloso.
##
## El guardia correcto es `Spear.esta_fuera()` y ya esta puesto; esto es la otra
## mitad: que no haya un valor sucio esperando a que alguien se lo crea.

func enter(_msg: Dictionary = {}) -> void:
	lanza.visible = false
	lanza.soltar_plataforma()


func physics_update(_delta: float) -> void:
	if lanza.dueno != null and is_instance_valid(lanza.dueno):
		lanza.global_position = lanza.punto_de_mano()


func exit(_siguiente: StringName) -> void:
	lanza.visible = true
