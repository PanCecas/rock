@tool
class_name Gym
extends Node3D
## Sala de pruebas. Se genera por código para poder cambiar los parámetros de un
## tirón en vez de arrastrar cubos a mano.
##
## Contiene, en este orden desde el spawn: rampas de todos los ángulos, huecos de
## anchura creciente para calibrar el salto, muros para wall-run, repisas para
## agarres, una torre vertical (el hito de la Fase 3) y pilares para el gancho.
##
## Aquí se corre la carrera de obstáculos del Hito 1. Ver docs/04_ROADMAP.md.

@export var palette: Palette:
	set(v):
		palette = v
		if is_inside_tree():
			construir()

@export_group("Parámetros")
@export var angulos_rampa: PackedFloat32Array = [15.0, 25.0, 35.0, 45.0, 60.0]
## Rampas de calibracion del limite CAMINAR/ESCALAR. La frontera esta en 45 y el
## techo en 110, asi que 30/40/44 se andan y de 45 en adelante se trepan. Es la
## unica forma de comprobar el limite sin fiarse de la vista, y por eso estan los
## dos lados de la frontera, no solo los casos bonitos.
@export var angulos_escalada: PackedFloat32Array = [
	30.0, 40.0, 44.0, 45.0, 50.0, 60.0, 75.0, 90.0, 110.0,
]
## Radio del domo de calibracion. Una media esfera recorre TODOS los angulos de 0
## a 90 de forma continua, asi que subir por ella ensena donde esta el umbral sin
## tener que leer ningun numero: caminas hasta que dejas de caminar.
@export_range(2.0, 20.0, 0.5) var domo_radio: float = 5.0
## Anchuras de hueco en metros. Con altura_salto_max 2.6 el jugador llega a ~6.
@export var huecos: PackedFloat32Array = [2.0, 4.0, 6.0, 8.0, 10.0, 12.0]
@export var alturas_repisa: PackedFloat32Array = [1.0, 2.0, 3.0, 4.2]
@export var tamano_suelo: float = 70.0

const EMBESTIDOR := preload("res://src/enemies/Embestidor.tscn")
const VOLADOR := preload("res://src/enemies/Volador.tscn")
const COLOSO := preload("res://src/enemies/ColosoMediano.tscn")
const PROYECTIL := preload("res://src/enemies/Proyectil.tscn")

var _raiz: Node3D
var _mat_suelo: StandardMaterial3D
var _mat_piedra: StandardMaterial3D
var _mat_piedra_osc: StandardMaterial3D
var _mat_marca: StandardMaterial3D


func _ready() -> void:
	if not Engine.is_editor_hint() and palette == null:
		palette = GameState.palette
	construir()


func construir() -> void:
	if palette == null:
		return
	if _raiz != null and is_instance_valid(_raiz):
		_raiz.queue_free()
	_raiz = Node3D.new()
	_raiz.name = "Geometria"
	add_child(_raiz)

	_crear_materiales()
	_suelo()
	_rampas()
	_saltos()
	_muros_wallrun()
	_repisas()
	_torre()
	_pilares_gancho()
	_pared_escalable()
	_rampas_escalada()
	_domo()
	_corral()
	_tunel()
	_piscina()


# --- Materiales --------------------------------------------------------------

func _crear_materiales() -> void:
	_mat_suelo = _mat(palette.pasto_medio, 0.94)
	_mat_piedra = _mat(palette.piedra_media, 0.86)
	_mat_piedra_osc = _mat(palette.piedra_sombra, 0.9)
	# El único acento del Gym: marca lo que hay que tocar. Regla del 10%.
	_mat_marca = _mat(palette.oro_palido, 0.7)


