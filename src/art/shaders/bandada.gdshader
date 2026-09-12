shader_type spatial;
render_mode cull_disabled, unshaded, blend_mix, depth_draw_opaque;

// CRIATURAS DE TELA VOLADORAS. La mitad visual de `src/world/Bandada.gd`.
//
// El reparto es el mismo que en la hierba y por el mismo motivo:
//
//   la CPU  -> donde esta cada criatura y hacia donde mira. Una vez por criatura.
//   aqui    -> como ondula su tela. Por vertice, y gratis.
//
// Todo lo que se ve cuelga de DOS numeros por criatura, y los dos vienen del
// mismo oscilador: el ciclo `(sinθ+1)/2` y el desvio respecto al grupo. Es la
// misma regla que las Criaturas de Tela del Jardin —color, opacidad y forma
// saliendo del mismo sitio— y es lo que hace que la bandada se lea como una cosa
// viva en vez de como tres efectos sueltos encima de una malla.
//
// INSTANCE_CUSTOM:  x = ciclo · y = desvio · z = opacidad · w = fase cruda

const float TAU_ = 6.28318530718;

uniform vec4 color_calma : source_color = vec4(0.71, 0.69, 0.75, 1.0);
uniform vec4 color_pico : source_color = vec4(0.95, 0.94, 0.90, 1.0);
// A donde desatura una criatura desviada. Es lo que hace VISIBLE el orden sin
// numeros: dispersas son colores corridos, al unisono son un solo color latiendo.
uniform vec4 color_perdida : source_color = vec4(0.60, 0.60, 0.54, 1.0);

// Cuantas ondas caben a lo largo de la cinta. Por encima de dos deja de leerse
// como tela y empieza a leerse como vibracion.
uniform float ondas : hint_range(0.2, 4.0) = 1.3;
uniform float onda_amplitud : hint_range(0.0, 2.0) = 0.34;
// Cuanto se pliegan los bordes con el ciclo. ES el aleteo, y sincronizado es
// exactamente lo que se busca ver.
uniform float aleteo : hint_range(0.0, 3.0) = 0.9;
// Cuanto se disuelve la cola. Una cinta que termina en un borde recto se lee
// como recortada; disolviendola, termina en aire.
uniform float disolver_cola : hint_range(0.0, 1.0) = 0.85;

varying float v_t;
varying float v_ciclo;
varying float v_desvio;
varying float v_opacidad;


void vertex() {
	v_t = UV.y;                       // 0 cabeza, 1 cola
	v_ciclo = INSTANCE_CUSTOM.x;
	v_desvio = INSTANCE_CUSTOM.y;
	v_opacidad = INSTANCE_CUSTOM.z;
	float fase = INSTANCE_CUSTOM.w;

	// ONDA VIAJERA. La cabeza quieta y la cola ondeando: es el t*t el que hace
	// que la amplitud crezca hacia atras. Con amplitud constante la criatura
	// entera sube y baja y parece que rebota.
	float onda = sin(fase * 2.0 - v_t * TAU_ * ondas);
	VERTEX.y += onda * onda_amplitud * v_t * v_t;

	// ALETEO. Los bordes se pliegan con el ciclo, el centro no. `VERTEX.x` ya es
	// la distancia al eje de la cinta, asi que sirve de peso sin pasar el ancho.
	VERTEX.y += abs(VERTEX.x) * (v_ciclo - 0.5) * aleteo * 2.0;

	// Y la criatura RESPIRA: se encoge y se estira con su ciclo. Es la misma
	// regla de escala que usan las Criaturas de Tela.
	VERTEX.xz *= 1.0 + (v_ciclo - 0.5) * 0.16;
}


void fragment() {
	vec3 c = mix(color_calma.rgb, color_pico.rgb, v_ciclo);
	c = mix(c, color_perdida.rgb, v_desvio * 0.75);
	ALBEDO = c;
	// La cola se disuelve, y ademas los bordes: sin el segundo desvanecido la
	// cinta tiene un contorno duro de poligono y se le ve la geometria.
	float borde = 1.0 - smoothstep(0.55, 1.0, abs(UV.x - 0.5) * 2.0);
	float cola = 1.0 - smoothstep(0.45, 1.0, v_t) * disolver_cola;
	ALPHA = v_opacidad * borde * cola;
}
