shader_type sky;
render_mode use_half_res_pass;

// CIELO PROCEDURAL CON NUBES PINTADAS.
//
// Sustituye al `ProceduralSkyMaterial`, que solo sabe hacer un degradado: da un
// fondo correcto y vacio. Aqui las nubes son parte del cielo, se mueven solas y
// —esto es lo que las hace encajar con el resto del juego— salen EN BANDAS, no en
// degradado.
//
// **Las bandas son la decision entera.** `docs/01_DIRECCION_ARTE.md` pide un look
// de ilustracion con luz cuantizada, y `docs/07_SHADERS.md §1` ya lo tenia escrito
// para las superficies. Un cielo con nubes suaves debajo de un mundo en bandas se
// lee como dos juegos pegados. Cuantizando el borde de la nube, el cielo pasa a
// ser del mismo dibujo — y de paso es lo que aguanta el filtro de pixel sin
// convertirse en un degradado sucio, porque un degradado suave a un cuarto de
// resolucion es exactamente donde aparece el banding feo que nadie eligio.
//
// LA PROYECCION es la de siempre para nubes de cielo: se divide `EYEDIR.xz` por
// `EYEDIR.y`, o sea se proyecta la mirada sobre un plano horizontal a altura fija.
// Eso da perspectiva gratis —las nubes se aprietan hacia el horizonte— y cuesta
// una division. El `max()` del denominador es obligatorio: en el horizonte `y`
// tiende a cero y sin el la coordenada explota a infinito y el ruido se convierte
// en ruido blanco.

// Colores. Regla dura #9: entran desde `Palette.tres`, nunca escritos aqui. Los
// valores por defecto solo existen para poder abrir el shader y ver algo.
uniform vec4 color_cenit : source_color = vec4(0.72, 0.70, 0.74, 1.0);
uniform vec4 color_horizonte : source_color = vec4(0.94, 0.91, 0.85, 1.0);
uniform vec4 color_nube : source_color = vec4(0.95, 0.94, 0.90, 1.0);
uniform vec4 color_nube_sombra : source_color = vec4(0.71, 0.69, 0.75, 1.0);
uniform vec4 color_sol : source_color = vec4(1.0, 0.95, 0.85, 1.0);

// Cuanto cielo tapan las nubes. 0 = despejado, 1 = cubierto.
uniform float cobertura : hint_range(0.0, 1.0) = 0.46;
// ESCALONES del borde de la nube. 1 = silueta dura de recorte; 4 = casi suave.
// Es el mando que decide si esto parece pintado a mano o renderizado.
uniform float bandas : hint_range(1.0, 8.0) = 3.0;
// Ancho de la transicion antes de cuantizar. A cero el borde es un recorte y el
// escalonado del ruido se ve como caspa; un poco de suavidad le da grosor.
uniform float suavidad : hint_range(0.001, 0.5) = 0.13;
// Tamano de las nubes. Mas alto = nubes mas pequenas y mas numerosas.
uniform float escala : hint_range(0.1, 12.0) = 1.9;
// Deriva, en unidades por segundo. Muy lenta a proposito: una nube que se ve
// moverse deja de ser fondo y pide atencion.
uniform float velocidad : hint_range(0.0, 0.5) = 0.014;
// Cuanto se deforma el ruido consigo mismo. Es lo que convierte manchas redondas
// en nubes con forma; a cero se ven como salpicaduras.
uniform float deformacion : hint_range(0.0, 2.0) = 0.75;
// Por debajo de esta altura de mirada no hay nubes: se funden con el horizonte.
uniform float suelo_nubes : hint_range(0.0, 0.6) = 0.06;
// Disco del sol y su halo.
uniform float sol_tamano : hint_range(0.0, 0.2) = 0.018;
uniform float sol_halo : hint_range(0.0, 1.0) = 0.30;
// Cuanto se aclara la cara de la nube que mira al sol.
uniform float luz_nube : hint_range(0.0, 1.0) = 0.55;

// RELOJ CONGELABLE, igual que en `agua.gdshader` y por lo mismo: una superficie
// animada no puede ser una referencia estable si cada pasada la fotografia en una
// fase distinta. Negativo = usar TIME.
uniform float tiempo_fijo = -1.0;


