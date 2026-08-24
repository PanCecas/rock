@tool
class_name Palette
extends Resource
## Paleta maestra de ROCK. Fuente única de color del proyecto.
##
## REGLA DURA (CLAUDE.md #9): ningún hex se escribe a mano fuera de este archivo.
## Materiales, shaders, VFX y UI leen siempre de un Palette.
##
## Reparto 60/30/10 — ver docs/01_DIRECCION_ARTE.md:
##   60%  Familia A (verde antiguo + piedra)  ->  masas: terreno, ruinas, arquitectura
##   30%  Familia B (aire, bruma, cielo)      ->  profundidad, lo onírico
##   10%  Familia C (acentos)                 ->  jugador, peligro, objetivos, VFX

# --- Familia A · Verde antiguo y piedra (60%) -------------------------------
@export_group("A · Verde antiguo (60%)")
## El "negro" del juego. No es negro: es verde. Interiores de arcos, bocas de cueva.
@export var verde_negro: Color = Color("#12180F")
@export var musgo_sombra: Color = Color("#24301C")
@export var musgo_medio: Color = Color("#3E5230")
@export var pasto_medio: Color = Color("#5F7A3E")
@export var pasto_sol: Color = Color("#8CA855")
@export var hierba_highlight: Color = Color("#B0C46B")

@export_group("A · Piedra (60%)")
@export var piedra_sombra: Color = Color("#6E6F62")
@export var piedra_media: Color = Color("#9A9A8A")
@export var caliza_sol: Color = Color("#C3BFAC")

# --- Familia B · Aire, bruma y cielo (30%) ----------------------------------
@export_group("B · Aire y bruma (30%)")
## El color más claro del juego. Niebla, horizonte, cielo bajo.
@export var crema_bruma: Color = Color("#EFE8D8")
@export var crema_medio: Color = Color("#DCD3C0")
## La sombra fría. La clave del look místico: las sombras se tintan, no se oscurecen.
@export var lavanda_gris: Color = Color("#B6AFC0")
@export var lavanda_profundo: Color = Color("#8E88A0")
## Solo cielo alto y despejado. Usar con avaricia.
@export var cian_cielo: Color = Color("#7EC8E3")

# --- Familia C · Acentos (10%) ----------------------------------------------
@export_group("C · Acentos (10%)")
## La capa del jugador. El ancla visual de todo el juego.
@export var cobalto: Color = Color("#2E4E8F")
@export var azul_claro: Color = Color("#4C7ACF")
## Peligro, puntos débiles del coloso, telegrafía de ataque.
@export var carmesi: Color = Color("#C8322D")
## Pelo del jugador, objetivos, interactuables, luz mágica.
@export var oro_palido: Color = Color("#E8C86A")
## Pájaros, polvo, destello de parry perfecto. El único blanco permitido.
@export var blanco_tiza: Color = Color("#F2F0E6")

# --- Luz ---------------------------------------------------------------------
@export_group("Luz")
@export var luz_solar: Color = Color("#FFF3D8")
@export var luz_ambiente: Color = Color("#B9C4C4")
@export_range(0.0, 3.0) var energia_solar: float = 1.15
@export_range(0.0, 2.0) var energia_ambiente: float = 0.55
## Ángulo del sol en grados: bajo = sombras largas, como en la referencia.
@export_range(-90.0, 0.0) var elevacion_solar: float = -32.0
@export_range(-180.0, 180.0) var azimut_solar: float = -50.0

# --- Niebla (perspectiva aérea) ---------------------------------------------
@export_group("Niebla")
## Lo lejano se disuelve en crema, nunca en gris. Es el 30% de la paleta hecho profundidad.
##
## Bajado de 0.0075 a 0.0035 tras montar el circuito de 150 m: con el valor alto
## no se veía la siguiente plataforma. Densidad y perspectiva aérea son efectos
## DISTINTOS y hay que tunearlos por separado — la niebla come legibilidad a media
## distancia, la perspectiva aérea solo tiñe la silueta lejana. El look de la
## referencia lo da la segunda, así que se sube esa y se baja esta.
@export_range(0.0, 0.05) var densidad_niebla: float = 0.0035
## Cuánto tiñe la niebla al cielo. Alto = horizonte disuelto. AQUÍ vive el look.
@export_range(0.0, 1.0) var perspectiva_aerea: float = 0.78
@export_range(0.0, 1.0) var niebla_afecta_cielo: float = 0.45

