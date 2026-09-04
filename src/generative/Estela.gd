class_name Estela
extends Node3D
## LA COLA: una línea que persigue a la criatura.
##
## Artística, no física. No colisiona, no tira de nada y no restringe el
## movimiento — igual que `Cordon`, y por la misma razón: lo que ata a la criatura
## a su sitio es el oscilador, un número; esto solo hace que ese número deje rastro.
##
## **Persecución en cadena, no verlet.** `Cordon` usa verlet porque cuelga entre
## dos puntos fijos y tiene que combarse con la gravedad. Aquí no cuelga de nada:
## va detrás. Cada nudo persigue al de delante con retraso, que es el modelo
## clásico de cola procedural y da la curva de látigo — la cola se queda atrás al
## acelerar y adelanta al frenar, que es justo lo que dibuja el recorrido.
##
## El retraso es exponencial e independiente del framerate: `1 - exp(-k·dt)`. Con
## un lerp de factor fijo la cola sería más rígida a 144 fps que a 60, y el look
## dependería de la máquina.

## Color del trazo. Lo escribe la criatura cada frame desde su ciclo.
var color: Color = Color.WHITE

var _puntos: PackedVector3Array = []
var _tuning: EnjambreTuning
var _malla: ImmediateMesh
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	# Fuera de la interpolación de física (regla dura #21bis): los vértices se
	# escriben en coordenadas de MUNDO y se pasan a local con `to_local()`. Si el
	# nodo además se interpolara, se calcularían contra una transformada y se
	# pintarían con otra.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	# Y FUERA DE LA TRANSFORMADA DE SU PADRE. La cola cuelga de la criatura en el
	# arbol, pero no es parte de su CUERPO: es el rastro de por donde ha pasado, y
	# eso vive en el mundo. Sin `top_level`, `to_local()` restaria la posicion de
	# la criatura a unos puntos que ya son absolutos y la cola viajaria pegada a
	# ella, que es justo lo contrario de lo que hace una cola.
	top_level = true

	_malla = ImmediateMesh.new()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _malla
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.extra_cull_margin = 64.0
	add_child(_mesh)

	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = _mat


## Tiende la cola ESTIRADA detrás de la cabeza.
##
## Estirada, no amontonada en un punto. Amontonarla parece lo natural —"que nazca
## donde nace la criatura"— y es el bug que costó la ronda: con todos los nudos en
## el mismo sitio la distancia entre vecinos es cero, la dirección que usa la
## restricción no significa nada, y la cadena se PLIEGA en zigzag en su primer
## frame. Medido: 14 nudos y 1.17 m de cuerda ocupando 0.125 m. Una vez plegada no
## se estira sola nunca, porque cada frame se recalcula desde el pliegue.
##
## Y tampoco en el origen del mundo: entonces el primer frame es un latigazo
## cruzando la escena.
func configurar(t: EnjambreTuning, cabeza: Vector3, hacia_atras: Vector3 = Vector3.DOWN) -> void:
	_tuning = t
	var atras := hacia_atras.normalized() if not hacia_atras.is_zero_approx() else Vector3.DOWN
	_puntos.resize(t.cola_nudos)
	for i in t.cola_nudos:
		_puntos[i] = cabeza + atras * (t.cola_paso * float(i))


## Lo llama la criatura con su posición. La cola no sabe nada más de ella.
func seguir(cabeza: Vector3) -> void:
	if _tuning == null or _puntos.is_empty():
		return
	var dt := get_physics_process_delta_time()
	var f: float = 1.0 - exp(-_tuning.cola_seguimiento * dt)

	_puntos[0] = cabeza
	for i in range(1, _puntos.size()):
		var delante := _puntos[i - 1]
		var p := _puntos[i].lerp(delante, f)
		# Y se mantiene a distancia de reposo del de delante: sin esto los nudos
		# se amontonan en la cabeza cuando la criatura se para, y la cola
		# desaparece justo cuando debería quedarse dibujada.
		var d := p - delante
		var l := d.length()
		if l > 0.0001:
			p = delante + d / l * _tuning.cola_paso
		else:
			# Degenerado: el nudo ha caído justo encima del de delante y ya no hay
			# dirección que normalizar. Dejarlo donde está es como se PLIEGA la
			# cadena, así que se reengancha con la dirección del tramo anterior.
			p = delante + _direccion_previa(i) * _tuning.cola_paso
		_puntos[i] = p
	_dibujar()


## Hacia dónde iba la cola justo antes del nudo `i`. Solo sirve para rescatar un
## tramo degenerado; en marcha normal no se llama nunca.
func _direccion_previa(i: int) -> Vector3:
	if i >= 2:
		var d := _puntos[i - 1] - _puntos[i - 2]
		if not d.is_zero_approx():
			return d.normalized()
	return Vector3.DOWN


## Tira de triángulos orientada a la cámara, afilándose hasta la punta.
##
## El grosor cae con el índice y la opacidad también: una cola de grosor constante
## se lee como un cable, y lo que se busca es un TRAZO — algo que empieza en el
## cuerpo y se desvanece.
func _dibujar() -> void:
	_malla.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null or _puntos.size() < 2:
		return
	var ojo := cam.global_position
	var n := _puntos.size()

	_malla.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	for i in n:
		var p := _puntos[i]
		var siguiente: Vector3 = _puntos[mini(i + 1, n - 1)]
		var anterior: Vector3 = _puntos[maxi(i - 1, 0)]
		var eje := siguiente - anterior
		if eje.is_zero_approx():
			eje = Vector3.UP
		var lado := eje.normalized().cross((ojo - p).normalized())
		if lado.is_zero_approx():
			lado = Vector3.RIGHT
		# `u` va de 0 en la base a 1 en la punta.
		var u := float(i) / float(n - 1)
		lado = lado.normalized() * _tuning.cola_grosor * (1.0 - u) * 0.5
		# La opacidad cae más despacio que el grosor. Si las dos se van a cero al
		# mismo ritmo, el último tercio del trazo no llega a dibujarse y la cola
		# parece la mitad de larga de lo que es.
		var c := Color(color.r, color.g, color.b, color.a * pow(1.0 - u, 0.7))
		_malla.surface_set_color(c)
		_malla.surface_add_vertex(to_local(p - lado))
		_malla.surface_set_color(c)
		_malla.surface_add_vertex(to_local(p + lado))
	_malla.surface_end()
