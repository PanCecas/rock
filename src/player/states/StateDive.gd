extends PlayerState
## CLAVADO. Los dos ataques aereos del juego, separados solo por el peso.
##
## Se lanza hacia DELANTE Y ABAJO desde el primer frame. Esa es la diferencia
## entre un clavado y "desplazarse mientras caes": antes salia con velocidad
## vertical cero y dejaba que la gravedad hiciera el resto, asi que la trayectoria
## empezaba plana y solo se curvaba tarde. Saliendo ya hacia abajo, la diagonal se
## dibuja entera desde el principio y se puede apuntar de un vistazo.
##
## Fisica de Mario 64: **velocidad horizontal CONSTANTE** en caida libre. Ni
## rozamiento ni aceleracion; solo la gravedad tira. Eso es lo que hace que la
## trayectoria se pueda leer y planificar antes de saltar.
##
## La hitbox vive TODO el trayecto. No es un golpe con ventana activa: es un
## proyectil que eres tu.
##
##   LIGERO -> el AGIL. Cae a plomo hacia delante y al pisar una cabeza REBOTA,
##     devolviendote al aire para encadenar sobre otra. Es el que mantiene el
##     ritmo, y por eso es el rapido y barato: rebotar tiene que ser el gesto que
##     mas repites, no el que mas te cuesta.
##   PESADO -> el CONTUNDENTE. Viaja mas y, al conectar, LEVANTA al enemigo por
##     los aires unos segundos. No rebota: se planta. Uno abre el juego aereo
##     —sube al enemigo—, el otro lo sostiene —te mantiene a ti arriba—.
##
## Si el clavado termina en agua, la entrada gana profundidad de verdad.

var _dir: Vector3 = Vector3.ZERO
var _rapidez: float = 0.0
var _pesado: bool = false
var _conectado: bool = false


func enter(msg: Dictionary = {}) -> void:
	_pesado = bool(msg.get("pesado", false))
	_conectado = false
	_dir = msg.get("direccion", motor.direccion_plana())
	if _dir.is_zero_approx():
		_dir = player.direccion_frontal()

	# El impulso inicial separa un clavado de una caida: sales hacia delante Y hacia
	# abajo. La velocidad horizontal ya no vuelve a cambiar.
	var empuje: float = tuning.dive_pesado_impulso if _pesado else tuning.dive_impulso
	_rapidez = maxf(motor.rapidez_plana(), empuje)
	motor.impulso(_dir, _rapidez)
	var vertical: float = tuning.dive_pesado_vertical if _pesado else tuning.dive_vertical_inicial
	motor.set_vertical(minf(motor.get_vertical(), vertical))

	player.cd_dive = tuning.dive_cooldown
	player.hitbox.nuevo_swing()
	player.orientar_a(_dir)
	player.set_alabeo(0.0)
	EventBus.camara_shake.emit(0.5 if _pesado else 0.35, 0.16 if _pesado else 0.14)
	CombatFX.arco(
		player.get_parent(), player.global_position + Vector3.UP * 0.9, _dir,
		player.color_de(&"oro_palido" if _pesado else &"azul_claro"), 2.6 if _pesado else 2.0
	)


func physics_update(delta: float) -> void:
	_pilotar(delta)

	# Velocidad horizontal CONSTANTE. Es la fisica de Mario 64 y la razon de que el
	# clavado sea predecible.
	motor.impulso(_dir, _rapidez)
	var vy := motor.get_vertical() + tuning.dive_gravedad * delta
	motor.set_vertical(maxf(vy, tuning.velocidad_terminal))

	# La hitbox esta viva desde el primer frame. `nuevo_swing()` no se repite, asi
	# que cada enemigo se lleva un solo golpe por clavado.
	var datos := _datos()
	if datos != null and player.hitbox.golpear(datos, _dir) > 0:
		_al_conectar(datos)

	if player.agua.en_agua:
		fsm.cambiar(&"Underwater", {"clavado": true, "direccion": _dir})
		return

	if player.is_on_floor():
		# Contra el suelo, un clavado es un aterrizaje duro. Duele porque lo has
		# elegido tu.
		fsm.cambiar(&"Landing", {"impacto": player.impacto_ultimo})


func _datos() -> AttackData:
	if _pesado and player.ataque_dive_pesado != null:
		return player.ataque_dive_pesado
	return player.ataque_dive


func _al_conectar(datos: AttackData) -> void:
	_conectado = true
	HitstopManager.golpe(datos.hitstop, [player])
	EventBus.camara_shake.emit(datos.shake, 0.16)
	CombatFX.impacto(
		player.get_parent(), player.global_position + Vector3.UP * 0.9,
		player.color_de(datos.color_vfx), 1.6 if _pesado else 1.3
	)

	if _pesado:
		# PESADO: se planta y LEVANTA. El enemigo sale por los aires y se queda
		# arriba unos segundos —lo hace el `lanzamiento` de su AttackData—, que es
		# lo que abre la ventana para seguir pegandole en el aire. Este no rebota:
		# si rebotara, los dos clavados harian lo mismo otra vez.
		player.dash_cargas = maxi(player.dash_cargas, tuning.dash_cargas_aire)
		EventBus.camara_shake.emit(0.6, 0.2)
		CombatFX.onda(
			player.get_parent(), player.global_position,
			player.color_de(&"oro_palido"), 2.2
		)
		return

	# REBOTE DEL LIGERO. Se pisa la cabeza y se sale despedido, de vuelta al aire y
	# con el clavado disponible otra vez: enemigo, rebote, enemigo, rebote.
	motor.set_vertical(tuning.dive_rebote)

	# HANG TIME: gravedad cero un instante. Sin esto el rebote es un empujon y ya;
	# con esto hay una pausa en la que se elige la siguiente cabeza.
	player.iniciar_hangtime(tuning.dive_hangtime)

	# Se devuelve el DASH pero NO el salto aereo, a proposito. Reponer el doble
	# salto convertiria la cadena en vuelo infinito: siempre habria una forma de
	# corregir el error de calculo. Sin el, cada rebote es un compromiso y quedarse
	# arriba depende de acertar el siguiente, que es justo lo que hace que la
	# cadena valga algo.
	player.dash_cargas = maxi(player.dash_cargas, tuning.dash_cargas_aire)
	# La espera si se levanta: encadenar es EL punto de esta mecanica.
	player.cd_dive = 0.0

	EventBus.camara_shake.emit(0.45, 0.14)
	CombatFX.onda(
		player.get_parent(), player.global_position,
		player.color_de(&"azul_claro"), 1.8
	)
	fsm.cambiar(&"Fall")


## El clavado se puede corregir, pero poco: es un compromiso, no un planeo.
func _pilotar(delta: float) -> void:
	var entrada := buffer.move_vector()
	if entrada.length() < 0.2:
		return
	var deseada := sc.direccion_movimiento(entrada, player.camara())
	if deseada.is_zero_approx():
		return
	var peso: float = clampf(deg_to_rad(tuning.dive_giro_grados_seg) * delta, 0.0, 1.0)
	_dir = _dir.slerp(deseada, peso).normalized()
	player.orientar_a(_dir)


## La pulsacion de ataque es suya: sin esto el grupo la convierte en otro clavado
## en bucle y el actual no llega a terminar. Ver regla dura #13 de CLAUDE.md.
func maneja_ataques() -> bool:
	return true


func debug_line() -> String:
	return "%s %.1f m/s  vy %.1f%s" % [
		"PESADO" if _pesado else "ligero", _rapidez, motor.get_vertical(),
		"  hit" if _conectado else "",
	]
