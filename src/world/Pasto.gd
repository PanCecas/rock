@tool
class_name Pasto
extends Node3D
## CAMPO DE HIERBA en MultiMesh, con viento e interaccion.
##
## Implementa `docs/07_SHADERS.md §4` —que responde a `01_DIRECCION_ARTE.md §4.5`—
## mas la interaccion: la hierba se aplasta al pasar el jugador y deja un rastro
## que se desvanece.
##
## EL REPARTO DE TRABAJO, que es lo que hace esto barato:
##
##   este nodo  -> DONDE hay una brizna. Se resuelve UNA vez, al sembrar.
##   el shader  -> QUE le pasa a cada brizna cada frame. Viento y aplastado.
##
## Nada de esto corre por brizna en GDScript. El unico trabajo por frame de este
## script son doce `Vector4` —el rastro— y solo si el jugador se ha movido.
##
## **El viento NO se toca aqui.** Vive en `project.godot > shader_globals` y lo
## evalua el shader a partir de `TIME` y de la posicion de mundo, asi que dos
## parches separados por medio mapa sacan el mismo valor sin hablar entre ellos.
## Sincronizarlos desde codigo seria inventar un problema que la formula no tiene.

## Doce huellas: la del jugador AHORA y once de por donde ha pasado. El numero es
## el mismo `HUELLAS` que declara el shader, y no puede cambiarse en un sitio sin
## cambiarlo en el otro.
const HUELLAS := 12

const SHADER := preload("res://src/art/shaders/hierba.gdshader")

@export var palette: Palette
## Lado del parche, en metros. Se siembra centrado en el nodo.
@export var area: Vector2 = Vector2(26.0, 26.0):
	set(v):
		area = v
		_pedir_rehacer()
## Briznas por metro cuadrado. Es EL numero de coste: todo lo demas es constante.
@export_range(0.5, 120.0, 0.5) var densidad: float = 34.0:
	set(v):
		densidad = v
		_pedir_rehacer()
## EL BORDE DEL PARCHE, en fraccion del semilado, donde la siembra se apaga.
##
## Sin esto el campo termina en una LINEA RECTA y el parche se lee como una
## alfombra puesta encima del suelo, no como un claro. Es lo que mas delataba la
## primera version a ojo, mas que la densidad.
@export_range(0.0, 0.9, 0.05) var borde_difuso: float = 0.4:
	set(v):
		borde_difuso = v
		_pedir_rehacer()
## Cuanto se rompe ese borde con ruido. Un desvanecido perfectamente elíptico
## sigue siendo una figura geometrica; lo que hace que parezca vegetacion es que
## el limite sea IRREGULAR.
@export_range(0.0, 0.6, 0.02) var borde_ruido: float = 0.26:
	set(v):
		borde_ruido = v
		_pedir_rehacer()
## Semilla del reparto. Fija a proposito: un campo que cambia entre arranques
## rompe el screenshot test y no aporta nada.
@export var semilla: int = 424242:
	set(v):
		semilla = v
		_pedir_rehacer()
@export_range(0.1, 3.0, 0.05) var alto: float = 0.78:
	set(v):
		alto = v
		_pedir_rehacer()
@export_range(0.005, 0.3, 0.005) var ancho: float = 0.035:
	set(v):
		ancho = v
		_pedir_rehacer()
## Segmentos de la brizna. Cuatro bastan para que el doblado cuadratico se lea
## como una curva; con dos se ve el codo.
@export_range(2, 8, 1) var segmentos: int = 4:
	set(v):
		segmentos = v
		_pedir_rehacer()
## Cuanto se arquea la brizna de serie, sin viento. Una hoja recta parece un palo.
@export_range(0.0, 1.0, 0.01) var curva: float = 0.32:
	set(v):
		curva = v
		_pedir_rehacer()
## Variacion de tamaño planta a planta, en fraccion.
@export_range(0.0, 0.9, 0.01) var variacion: float = 0.35:
	set(v):
		variacion = v
		_pedir_rehacer()
## TU MALLA DE BLENDER, si la tienes. Vacio = la brizna procedural de aqui abajo.
##
## Lo unico que el shader le pide, y no es negociable: **`UV.y = 1` en la base y
## `0` en la punta**, y el origen del objeto EN LA BASE. De esa coordenada salen a
## la vez el gradiente de color y el factor de doblado; con la convencion al reves
## la hierba se dobla desde la punta y crece hacia abajo.
##
## `alto`, `ancho`, `segmentos` y `curva` dejan de usarse en cuanto pones una.
@export var malla: Mesh:
	set(v):
		malla = v
		_pedir_rehacer()

