extends EnemyState
## Persigue hasta ponerse a distancia de ataque, y espera su turno.
##
## Un enemigo que mantiene distancia (el Vigia) usa el mismo estado: la diferencia
## esta en `distancia_deseada()`, no en un estado aparte, porque acercarse y
## alejarse son el mismo problema con el signo cambiado.

func physics_update(delta: float) -> void:
	if not enemigo.objetivo_valido():
		fsm.cambiar(&"Dormido")
		return

	var hacia := enemigo.hacia_objetivo()
	var dist := hacia.length()
	enemigo.encarar(hacia)

	var minima := enemigo.distancia_minima()
	if minima > 0.0 and dist < minima:
		# Demasiado cerca: retroceder. Es lo que obliga al jugador a perseguir en
		# vez de quedarse pegado.
		enemigo.motor.mover(-hacia.normalized(), enemigo.velocidad, delta)
		return

	if dist > enemigo.alcance_ataque:
		# POR LA RUTA, no en linea recta. `rumbo_hacia()` devuelve el siguiente
		# paso del navmesh si el enemigo trae agente y la linea recta si no, asi
		# que este estado no sabe —ni tiene por que saber— cual de las dos cosas
		# esta pasando. Encarar sigue siendo hacia el JUGADOR y no hacia el nodo
		# del camino: mirar a una esquina mientras te persigue se lee fatal.
		var rumbo := enemigo.rumbo_hacia(enemigo.objetivo.global_position)
		if not rumbo.is_zero_approx():
			enemigo.motor.mover(rumbo.normalized(), enemigo.velocidad, delta)
		return

	enemigo.motor.frenar(delta)
	if enemigo.espera <= 0.0 and enemigo.ataque != null:
		# ARQUETIPO A DISTANCIA: sin linea de vision NO dispara.
		#
		# Es la mitad que lo separa del cuerpo a cuerpo. Un enemigo a distancia que
		# atraviesa columnas convierte la cobertura en decorado, y esconderse —que
		# es la respuesta que este arquetipo existe para enseñar— deja de funcionar.
		# En vez de disparar se DESPLAZA de lado para volver a verte, que es lo que
		# haria cualquiera y ademas lo mantiene legible: se le ve buscando angulo.
		if enemigo.necesita_linea_de_vision() and not enemigo.hay_linea_de_vision(enemigo.objetivo):
			_buscar_angulo(hacia, delta)
			return
		fsm.cambiar(enemigo.estado_de_ataque())


## Se mueve PERPENDICULAR a la linea con el jugador para recuperar el angulo.
##
## El lado se decide una vez por enemigo y no cambia: recalcularlo cada frame hace
## que dos obstaculos seguidos lo dejen oscilando en el sitio. Sale del id de la
## instancia para que dos enemigos detras de la misma columna no salgan los dos por
## el mismo lado y se amontonen.
func _buscar_angulo(hacia: Vector3, delta: float) -> void:
	if hacia.is_zero_approx():
		return
	var lado := 1.0 if (enemigo.get_instance_id() % 2) == 0 else -1.0
	var perpendicular := hacia.normalized().cross(Vector3.UP) * lado
	enemigo.motor.mover(perpendicular.normalized(), enemigo.velocidad * 0.8, delta)


func debug_line() -> String:
	return "%.1f m" % enemigo.hacia_objetivo().length()
