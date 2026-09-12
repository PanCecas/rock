extends Node
## Test funcional del sistema generativo — el enjambre de Kuramoto.
##
##   godot --headless --path . tools/TestEnjambre.tscn
##
## Dos mitades, porque son dos cosas que se miden de formas distintas:
##
##   · **EL MODELO, EN SECO.** Matemática pura: se pisa `_physics_process` a mano
##     con el mismo dt fijo y se corren minutos de simulación en milisegundos. No
##     es forzar estado —es la MISMA integración por el MISMO camino—, es solo no
##     esperar en tiempo de pared a que respire un sistema cuyo ciclo dura medio
##     minuto.
##   · **LA MANIFESTACIÓN, EN VIVO.** El Jardín corriendo de verdad, a 60 Hz, con
##     sus criaturas y sus colas. Aquí se comprueba lo que el modelo no sabe: que
##     nadie rota, que la cola va detrás y que el color se mueve.
##
## La separación es la misma que hay en el código y por la misma razón: del modelo
## se pueden afirmar cosas —es determinista—, del render no.

const DT := 1.0 / 60.0

var _jardin: Node3D
var _enj: Enjambre
var _paso: int = 0
var _t: float = 0.0
var _guion: Array = []
var _fallos: PackedStringArray = []
var _total: int = 0

## --- Latches de la mitad viva -------------------------------------------------
## Se miden MIENTRAS pasa, frame a frame. Preguntar al final por el estado final
## no sirve para ninguna de estas: "no rota nunca" no es un estado, es una
## propiedad de todos los frames del recorrido.
var _rotacion_max: float = 0.0
var _lejos_del_ancla: float = 0.0
var _alfa_min: float = 99.0
var _alfa_max: float = -99.0
var _color_min: Vector3 = Vector3(9, 9, 9)
var _color_max: Vector3 = Vector3(-9, -9, -9)
var _cola_detras: int = 0
var _cola_delante: int = 0
## Lo LEJOS de la cabeza que llega a estirarse la cola.
##
## No la distancia de punta a cabeza: eso valía cuando la trayectoria era una
## recta, pero con el recorrido en ocho la cola se curva sobre la órbita y sus
## dos extremos vuelven a acercarse. Medir el alcance MÁXIMO sobre todos los
## nudos distingue lo que hay que distinguir: una cola plegada sobre sí misma no
## llega a ningún sitio, una tendida sí.
var _cola_alcance_max: float = 0.0
var _cola_n: int = -1
var _cabeza_ant: Vector3 = Vector3.ZERO
var _hubo_cabeza: bool = false
## Señales.
var _ciclos_vistos: int = 0
var _ultimo_n: int = -1
var _perturbado_visto: int = -99


func _ready() -> void:
	set_physics_process(false)
	_seco()
	_jardin = load("res://tools/Jardin.tscn").instantiate() as Node3D
	add_child(_jardin)
	await get_tree().physics_frame
	_enj = _jardin.get_node("Enjambre") as Enjambre
	_enj.ciclo.connect(_al_ciclo)
	_enj.perturbado.connect(func(i: int) -> void: _perturbado_visto = i)
	_construir_vivo()


# =============================================================================
#  MITAD 1 — EL MODELO, EN SECO
# =============================================================================

func _seco() -> void:
	print("--- EL MODELO ---")
	_personalidad()
	_respiracion()
	_control_sin_acoplamiento()
	_perturbacion()
	_determinismo()
	_valores_publicados()


## Un enjambre parado: en el árbol para que `_ready()` lo inicialice, pero con el
## proceso apagado, porque a partir de ahí los pasos los doy yo.
func _banco(t: EnjambreTuning) -> Enjambre:
	var e := Enjambre.new()
	e.tuning = t
	add_child(e)
	e.set_physics_process(false)
	return e


func _pasos(e: Enjambre, segundos: float) -> void:
	for _i in int(segundos / DT):
		e._physics_process(DT)


## Corre `segundos` y devuelve qué FRACCIÓN del tiempo estuvo al unísono, más la
## racha continua más larga.
func _censo(e: Enjambre, segundos: float, umbral: float) -> Dictionary:
	var n := int(segundos / DT)
	var dentro := 0
	var racha := 0
	var racha_max := 0
	for _i in n:
		e._physics_process(DT)
		if e.orden >= umbral:
			dentro += 1
			racha += 1
			racha_max = maxi(racha_max, racha)
		else:
			racha = 0
	return {"fraccion": float(dentro) / float(n), "racha": float(racha_max) * DT}


