class_name Anclaje
extends Node3D
## EL ANCLAJE: la SEGUNDA cuerda, y solo eso.
##
## Existe para la **resortera** (`docs/03 §5.2`): con dos puntos fijos el jugador
## queda suspendido entre ellos, tira hacia atras y sale catapultado. Con una sola
## cuerda eso no se puede construir —un solo punto da un pendulo, que es el
## balanceo que ya existe—, asi que hacia falta un segundo anclaje.
##
## **No es una segunda lanza, y esa es la decision de diseno.** `Spear` documenta
## por que hay UNA sola: la escasez es lo que convierte "donde la clavo" en una
## decision. Duplicarla se habria llevado eso por delante y ademas habria dejado
## dos plataformas, dos movesets y dos "cual es la empunada". El anclaje no hace
## dano, no es plataforma, no cambia el moveset y no se puede empunar: su unico
## trabajo es ser un punto fijo del que colgar una cuerda.
##
## **Sin FSM, a proposito.** Tiene cuatro comportamientos —guardado, volando,
## clavado y volviendo— y ninguno tiene reglas propias mas alla de "avanza" y
## "quedate quieto". La FSM de `Spear` se justifica sola con seis estados con
## logica distinta cada uno; aqui el precedente correcto es `Proyectil`, que vuela
## y muere en cuarenta lineas. Un nodo-estado por cada `pass` no es arquitectura,
## es ceremonia. Si algun dia le crece un quinto comportamiento con reglas
## propias, ese es el momento de extraerle la maquina: no antes.

signal clavado_en(punto: Vector3, normal: Vector3)
signal recuperado

enum Estado { GUARDADO, VUELO, CLAVADO, RETORNO }

## Techo de duracion del vuelo de vuelta. Existe para que el estado TERMINE
## siempre: si el jugador corre mas rapido de lo previsto, o se teletransporta,
## el anclaje no puede quedarse persiguiendo indefinidamente.
const RETORNO_MAX := 3.0

@export var tuning: SpearTuning
@export var palette: Palette
## Quien lo lanzo. De el cuelga el cordon.
@export var dueno_path: NodePath
## Mismas superficies que la lanza: si algo aguanta un arma clavada, aguanta un
## garfio. Dos listas distintas serian dos sitios donde olvidarse de etiquetar un
## muro, y ese fallo es invisible.
## **INCLUYE `ENEMY`, y eso es lo que separa a la daga de la lanza.**
##
## La lanza ATRAVIESA a los enemigos a propósito (invariante nº 1 de
## `SpearInFlight`) y se para contra la piedra: es la herramienta del MUNDO. La
## daga hace lo contrario en carne — se queda — y ahí nace el reparto:
##
##   la lanza es del MUNDO · la daga es de la CARNE
##
## Sigue clavándose también en piedra, y no es una concesión: la resortera
## necesita DOS puntos fijos, y si la daga fuera solo de carne el tirachinas se
## quedaría sin su segundo anclaje. Un enemigo se mueve, y un ancla que anda rompe
## la conservación de energía del elástico.
@export_flags_3d_physics var capas_clavado: int = (Layers.WORLD | Layers.COLOSSUS_SURFACE
	| Layers.SPEAR_STICK | Layers.ENEMY)

@onready var visual: MeshInstance3D = $Visual
@onready var cordon: Cordon = $Cordon

var dueno: Node3D = null
var estado: int = Estado.GUARDADO
## EN QUE se clavo. Lo mismo que `Spear.cuerpo_clavado` y por lo mismo: un anclaje
## en un coloso es un punto que se mueve, y la Fase 4 lo necesita.
var cuerpo_clavado: Node3D = null

var _dir: Vector3 = Vector3.FORWARD
var _t: float = 0.0
var _origen: Vector3 = Vector3.ZERO
## Desde donde arranco el vuelo de vuelta. Lo usa el arco del retorno.
var _retorno_desde: Vector3 = Vector3.ZERO
## Distancia que habia que recorrer al empezar la vuelta. Es la referencia del
## arco: sin ella no se sabe si vamos por la mitad o acabando.
var _retorno_total: float = 0.0
## Transformada en el espacio del cuerpo clavado, para viajar con el si se mueve.
var _local: Transform3D = Transform3D.IDENTITY
var _mat: StandardMaterial3D


func _ready() -> void:
	if tuning == null:
		tuning = SpearTuning.new()
	if palette == null:
		palette = GameState.palette
	if dueno == null:
		dueno = get_node_or_null(dueno_path) as Node3D
	if cordon != null:
		cordon.palette = palette
	_preparar_visual()
	_ocultar()