@export_group("Suelo")
## Desde cuanto por encima del nodo se busca el suelo, y hasta cuanto por debajo.
@export var sonda_arriba: float = 30.0
@export var sonda_abajo: float = 30.0
## Pendiente maxima donde crece hierba, en grados. En una pared no crece.
@export_range(0.0, 89.0, 1.0) var pendiente_max: float = 42.0:
	set(v):
		pendiente_max = v
		_pedir_rehacer()

@export_group("Rastro")
## De quien se sigue el rastro. NodePath y no `@export var x: Node3D` — regla #10.
## Vacio = se adopta al jugador que anuncie `EventBus.player_spawned`.
@export var jugador_path: NodePath
## Metros entre huella y huella. Bajo = rastro continuo y se gastan las ranuras en
## un palmo; alto = se ven las pisadas sueltas. A 9.4 m/s —velocidad de correr—
## 0.9 m son diez huellas por segundo, y once ranuras dan algo mas de un segundo
## de cola visible.
@export_range(0.1, 4.0, 0.05) var rastro_paso: float = 0.9
## Cuanto tarda una huella en levantarse del todo.
@export_range(0.2, 20.0, 0.1) var rastro_duracion: float = 3.5
## Radio del aplastado de cada huella, en metros. Ancho de la pisada, no del pie:
## la hierba se tumba mas alla de donde la pisas.
@export_range(0.2, 6.0, 0.05) var rastro_radio: float = 1.5
## Margen vertical. Sin el, pasar por un puente aplasta la hierba de abajo.
@export_range(0.2, 10.0, 0.1) var rastro_alto: float = 1.6
## Cuanto se APARTA la hierba de la huella, en metros de punta.
@export_range(0.0, 3.0, 0.05) var aplaste_empuje: float = 0.85
## Cuanto se HUNDE, en fraccion de su propia altura. A 1.0 queda tumbada del todo.
@export_range(0.0, 3.0, 0.05) var aplaste_hundir: float = 1.4
## Cuanto OSCURECE el aplastado. Es lo que hace que el rastro se LEA: una brizna
## tumbada enseña su cara de abajo y se mete en la sombra de sus vecinas. A cero,
## el rastro existe pero a diez metros solo se distingue un campo un poco mas
## corto — la silueta cambia y el color no.
@export_range(0.0, 1.0, 0.01) var aplaste_sombra: float = 0.35

@export_group("Pixel art")
## ESCALONES del gradiente de cada brizna. 0 = degradado continuo.
##
## Con 3 o 4 la brizna tiene franjas en vez de una rampa, que es lo que la hace
## leerse como pixel art aunque el juego corra a resolucion completa. Y es lo que
## impide que el filtro de pixel (`src/art/PixelArt.gd`) invente sus propios
## escalones donde no tocan.
@export_range(0.0, 8.0, 1.0) var bandas: float = 4.0:
	set(v):
		bandas = v
		_aplicar_bandas()

var multimesh: MultiMeshInstance3D
var _mat: ShaderMaterial
var _jugador: Node3D
## [posicion, segundo de nacimiento]. La 0 es la mas reciente.
var _huellas: Array = []
var _ultima_huella: Vector3 = Vector3(1e9, 1e9, 1e9)
var _reloj: float = 0.0
var _sembrado: bool = false
var _buffer: PackedVector4Array = PackedVector4Array()
## Hay una resiembra pedida para el final de este frame. Ver `_pedir_rehacer()`.
var _pendiente: bool = false


func _ready() -> void:
	if palette == null:
		palette = GameState.palette
	_buffer.resize(HUELLAS)
	_montar()
	if Engine.is_editor_hint():
		# EN EL EDITOR SE SIEMBRA YA. `_physics_process` espera al primer tick de
		# fisica, que en el editor no llega hasta que se pulsa play: sin esto el
		# nodo se ve vacio y no hay nada que ajustar en el inspector.
		sembrar()
		return
	if jugador_path.is_empty():
		EventBus.player_spawned.connect(_adoptar)
	else:
		_jugador = get_node_or_null(jugador_path) as Node3D