## Corre hasta que el orden cruce `umbral` en el sentido pedido. Devuelve los
## segundos que tardó, o -1 si no llegó a pasar.
func _hasta(e: Enjambre, umbral: float, subiendo: bool, limite: float) -> float:
	var n := int(limite / DT)
	for i in n:
		e._physics_process(DT)
		if (subiendo and e.orden >= umbral) or (not subiendo and e.orden <= umbral):
			return float(i) * DT
	return -1.0


## Desvío ACUMULADO de un agente durante un rato. Es la medida honesta de "cuánto
## tarda en volver al grupo": mirar el desvío en un instante suelto puede caer en
## un cruce y decir cero justo cuando la criatura va de paso.
func _area_desvio(e: Enjambre, i: int, segundos: float) -> float:
	var area := 0.0
	for _p in int(segundos / DT):
		e._physics_process(DT)
		area += e.desvio_de(i) * DT
	return area


## LA PERSONALIDAD ES LA FRECUENCIA PROPIA, y tiene que ser estable entre
## arranques o ni las capturas ni los tests valen nada.
func _personalidad() -> void:
	var e := _banco(EnjambreTuning.new())
	var primera := e.omegas.duplicate()
	var iguales := true
	for i in range(1, primera.size()):
		if not is_equal_approx(primera[i], primera[0]):
			iguales = false
			break
	_ok("cada criatura tiene su frecuencia propia", not iguales,
		"con todas iguales no hay sincronización que ver: es un metrónomo")

	e.reiniciar()
	var estable := true
	for i in primera.size():
		if not is_equal_approx(primera[i], e.omegas[i]):
			estable = false
	_ok("la personalidad no cambia al reiniciar", estable,
		"con `randf()` cada arranque sería otro sistema y no se podría comparar nada")

	_ok("arranca DISPERSO", e.orden < 0.5,
		"r=%.3f — el reparto áureo tiene que dar caos, no un enjambre ya formado" % e.orden)
	e.queue_free()


## LA INESTABILIDAD. Es la promesa central del encargo —caos a orden— y además
## que no se quede ahí: el sistema respira y no termina nunca.
func _respiracion() -> void:
	var t := EnjambreTuning.new()
	var e := _banco(t)

	var t_orden := _hasta(e, t.orden_saciedad, true, 90.0)
	_ok("CAOS -> ORDEN: el enjambre se sincroniza solo", t_orden >= 0.0,
		"r nunca llegó a %.2f en 90 s" % t.orden_saciedad)
	var k_pico := e.k
	print("        (tardó %.1f s · K=%.2f al llegar)" % [t_orden, k_pico])

	var t_caos := _hasta(e, t.orden_hambre, false, 90.0)
	_ok("ORDEN -> CAOS: y se deshace", t_caos >= 0.0,
		"r se quedó por encima de %.2f: eso converge y se planta, no respira" % t.orden_hambre)
	print("        (tardó %.1f s · K=%.2f al soltarse)" % [t_caos, e.k])

	_ok("K baja mientras el sistema se deshace", e.k < k_pico,
		"K=%.2f no bajó de %.2f: la histéresis no está realimentando" % [e.k, k_pico])

	var t_otra := _hasta(e, t.orden_saciedad, true, 90.0)
	_ok("y VUELVE a ordenarse: respira, no decae", t_otra >= 0.0,
		"llegó al caos y se quedó: eso es un transitorio, no un sistema inestable")
	print("        (segundo ciclo: %.1f s)" % t_otra)
	e.queue_free()


