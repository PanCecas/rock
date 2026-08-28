# ROCK — Shaders y look, implementación

`docs/01_DIRECCION_ARTE.md` dice **qué** tiene que verse. Este documento dice
**cómo**, con la API exacta de Godot 4.7 y las fuentes.

Todo lo que hay aquí está verificado contra el build real del proyecto
(`ClassDB` sobre Godot 4.7.1) o contra la documentación oficial. Donde algo es
una decisión mía y no un hecho del motor, lo dice.

---

## 0. Estado actual, medido

| Pieza | Doc de arte | Estado real |
|---|---|---|
| `Palette` como Resource | §4.1 | ✅ hecho, con validador de croma |
| Niebla crema + tonemap | §4.3 | ⚠️ **a medias** — ver §2 |
| `banded_surface.gdshader` | §4.2 | ❌ **no existe** |
| Post-proceso propio | §4.4 | ❌ no existe |
| Hierba en MultiMesh | §4.5 | ❌ no existe |
| Fauna atmosférica | §4.6 | ❌ no existe |

`find . -name "*.gdshader" -not -path "./addons/*"` devuelve **cero**. Todo el
look actual sale del `WorldEnvironment` y de `StandardMaterial3D`.

**Nota honesta sobre la referencia:** trabajo desde la descripción que
`01_DIRECCION_ARTE.md §2` hace de tu imagen (arcos casi negros enmarcando un
centro claro, perspectiva aérea a crema, figura como único elemento saturado,
sombras tintadas en lavanda). No tengo la imagen delante en esta sesión. Si
quieres que compare contra ella de verdad, vuelve a mandarla.

---

## 1. El shader base — `banded_surface.gdshader`

### 1.1 La API, y el detalle que importa

Godot permite escribir una función `light()` propia en un shader `spatial`. Se
llama **una vez por luz y por píxel**, y se escribe acumulando en `DIFFUSE_LIGHT`
y `SPECULAR_LIGHT`.

Los built-ins relevantes, según la documentación oficial:

| Built-in | Qué es |
|---|---|
| `LIGHT` | Vector de luz, en espacio de vista |
| `LIGHT_COLOR` | Color × energía × PI |
| `ATTENUATION` | **Atenuación por distancia *o sombra*** |
| `NORMAL`, `ALBEDO`, `VIEW` | Los de siempre |
| `DIFFUSE_LIGHT` / `SPECULAR_LIGHT` | Salida, se acumula con `+=` |

**El detalle que decide si esto se ve bien: la sombra proyectada entra por
`ATTENUATION`.** Si cuantizas solo `dot(NORMAL, LIGHT)` y luego multiplicas por
`ATTENUATION`, la cara sombreada sale en bandas duras y la sombra proyectada sale
con degradado suave — dos técnicas distintas en la misma superficie, y se nota.
Hay que **cuantizar el producto**.

### 1.2 El shader

```glsl
shader_type spatial;

// Sin outline negro: la referencia no tiene contornos, el volumen lo da el valor.
// `ambient_light_disabled` NO se pone: la luz ambiente es la que sostiene la
// zona oscura y evita que caiga a negro.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D textura_albedo : source_color, hint_default_white;
// La sombra se TIÑE, no se oscurece (§2.4 del doc de arte).
// Piedra -> lavanda_gris #B6AFC0 · vegetación -> musgo_sombra #24301C
uniform vec4 shadow_tint : source_color = vec4(0.714, 0.686, 0.753, 1.0);
uniform float shadow_mezcla : hint_range(0.0, 1.0) = 0.65;
uniform int bandas : hint_range(2, 6) = 3;
// Rim en crema, para separar siluetas contra la bruma.
uniform vec4 rim_color : source_color = vec4(0.937, 0.910, 0.847, 1.0);
uniform float rim_fuerza : hint_range(0.0, 2.0) = 0.35;
uniform float rim_dureza : hint_range(1.0, 12.0) = 4.0;

void fragment() {
    ALBEDO = albedo.rgb * texture(textura_albedo, UV).rgb;

    // RIM LIGHT. Va en fragment() y no en light() a propósito: depende de la
    // cámara, no de dónde esté el sol. Puesto en light() se multiplicaría por
    // cada luz de la escena y una sala con tres focos daría triple halo.
    float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
    EMISSION = rim_color.rgb * pow(rim, rim_dureza) * rim_fuerza;
}

void light() {
    // ATTENUATION lleva la sombra DENTRO. Se cuantiza el producto, no N·L solo.
    float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;

    float niveles = float(bandas);
    float banda = clamp(floor(nl * niveles) / max(niveles - 1.0, 1.0), 0.0, 1.0);

    vec3 iluminado = ALBEDO;
    vec3 sombreado = mix(ALBEDO, shadow_tint.rgb, shadow_mezcla);
    DIFFUSE_LIGHT += mix(sombreado, iluminado, banda) * LIGHT_COLOR;
}
```