func _mat(color: Color, rugosidad: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugosidad
	m.metallic = 0.0
	m.metallic_specular = 0.15
	return m


# --- Piezas ------------------------------------------------------------------

func _suelo() -> void:
	_bloque("Suelo", Vector3(tamano_suelo, 1.0, tamano_suelo), Vector3(0, -0.5, 0), _mat_suelo)
	_etiqueta("SPAWN", Vector3(0, 0.02, 4))


func _rampas() -> void:
	var x := -26.0
	var grosor := 0.5
	for angulo in angulos_rampa:
		var largo := 8.0
		var a := deg_to_rad(angulo)
		# HUNDIDAS lo justo para que la cara superior ARRANQUE BAJO EL SUELO.
		#
		# Estaban centradas a `largo/2 * sin(a)`, y con eso su cara util empezaba a
		# `grosor/2 * cos(a)` de altura: un labio de 13 a 25 cm en el pie de cada
		# rampa. `CharacterBody3D` no sube escalones por su cuenta, asi que el
		# jugador chocaba contra ese labio y NINGUNA rampa del campo se podia subir
		# andando —ni la de 15 grados—. Se notaba sobre todo en la de 45 porque es
		# la que mas obviamente deberia subirse.
		var rampa := _bloque(
			"Rampa_%d" % int(angulo),
			Vector3(4.0, grosor, largo),
			Vector3(x, largo * 0.5 * sin(a) - grosor * 0.5 * cos(a) - 0.05, -14.0),
			_mat_piedra
		)
		rampa.rotation_degrees = Vector3(-angulo, 0, 0)
		_etiqueta("%d°" % int(angulo), Vector3(x, 0.05, -8.0))
		x += 6.0


func _saltos() -> void:
	# Plataformas separadas por huecos crecientes: calibra la altura y el dash.
	var z := 10.0
	var x := 0.0
	_bloque("Salto_Inicio", Vector3(5, 1, 5), Vector3(x, 0.5, z), _mat_piedra)
	for hueco in huecos:
		x += 5.0 + hueco
		_bloque("Salto_%.0fm" % hueco, Vector3(5, 1, 5), Vector3(x, 0.5, z), _mat_piedra)
		_etiqueta("%.0f m" % hueco, Vector3(x - (hueco * 0.5) - 2.5, 0.05, z))


func _muros_wallrun() -> void:
	# Dos muros paralelos con un pasillo de 3 m: wall-run y wall-jump alterno.
	for i in 2:
		var lado := -1.0 if i == 0 else 1.0
		_bloque(
			"MuroWallrun_%d" % i,
			Vector3(1.0, 8.0, 24.0),
			Vector3(lado * 1.8, 4.0, -34.0),
			_mat_piedra_osc
		)
	_etiqueta("WALL-RUN", Vector3(0, 0.05, -21.0))


func _repisas() -> void:
	# Escalones a distintas alturas para probar agarre de borde y ledge assist.
	var z := -6.0
	var x := 20.0
	for h in alturas_repisa:
		_bloque("Repisa_%.1f" % h, Vector3(6, h, 3), Vector3(x, h * 0.5, z), _mat_piedra)
		# La franja dorada marca el borde exacto que hay que agarrar.
		_bloque("Borde_%.1f" % h, Vector3(6, 0.06, 0.3), Vector3(x, h + 0.03, z - 1.35), _mat_marca)
		z -= 5.0
	_etiqueta("BORDES", Vector3(x, 0.05, -1.0))


func _torre() -> void:
	# 60 m de altura: el hito de la Fase 3 es subirla sin escaleras, solo con
	# lanza + lazo + planeo. De momento solo marca la escala vertical.
	var pos := Vector3(-24.0, 0.0, 22.0)
	_bloque("Torre_Base", Vector3(9, 2, 9), pos + Vector3(0, 1, 0), _mat_piedra_osc)
	var altura := 0.0
	var i := 0
	while altura < 60.0:
		altura += 4.5
		var lado := 1.0 if i % 2 == 0 else -1.0
		_bloque(
			"Torre_Rellano_%d" % i,
			Vector3(3.5, 0.5, 3.5),
			pos + Vector3(lado * 3.0, altura, sin(float(i) * 0.9) * 3.0),
			_mat_piedra
		)
		i += 1
	_bloque("Torre_Cima", Vector3(6, 0.6, 6), pos + Vector3(0, altura + 4.0, 0), _mat_marca)
	_etiqueta("TORRE 60 m", pos + Vector3(0, 2.1, 5.5))


func _pilares_gancho() -> void:
	# Pilares altos y separados: anclajes del lazo y objetivos de la lanza.
	for i in 5:
		var a := float(i) / 5.0 * TAU
		var pos := Vector3(cos(a) * 16.0, 0.0, 34.0 + sin(a) * 8.0)
		var alto := 9.0 + float(i) * 2.5
		_bloque("Pilar_%d" % i, Vector3(1.6, alto, 1.6), pos + Vector3(0, alto * 0.5, 0), _mat_piedra)
		_bloque("PilarCima_%d" % i, Vector3(2.4, 0.4, 2.4), pos + Vector3(0, alto + 0.2, 0), _mat_marca)
	_etiqueta("GANCHO", Vector3(0, 0.05, 30.0))


func _pared_escalable() -> void:
	# Superficie marcada como escalable a mano (capa CLIMBABLE).
	var pared := _bloque(
		"ParedEscalable",
		Vector3(14, 12, 1),
		Vector3(24.0, 6.0, 20.0),
		_mat_piedra_osc
	)
	pared.set_collision_layer_value(1, true)
	pared.set_collision_layer_value(4, true)  # CLIMBABLE
	_etiqueta("ESCALABLE", Vector3(24.0, 0.05, 21.5))


## Rampas empinadas, todas con el BORDE INFERIOR en la misma linea (z = borde_z).
##
## Que el pie de todas coincida no es cosmetica: es lo que permite acercarse a
## cualquiera de ellas desde la misma linea de salida y comparar. Si cada una
## empezara donde le tocase, medir "a partir de que angulo se escala" seria medir
## tambien lo bien que uno se coloca.
func _rampas_escalada() -> void:
	var borde_z := -30.0
	var largo := 10.0
	var grosor := 0.6
	var x := -33.0
	for angulo in angulos_escalada:
		var a := deg_to_rad(angulo)
		# Ejes de la cara inclinada: `u` sube por ella, `n` sale de ella.
		var u := Vector3(0.0, sin(a), cos(a))
		var n := Vector3(0.0, cos(a), -sin(a))
		# El centro del bloque se deduce del borde que se quiere fijar, no al reves.
		var centro := Vector3(x, 0.0, borde_z) + u * (largo * 0.5) - n * (grosor * 0.5)
		var rampa := _bloque(
			"RampaEscalada_%d" % int(angulo),
			Vector3(2.6, grosor, largo),
			centro,
			_mat_piedra_osc
		)
		rampa.rotation_degrees = Vector3(-angulo, 0.0, 0.0)
		_etiqueta("%d°" % int(angulo), Vector3(x, 0.05, borde_z - 1.6))
		x += 3.4
	_etiqueta("SE ESCALA DE 45° A 110°", Vector3(-19.4, 0.05, borde_z - 3.4))


## DOMO DE CALIBRACION. Media esfera: en la cima la superficie es horizontal y en
## la base es vertical, recorriendo todos los angulos intermedios sin un solo
## escalon. Es la forma honesta de ensenar donde esta el slope limit —subes
## andando hasta que el suelo deja de dejarte, y ese punto es el umbral—, y de
## paso el mejor sitio para notar si el umbral esta donde tiene que estar.
##
## El anillo dorado marca la latitud exacta del limite. Es geometria, no adorno:
## si el numero cambia, el anillo se mueve solo.
func _domo() -> void:
	# Esquina propia: el domo es una montana de 5 m y en cualquier otro sitio se
	# come el espacio libre que necesitan las pruebas de carrera.
	var centro := Vector3(28.0, 0.0, 30.0)
	var r := domo_radio

	var cuerpo := StaticBody3D.new()
	cuerpo.name = "DomoCalibracion"
	cuerpo.position = centro
	cuerpo.collision_layer = 1

	var malla := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = r
	esfera.height = r * 2.0
	esfera.radial_segments = 48
	esfera.rings = 24
	malla.mesh = esfera
	malla.material_override = _mat_piedra
	cuerpo.add_child(malla)

	var col := CollisionShape3D.new()
	var forma := SphereShape3D.new()
	forma.radius = r
	col.shape = forma
	cuerpo.add_child(col)
	_raiz.add_child(cuerpo)

	# El anillo del umbral: la latitud donde la superficie alcanza el slope limit.
	# En una esfera el angulo de la superficie coincide con la latitud, asi que
	# sale directo del tuning sin ninguna constante intermedia.
	# El tuning se carga del disco y no del autoload: este script es `@tool` y en
	# el editor los autoloads no estan garantizados.
	var limite: float = 45.0
	var tun := ResourceLoader.load("res://content/data/default_tuning.tres") as PlayerTuning
	if tun != null:
		limite = tun.climb_angulo_min
	var a := deg_to_rad(limite)
	var anillo := MeshInstance3D.new()
	anillo.name = "DomoUmbral"
	var toro := TorusMesh.new()
	toro.inner_radius = r * sin(a) - 0.08
	toro.outer_radius = r * sin(a) + 0.08
	anillo.mesh = toro
	anillo.material_override = _mat_marca
	anillo.position = centro + Vector3(0.0, r * cos(a), 0.0)
	_raiz.add_child(anillo)

	_etiqueta("DOMO — el anillo es el limite (%d°)" % int(limite), centro + Vector3(0, 0.06, r + 2.0))


## CORRAL DE ENEMIGOS. Los tres del parche 3.03, cada uno en su sitio y lejos de
## los demas.
##
## Aparte de la Arena a proposito: la Arena es el patio de combate de los tres
## Guardianes y **su poblacion es load-bearing** para los tests de la Fase 2.
## Anadir tres enemigos alli hacia que alguno alcanzara al jugador en mitad de la
## prueba de la cadena de golpes. Un banco de pruebas no puede alterar otro.
##
## Y separados entre si porque cada uno ensena una cosa distinta: mezclarlos
## convierte el corral en un caos donde no se puede estudiar ninguno.
func _corral() -> void:
	var centro := Vector3(11.0, 0.0, -32.0)
	_etiqueta("CORRAL — embestidor · volador · coloso", centro + Vector3(0, 0.06, 5.0))

	# Un muro corto detras del embestidor: sin algo contra lo que estrellarse, su
	# carga fallida no tiene consecuencia y la mecanica no se entiende.
	_bloque("Corral_Muro", Vector3(9.0, 3.0, 0.8), centro + Vector3(0, 1.5, -6.0), _mat_piedra_osc)

	for datos in [
		{"escena": EMBESTIDOR, "nombre": "Embestidor", "pos": Vector3(-4.0, 0.2, 0.0),
			"ataque": "res://content/data/attacks/embestida.tres"},
		{"escena": VOLADOR, "nombre": "Volador", "pos": Vector3(4.0, 5.0, 0.0),
			"ataque": "res://content/data/attacks/volador_disparo.tres"},
		# El coloso NO lleva ataque: su unico trabajo es dejarse escalar.
		{"escena": COLOSO, "nombre": "ColosoMediano", "pos": Vector3(0.0, 3.6, 3.5), "ataque": ""},
	]:
		var escena: PackedScene = datos["escena"]
		if escena == null:
			continue
		var e := escena.instantiate() as Enemigo
		e.name = datos["nombre"]
		e.palette = palette
		var ruta: String = datos["ataque"]
		if not ruta.is_empty():
			e.ataque = load(ruta)
		if e is Volador:
			(e as Volador).proyectil = PROYECTIL
		_raiz.add_child(e)
		e.global_position = centro + (datos["pos"] as Vector3)


## Tunel de 1.2 m: por debajo de la altura del jugador (1.8 m). Solo se cruza
## agachado o surfeando, y una vez dentro NO se puede uno levantar: el
## CeilingSensor obliga a seguir agachado hasta salir.
##
## Es la prueba de que agacharse es un estado y no un boton.
func _tunel() -> void:
	var pos := Vector3(-14.0, 0.0, 8.0)
	var largo := 14.0
	var ancho := 5.0
	var hueco := 1.2

	# Techo: la pieza que obliga. Se apoya justo a la altura del hueco.
	_bloque("Tunel_Techo", Vector3(ancho, 1.2, largo), pos + Vector3(0, hueco + 0.6, 0), _mat_piedra_osc)
	# Paredes laterales, para que no se pueda rodear por dentro.
	for i in 2:
		var lado := -1.0 if i == 0 else 1.0
		_bloque("Tunel_Muro_%d" % i, Vector3(0.8, hueco + 1.2, largo),
			pos + Vector3(lado * (ancho * 0.5 + 0.4), (hueco + 1.2) * 0.5, 0), _mat_piedra_osc)

	# Rampa de entrada: invita a llegar con velocidad y cruzarlo surfeando.
	_bloque("Tunel_Entrada", Vector3(ancho, 0.4, 4.0), pos + Vector3(0, 0.2, -largo * 0.5 - 2.0), _mat_marca)
	_etiqueta("TUNEL 1.2 m — agachado o surf", pos + Vector3(0, 0.45, -largo * 0.5 - 4.5))


## Piscina de pruebas: un hueco en el suelo con una ZonaAgua dentro. Tiene un
## trampolin alto a proposito, porque lo que hay que poder probar no es flotar:
## es el CLAVADO desde un dive y la curva de penetracion que gana.
## Estanque de pruebas. ELEVADO y no excavado: el suelo del Gym es una losa
## maciza de 70x70 y un agujero exigiria trocearla. Un vaso construido hacia
## arriba resuelve lo mismo y deja ver el agua desde fuera.
##
## Tiene torre y trampolin a proposito: lo que hay que poder probar no es flotar,
## es el CLAVADO desde un dive y la profundidad que gana.
func _piscina() -> void:
	var centro := Vector3(28.0, 0.0, -28.0)
	var ancho := 18.0
	var alto := 9.0

	for i in 4:
		var a := float(i) * PI * 0.5
		var d := Vector3(sin(a), 0.0, cos(a)) * (ancho * 0.5 + 0.5)
		var tam := Vector3(ancho + 2.0, alto, 1.0) if i % 2 == 0 else Vector3(1.0, alto, ancho + 2.0)
		_bloque("Piscina_Muro_%d" % i, tam, centro + d + Vector3(0, alto * 0.5, 0), _mat_piedra_osc)

	# Torre y trampolin: 16 m de caida, de sobra para entrar en dive.
	_bloque("Piscina_Torre", Vector3(3, 16.0, 3), centro + Vector3(0, 8.0, -ancho * 0.5 - 6.0), _mat_piedra)
	_bloque("Piscina_Trampolin", Vector3(4, 0.5, 7), centro + Vector3(0, 16.0, -ancho * 0.5 - 3.0), _mat_marca)

	# El agua llena el vaso casi hasta arriba. Superficie en y = alto - 0.5.
	var agua := ZonaAgua.new()
	agua.name = "Agua"
	agua.tamano = Vector3(ancho, alto - 0.5, ancho)
	agua.palette = palette
	_raiz.add_child(agua)
	agua.position = centro + Vector3(0, (alto - 0.5) * 0.5, 0)

	_etiqueta("ESTANQUE — clavate desde la torre", centro + Vector3(0, 0.06, ancho * 0.5 + 2.5))


# --- Utilidades --------------------------------------------------------------

func _bloque(nombre: String, tam: Vector3, pos: Vector3, material: Material) -> StaticBody3D:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = nombre
	cuerpo.position = pos
	cuerpo.collision_layer = 1  # WORLD

	var malla := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	malla.mesh = caja
	malla.material_override = material
	cuerpo.add_child(malla)

	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = tam
	col.shape = forma
	cuerpo.add_child(col)

	_raiz.add_child(cuerpo)
	return cuerpo


func _etiqueta(texto: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = texto
	l.position = pos
	l.rotation_degrees.x = -90.0
	l.font_size = 96
	l.pixel_size = 0.006
	l.modulate = palette.crema_bruma
	l.outline_modulate = palette.verde_negro
	l.outline_size = 18
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.no_depth_test = false
	l.double_sided = true
	_raiz.add_child(l)