## EL CONTROL. Sin acoplamiento las nueve fases TAMBIÉN se alinean de vez en
## cuando: sus frecuencias están repartidas a intervalos iguales, así que la
## configuración entera reaparece cada 2π/δω y r sube casi a 1. Ese pico es
## indistinguible de sincronizar si solo se mira r un instante.
##
## Lo que separa una coincidencia de un enganche es cuánto DURA. Por eso se mide
## la fracción de tiempo al unísono y la racha, no si alguna vez lo estuvo.
func _control_sin_acoplamiento() -> void:
	var mudo := EnjambreTuning.new()
	mudo.k_min = 0.0
	mudo.k_max = 0.0
	var a := _banco(mudo)
	var sin_k := _censo(a, 120.0, mudo.orden_saciedad)
	a.queue_free()

	var normal := EnjambreTuning.new()
	var b := _banco(normal)
	var con_k := _censo(b, 120.0, normal.orden_saciedad)
	b.queue_free()

	print("        sin K: %.1f%% del tiempo al unísono · racha máx %.2f s" % [
		sin_k["fraccion"] * 100.0, sin_k["racha"]])
	print("        con K: %.1f%% del tiempo al unísono · racha máx %.2f s" % [
		con_k["fraccion"] * 100.0, con_k["racha"]])
	_ok("el orden lo trae el ACOPLAMIENTO, no la casualidad",
		float(con_k["fraccion"]) > float(sin_k["fraccion"]) * 3.0,
		"con K y sin K se pasan el mismo rato ordenados: entonces r no está midiendo el enganche")
	_ok("y sin acoplamiento el orden no DURA",
		float(sin_k["racha"]) < float(con_k["racha"]),
		"la recurrencia aguanta tanto como el enganche: un pico de r no es sincronización")


## LA INTERACCIÓN ENTERA: desordenar y mirar cómo se recompone.
##
## Con `orden_saciedad` casi a 1 a propósito. El enjambre normal se cansa del
## unísono y se suelta solo, así que medir "vuelve a sincronizar" encima de eso
## sería medir dos cosas a la vez y no saber cuál falló.
func _perturbacion() -> void:
	var t := EnjambreTuning.new()
	t.orden_saciedad = 0.99
	var e := _banco(t)
	_hasta(e, 0.95, true, 120.0)
	var r0 := e.orden
	var d0 := e.desvio_de(3)

	e.perturbar(3)
	var r1 := e.orden
	var d1 := e.desvio_de(3)
	print("        r %.3f -> %.3f   ·   desvío del #3 %.3f -> %.3f" % [r0, r1, d0, d1])
	_ok("perturbar TIRA el orden", r1 < r0 - 0.02,
		"r no se movió: la perturbación no llega al sistema")
	_ok("y saca de fase a esa criatura, no a otra", d1 > d0 + 0.1,
		"el desvío del #3 no subió")

	# LA SORDERA, contra un enjambre idéntico SIN ella. Es la única forma de saber
	# que el parámetro hace algo, y de justificar su valor con un número.
	var t2 := EnjambreTuning.new()
	t2.orden_saciedad = 0.99
	t2.perturbacion_sordera = 0.0
	var e2 := _banco(t2)
	_hasta(e2, 0.95, true, 120.0)
	e2.perturbar(3)

	var ventana := t.perturbacion_duracion * 2.0
	var area_sordo := _area_desvio(e, 3, ventana)
	var area_oyente := _area_desvio(e2, 3, ventana)
	print("        desvío acumulado en %.1f s: sordo %.3f · no sordo %.3f" % [
		ventana, area_sordo, area_oyente])
	_ok("la sordera alarga la resincronización", area_sordo > area_oyente * 1.15,
		"sin sordera vuelve igual de rápido, y entonces perturbar no se ve")
	e2.queue_free()

	_pasos(e, t.perturbacion_duracion * 3.0)
	print("        r tras resincronizar: %.3f (venía de %.3f)" % [e.orden, r0])
	_ok("RESINCRONIZA: el sistema se recompone solo", e.orden > r0 - 0.03,
		"r=%.3f — se quedó roto: el usuario desordena, no rompe" % e.orden)
	_ok("y la criatura vuelve al grupo", e.desvio_de(3) < 0.15,
		"desvío %.3f — sigue suelta" % e.desvio_de(3))

	e.perturbar(-1)
	e.perturbar(9999)
	_ok("un índice que no existe no revienta nada",
		is_equal_approx(e.ciclo_de(-1), 0.0) and is_equal_approx(e.desvio_de(999), 0.0),
		"esta API la leen el VFX y el audio: tiene que aguantar un índice viejo")
	e.queue_free()