Con `bandas = 3` los niveles salen **0.0 · 0.5 · 1.0**, que es lo que pide §4.2.

### 1.3 Lo que hay que probar en tu GPU

El borde entre bandas hace **dientes de sierra** al mover la cámara, porque es un
`floor()` sin suavizado. La solución habitual es suavizar con la derivada de
pantalla (`fwidth`), pero `fwidth` dentro de `light()` se evalúa en un bucle por
luz y **no puedo afirmarte que se comporte igual en todas las tarjetas**. Dos
salidas, en orden de a qué recurrir:

1. Subir el MSAA del proyecto. Es gratis y suele bastar a 3 bandas.
2. Meter el suavizado con `smoothstep` sobre `fract(nl * niveles)` y medirlo.

No pongas `fwidth` sin comprobarlo. Es exactamente el tipo de cosa que funciona
en tu 4060 y falla en otra máquina.

### 1.4 La alternativa barata

Godot trae `render_mode diffuse_toon, specular_toon` de fábrica. **No da bandas
configurables ni sombra tintada** —da un corte duro y ya—, pero si quieres ver el
look aproximado en cinco minutos antes de escribir shader, es una línea en un
`StandardMaterial3D`.

---

## 2. WorldEnvironment — lo que falta ajustar

Los nombres de propiedad están verificados contra `ClassDB` en tu build.

`Main.tscn` ya tiene niebla, glow, SSAO y tonemap FILMIC. **Falta lo que más
vende la referencia:**

| Propiedad | Ahora | Objetivo | Por qué |
|---|---|---|---|
| `fog_aerial_perspective` | **sin poner (0.0)** | **≈ 0.7** | Es *la* propiedad de §2.2. Hace que lo lejano tienda al color de la niebla y que un coloso se lea como silueta plana. |
| `fog_mode` | sin poner → `FOG_MODE_EXPONENTIAL` (0) | correcto | Los dos valores son `EXPONENTIAL = 0` y `DEPTH = 1`. |
| `fog_sky_affect` | sin poner | probar 0.5–1.0 | Cuánto tiñe la niebla al cielo. Sin esto el horizonte corta. |
| `fog_light_color` | `#EFE8D8` ✅ | — | Ya es crema, no gris. Bien. |
| `fog_density` | 0.0035 | subir con `depth_curve` | Muy baja para "a 300 m el contraste es casi cero". |
| `adjustment_enabled` + `adjustment_color_correction` | sin poner | LUT de la paleta | §4.3. Es la vía barata al color grading. |

`fog_depth_begin` / `fog_depth_end` / `fog_depth_curve` existen y dan control fino
de dónde arranca la bruma — útil para que el personaje no se lave en primer plano.

**Tonemap:** los modos son `LINEAR=0 · REINHARDT=1 · FILMIC=2 · ACES=3 · AGX=4`.
Estás en FILMIC, que es lo que pide §4.3. **AGX** merece una prueba: preserva
mejor los tonos en las altas luces y para una paleta crema sobreexpuesta puede
dar justo lo que buscas. Es cambiar un número.

---

## 3. El overlay de pinceladas — dos caminos

§4.4 pide una textura de brochazos en screen-space al 4–8 %, animada a 12 fps.
Hay dos formas y **la diferencia de coste es grande**.

### 3.1 Camino A — quad de pantalla completa (recomendado para empezar)

Un `MeshInstance3D` con `QuadMesh` de 2×2, *Flip Faces* activado, colgado de la
cámara. El truco está en el vértice:

