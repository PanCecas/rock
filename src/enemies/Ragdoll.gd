class_name Ragdoll
extends RigidBody3D
## Cadáver físico. Al morir, el enemigo se sustituye por este cuerpo rígido y sale
## despedido con la fuerza del golpe que lo mató (muerte estilo Overwatch).
##
## No es un ragdoll de esqueleto: los Guardianes son cápsulas y todavía no hay rigs.
## Cuando lleguen (Fase 6) esto se cambia por `PhysicalBoneSimulator3D`, pero la
## FUERZA y el TIMING ya estarán afinados, que es lo que cuesta acertar.
##
## Solo choca con el mundo: un cadáver volando no debe empujar al jugador ni a sus
## compañeros, o el combate se vuelve impredecible por accidente.

## Cuánto sobrevive el cuerpo antes de disolverse.
@export_range(0.5, 30.0, 0.5) var vida: float = 6.0
@export_range(0.1, 3.0, 0.1) var duracion_disolucion: float = 1.2

var _t: float = 0.0
var _mat: StandardMaterial3D


## Crea el cadáver a partir de un enemigo y lo lanza.
##
## `fuerza` va en m/s (se multiplica por la masa dentro), así que el número que se
## tunea se lee como velocidad y no como un impulso abstracto.
static func lanzar(
	origen: Node3D, malla: Mesh, material: Material,
	direccion: Vector3, fuerza: float, torque: float, vida_seg: float
) -> Ragdoll:
	var r := Ragdoll.new()
	r.name = "Cadaver"
	r.vida = vida_seg
	r.mass = 60.0
	r.collision_layer = Layers.RAGDOLL
	r.collision_mask = Layers.WORLD
	r.continuous_cd = true

	var fisica := PhysicsMaterial.new()
	fisica.friction = 0.55
	fisica.bounce = 0.22
	r.physics_material_override = fisica

	var forma := CapsuleShape3D.new()
	forma.radius = 0.45
	forma.height = 2.0
	var col := CollisionShape3D.new()
	col.shape = forma
	col.position = Vector3.UP
	r.add_child(col)

	if malla != null:
		var mi := MeshInstance3D.new()
		mi.mesh = malla
		mi.position = Vector3.UP
		if material != null:
			# Duplicado: hay que poder desvanecerlo sin tocar el material del vivo.
			r._mat = (material as StandardMaterial3D).duplicate()
			r._mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mi.material_override = r._mat
		r.add_child(mi)

	origen.get_parent().add_child(r)
	r.global_transform = origen.global_transform

	# El impulso sale del golpe pero siempre con algo de vertical: un cuerpo que
	# se arrastra por el suelo no se lee; uno que despega, sí.
	var dir := (direccion.normalized() + Vector3.UP * 0.55).normalized()
	r.apply_central_impulse(dir * fuerza * r.mass)
	r.apply_torque_impulse(Vector3(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
	).normalized() * torque * r.mass)
	return r


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < vida:
		return
	if _mat == null:
		queue_free()
		return
	var a := 1.0 - (_t - vida) / duracion_disolucion
	if a <= 0.0:
		queue_free()
		return
	_mat.albedo_color.a = a
