shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// AGUA POR DERIVADAS ANALÍTICAS. Sin simulación.
//
// El usuario lo pidió así: *"utilizar matemáticas dy/dx para el agua y que
// parezca agua, pero nada de simulación fuerte; mientras parezca líquido"*. Es la
// forma correcta y además la barata.
//
// La idea entera: la altura de la superficie es una SUMA DE SENOS,
//
//     h(x, z) = Σ aᵢ · sin(kᵢ·(dᵢ·p) + ωᵢ·t)
//
// y de una función analítica se puede sacar la pendiente DERIVANDO en vez de
// midiendo. La normal sale de las dos parciales:
//
//     ∂h/∂x = Σ aᵢ·kᵢ·dᵢ.x · cos(…)
//     ∂h/∂z = Σ aᵢ·kᵢ·dᵢ.y · cos(…)
//     n = normalize(vec3(-∂h/∂x, 1, -∂h/∂z))
//
// **Por qué derivadas y no un normal map ni muestrear vecinos:**
//
//   · Un normal map animado es una textura que no cuadra con la geometría: la
//     ola sube y el brillo no la sigue. Aquí la normal es la de la ola de verdad,
//     porque sale de la misma fórmula que la mueve.
//   · Muestrear tres puntos (`h(x+ε)`, `h(x)`, `h(z+ε)`) cuesta el triple y da un
//     resultado peor: el ε introduce error justo en las crestas, que es donde se
//     mira. La derivada es exacta y gratis.
//   · Y es la ÚNICA vía que funciona con pocos vértices. El plano de la piscina
//     no está subdividido, así que las olas no se pueden ver como geometría —
//     pero sí como iluminación, y la iluminación solo necesita la normal.
//
// Cuatro ondas con direcciones y frecuencias que **no son múltiplos entre sí**.
// Con periodos conmensurables el patrón se repite visiblemente cada pocos
// segundos y el ojo lo caza enseguida: se lee como una textura girando, no como
// agua.

// Colores. Regla dura #9: entran desde `Palette.tres`, nunca escritos aquí.
uniform vec4 color_poco : source_color = vec4(0.49, 0.78, 0.89, 1.0);
uniform vec4 color_hondo : source_color = vec4(0.18, 0.31, 0.56, 1.0);
uniform vec4 color_espuma : source_color = vec4(0.95, 0.94, 0.90, 1.0);

uniform float amplitud : hint_range(0.0, 0.5) = 0.085;
// NUMERO DE ONDA. Es el mando que MAS importa: la pendiente de la ola es a·k, asi
// que subir la escala inclina la normal sin levantar la superficie. Con 0.55 la
// normal se movia dos grados y el agua se veia como un degradado plano.
uniform float escala : hint_range(0.05, 8.0) = 1.5;
uniform float velocidad : hint_range(0.0, 4.0) = 0.85;
uniform float transparencia : hint_range(0.0, 1.0) = 0.42;
// Profundidad a la que el agua alcanza su color hondo, en metros.
uniform float profundidad_color : hint_range(0.5, 30.0) = 5.0;
// Grosor del borde de espuma contra la geometría, en metros.
uniform float borde_espuma : hint_range(0.0, 2.0) = 0.45;
uniform float brillo : hint_range(0.0, 1.0) = 0.62;

// RELOJ CONGELABLE. Negativo = usar TIME, que es lo normal.
//
// Existe para el screenshot test, y no es una concesion: una superficie animada
// NUNCA puede ser una referencia estable, porque cada pasada fotografia una fase
// distinta de la ola. Es el mismo problema que el cordon —resuelto con
// `asentar()`— y la postura agachada —resuelto igualando la altura—: una toma
// tiene que medir la FORMA, no el instante.
uniform float tiempo_fijo = -1.0;

uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D profundidad_buf : hint_depth_texture;

varying vec3 mundo;

