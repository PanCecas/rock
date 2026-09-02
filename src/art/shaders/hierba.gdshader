shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_burley, specular_disabled;

// HIERBA EN MULTIMESH. Implementa `docs/07_SHADERS.md §4`, que a su vez responde
// a `docs/01_DIRECCION_ARTE.md §4.5`: gradiente de altura del musgo a la punta y
// "el viento es un personaje del juego — que las ondas se vean desde lejos".
//
// Las cuatro piezas que pide el doc, y por que:
//
//   · DOBLADO CUADRATICO respecto a la altura. Lineal se ve como si la brizna
//     pivotara desde el suelo entera; cuadratico dobla la punta y deja la base
//     quieta, que es lo que hace una hoja de verdad.
//   · UV.y = 0 EN LA PUNTA y 1 en la base. Es la convencion de los shaders
//     publicados y de ahi salen a la vez el gradiente y el doblado.
//   · RUIDO FBM, no una sinusoide. Una sinusoide se lee como una rejilla en
//     cuanto miras un campo entero; el fbm es lo que produce las ondas grandes
//     que cruzan la pradera, que es lo que §4.5 pide ver desde lejos.
//   · COLOR POR INSTANCIA para variar el tono planta a planta sin romper el batch.
//
// EL VIENTO ES UN CAMPO, NO UN PARAMETRO POR PARCHE.
//
// El doc pedia "direccion de viento como uniform global, transformada de espacio
// de mundo a espacio de modelo antes de aplicarla, o cada instancia dobla hacia
// un lado distinto". Aqui la transformada NO EXISTE, y no por saltarsela: con
// `world_vertex_coords` el shader trabaja ya en coordenadas de mundo, asi que la
// direccion del viento no necesita convertirse a nada. El problema que el doc
// avisaba desaparece por construccion en vez de resolverse cada frame.
//
// Y por eso la onda sale de `TIME` y de la POSICION DE MUNDO: cualquier parche,
// este donde este y de quien sea, evalua el mismo campo y saca el mismo valor. La
// sincronizacion entre parches no se coordina — es que no hay nada que coordinar.

// --- El viento, compartido por TODO el mundo (project.godot > shader_globals) --
global uniform vec4 viento_direccion;   // xz = rumbo. Se normaliza aqui.
global uniform float viento_fuerza;
global uniform float viento_escala;     // tamaño de las ondas: bajo = ondas anchas
global uniform float viento_velocidad;  // a que ritmo cruzan el mapa
global uniform float viento_temblor;    // el tiritón fino, por encima de la onda

// --- Color: SIEMPRE desde Palette (regla dura #9) -----------------------------
uniform vec4 color_base : source_color = vec4(0.24, 0.32, 0.19, 1.0);
uniform vec4 color_punta : source_color = vec4(0.69, 0.77, 0.42, 1.0);
// Cuanto aclara la cresta de la onda. Es lo que hace que el viento se VEA y no
// solo se mueva: al doblarse, la hoja da la cara a la luz.
uniform float brillo_onda : hint_range(0.0, 1.0) = 0.22;

// --- El rastro del jugador ----------------------------------------------------
// Doce huellas con su frescura. La 0 es el jugador AHORA mismo; las demas son por
// donde ha pasado, y su `w` baja hasta cero.
//
// Un array de huellas y no una textura de rastro a proposito. La textura obliga a
// un SubViewport con realimentacion —dibujar sobre lo que ya habia y desvanecerlo—
// y eso son dos pasadas y un estado que no se puede afirmar en un test. Doce
// vec4 se leen, se miden y se comprueban.
const int HUELLAS = 12;
uniform vec4 rastro[HUELLAS];
uniform float rastro_radio = 1.1;
// Margen vertical. Sin el, pasar por un puente aplasta la hierba de abajo.
uniform float rastro_alto = 1.6;
uniform float aplaste_empuje = 0.55;
uniform float aplaste_hundir = 0.8;
// Cuanto oscurece el aplastado. Ver el comentario en `fragment()`.
uniform float aplaste_sombra : hint_range(0.0, 1.0) = 0.35;

// RELOJ CONGELABLE. Negativo = el reloj de verdad.
//
// Misma solucion, y por el mismo motivo, que `agua.gdshader`: una toma del
// screenshot test se dispara contando frames de RENDER, asi que con `TIME` cada
// pasada fotografia una fase distinta de la onda y la referencia no puede ser
// estable. Una toma tiene que medir la FORMA, no el instante.
uniform float tiempo_fijo = -1.0;

varying float v_altura;
varying float v_onda;
varying float v_aplaste;


float reloj() {
	return tiempo_fijo < 0.0 ? TIME : tiempo_fijo;
}


