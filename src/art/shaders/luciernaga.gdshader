shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

// LUCIERNAGAS. La mitad visual de `src/world/Luciernagas.gd`.
//
// EL DESTELLO ES ESTRECHO A PROPOSITO. `pow(ciclo, dureza)` con exponente alto
// deja el brillo casi a cero durante la mayor parte del ciclo y lo dispara solo
// en la cresta: lo que se lee entonces es el PULSO, no un objeto luminoso.
// Con un brillo proporcional al ciclo el resultado es una bombilla que sube y
// baja, y la sincronizacion —que es todo el numero— deja de verse.
//
// Es la misma regla que usan las Criaturas de Tela para su destello, y sale del
// mismo sitio del modelo. Lo unico que cambia aqui es el exponente.
//
// INSTANCE_CUSTOM:  x = ciclo · y = desvio

uniform vec4 color_frio : source_color = vec4(0.55, 0.60, 0.48, 1.0);
uniform vec4 color_calido : source_color = vec4(0.91, 0.78, 0.42, 1.0);
// Dureza del destello. Alto = chispazo corto; bajo = respiracion.
uniform float dureza : hint_range(1.0, 24.0) = 7.0;
uniform float tamano : hint_range(0.01, 2.0) = 0.16;
// Cuanto crece el halo al encenderse. Es lo que hace que el parpadeo se note en
// el TAMAÑO ademas de en el brillo, que es como se ve una luz pequeña de verdad.
uniform float halo : hint_range(0.0, 8.0) = 2.6;

varying float v_brillo;
varying float v_desvio;


void vertex() {
	v_brillo = pow(clamp(INSTANCE_CUSTOM.x, 0.0, 1.0), dureza);
	v_desvio = INSTANCE_CUSTOM.y;

	// BILLBOARD. Se tira la rotacion del modelo y se queda solo su traslacion, de
	// forma que el quad siempre da la cara. Va aqui y no como propiedad del
	// material porque con MultiMesh el billboard del StandardMaterial no aplica
	// por instancia.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX.xy *= tamano * (0.3 + v_brillo * halo);
}


void fragment() {
	// Nucleo duro y aura blanda, los dos radiales sobre el mismo quad. Dos
	// gradientes y no una textura: no hay que importar nada y el borde nunca
	// pixela por mucho que la camara se acerque.
	float d = length(UV - vec2(0.5)) * 2.0;
	float nucleo = 1.0 - smoothstep(0.0, 0.32, d);
	float aura = 1.0 - smoothstep(0.0, 1.0, d);

	vec3 c = mix(color_frio.rgb, color_calido.rgb, v_brillo);
	// Las desviadas brillan menos, igual que cantan mas flojo. Misma regla, otro
	// canal: el orden tiene que notarse en TODO lo que sale del modelo.
	c *= 1.0 - v_desvio * 0.45;

	ALBEDO = c;
	ALPHA = (nucleo * 0.95 + aura * 0.35) * v_brillo;
}
