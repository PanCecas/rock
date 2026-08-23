extends SceneTree

func _init() -> void:
	var p: Palette = load("res://content/data/default_palette.tres")
	print("--- ENTORNO ---")
	for n in p.colores_entorno():
		var c: Color = p.colores_entorno()[n]
		print("%-20s hsv_s=%.2f  ok_s=%.2f  lum=%.2f" % [n, c.s, c.ok_hsl_s, c.get_luminance()])
	print("--- ACENTOS ---")
	for n in p.colores_acento():
		var c: Color = p.colores_acento()[n]
		print("%-20s hsv_s=%.2f  ok_s=%.2f  lum=%.2f" % [n, c.s, c.ok_hsl_s, c.get_luminance()])
	quit()