// Las cuatro ondas: direccion (xy), numero de onda, frecuencia angular, amplitud.
//
// EN OCTAVAS, no en frecuencias parecidas. La primera version usaba
// K = 1.0, 1.73, 2.41, 3.19 —todas dentro de un factor 3— y el resultado era una
// REJILLA visible: cuatro ondas de tamaño similar se cruzan formando un enrejado
// regular que el ojo lee como tela metalica, no como agua.
//
// Con cada octava al DOBLE de frecuencia y a la MITAD de amplitud, la suma tiene
// detalle en varias escalas a la vez, que es como se ve una superficie real: olas
// grandes con rizos pequeños encima, no un patron unico repetido.
//
// Las direcciones no son simetricas ni multiplos de 90 grados, por lo mismo: dos
// ondas perpendiculares dan cuadros.
const vec2 DIR[4] = {vec2(1.0, 0.0), vec2(-0.34, 0.94), vec2(0.77, -0.64), vec2(-0.87, -0.5)};
const float K[4] = {1.0, 2.1, 4.3, 8.7};
const float W[4] = {1.0, 1.41, 2.13, 3.31};
const float A[4] = {1.0, 0.52, 0.26, 0.12};

// Altura y sus dos parciales, de una pasada. Devolver las tres juntas evita
// recorrer las ondas dos veces.
vec3 olas(vec2 p, float t) {
    float h = 0.0;
    float dx = 0.0;
    float dz = 0.0;
    for (int i = 0; i < 4; i++) {
        float k = K[i] * escala;
        float fase = k * dot(DIR[i], p) + W[i] * t * velocidad;
        float a = A[i] * amplitud;
        h += a * sin(fase);
        // La derivada de la cadena: d/dp [a·sin(k·(d·p) + wt)] = a·k·d · cos(…)
        float c = a * k * cos(fase);
        dx += c * DIR[i].x;
        dz += c * DIR[i].y;
    }
    return vec3(h, dx, dz);
}

float reloj() {
    return tiempo_fijo < 0.0 ? TIME : tiempo_fijo;
}

void vertex() {
    mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    // El vértice SÍ se desplaza, aunque el plano tenga pocos: en una piscina
    // pequeña basta para que el borde no se lea como una línea recta muerta.
    VERTEX.y += olas(mundo.xz, reloj()).x;
}

void fragment() {
    vec3 o = olas(mundo.xz, reloj());

    // LA NORMAL SALE DE LAS PARCIALES. Esta línea es todo el efecto: sin ella
    // la superficie es un plano y ninguna cantidad de color la hace parecer agua.
    NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-o.y, 1.0, -o.z)), 0.0)).xyz);

    // PROFUNDIDAD: lo hondo tira al azul oscuro y lo somero al cian. Es lo que
    // hace que se lea el fondo del vaso sin dibujarlo.
    //
    // Ojo con el buffer invertido de Godot 4.3+: va de 1.0 cerca a 0.0 lejos.
    float d = texture(profundidad_buf, SCREEN_UV).x;
    vec4 vista = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
    vista.xyz /= vista.w;
    float grosor = max(0.0, -vista.z + VERTEX.z);

    float f = clamp(grosor / profundidad_color, 0.0, 1.0);
    vec3 color = mix(color_poco.rgb, color_hondo.rgb, f);

    // ESPUMA donde el agua se encuentra con algo. Es el detalle que más vende
    // que hay un volumen y no una lámina pintada.
    float espuma = 1.0 - smoothstep(0.0, borde_espuma, grosor);
    color = mix(color, color_espuma.rgb, espuma * 0.8);

    // Refracción: lo de debajo se desplaza con la pendiente de la ola. La misma
    // derivada, reutilizada — por eso se calcula una vez y se usa tres.
    vec2 uv = SCREEN_UV + vec2(o.y, o.z) * 0.06;
    vec3 fondo = texture(pantalla, clamp(uv, vec2(0.001), vec2(0.999))).rgb;

    ALBEDO = mix(fondo, color, mix(transparencia, 1.0, f));
    ROUGHNESS = 0.08;
    SPECULAR = brillo;
    METALLIC = 0.0;
}