float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Suavizado de Hermite: sin el, las celdas del ruido se ven como una rejilla.
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Cuatro octavas. Con tres las nubes no tienen borde menudo y se ven como humo;
// con cinco el detalle cae por debajo del pixel y solo cuesta.
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * ruido(p);
		p *= 2.03;   // no exactamente 2: con el doble exacto las octavas se alinean
		a *= 0.5;    // y aparecen ejes visibles en diagonal
	}
	return v;
}

float reloj() {
	return tiempo_fijo < 0.0 ? TIME : tiempo_fijo;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float t = reloj();

	// --- El degradado de fondo -----------------------------------------------
	// La potencia comprime el cenit y estira el horizonte, que es donde se mira.
	float alto = pow(clamp(d.y, 0.0, 1.0), 0.55);
	vec3 fondo = mix(color_horizonte.rgb, color_cenit.rgb, alto);

	// --- Las nubes ------------------------------------------------------------
	vec2 p = d.xz / max(abs(d.y), 0.055) * escala;
	vec2 deriva = vec2(t * velocidad, t * velocidad * 0.4);
	// DEFORMACION DE DOMINIO: se evalua el ruido, y con ESE resultado se desplaza
	// la coordenada antes de volver a evaluarlo. Cuesta una segunda pasada y es lo
	// unico que separa una mancha de una nube.
	vec2 q = vec2(fbm(p + deriva), fbm(p + deriva + vec2(5.2, 1.3)));
	float n = fbm(p + deriva + q * deformacion);

	// El horizonte se despeja: sin esto las nubes se apelmazan en una linea negra
	// justo donde el ruido se estira al infinito.
	float velo = smoothstep(suelo_nubes, suelo_nubes + 0.18, abs(d.y));
	float bruto = smoothstep(1.0 - cobertura - suavidad, 1.0 - cobertura + suavidad, n);

	// EN BANDAS. `floor` sobre el valor ya suavizado: la silueta sale escalonada en
	// N pasos en vez de difuminada, que es el look de ilustracion del proyecto.
	float pasos = max(bandas, 1.0);
	float nube = floor(bruto * pasos) / max(pasos - 1.0, 1.0);
	nube = clamp(nube, 0.0, 1.0) * velo;

	// La cara que mira al sol se aclara. Se usa la MISMA `n` desplazada hacia el
	// sol en vez de una normal: una nube plana no tiene normal, pero desplazar el
	// muestreo da exactamente la sensacion de volumen iluminado por un lado.
	vec3 sol = normalize(LIGHT0_DIRECTION);
	vec2 hacia = normalize(sol.xz + vec2(0.0001)) * 0.35;
	float n2 = fbm(p + deriva + q * deformacion - hacia);
	float cara = clamp((n - n2) * 4.0, -1.0, 1.0) * 0.5 + 0.5;
	cara = floor(cara * pasos) / max(pasos - 1.0, 1.0);
	vec3 tinta = mix(color_nube_sombra.rgb, color_nube.rgb, mix(0.35, 1.0, cara * luz_nube + (1.0 - luz_nube)));

	vec3 c = mix(fondo, tinta, nube);

	// --- El sol ---------------------------------------------------------------
	// EL SOL NO SE MULTIPLICA POR SU ENERGIA, y esa linea costo el look entero.
	//
	// El cielo alimenta el mapa de radiancia —`ambient_light_source = SKY`—, asi
	// que un disco a `LIGHT0_ENERGY` (1.87 aqui) mete un punto muy caliente en la
	// integral y **sube el ambiente de toda la escena**: las sombras se levantan,
	// el verde se lava y el mundo entero pierde contraste. Se veia en el Gym antes
	// que en el cielo.
	//
	// El sol del cielo es un DIBUJO del sol, no el sol: quien ilumina es el
	// `DirectionalLight3D`, y su energia ya esta contada ahi.
	float cerca = dot(d, sol);
	float halo = pow(clamp(cerca, 0.0, 1.0), 24.0) * sol_halo;
	float disco = smoothstep(1.0 - sol_tamano, 1.0 - sol_tamano * 0.55, cerca);
	c += color_sol.rgb * (halo + disco);

	// Y NO EN LA PASADA DE MEDIA RESOLUCION. Godot construye la radiancia desde
	// ella, asi que dejar las nubes y el sol fuera mantiene el ambiente igual que
	// con el degradado de antes: lo que cambia es lo que se VE, no como ilumina.
	if (AT_HALF_RES_PASS) {
		COLOR = fondo;
	} else {
		COLOR = c;
	}
}