## RESIEMBRA DIFERIDA, y diferida a proposito.
##
## Cada `set` del inspector llega por separado, asi que arrastrar un deslizador
## dispara uno por frame y tocar dos valores seguidos dispara dos. Sembrar cuesta
## un rayo por brizna —miles—, y hacerlo en el propio setter congela el editor.
## Con la bandera, N cambios en el mismo frame son UNA siembra.
func _pedir_rehacer() -> void:
	if _pendiente or not is_inside_tree():
		return
	_pendiente = true
	_rehacer.call_deferred()


func _rehacer() -> void:
	_pendiente = false
	if not is_inside_tree():
		return
	if multimesh != null and is_instance_valid(multimesh):
		multimesh.queue_free()
		multimesh = null
	_montar()
	sembrar()


func _adoptar(p: Node3D) -> void:
	if _jugador == null:
		_jugador = p


## A quien seguirle el rastro, ya montado el nodo.
##
## `jugador_path` solo se lee en `_ready()`, y un `NodePath` no se puede calcular
## antes de estar en el arbol: quien planta un `Pasto` desde codigo lo añade
## primero y solo entonces sabe la ruta. Sin esto, ponerle la ruta despues no hace
## nada y el rastro no aparece jamas — sin un solo error.
func seguir(nodo: Node3D) -> void:
	_jugador = nodo
	_ultima_huella = Vector3(1e9, 1e9, 1e9)


## Se siembra en el PRIMER frame de fisica, no en `_ready()`.
##
## La siembra lanza un rayo por brizna para pegarla al suelo, y en `_ready()` los
## colliders del nivel pueden no estar todavia registrados en el espacio: el
## resultado seria un campo de cero briznas y ni un error.
func _physics_process(_delta: float) -> void:
	if not _sembrado:
		sembrar()
		set_physics_process(false)


func _process(delta: float) -> void:
	_reloj += delta
	_actualizar_rastro()


# --- Siembra ------------------------------------------------------------------

## Reparte las briznas por el area y las pega al suelo. Publica, para que un test
## pueda pedirla sin depender de en que frame cae.
func sembrar() -> void:
	_sembrado = true
	if multimesh == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var espacio := get_world_3d().direct_space_state
	var cuantas := int(area.x * area.y * densidad)

	# El ruido que rompe el borde. Se evalua en la siembra y nunca mas: esto no es
	# una animacion, es la FORMA del parche.
	var ruido := FastNoiseLite.new()
	ruido.seed = semilla
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ruido.frequency = 0.12

	var poses: Array[Transform3D] = []
	var colores: PackedColorArray = PackedColorArray()
	for _i in cuantas:
		var x := rng.randf_range(-area.x * 0.5, area.x * 0.5)
		var z := rng.randf_range(-area.y * 0.5, area.y * 0.5)
		# CUANTA hierba toca AQUI. 1 en el centro, 0 pasado el borde.
		var u: float = maxf(
			absf(x) / maxf(area.x * 0.5, 0.001), absf(z) / maxf(area.y * 0.5, 0.001))
		u += ruido.get_noise_2d(x, z) * borde_ruido
		var mezcla: float = 1.0 - smoothstep(1.0 - borde_difuso, 1.0, u)
		if mezcla <= 0.001 or rng.randf() > mezcla:
			continue
		var arriba := global_position + Vector3(x, sonda_arriba, z)
		var abajo := global_position + Vector3(x, -sonda_abajo, z)
		var q := PhysicsRayQueryParameters3D.create(arriba, abajo, Layers.SUELO_JUGADOR)
		var r := espacio.intersect_ray(q)
		var punto: Vector3
		if r.is_empty():
			# SIN SUELO DEBAJO, EN EL EDITOR, SE SIEMBRA EN EL PLANO DEL NODO.
			#
			# En una partida esto es correcto —donde no hay suelo no hay hierba—,
			# pero en el editor el Gym no existe todavia: sus bloques los construye
			# `Gym.gd` al arrancar. Sin esta salida, soltar un `Pasto` en una escena
			# vacia da un campo de cero briznas y nada que ajustar en el inspector.
			if not Engine.is_editor_hint():
				continue
			punto = global_position + Vector3(x, 0.0, z)
		else:
			# EN UNA PARED NO CRECE HIERBA. Sin esta pregunta el campo trepa por los
			# muros y el parche se lee como pintura, no como vegetacion.
			var n: Vector3 = r["normal"]
			if rad_to_deg(Vector3.UP.angle_to(n)) > pendiente_max:
				continue
			punto = r["position"]
		# Y ademas MENGUA hacia el borde. Apagar solo la cantidad deja briznas de
		# altura completa sueltas por fuera, que se leen como pelos; menguando, el
		# campo se hunde en el suelo.
		var escala := (1.0 + rng.randf_range(-variacion, variacion)) * lerpf(0.5, 1.0, mezcla)
		var base := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
			Vector3(escala, escala, escala))
		poses.append(Transform3D(base, punto - global_position))
		# Variacion de tono planta a planta. Es un MULTIPLICADOR sobre el
		# gradiente, no un color: el gradiente lo pone la Palette (regla dura #9)
		# y esto solo lo mueve un poco arriba o abajo.
		var v := rng.randf_range(0.82, 1.14)
		colores.append(Color(v, v * rng.randf_range(0.96, 1.04), v * 0.97, 1.0))

	var mm := multimesh.multimesh
	mm.instance_count = poses.size()
	for i in poses.size():
		mm.set_instance_transform(i, poses[i])
		mm.set_instance_color(i, colores[i])

	# AABB A MANO. El MultiMesh la deduce de las transformadas, y el shader mueve
	# los vertices FUERA de ella: con viento fuerte y el borde del parche justo en
	# el limite del encuadre, el parche entero desaparece de golpe.
	multimesh.custom_aabb = AABB(
		Vector3(-area.x * 0.5 - 2.0, -sonda_abajo, -area.y * 0.5 - 2.0),
		Vector3(area.x + 4.0, sonda_abajo + sonda_arriba, area.y + 4.0))