// Ruido de valor con hash entero. Tres octavas: la primera pone las ondas
// grandes que se ven desde lejos y las otras dos rompen su regularidad.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * ruido(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}


void vertex() {
	// Origen de ESTA brizna. Con `world_vertex_coords` la columna de traslacion
	// de MODEL_MATRIX ya viene en mundo.
	vec3 raiz = MODEL_MATRIX[3].xyz;
	// 0 en la base, 1 en la punta. La malla trae UV.y = 1 abajo (convencion §4).
	float altura = 1.0 - UV.y;
	v_altura = altura;
	// CUADRATICO. Ver la cabecera.
	float doblado = altura * altura;
	// Alto real de este vertice sobre su raiz: lo necesita el hundimiento, y
	// leerlo de la geometria evita tener que pasarlo como uniform.
	float alto_local = VERTEX.y - raiz.y;

	vec2 rumbo = viento_direccion.xz;
	rumbo = length(rumbo) > 0.0001 ? normalize(rumbo) : vec2(1.0, 0.0);

	// LA ONDA. Campo continuo en mundo que se desplaza a favor del viento.
	float t = reloj();
	float onda = fbm(raiz.xz * viento_escala - rumbo * (t * viento_velocidad));
	onda = (onda - 0.4375) * 2.0;   // el fbm de 3 octavas promedia 0.4375
	// El tiritón fino, desfasado por posicion para que no vibren todas a la vez.
	float temblor = sin(t * viento_temblor + (raiz.x + raiz.z * 1.7) * 2.3) * 0.18;
	v_onda = onda;

	vec3 empuje = vec3(rumbo.x, 0.0, rumbo.y) * ((onda + temblor) * viento_fuerza) * doblado;
	// Doblarse ACORTA. Sin esto la brizna se estira al inclinarse y el campo
	// entero parece de goma.
	empuje.y -= length(empuje.xz) * 0.35;

	// --- EL RASTRO -----------------------------------------------------------
	// Se acumula la direccion de huida ponderada y se guarda el aplaste MAYOR:
	// sumarlos haria que dos huellas juntas hundieran la hierba al doble.
	float aplaste = 0.0;
	vec2 huida = vec2(0.0);
	v_aplaste = 0.0;
	for (int i = 0; i < HUELLAS; i++) {
		float frescura = rastro[i].w;
		if (frescura <= 0.001) {
			continue;
		}
		vec2 d = raiz.xz - rastro[i].xz;
		float dist = length(d);
		float vertical = 1.0 - clamp(abs(raiz.y - rastro[i].y) / rastro_alto, 0.0, 1.0);
		float f = frescura * vertical * (1.0 - smoothstep(rastro_radio * 0.3, rastro_radio, dist));
		aplaste = max(aplaste, f);
		huida += (dist > 0.001 ? d / dist : vec2(1.0, 0.0)) * f;
	}
	v_aplaste = aplaste;
	if (aplaste > 0.001) {
		vec2 fuera = length(huida) > 0.0001 ? normalize(huida) : vec2(0.0);
		empuje.xz += fuera * (aplaste * aplaste_empuje) * doblado;
		empuje.y -= aplaste * aplaste_hundir * alto_local;
	}

	VERTEX += empuje;

	// NORMAL CASI VERTICAL a proposito. Una brizna es una carta plana y su normal
	// real apunta de canto: iluminada asi, un campo entero se ve como una valla de
	// tarjetas. Tirandola hacia arriba, la pradera se ilumina como la superficie
	// que el ojo cree estar viendo.
	NORMAL = normalize(vec3(NORMAL.x, 2.2, NORMAL.z));
}


void fragment() {
	// El gradiente de §4.5, de `musgo_medio` en la base a `hierba_highlight` en la
	// punta, y la variacion planta a planta que trae la instancia en COLOR.
	vec3 c = mix(color_base.rgb, color_punta.rgb, v_altura) * COLOR.rgb;
	// La cresta de la onda aclara. Es la mitad de "que las ondas se vean desde
	// lejos": sin esto el viento solo se nota en la silueta y de lejos no llega.
	c *= 1.0 + v_onda * brillo_onda * v_altura;
	// LA HIERBA PISADA SE OSCURECE, y no es un truco: una brizna tumbada enseña
	// su cara de abajo y se mete en la sombra de sus vecinas. Sin esto el rastro
	// existe pero no se LEE — la silueta cambia y el color no, y a diez metros
	// solo se distingue un campo un poco mas corto. Es lo que separa un rastro de
	// una zona con menos hierba.
	c *= 1.0 - v_aplaste * aplaste_sombra;
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