## Dos enjambres, mismo tuning, mismos pasos: mismas fases. Sin esto no se puede
## comparar una captura con otra ni afirmar nada de todo lo de arriba.
func _determinismo() -> void:
	var a := _banco(EnjambreTuning.new())
	var b := _banco(EnjambreTuning.new())
	_pasos(a, 12.0)
	_pasos(b, 12.0)
	var igual := true
	for i in a.fases.size():
		if absf(a.fases[i] - b.fases[i]) > 0.0001:
			igual = false
	_ok("el sistema es DETERMINISTA", igual,
		"dos ejecuciones divergen: ni test ni comparación de capturas son posibles")
	a.queue_free()
	b.queue_free()


## Lo que sale por la puerta: `ciclo_de`, `pitch_de`, `amplitud_de`. Es todo lo
## que ven la manifestación visual y el audio, que es externo por encargo.
func _valores_publicados() -> void:
	var t := EnjambreTuning.new()
	var e := _banco(t)

	var fuera := false
	for _i in 600:
		e._physics_process(DT)
		for j in t.agentes:
			var c := e.ciclo_de(j)
			if c < 0.0 or c > 1.0:
				fuera = true
	_ok("el ciclo se queda entre 0 y 1, siempre", not fuera,
		"de ahí cuelgan color, opacidad, escala y pitch: fuera de rango los rompe todos a la vez")

	# +12 semitonos es una octava. Si el mando del usuario no dobla la frecuencia,
	# no está en semitonos y la etiqueta miente.
	e.pitch_usuario = 0.0
	var p0 := e.pitch_de(0)
	e.pitch_usuario = 12.0
	var p1 := e.pitch_de(0)
	print("        pitch del #0: %.1f Hz -> %.1f Hz al subir una octava" % [p0, p1])
	_ok("el usuario mueve el pitch en SEMITONOS", absf(p1 / p0 - 2.0) < 0.001,
		"+12 dio x%.3f y no x2: el mando no está en semitonos" % (p1 / p0))
	e.pitch_usuario = 0.0

	# "Las desviadas cantan más flojo" se comprueba en la amplitud POR unidad de
	# ciclo, que es donde vive esa regla. Comparar amplitudes crudas mediría
	# además en qué punto del ciclo está cada una, que es otra cosa.
	var quieta := 0
	var suelta := 0
	for j in t.agentes:
		if e.desvio_de(j) < e.desvio_de(quieta):
			quieta = j
		if e.desvio_de(j) > e.desvio_de(suelta):
			suelta = j
	var rq := e.amplitud_de(quieta) / maxf(e.ciclo_de(quieta), 0.0001)
	var rs := e.amplitud_de(suelta) / maxf(e.ciclo_de(suelta), 0.0001)
	print("        voz por unidad de ciclo: en grupo %.3f · desviada %.3f" % [rq, rs])
	_ok("las criaturas desviadas cantan más flojo", rs < rq,
		"si el desvío no baja el volumen, el caos y el orden suenan igual de fuerte")
	e.queue_free()


# =============================================================================
#  MITAD 2 — LA MANIFESTACIÓN, EN VIVO
# =============================================================================