func _montar() -> void:
	multimesh = MultiMeshInstance3D.new()
	multimesh.name = "Briznas"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = malla if malla != null else _malla_brizna()
	multimesh.multimesh = mm

	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	# LA BASE ES EL COLOR DEL SUELO DEL QUE SALE, no un verde mas oscuro.
	#
	# Con `musgo_medio` (#3E5230) contra un suelo `pasto_medio` (#5F7A3E) la brizna
	# nacia mas oscura que la tierra y moria en `hierba_highlight` (#B0C46B), o sea
	# recorria medio circulo cromatico en 78 cm: de lejos el parche se leia como
	# PAJA tirada encima del cesped, con una costura visible en el borde. Naciendo
	# del mismo color, el campo y el suelo son la misma cosa y el degradado solo
	# aporta el remate de luz en la punta.
	_mat.set_shader_parameter(&"color_base", _color(&"pasto_medio"))
	_mat.set_shader_parameter(&"color_punta", _color(&"hierba_highlight"))
	_mat.set_shader_parameter(&"rastro_radio", rastro_radio)
	_mat.set_shader_parameter(&"rastro_alto", rastro_alto)
	_mat.set_shader_parameter(&"aplaste_empuje", aplaste_empuje)
	_mat.set_shader_parameter(&"aplaste_hundir", aplaste_hundir)
	_mat.set_shader_parameter(&"aplaste_sombra", aplaste_sombra)
	_mat.set_shader_parameter(&"bandas", bandas)
	multimesh.material_override = _mat
	# SIN SOMBRA PROPIA. Diez mil briznas en el mapa de sombras cuestan mas que
	# todo lo demas junto y aportan ruido, no forma: la sombra que importa aqui es
	# la que el terreno recibe.
	multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(multimesh)


## LA BRIZNA: una tira que se estrecha hacia la punta y ya viene arqueada.
##
## `UV.y = 1` en la base y `0` en la punta, que es la convencion de §4: de ahi
## salen a la vez el gradiente de color y el factor de doblado, sin un segundo
## criterio que se pueda desincronizar del primero.
func _malla_brizna() -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var nor := PackedVector3Array()
	var idx := PackedInt32Array()

	for s in segmentos + 1:
		var t := float(s) / float(segmentos)
		# La punta no llega a cero: un triangulo de area nula se ve como un
		# pinchazo de aliasing cuando la camara pasa cerca.
		var w := ancho * 0.5 * pow(1.0 - t, 0.75) + ancho * 0.04
		var y := alto * t
		var z := curva * alto * t * t
		v.append(Vector3(-w, y, z))
		v.append(Vector3(w, y, z))
		uv.append(Vector2(0.0, 1.0 - t))
		uv.append(Vector2(1.0, 1.0 - t))
		nor.append(Vector3(0, 0, 1))
		nor.append(Vector3(0, 0, 1))

	for s in segmentos:
		var a := s * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_NORMAL] = nor
	arrays[Mesh.ARRAY_INDEX] = idx
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malla