func _physics_process(delta: float) -> void:
	if HitstopManager.global_activo():
		return

	match estado:
		Estado.GUARDADO:
			global_position = punto_de_mano()
		Estado.VUELO:
			_volar(delta)
		Estado.CLAVADO:
			# SE MUEVE CON AQUELLO EN LO QUE SE CLAVO. Mismo caso que la lanza: el
			# `ColosoMediano` esta en `COLOSSUS_SURFACE`, que es capa clavable, y
			# se mueve — el anclaje se quedaba flotando en el aire mientras el
			# bicho se iba. Y ademas es un punto de RESORTERA: un ancla que se
			# queda atras convierte el tirachinas en una mentira.
			if cuerpo_clavado != null:
				if not is_instance_valid(cuerpo_clavado):
					recuperar()
				elif cuerpo_clavado is Node3D:
					global_transform = (cuerpo_clavado as Node3D).global_transform * _local
		Estado.RETORNO:
			_volver(delta)


## El cordon a ritmo de RENDER, igual que el de la lanza y por lo mismo: sus
## extremos cuelgan de cosas que la interpolacion de fisica dibuja suaves, asi que
## tenderlo a 60 Hz lo hacia dar saltos contra un personaje fluido.
func _process(_delta: float) -> void:
	_tender_cordon()


# --- API ----------------------------------------------------------------------

func clavado() -> bool:
	return estado == Estado.CLAVADO


func en_vuelo() -> bool:
	return estado == Estado.VUELO


func guardado() -> bool:
	return estado == Estado.GUARDADO


## ¿Está clavada en CARNE, y en carne que se pueda zarandear?
##
## Pregunta por `agarrable` y no por `is Enemigo`: quién se deja agarrar lo
## declara el enemigo, igual que `WeakPoint.llave` y `AttackData.etiquetas`. Con
## una propiedad, añadir un bicho agarrable es escribirle un `true` en su `.tscn`;
## con un `if enemigo is Embestidor` aquí dentro, cada enemigo nuevo obliga a
## abrir el arma.
##
## Un coloso NO es agarrable, y ese defecto es la regla: zarandear algo de siete
## metros no es creíble, y el punto débil ya tiene su verbo.
func en_carne() -> bool:
	if estado != Estado.CLAVADO or cuerpo_clavado == null:
		return false
	if not is_instance_valid(cuerpo_clavado) or not (cuerpo_clavado is Enemigo):
		return false
	var e := cuerpo_clavado as Enemigo
	return e.agarrable and e.esta_vivo()


## El enemigo en el que está clavada, o null.
func presa() -> Enemigo:
	return cuerpo_clavado as Enemigo if en_carne() else null


## Lo tira. Solo desde guardado: un anclaje ya puesto se recupera antes de volver
## a tirarlo, y eso es lo que hace que colocar los dos puntos sea una decision.
func lanzar(desde: Vector3, hacia: Vector3) -> bool:
	if estado != Estado.GUARDADO or hacia.is_zero_approx():
		return false
	global_position = desde
	reset_physics_interpolation()   # un teletransporte no se interpola
	_origen = desde
	_dir = hacia.normalized()
	_t = 0.0
	cuerpo_clavado = null
	estado = Estado.VUELO
	_mostrar()
	return true


## Lo llama de vuelta. **Vuelve VOLANDO, como la lanza.**
##
## Antes desaparecia y reaparecia en la mano de golpe, y eso se lee mal por la
## misma razon que `SpearReturning` existe: sin ver el recorrido, recuperar parece
## un teletransporte y el jugador no sabe si lo ha recogido o lo ha perdido. Es la
## misma leccion que `docs/03 §4.4` ya tenia escrita para la lanza — y como ya
## estaba resuelta ahi, aqui se copia el criterio en vez de inventar otro.
func recuperar() -> bool:
	if estado == Estado.GUARDADO or estado == Estado.RETORNO:
		return false
	cuerpo_clavado = null
	_retorno_desde = global_position
	_retorno_total = maxf(global_position.distance_to(punto_de_mano()), 0.001)
	_t = 0.0
	estado = Estado.RETORNO
	return true


## EL VUELO DE VUELTA, con arco.
##
## En linea recta se ve peor y no es capricho: la curva es lo que hace legible que
## el anclaje VUELVE en vez de aparecer. Mismos numeros que la lanza
## (`velocidad_retorno`, `arco_retorno`) porque es el mismo gesto: dos curvas de
## retorno distintas en el mismo juego se leerian como un bug de una de las dos.
func _volver(delta: float) -> void:
	_t += delta
	var mano := punto_de_mano()
	var hacia := mano - global_position
	var dist := hacia.length()

	# LLEGA, O SE RINDE. El techo de tiempo no es paranoia: es lo que garantiza
	# que el estado TERMINA pase lo que pase con el jugador.
	if dist <= tuning.radio_atrape or _t >= RETORNO_MAX:
		_guardar()
		return

	# PERSECUCION, no interpolacion entre dos puntos.
	#
	# La primera version interpolaba de `_retorno_desde` a la mano con un
	# progreso `_t * velocidad / distancia_total`, recalculando la distancia cada
	# frame. Con el jugador quieto funciona; con el jugador ALEJANDOSE, la
	# distancia crece igual de rapido que el progreso y `u` no llega a 1 nunca:
	# el anclaje se queda persiguiendo para siempre. Lo cazo el test, y es un
	# fallo real —tirar el anclaje, seguir corriendo y llamarlo es justo lo que
	# uno hace jugando—, no una rareza del banco de pruebas.
	#
	# Persiguiendo, el retorno termina porque el anclaje es MAS RAPIDO que el
	# jugador: 40 m/s contra un techo de 22.
	var paso: float = minf(tuning.velocidad_retorno * delta, dist)
	global_position += (hacia / dist) * paso

	# El arco decae con lo que queda: maximo a media vuelta, cero al llegar. Se
	# mide sobre la distancia RESTANTE y no sobre el tiempo, para que un jugador
	# que se mueve no deje el anclaje volando en alto.
	var recorrido: float = clampf(1.0 - dist / maxf(_retorno_total, 0.001), 0.0, 1.0)
	global_position += Vector3.UP * (sin(recorrido * PI) * tuning.arco_retorno * delta * 4.0)