func _construir_vivo() -> void:
	print("--- LA MANIFESTACIÓN ---")
	_guion = [
		_chequeo("el Jardín monta el enjambre entero", 0.2,
			func() -> void: pass,
			func() -> bool: return _criaturas().size() == _enj.tuning.agentes,
			func() -> String: return "faltan criaturas: %d de %d" % [_criaturas().size(), _enj.tuning.agentes]),

		_chequeo("cada criatura nace con su cola, y no en el origen", 0.2,
			func() -> void: pass,
			func() -> bool:
				for c in _criaturas():
					if c.cola == null or c.cola._puntos.is_empty():
						return false
					if c.cola._puntos[0].distance_to(Vector3.ZERO) < 0.5:
						return false
				return true,
			"una cola nacida en el origen dibuja un latigazo cruzando la escena en su primer frame"),

		# LA RESTRICCIÓN DEL ENCARGO, medida en TODOS los frames.
		_chequeo("NO ROTA. Ninguna. Ni un frame", 3.5,
			func() -> void: pass,
			func() -> bool: return _rotacion_max < 0.0001,
			func() -> String: return "alguna giró (máx %.4f): sin rotación, un cuerpo solo puede decir dónde está, cuánto ocupa y de qué color es" % _rotacion_max),

		# Y la prueba fuerte: meterle una rotación a mano y ver que se la quita.
		# Sin esto solo se estaría comprobando que hoy nadie la escribe.
		_chequeo("y si alguien le mete una rotación, se la quita", 0.3,
			func() -> void:
				_criaturas()[0].rotation = Vector3(0.4, 1.2, 0.7),
			func() -> bool: return _criaturas()[0].basis.is_equal_approx(Basis.IDENTITY),
			"un `look_at()` colado en el futuro se leería como 'el enjambre se ve raro' y nadie sabría por qué"),

		# El techo es la suma de los dos ejes, no solo el principal. El ocho llega a
		# 0.623 m de un límite de 0.62 puesto sobre el eje solo: pasaba por siete
		# milímetros de suerte, no por estar bien puesto.
		_chequeo("se mueve, y no se va de su sitio", 0.1,
			func() -> void: pass,
			func() -> bool:
				var t := _enj.tuning
				var techo: float = t.onda_amplitud * (1.0 + t.onda_lateral)
				return _lejos_del_ancla > 0.05 and _lejos_del_ancla <= techo + 0.01,
			func() -> String: return "recorrido medido %.3f m contra %.3f de amplitud: o está quieta o se escapa del ancla" % [
				_lejos_del_ancla, _enj.tuning.onda_amplitud]),

		# LA COLA. Que exista no basta: tiene que ir DETRÁS. Con el signo del
		# producto escalar contra el avance, nunca con un módulo (regla dura #22):
		# una cola que ADELANTA a la criatura también "se separa" de ella.
		_chequeo("la cola va DETRÁS del movimiento", 0.1,
			func() -> void: pass,
			func() -> bool: return _cola_detras > _cola_delante * 4,
			func() -> String: return "detrás %d frames contra delante %d (%d nudos): eso no es una estela, es un adorno" % [
				_cola_detras, _cola_delante, _cola_n]),

		_chequeo("y tiene largo: es un trazo, no un punto", 0.1,
			func() -> void: pass,
			func() -> bool:
				var t := _enj.tuning
				return _cola_alcance_max > t.cola_paso * 4.0,
			func() -> String: return "alcance máx %.3f m de %d nudos: la cola se amontona en la cabeza y desaparece justo cuando debería quedarse dibujada" % [
				_cola_alcance_max, _cola_n]),

		_chequeo("los nudos guardan su separación", 0.1,
			func() -> void: pass,
			func() -> bool:
				var t := _enj.tuning
				for c in _criaturas():
					var p := c.cola._puntos
					for i in range(1, p.size()):
						if absf(p[i].distance_to(p[i - 1]) - t.cola_paso) > 0.002:
							return false
				return true,
			"sin la restricción de distancia los nudos se juntan en cuanto la criatura frena"),

		_chequeo("la opacidad recorre su rango con el ciclo", 0.1,
			func() -> void: pass,
			func() -> bool:
				var t := _enj.tuning
				return (_alfa_max - _alfa_min) > (t.opacidad_max - t.opacidad_min) * 0.7,
			func() -> String: return "recorrido %.3f: no llega a desvanecerse, y es lo que la hace de TELA y no de piedra" % (_alfa_max - _alfa_min)),

		_chequeo("y el color se mueve con ella", 0.1,
			func() -> void: pass,
			func() -> bool: return (_color_max - _color_min).length() > 0.05,
			"el color está congelado: es el canal que hace visible la fase"),

		_chequeo("publica pitch y amplitud por agente y por frame", 0.1,
			func() -> void: pass,
			func() -> bool: return _ciclos_vistos > 100 and _ultimo_n == _enj.tuning.agentes,
			func() -> String: return "la señal `ciclo` es toda la interfaz del audio, que es externo: %d emisiones, %d valores" % [
				_ciclos_vistos, _ultimo_n]),

		# El observador SEÑALA un sitio, no escribe un índice.
		_chequeo("perturbar por posición alcanza a la criatura de al lado", 0.3,
			func() -> void:
				_enj.perturbar_cerca(_criaturas()[4].global_position + Vector3(0.2, 0, 0), 3.0),
			func() -> bool: return _perturbado_visto == 4,
			func() -> String: return "perturbó al #%d: el usuario apunta a un sitio, no elige de una lista" % _perturbado_visto),
	]
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _paso >= _guion.size():
		_informe()
		return
	_medir()

	var actual: Dictionary = _guion[_paso]
	if is_zero_approx(_t):
		(actual["hacer"] as Callable).call()
	_t += delta
	if _t >= float(actual["dur"]):
		_total += 1
		if not (actual["chequeo"] as Callable).call():
			_fallos.append("%-48s %s" % [actual["nombre"], _porque(actual["porque"])])
		else:
			print("  OK    %s" % actual["nombre"])
		_paso += 1
		_t = 0.0


