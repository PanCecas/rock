class_name Golpe
extends RefCounted
## Un impacto concreto viajando del atacante a la víctima.
##
## Existe para que la Hurtbox pueda decidir qué hacer con él —encajarlo, bloquearlo,
## parriearlo— sin que el atacante tenga que saber nada de la defensa del otro.

enum Resultado { IMPACTO, BLOQUEADO, PARRY, PARRY_PERFECTO, INMUNE }

var atacante: Node3D
var datos: AttackData
var punto: Vector3
## Dirección del golpe en el mundo, del atacante hacia la víctima.
var direccion: Vector3
var resultado: int = Resultado.IMPACTO
## Multiplicador de dano. Lo pone quien recibe, no quien pega: un punto debil
## sabe cuanto vale golpearle ahi, y el arma no tiene por que enterarse.
var multiplicador: float = 1.0
## ¿Ha sido critico? Lo consulta la presentacion y el remate.
var critico: bool = false


func _init(quien: Node3D, que: AttackData, donde: Vector3, hacia: Vector3) -> void:
	atacante = quien
	datos = que
	punto = donde
	direccion = hacia


func dano() -> float:
	return (datos.dano * multiplicador) if datos != null else 0.0


func poise() -> float:
	return (datos.dano_poise * multiplicador) if datos != null else 0.0


## Empuje en espacio de mundo, con la Z local del AttackData girada hacia la víctima.
func empuje_mundo() -> Vector3:
	if datos == null:
		return Vector3.ZERO
	var adelante := direccion
	adelante.y = 0.0
	adelante = adelante.normalized() if not adelante.is_zero_approx() else Vector3.FORWARD
	var derecha := Vector3.UP.cross(adelante).normalized()
	return (
		derecha * datos.empuje.x
		+ Vector3.UP * (datos.empuje.y + datos.lanzamiento)
		+ adelante * datos.empuje.z
	)