func _guardar() -> void:
	estado = Estado.GUARDADO
	global_position = punto_de_mano()
	reset_physics_interpolation()
	_ocultar()
	recuperado.emit()


## De donde cuelga el cordon. Espejo de `Spear.punto_de_mano()`, y al otro lado
## del cuerpo: dos cuerdas saliendo del mismo punto se leen como una.
func punto_de_mano() -> Vector3:
	if dueno == null or not is_instance_valid(dueno):
		return global_position
	return dueno.global_position + Vector3.UP * 0.95 - dueno.global_basis.x * 0.45


# --- Vuelo --------------------------------------------------------------------

## Igual que `Proyectil`: se avanza y se comprueba el TRAMO recorrido con un rayo,
## no el punto de llegada. A 46 m/s cada frame son 77 cm, y una consulta puntual
## se salta una pared fina entera.
func _volar(delta: float) -> void:
	_t += delta
	var antes := global_position
	global_position += _dir * tuning.anclaje_velocidad * delta

	var espacio := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(antes, global_position, capas_clavado)
	var r := espacio.intersect_ray(q)
	if not r.is_empty():
		_clavar(r.position as Vector3, r.normal as Vector3, r.get("collider") as Node3D)
		return

	# Sin nada que agarrar: vuelve. No se queda en el suelo como la lanza, porque
	# un anclaje tirado en el suelo no es una plataforma ni un arma: es basura que
	# el jugador tendria que ir a recoger.
	if _t >= tuning.anclaje_vida or _origen.distance_to(global_position) > tuning.anclaje_alcance:
		recuperar()


func _clavar(punto: Vector3, normal: Vector3, cuerpo: Node3D) -> void:
	global_position = punto + normal * 0.05
	cuerpo_clavado = cuerpo
	estado = Estado.CLAVADO
	if not normal.is_zero_approx():
		look_at(global_position + normal, Vector3.UP if absf(normal.y) < 0.99 else Vector3.FORWARD)
	# La transformada RESPECTO al cuerpo, para poder viajar con el. Se guarda
	# despues del `look_at` para que la orientacion tambien acompañe si el cuerpo
	# gira. Sin cuerpo se queda en identidad y no se usa.
	if cuerpo != null and is_instance_valid(cuerpo) and cuerpo is Node3D:
		_local = (cuerpo as Node3D).global_transform.affine_inverse() * global_transform
	EventBus.camara_shake.emit(0.12, 0.06)
	clavado_en.emit(punto, normal)


# --- Presentacion -------------------------------------------------------------

## El cordon solo existe cuando el anclaje esta FUERA. Guardado no cuelga de nada,
## y dibujar una cuerda de cero metros deja una mancha en pantalla.
func _tender_cordon() -> void:
	if cordon == null:
		return
	cordon.tender(_mano_dibujada(), get_global_transform_interpolated().origin,
		estado != Estado.GUARDADO and dueno != null)


## Espejo de `Spear._mano_dibujada()`: la mano tal y como se DIBUJA este frame.
func _mano_dibujada() -> Vector3:
	if dueno == null or not is_instance_valid(dueno):
		return global_position
	var t := dueno.get_global_transform_interpolated()
	return t.origin + Vector3.UP * 0.95 - t.basis.x * 0.45


func _preparar_visual() -> void:
	if visual == null:
		return
	var m := SphereMesh.new()
	m.radius = tuning.anclaje_radio
	m.height = tuning.anclaje_radio * 2.0
	m.radial_segments = 8
	m.rings = 4
	visual.mesh = m
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color_de(&"lavanda_gris")
	_mat.metallic = 0.5
	_mat.roughness = 0.35
	visual.material_override = _mat


func _mostrar() -> void:
	if visual != null:
		visual.visible = true


func _ocultar() -> void:
	if visual != null:
		visual.visible = false


func color_de(nombre: StringName) -> Color:
	if palette == null:
		return Color.WHITE
	var v: Variant = palette.get(nombre)
	return v if v is Color else Color.WHITE


func debug_line() -> String:
	return ["guardado", "VUELO", "CLAVADO", "VOLVIENDO"][estado]