## Todo lo que hay que mirar frame a frame.
func _medir() -> void:
	var cs := _criaturas()
	if cs.is_empty():
		return
	for c in cs:
		# Cuánto se ha torcido, en la unidad que importa: si sus ejes siguen
		# siendo los del mundo.
		var b := c.basis
		var giro := (b.x - Vector3.RIGHT).length() \
			+ (b.y - Vector3.UP).length() + (b.z - Vector3.BACK).length()
		_rotacion_max = maxf(_rotacion_max, giro)
		_lejos_del_ancla = maxf(_lejos_del_ancla, c.global_position.distance_to(c.ancla))

	var testigo := cs[0]
	if testigo._mat != null:
		var col := testigo._mat.albedo_color
		_alfa_min = minf(_alfa_min, col.a)
		_alfa_max = maxf(_alfa_max, col.a)
		var rgb := Vector3(col.r, col.g, col.b)
		_color_min = Vector3(minf(_color_min.x, rgb.x), minf(_color_min.y, rgb.y), minf(_color_min.z, rgb.z))
		_color_max = Vector3(maxf(_color_max.x, rgb.x), maxf(_color_max.y, rgb.y), maxf(_color_max.z, rgb.z))

	var cabeza := testigo.global_position
	var avance := cabeza - _cabeza_ant
	var valido := _hubo_cabeza
	_cabeza_ant = cabeza
	_hubo_cabeza = true

	var p := testigo.cola._puntos
	_cola_n = p.size()
	if p.size() < 2:
		return
	for q in p:
		_cola_alcance_max = maxf(_cola_alcance_max, q.distance_to(p[0]))
	# El PRIMER seguidor es el que define "ir detrás": está exactamente a un paso
	# de la cabeza, en la dirección de la que viene. La punta, a un ciclo entero
	# de historia, ya no dice nada del instante.
	if valido and avance.length() > 0.0005:
		if (p[1] - cabeza).dot(avance) < 0.0:
			_cola_detras += 1
		else:
			_cola_delante += 1


func _al_ciclo(pitches: PackedFloat32Array, amplitudes: PackedFloat32Array, _orden: float) -> void:
	_ciclos_vistos += 1
	_ultimo_n = pitches.size() if pitches.size() == amplitudes.size() else -1


func _criaturas() -> Array[CriaturaTela]:
	var r: Array[CriaturaTela] = []
	if _enj == null:
		return r
	for h in _enj.get_children():
		var c := h as CriaturaTela
		if c != null:
			r.append(c)
	return r


func _ok(nombre: String, cond: bool, porque: String) -> void:
	_total += 1
	if cond:
		print("  OK    %s" % nombre)
	else:
		_fallos.append("%-48s %s" % [nombre, porque])


## El motivo de un fallo puede ser un texto o un `Callable` que lo construye.
##
## No es un lujo: un mensaje escrito con `%` dentro del guion se formatea CUANDO
## SE MONTA, y en ese momento todos los latches valen cero. Dos fallos reales de
## la cola se reportaron como "0 frames contra 0 frames" y "largo 0.000 m", que no
## era lo medido — era la hora a la que se imprimio la regla.
func _porque(v: Variant) -> String:
	return str((v as Callable).call()) if v is Callable else str(v)


func _chequeo(nombre: String, dur: float, hacer: Callable, chequeo: Callable, porque: Variant) -> Dictionary:
	return {"nombre": nombre, "dur": dur, "hacer": hacer, "chequeo": chequeo, "porque": porque}


func _informe() -> void:
	set_physics_process(false)
	print("RESULTADO ENJAMBRE: %d/%d comprobaciones." % [_total - _fallos.size(), _total])
	if not _fallos.is_empty():
		print("--- FALLOS ---")
		for f in _fallos:
			print("  " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)
