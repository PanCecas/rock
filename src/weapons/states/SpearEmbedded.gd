extends SpearState
## CLAVADA. La mecánica clave (`docs/03 §4.3`).
##
## Al clavarse aparece una plataforma sobre la que el jugador se puede quedar DE
## PIE. No es un extra: tirarla a lo alto, subir y pararse encima es el bucle de
## progresión vertical del juego. Sin la plataforma, la lanza es solo un arma que
## luego hay que recoger.
##
## **SE MUEVE CON AQUELLO EN LO QUE SE CLAVÓ**, y sin reparentarse a nada.
##
## Antes se quedaba fija en el mundo. Contra una pared da igual, pero el
## `ColosoMediano` está en la capa `COLOSSUS_SURFACE` —que sí es clavable— y se
## mueve: la lanza se quedaba flotando en el aire mientras el bicho se iba, que es
## justo lo que el usuario reportó. Y la plataforma se quedaba con ella, así que
## el asidero acababa en mitad de la nada.
##
## Se guarda la transformada **en el espacio del cuerpo** y se recompone cada
## frame. Guardar solo un desfase de posición no basta: si el coloso GIRA, la
## lanza tiene que girar con él y su normal también, o la plataforma sale por el
## lado equivocado.
##
## **Nunca se reparenta** (regla dura #3), y esto no contradice la #19: aquello
## mueve al JUGADOR con una superficie, y de eso sigue encargándose
## `SurfaceContext` en exclusiva. Esto mueve un objeto con el cuerpo en el que
## está clavado, que es otro problema.

## Transformada de la lanza en el espacio local del cuerpo clavado.
var _local: Transform3D = Transform3D.IDENTITY
## El punto y la normal, también en local: los dos viajan con el cuerpo.
var _punto_local: Vector3 = Vector3.ZERO
var _normal_local: Vector3 = Vector3.UP


func enter(msg: Dictionary = {}) -> void:
	lanza.punto_clavado = msg.get("punto", lanza.global_position)
	lanza.normal_clavado = msg.get("normal", Vector3.UP)
	lanza.cuerpo_clavado = msg.get("cuerpo", null) as Node3D
	_guardar_local()
	lanza.poner_plataforma()
	_colocar()
	EventBus.camara_shake.emit(0.35, 0.12)
	CombatFX.impacto(lanza.get_parent(), lanza.punto_clavado,
		lanza.color_de(&"oro_palido"), 1.1)
	lanza.clavada.emit(lanza.punto_clavado, lanza.normal_clavado)


func physics_update(_delta: float) -> void:
	var c := lanza.cuerpo_clavado
	if c == null or not is_instance_valid(c) or not (c is Node3D):
		return   # clavada en el mundo estático: no hay nada que seguir
	var t := (c as Node3D).global_transform
	lanza.global_transform = t * _local
	lanza.punto_clavado = t * _punto_local
	lanza.normal_clavado = (t.basis * _normal_local).normalized()
	_colocar()


func exit(_siguiente: StringName) -> void:
	lanza.soltar_plataforma()


## Guarda dónde está la lanza RESPECTO al cuerpo. Si no hay cuerpo, o no es un
## `Node3D`, se queda en identidad y `physics_update` no hace nada.
func _guardar_local() -> void:
	var c := lanza.cuerpo_clavado
	if c == null or not is_instance_valid(c) or not (c is Node3D):
		return
	var inv := (c as Node3D).global_transform.affine_inverse()
	_local = inv * lanza.global_transform
	_punto_local = inv * lanza.punto_clavado
	_normal_local = inv.basis * lanza.normal_clavado


func _colocar() -> void:
	# FUERA de la pared, sobre el trozo de asta que sobresale. El origen de la
	# lanza queda hundido dentro de la superficie, asi que dejar la plataforma
	# ahi la entierra y el jugador la atraviesa al caer encima.
	lanza.colocar_plataforma(lanza.punto_clavado
		+ lanza.normal_clavado * tuning.plataforma_salida)
	# Clavada CONTRA la superficie: el asta apunta hacia dentro.
	lanza.apuntar_a(-lanza.normal_clavado)


func debug_line() -> String:
	var n := lanza.normal_clavado
	var s := "" if lanza.cuerpo_clavado == null else "  en %s" % lanza.cuerpo_clavado.name
	return "CLAVADA  n=%.1f,%.1f,%.1f%s" % [n.x, n.y, n.z, s]