# --- El rastro ----------------------------------------------------------------

## Doce `Vector4` por frame, y solo eso. `w` es la FRESCURA: 1 recien pisado, 0
## levantado del todo. La ranura 0 es el jugador ahora mismo —el aplastado que
## sigue al pie— y las once restantes son la cola que se deshace.
func _actualizar_rastro() -> void:
	if _mat == null:
		return
	var vivo := _jugador != null and is_instance_valid(_jugador)
	var p := _jugador.global_position if vivo else Vector3.ZERO

	if vivo and p.distance_to(_ultima_huella) >= rastro_paso:
		_huellas.push_front([p, _reloj])
		_ultima_huella = p
		while _huellas.size() > HUELLAS - 1:
			_huellas.pop_back()

	_buffer[0] = Vector4(p.x, p.y, p.z, 1.0 if vivo else 0.0)
	for i in range(1, HUELLAS):
		var j := i - 1
		if j >= _huellas.size():
			_buffer[i] = Vector4(0.0, 0.0, 0.0, 0.0)
			continue
		var h: Array = _huellas[j]
		var edad: float = _reloj - float(h[1])
		var frescura: float = clampf(1.0 - edad / maxf(rastro_duracion, 0.01), 0.0, 1.0)
		var pos: Vector3 = h[0]
		_buffer[i] = Vector4(pos.x, pos.y, pos.z, frescura)
	_mat.set_shader_parameter(&"rastro", _buffer)


## Deja una huella A MANO, sin jugador.
##
## La usan el banco y el screenshot test: una toma tiene que enseñar el rastro, y
## esperar a que un jugador lo pise en el frame correcto es justo la clase de
## dependencia que hace una referencia inestable. Tambien vale para lo que venga
## —un enemigo pesado, un coloso— sin tener que darle a `Pasto` una lista de
## candidatos a los que seguir.
func pisar(punto: Vector3) -> void:
	_huellas.push_front([punto, _reloj])
	_ultima_huella = punto
	while _huellas.size() > HUELLAS - 1:
		_huellas.pop_back()
	_actualizar_rastro()


## Deja el parche QUIETO del todo: el viento en una fase fija y el rastro como
## esta ahora mismo.
##
## Las dos mitades hacen falta. Congelar solo el viento dejaba el rastro
## desvaneciendose a ritmo de render, y con eso la toma del claro no convergia:
## 0.028% entre dos pasadas del MISMO codigo, porque cuantos frames caen entre el
## estampado y el disparo no es determinista. Es exactamente el fallo del agua,
## con otra variable.
func congelar(segundos: float = 3.0) -> void:
	congelar_viento(segundos)
	set_process(false)


## Congela el reloj del VIENTO en un instante exacto. Negativo = reloj de verdad.
##
## Mismo motivo que `agua.gdshader` y por eso la misma forma: el screenshot test
## dispara contando frames de RENDER, y con el reloj corriendo cada pasada
## fotografia una fase distinta de la onda. Una toma mide la FORMA, no el instante.
func congelar_viento(segundos: float = 3.0) -> void:
	if _mat != null:
		_mat.set_shader_parameter(&"tiempo_fijo", segundos)


## El rastro tal y como lo ve el shader. Existe para el test: comprobar que una
## huella se desvanece hay que hacerlo sobre el dato que se ENVIA, no sobre uno
## paralelo que podria decir otra cosa.
func rastro() -> PackedVector4Array:
	return _buffer


func briznas() -> int:
	return multimesh.multimesh.instance_count if multimesh != null else 0


## Solo el escalonado, sin resembrar: es un parametro del material y no de la
## forma del campo, asi que rehacer miles de rayos por moverlo seria absurdo.
func _aplicar_bandas() -> void:
	if _mat != null:
		_mat.set_shader_parameter(&"bandas", bandas)


func _color(nombre: StringName) -> Color:
	if palette == null:
		return Color.WHITE
	var v: Variant = palette.get(nombre)
	return v if v is Color else Color.WHITE


func debug_line() -> String:
	return "%d briznas · %d huellas" % [briznas(), _huellas.size()]
