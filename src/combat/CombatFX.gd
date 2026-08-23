class_name CombatFX
extends RefCounted
## VFX de combate por código, con colores de la Palette.
##
## Cápsulas grises también necesitan feedback: sin un destello en el punto de
## impacto no se distingue un golpe que conecta de uno que pasa de largo, y el
## Hito 2 se juzga en vídeo. Cuando llegue la Fase 5 esto se sustituye por las
## hojas de VFX reales, pero el TIMING ya estará afinado.

## Destello esférico corto en el punto de impacto.
static func impacto(padre: Node, pos: Vector3, color: Color, escala: float = 1.0) -> void:
	var m := _malla_esfera(color, 0.18 * escala)
	padre.add_child(m)
	m.global_position = pos
	_disolver(m, 0.55 * escala, 0.18)


## Anillo plano que se expande. Para el parry y los guard break.
static func onda(padre: Node, pos: Vector3, color: Color, radio: float = 2.4) -> void:
	var malla := TorusMesh.new()
	malla.inner_radius = 0.28
	malla.outer_radius = 0.34
	malla.rings = 24
	malla.ring_segments = 8
	malla.material = _material(color)

	var m := MeshInstance3D.new()
	m.mesh = malla
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(m)
	m.global_position = pos
	_disolver(m, radio, 0.32)


## Arco de espada: una estela corta que marca por dónde ha pasado el filo.
static func arco(padre: Node, pos: Vector3, direccion: Vector3, color: Color, largo: float = 2.0) -> void:
	var malla := TorusMesh.new()
	malla.inner_radius = largo * 0.62
	malla.outer_radius = largo * 0.72
	malla.rings = 20
	malla.ring_segments = 6
	malla.material = _material(color)

	var m := MeshInstance3D.new()
	m.mesh = malla
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(m)
	m.global_position = pos
	var plano := Vector3(direccion.x, 0.0, direccion.z)
	if not plano.is_zero_approx():
		m.look_at(m.global_position + plano.normalized(), Vector3.UP)
	m.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_disolver(m, 1.15, 0.16)


static func _malla_esfera(color: Color, radio: float) -> MeshInstance3D:
	var esfera := SphereMesh.new()
	esfera.radius = radio
	esfera.height = radio * 2.0
	esfera.radial_segments = 10
	esfera.rings = 6
	esfera.material = _material(color)

	var m := MeshInstance3D.new()
	m.mesh = esfera
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


static func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_receive_shadows = true
	return mat


## Crece y se apaga. Curvas rápidas: un VFX que dura más que el hitstop estorba.
static func _disolver(m: MeshInstance3D, escala_final: float, duracion: float) -> void:
	m.scale = Vector3.ONE * 0.25
	var t := m.create_tween()
	t.set_parallel(true)
	t.tween_property(m, "scale", Vector3.ONE * escala_final, duracion).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var mat := (m.mesh as PrimitiveMesh).material as StandardMaterial3D
	t.tween_property(mat, "albedo_color:a", 0.0, duracion).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(m.queue_free)