```glsl
shader_type spatial;
render_mode unshaded, fog_disabled;

uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D profundidad : hint_depth_texture;
uniform sampler2D pinceladas : filter_linear, repeat_enable;
uniform float opacidad : hint_range(0.0, 0.3) = 0.06;
uniform float fps_overlay = 12.0;

void vertex() {
    // Salta las transformaciones de Godot y escribe en espacio de clip
    // directamente. -1..1 cubre la pantalla entera.
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
    vec3 color = texture(pantalla, SCREEN_UV).rgb;

    // A 12 fps, no por frame. Animado por frame el ruido "hierve" y marea:
    // lo dice §4.4 y es el error clásico de este efecto.
    float paso = floor(TIME * fps_overlay);
    vec2 desplazamiento = vec2(fract(paso * 0.37), fract(paso * 0.61));
    vec3 brocha = texture(pinceladas, SCREEN_UV * 3.0 + desplazamiento).rgb;

    COLOR.rgb = mix(color, color * brocha, opacidad);
    COLOR.a = 1.0;
}
```

**Culling:** si el quad no es hijo de la cámara, hay que subirle
`extra_cull_margin` al máximo o desaparece al mirar a otro lado.

**Desaturación por profundidad** (§4.4 punto 1) va en el mismo shader: se lee
`texture(profundidad, SCREEN_UV).x` y se desatura con la distancia.

> ⚠️ **Godot 4.3+ usa buffer de profundidad invertido (*reversed-Z*).** El valor
> va de **1.0 cerca a 0.0 lejos**, al revés de lo que asume casi todo el código
> que encuentres en foros escrito para 4.0–4.2. Si copias un shader de
> profundidad de internet y sale al revés, es esto.

### 3.2 Camino B — `CompositorEffect`

Es la vía moderna (Godot 4.3+) y la correcta para efectos que necesiten compute
shaders o meterse entre etapas del render. Verificado en tu build:

- Clase `CompositorEffect`, con `enabled`, `effect_callback_type`,
  `access_resolved_color`, `access_resolved_depth`, `needs_motion_vectors`,
  `needs_normal_roughness`, `needs_separate_specular`.
- Método a implementar: `func _render_callback(p_effect_callback_type, p_render_data)`.
- Etapas disponibles: `PRE_OPAQUE=0 · POST_OPAQUE=1 · POST_SKY=2 ·
  PRE_TRANSPARENT=3 · POST_TRANSPARENT=4`.
- Se cuelga en un recurso `Compositor`, que va en la propiedad `compositor` del
  `WorldEnvironment` (todo el viewport) o de una `Camera3D` (solo esa).
- **Solo Forward+ y Mobile.** Estás en Forward+.

**El aviso que vas a agradecer:** `_render_callback` corre **en el hilo de
render**, no en el principal. Todo lo que comparta datos con el juego necesita
`Mutex`. La documentación lo dice explícitamente.

### 3.3 Cuál usar

Empieza por **A**. El overlay de pinceladas y la desaturación por profundidad son
efectos de un solo paso sobre el color y la profundidad ya resueltos: el quad los
hace bien, se depura en el editor y no toca hilos. Pasa a **B** cuando necesites
algo que el quad no puede: un blur multipaso, un outline por distancia, o leer
normales y rugosidad.

---

## 4. Hierba — MultiMesh con viento

§4.5 pide `MultiMesh` con viento y gradiente de altura (`#3E5230` en la base →
`#B0C46B` en la punta).

Las piezas, según lo que hace el ecosistema:

- **Desplazamiento en `vertex()` por `TIME`**, con el factor de doblado
  **cuadrático** respecto a la altura: más fuerte en la punta, cero en la base.
  Lineal se ve como si la hierba pivotara desde el suelo entero.
- **UV.y = 0 en la punta y 1 en la base.** Es la convención que usan los shaders
  publicados, y de ahí salen a la vez el gradiente de color y el doblado.
- **Dirección de viento como uniform global**, transformada de espacio de mundo a
  espacio de modelo antes de aplicarla. Si no la transformas, cada instancia del
  MultiMesh dobla hacia un lado distinto.
