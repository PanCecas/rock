extends EnemyState
## ESTAMPADO. Volando hacia el suelo despues de que lo zarandearan, y con un
## golpe en AREA esperando al aterrizar.
##
## Es el pago del zarandeo: girar antes de estampar tiene que significar algo, y
## lo que significa es **cuanta area barre el impacto y cuanto duele**. Un cuerpo
## que llevabas quieto cae; uno que llevabas lanzado revienta.
##
## El dano lo escala `PlayerController.escalar_por_inercia()`, que ya existe para
## la carga en viaje. Reusarlo no es ahorro: es que el jugador ya aprendio esa
## relacion —mas velocidad, mas empuje— y darle otra curva aqui seria enseñarle
## dos reglas para lo mismo.

## Techo de tiempo. Si no toca nada —lo estampas al vacio— se rinde y vuelve a la
## vida normal en vez de quedarse cayendo para siempre.
const VUELO_MAX := 2.5
## Gracia antes de admitir un impacto, en segundos.
##
## Sin ella el estampido se resuelve EN EL MISMO FRAME cuando el cuerpo ya estaba
## rozando el suelo —que es lo normal, porque gira a la altura del jugador—:
## `is_on_floor()` sigue siendo cierto del frame anterior y el golpe salta antes
## de que el cuerpo se haya movido un centimetro. El impacto tiene que ser un
## VIAJE que termina, no una casilla que ya estaba marcada.
const GRACIA := 0.08

var _equipo_previo: int = 1


func enter(_msg: Dictionary = {}) -> void:
	if enemigo.hitbox != null:
		# Sigue siendo un arma del jugador hasta que aterriza: atropellar a otro
		# enemigo de camino al suelo es media gracia.
		_equipo_previo = enemigo.hitbox.equipo
		enemigo.hitbox.equipo = 0
		enemigo.hitbox.nuevo_swing()


func exit(_siguiente: StringName = &"") -> void:
	if enemigo.hitbox != null:
		enemigo.hitbox.equipo = _equipo_previo
	enemigo.impacto_estampido = 0.0


func physics_update(_delta: float) -> void:
	# La gravedad normal ya se le aplica desde `Enemigo._physics_process`: aqui el
	# cuerpo ya no cuelga de nadie, asi que vuelve a pesar como todo lo demas.
	if t >= GRACIA and (enemigo.is_on_floor() or enemigo.is_on_wall()):
		_impactar()
		return
	if t >= VUELO_MAX:
		fsm.cambiar(&"Aturdido")


## EL IMPACTO. Dano en area alrededor del punto donde cayo, escalado por la
## velocidad que traia.
func _impactar() -> void:
	var datos: AttackData = enemigo.ataque_estampido
	var j := enemigo.jugador()
	if datos != null and enemigo.hitbox != null:
		if j != null and is_instance_valid(j) and j.has_method("escalar_por_inercia"):
			datos = j.escalar_por_inercia(datos, enemigo.impacto_estampido)
		enemigo.hitbox.nuevo_swing()
		enemigo.hitbox.golpear(datos, Vector3.UP)
		# Y SE HACE DANO A SI MISMO. Estamparse contra el suelo a veinte metros por
		# segundo tiene que doler tambien al que se estampa, o el cuerpo agarrado
		# seria un arma sin desgaste.
		enemigo.recibir_golpe(Golpe.new(j, datos, enemigo.global_position, Vector3.UP))

	EventBus.camara_shake.emit(0.8, 0.22)
	CombatFX.onda(enemigo.get_parent(), enemigo.global_position,
		enemigo.color_de(&"oro_palido"), 3.2)
	if enemigo.esta_vivo():
		enemigo.stagger = 1.1
		fsm.cambiar(&"Aturdido")


func debug_line() -> String:
	return "ESTAMPADO  %.1f m/s" % enemigo.impacto_estampido
