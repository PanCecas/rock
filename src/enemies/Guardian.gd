class_name Guardian
extends Enemigo
## Guardián de Ruina: constructo de piedra. Existe para que el combate tenga con
## qué practicarse, no para poblar el mundo.
##
## Los tres arquetipos comparten este script y se diferencian por DATOS:
##   LANCERO — agresivo, presiona y castiga la pasividad
##   ESCUDO  — bloquea de frente; su ataque cargado es EL objetivo del parry
##   VIGIA   — a distancia, obliga a moverse
##
## Este archivo tenía 372 líneas y mezclaba tres cosas: la IA (un `match` sobre un
## enum dentro de `_physics_process`), la física (`is_on_floor()`, gravedad manual)
## y la presentación. Eso bloqueaba al director de grupo, al coloso mediano y a
## cualquier enemigo que no pisara el suelo.
##
## Ahora solo queda **lo que es específico de un guardián terrestre**:
## los tres arquetipos, la guardia frontal del Escudo y la embestida del Lancero.
## Todo lo demás vive en `Enemigo`, `EnemyMotor` y `states/`.
##
## Criterio de terminado del P0, y se cumple: escribir un enemigo que vuele o nade
## no toca este archivo. Basta con `vuela = true` y su propio `.tscn`.

enum Tipo { LANCERO, ESCUDO, VIGIA }

## El enum de estados se conserva porque las herramientas y los tests hablan en
## `Guardian.Estado.DERRIBADO`. La FSM es la que manda; `Enemigo.estado` traduce
## entre los dos en las dos direcciones.
enum Estado { DORMIDO, ACERCARSE, TELEGRAFIA, ATACAR, RECUPERAR, ATURDIDO, DERRIBADO, QUEBRADO, MUERTO }

@export var tipo: Tipo = Tipo.LANCERO
## El Escudo bloquea todo lo que llegue dentro de este semiángulo frontal.
@export_range(0.0, 180.0, 5.0) var arco_guardia: float = 70.0
## Velocidad del empujón del Lancero en el frame activo.
@export_range(0.0, 20.0, 0.5) var lancero_embestida: float = 5.0


func _ready() -> void:
	super()
	add_to_group(&"guardianes")


## Estadísticas por arquetipo. Son datos, no comportamiento: los tres usan
## exactamente los mismos estados.
func configurar_tipo() -> void:
	match tipo:
		Tipo.LANCERO:
			salud.maxima = 60.0
			poise.maxima = 30.0
			cadencia = 1.1
			velocidad = 4.2
		Tipo.ESCUDO:
			salud.maxima = 110.0
			poise.maxima = 55.0
			cadencia = 2.0
			velocidad = 2.6
			alcance_ataque = 2.2
		Tipo.VIGIA:
			salud.maxima = 45.0
			poise.maxima = 20.0
			cadencia = 2.4
			velocidad = 3.0
			alcance_ataque = 9.0
	salud.actual = salud.maxima
	poise.actual = poise.maxima


## El Escudo bloquea de frente salvo que el ataque rompa guardia o esté quebrado.
## Es la única defensa activa del bestiario y la razón de que el parry se entrene
## contra él.
func bloquea(golpe: Golpe) -> bool:
	if tipo != Tipo.ESCUDO or poise.rota or fsm.nombre_actual() == &"Quebrado":
		return false
	if golpe.datos != null and golpe.datos.rompe_guardia:
		return false
	var frente := -global_basis.z
	var desde := -golpe.direccion
	desde.y = 0.0
	if desde.is_zero_approx():
		return false
	return rad_to_deg(frente.angle_to(desde.normalized())) <= arco_guardia


## El Lancero avanza al golpear: castiga quedarse quieto justo fuera de rango.
func avance_al_golpear() -> float:
	return lancero_embestida if tipo == Tipo.LANCERO else 0.0


## El VIGIA mantiene distancia; los otros dos van a por ti. Es un número, no un
## estado: acercarse y alejarse son el mismo problema con el signo cambiado.
func distancia_minima() -> float:
	return alcance_ataque * 0.6 if tipo == Tipo.VIGIA else 0.0
