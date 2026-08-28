extends Node
## MIDE EL JITTER. No lo supone: lo cuenta, y mide las dos condiciones seguidas.
##
##   godot --path . --resolution 960x540 tools/MedirJitter.tscn
##
## Un personaje que se mueve a velocidad constante deberia recorrer la misma
## distancia en cada FRAME RENDERIZADO. Si la fisica va a 60 Hz y la pantalla a
## 144, el cuerpo solo cambia de sitio 60 veces por segundo: sin interpolacion,
## dos de cada tres frames repiten posicion y eso es exactamente lo que se ve como
## "borroso" o "a tirones".
##
## **Se miden DOS transformadas, y confundirlas es el error facil:**
##
##   `global_position`                     -> la de FISICA. Cambia 60 veces por
##     segundo pase lo que pase. Que salga escalonada NO es el bug; es lo correcto,
##     y no mejora al activar la interpolacion. Aqui esta como referencia, para
##     ver el desfase entre los dos relojes.
##   `get_global_transform_interpolated()` -> lo que se DIBUJA este frame. Es lo
##     unico que ve el jugador, y es lo que tiene que salir suave.
##
## Las dos condiciones se miden en la MISMA pasada (`SceneTree.physics_interpolation`
## se apaga y se enciende a mitad). Comparar dos ejecuciones distintas mezclaria el
## resultado con el ruido de la maquina.
##
## Se corre con GPU a proposito. En headless el reloj de render es libre.

const VELOCIDAD := 8.0
## Se descarta el primer tramo de cada fase: el personaje esta cayendo al suelo y
## la velocidad aun no es constante. Meterlo en la media inflaba la desviacion.
const WARMUP := 1.0
const MEDICION := 2.5

var _p: PlayerController
var _fase: int = 0
var _t: float = 0.0
var _frames: int = 0
var _fisicas: int = 0

var _pos_anterior: Vector3 = Vector3.ZERO
var _fisica_anterior: Vector3 = Vector3.ZERO
var _repetidos: int = 0
var _repetidos_fisica: int = 0
var _racha: int = 0
var _racha_max: int = 0
var _pasos: PackedFloat32Array = []

var _informes: Array[String] = []


func _ready() -> void:
	var main: Node = (load("res://content/levels/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	_p = main.get_node("Player") as PlayerController
	await get_tree().physics_frame
	_arrancar_fase(false)


func _physics_process(_delta: float) -> void:
	_fisicas += 1
	# Velocidad constante impuesta a mano: se mide el RENDER, no la locomocion.
	_p.velocity = Vector3(0.0, _p.velocity.y, -VELOCIDAD)


func _process(delta: float) -> void:
	_t += delta
	_frames += 1

	var fisica := _p.global_position
	var pintada := _p.get_global_transform_interpolated().origin
	if _t > WARMUP and _frames > 1:
		var paso := pintada.distance_to(_pos_anterior)
		_pasos.append(paso)
		if paso < 0.0001:
			_repetidos += 1
			_racha += 1
			_racha_max = maxi(_racha_max, _racha)
		else:
			_racha = 0
		if fisica.distance_to(_fisica_anterior) < 0.0001:
			_repetidos_fisica += 1
	_pos_anterior = pintada
	_fisica_anterior = fisica

	if _t >= WARMUP + MEDICION:
		_cerrar_fase()


func _arrancar_fase(interpolar: bool) -> void:
	get_tree().physics_interpolation = interpolar
	_p.global_position = Vector3(0.0, 0.05, 10.0)
	_p.velocity = Vector3.ZERO
	_p.reset_physics_interpolation()
	_t = 0.0
	_frames = 0
	_fisicas = 0
	_pasos.clear()
	_repetidos = 0
	_repetidos_fisica = 0
	_racha = 0
	_racha_max = 0


func _cerrar_fase() -> void:
	_informes.append(_resumen(get_tree().physics_interpolation))
	_fase += 1
	if _fase == 1:
		_arrancar_fase(true)
		return
	print("")
	for linea in _informes:
		print(linea)
	print("  LECTURA: lo que cuenta es la fila DIBUJADO. La fila FISICA mide el")
	print("           desfase entre relojes y no puede bajar: es lo esperado.")
	get_tree().quit()


func _resumen(interpolar: bool) -> String:
	var n := maxf(float(_pasos.size()), 1.0)
	var media := 0.0
	for p in _pasos:
		media += p
	media /= n
	var desv := 0.0
	for p in _pasos:
		desv += (p - media) * (p - media)
	desv = sqrt(desv / n)

	return "\n".join([
		"=== physics_interpolation = %s ===" % ("SI " if interpolar else "NO "),
		"  render %d frames / fisica %d ticks  ->  %.2f frames por tick" % [
			_frames, _fisicas, float(_frames) / maxf(float(_fisicas), 1.0)],
		"  FISICA   congelada en %5.1f%% de los frames   (el desfase de relojes)" % [
			100.0 * _repetidos_fisica / n],
		"  DIBUJADO congelado en %5.1f%% de los frames   <- ESTO es el jitter" % [
			100.0 * _repetidos / n],
		"  racha maxima de frames congelados: %d" % _racha_max,
		"  avance por frame: media %.4f m  desviacion %.4f m  (%.0f%% de la media)" % [
			media, desv, 100.0 * desv / maxf(media, 0.00001)],
		"  posicion final: %.2f, %.2f, %.2f   (rapidez %.1f m/s)" % [
			_p.global_position.x, _p.global_position.y, _p.global_position.z,
			_p.velocity.length()],
		"",
	])