# --- Reparto de croma (CLAUDE.md #8) ----------------------------------------
# Medido sobre los hex reales con `tools/_medir_paleta.gd`: un único techo de
# saturación NO separa entorno de acento (el pasto al sol da 0.63 en Okhsl y el
# cobalto 0.65 — no hay hueco). Lo que hace destacar al jugador no es el croma
# bruto: es que sus TONOS no existen en el entorno. Por eso la regla tiene dos
# partes, techo por familia y tonos reservados.
@export_group("Reparto de croma")
## Techo Okhsl para piedra, bruma y lavanda. Los neutros deben leerse como neutros.
@export_range(0.0, 1.0) var croma_max_neutro: float = 0.40
## Techo Okhsl para vegetación. El verde puede ser vivo sin competir con un acento.
@export_range(0.0, 1.0) var croma_max_vegetacion: float = 0.66
## Suelo Okhsl para jugador, puntos débiles e interactuables.
@export_range(0.0, 1.0) var croma_min_acento: float = 0.65
## Bandas de tono (grados) prohibidas al entorno: azul del jugador y rojo del peligro.
@export var tonos_reservados: PackedVector2Array = [Vector2(200, 265), Vector2(335, 25)]
## Un neutro puede rozar un tono reservado si su croma queda por debajo de esto.
@export_range(0.0, 1.0) var croma_libre_de_tono: float = 0.35


## Vegetación y verde-negro: techo alto, tono siempre verde.
func colores_vegetacion() -> Dictionary:
	return {
		"verde_negro": verde_negro,
		"musgo_sombra": musgo_sombra,
		"musgo_medio": musgo_medio,
		"pasto_medio": pasto_medio,
		"pasto_sol": pasto_sol,
		"hierba_highlight": hierba_highlight,
	}


## Piedra, bruma y lavanda: tienen que leerse como neutros.
func colores_neutros() -> Dictionary:
	return {
		"piedra_sombra": piedra_sombra,
		"piedra_media": piedra_media,
		"caliza_sol": caliza_sol,
		"crema_bruma": crema_bruma,
		"crema_medio": crema_medio,
		"lavanda_gris": lavanda_gris,
		"lavanda_profundo": lavanda_profundo,
	}


## Todo lo que forma el 90% del frame.
func colores_entorno() -> Dictionary:
	return colores_vegetacion().merged(colores_neutros())


## El 10%. Deben superar el suelo de croma.
## El oro comparte tono con la crema a propósito: se distingue solo por croma,
## igual que el pelo del personaje contra el cielo en la ilustración.
func colores_acento() -> Dictionary:
	return {
		"cobalto": cobalto,
		"azul_claro": azul_claro,
		"carmesi": carmesi,
		"oro_palido": oro_palido,
	}


## Infracciones del reparto de croma. Vacía = paleta sana.
## El validador de editor de la Fase 5 corre esto sobre todos los materiales.
func validar() -> PackedStringArray:
	var fallos := PackedStringArray()

	for nombre in colores_vegetacion():
		var c: Color = colores_vegetacion()[nombre]
		if c.ok_hsl_s > croma_max_vegetacion:
			fallos.append("%s: croma %.2f > techo vegetación %.2f" % [nombre, c.ok_hsl_s, croma_max_vegetacion])

	for nombre in colores_neutros():
		var c: Color = colores_neutros()[nombre]
		if c.ok_hsl_s > croma_max_neutro:
			fallos.append("%s: croma %.2f > techo neutro %.2f" % [nombre, c.ok_hsl_s, croma_max_neutro])

	for nombre in colores_entorno():
		var c: Color = colores_entorno()[nombre]
		if c.ok_hsl_s > croma_libre_de_tono and tono_reservado(c):
			fallos.append("%s: tono %.0f° está reservado a los acentos" % [nombre, c.h * 360.0])

	for nombre in colores_acento():
		var c: Color = colores_acento()[nombre]
		if c.ok_hsl_s < croma_min_acento:
			fallos.append("%s: croma %.2f < suelo acento %.2f" % [nombre, c.ok_hsl_s, croma_min_acento])

	return fallos


## ¿El tono de este color pertenece a una banda reservada al 10%?
func tono_reservado(c: Color) -> bool:
	var grados := c.h * 360.0
	for banda in tonos_reservados:
		if banda.x <= banda.y:
			if grados >= banda.x and grados <= banda.y:
				return true
		# Banda que cruza el 0°, como el rojo.
		elif grados >= banda.x or grados <= banda.y:
			return true
	return false


## Sombra tintada, nunca `albedo * 0.2`. Ver docs/01_DIRECCION_ARTE.md §2.4.
func sombra_de(albedo: Color, tinte: Color = lavanda_gris, mezcla: float = 0.35) -> Color:
	return albedo.darkened(0.35).lerp(tinte, mezcla)