- **Ruido Perlin FBM** para que las ondas no sean una sinusoide: es lo que hace
  que "las ondas se vean desde lejos", que es lo que pide §4.5.
- **`COLOR` por instancia** del MultiMesh para variar el tono planta a planta sin
  romper el batch.

**Ojo con la paleta:** el degradado base→punta tiene que salir de `Palette.tres`,
no de dos hex escritos en el shader. Regla dura #9. Un `uniform vec4 ... :
source_color` alimentado desde código es la forma.

Hay implementaciones completas y estudiables en **godotshaders.com** — buscar
*Stylized Multimesh Grass Shader* y *Stylized grass with wind and deformation*.

---

## 5. Orden de implementación

Ordenado por **cuánto cambia la imagen dividido por lo que cuesta**. Cada paso
deja el juego jugable y verificable.

| # | Paso | Coste | Qué cambia |
|---|---|---|---|
| 1 | `fog_aerial_perspective ≈ 0.7` y `fog_sky_affect` | 2 números | **Lo más rentable de la lista.** Es la profundidad de la referencia. |
| 2 | Probar tonemap AGX contra FILMIC | 1 número | Altas luces en una paleta crema |
| 3 | `banded_surface.gdshader` en el terreno | 1 archivo | El look de ilustración |
| 4 | Extenderlo a props y personajes | materiales | Coherencia |
| 5 | LUT de corrección de color | 1 textura | Unifica el frame entero |
| 6 | Quad de pantalla: desaturación por profundidad | 1 shader | Refuerza el 60/30/10 solo |
| 7 | Overlay de pinceladas a 12 fps | mismo shader | La firma del estilo |
| 8 | Hierba MultiMesh | 1 shader + escena | El viento como personaje |
| 9 | Bandadas de pájaros | boids | §4.6 |

**Del 1 al 2 son cinco minutos y ya vas a ver el cambio.** No empieces por el
shader.

### Cómo se verifica

**El screenshot test es la herramienta correcta para esto**, y ya existe. Cada
paso de esta lista va a poner las 11 tomas en rojo, y eso está bien: se mira el
mapa de diff en `user://visual/`, se comprueba que cambió lo que tenía que
cambiar, y **entonces** se regenera la referencia (regla dura #18).

Además, `docs/01_DIRECCION_ARTE.md §5` tiene el test de aceptación estético:
*¿puedo señalar al jugador en menos de 0.5 s?* Si no, hay demasiado acento en el
entorno.

Y `tools/medir_paleta.gd` mide croma y luminancia reales. Antes de decidir que un
color "queda bien", mídelo.

---

## Fuentes

Documentación oficial:

- [Spatial shaders — referencia completa, `light()` y render modes](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)
- [Tu primer shader espacial, parte 2](https://docs.godotengine.org/en/stable/tutorials/shading/your_first_shader/your_second_spatial_shader.html)
- [Post-procesado avanzado — el quad de pantalla completa](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html)
- [El Compositor y `CompositorEffect`](https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html)
- [Fuente del doc del compositor en GitHub](https://github.com/godotengine/godot-docs/blob/master/tutorials/rendering/compositor.rst)

Comunidad y ejemplos:

- [Demo oficial de Compositor Effects](https://store.godotengine.org/asset/godot-foundation/compositor-effects-post-processing-demo/)
- [PPMagic — efectos de post con el stack de CompositorEffect](https://github.com/peterprickarz/PPMagic)
- [Empezar con CompositorEffects sin fondo de gráficos](https://github.com/pink-arcana/godot-distance-field-outlines/discussions/1)
- [Stylized Multimesh Grass Shader](https://godotshaders.com/shader/stylized-multimesh-grass-shader/)
- [Stylized grass with wind and deformation](https://godotshaders.com/shader/stylized-grass-with-wind-and-deformation/)
- [Serie de renderizado de hierba — animación e interacción](https://hexaquo.at/pages/grass-rendering-series-part-3-animating-and-interacting-with-grass-in-godot/)

Verificado contra el build local (Godot 4.7.1) con `ClassDB`: los nombres de
propiedad de `Environment`, las constantes de `CompositorEffect.EffectCallbackType`,
`Environment.FogMode` y `Environment.ToneMapper`.
