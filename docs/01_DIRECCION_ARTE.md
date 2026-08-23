# ROCK — Dirección de Arte y Paleta

Extraída de la ilustración de referencia (ruinas + arcos + figura solitaria).
El objetivo emocional: **misterio, onírico, místico, antiguo, silencioso.**

---

## 1. La paleta

### FAMILIA A — VERDE ANTIGUO + PIEDRA · **60%**
Las masas grandes: terreno, ruinas, arquitectura, vegetación.

| Hex | Nombre | Uso |
|---|---|---|
| `#12180F` | Verde-negro | Interiores de arcos, bocas de cueva, "el vacío". El negro del juego NO es negro: es verde. |
| `#24301C` | Musgo sombra | Sombra proyectada sobre vegetación |
| `#3E5230` | Musgo medio | Terreno en penumbra, hiedra |
| `#5F7A3E` | Pasto medio | Terreno base |
| `#8CA855` | Pasto sol | Terreno iluminado |
| `#B0C46B` | Hierba highlight | Puntas de hierba a contraluz |
| `#6E6F62` | Piedra sombra | Muros en sombra |
| `#9A9A8A` | Piedra media | Muros neutros |
| `#C3BFAC` | Caliza al sol | Torres, arcos iluminados |

### FAMILIA B — AIRE, BRUMA Y CIELO · **30%**
La profundidad. Es lo que hace que se sienta *de ensueño*, no un juego de bosque genérico.

| Hex | Nombre | Uso |
|---|---|---|
| `#EFE8D8` | Crema bruma | Cielo bajo, niebla, horizonte. **El color más claro del juego.** |
| `#DCD3C0` | Crema medio | Transición cielo/tierra |
| `#B6AFC0` | Lavanda-gris | **Color de sombra fría. La clave del look místico.** |
| `#8E88A0` | Lavanda profundo | Sombra de piedra a distancia media |
| `#7EC8E3` | Cian cielo | Solo cielo alto y despejado. Usar con avaricia. |

### FAMILIA C — ACENTOS · **10%**
Escasos por decreto. Si esto pasa del 10% del frame, el juego pierde su alma.

| Hex | Nombre | Uso |
|---|---|---|
| `#2E4E8F` | **Azul cobalto** | La capa del jugador. El ancla visual. |
| `#4C7ACF` | Azul claro | VFX aliados, el lazo, energía del jugador |
| `#C8322D` | **Carmesí** | Peligro, puntos débiles del coloso, telegrafía de ataque |
| `#E8C86A` | Oro pálido | Pelo del jugador, objetivos, interactuables, luz mágica |
| `#F2F0E6` | Blanco tiza | Pájaros, polvo, destello de parry perfecto |

---

## 2. Cómo se aplica el 60/30/10 (leído de la imagen)

La ilustración no reparte el color al azar. Hace cuatro cosas concretas y todas se traducen
directo a decisiones de motor:

### 2.1 El valor construye la composición, no el color
Los arcos son casi negros y **enmarcan** un centro claro. El ojo entra por el hueco.
→ **En el juego:** portales, túneles y arcos se renderizan como masas casi planas de `#12180F`.
El objetivo del jugador siempre está en la zona clara del encuadre. La cámara se diseña para
que el jugador siempre atraviese oscuridad hacia luz.

### 2.2 Perspectiva aérea extrema
Todo lo lejano tiende a `#EFE8D8`. A 300m el contraste es casi cero.
→ **En el juego:** niebla exponencial de color crema (NO gris), `fog_aerial_perspective` alto,
y desaturación por profundidad en post. Esto además hace que un coloso lejano se lea como
**silueta plana** — que es exactamente el momento de "oh dios, qué grande es eso".

### 2.3 El croma es un recurso escaso
El único elemento saturado de la ilustración es la figura (azul o roja).

> **Corregido tras medir los hex reales** con `tools/medir_paleta.gd`. La primera
> versión de esta regla decía "entorno ≤ 0.35, acento ≥ 0.60" en saturación HSV.
> No sobrevive a los datos: el pasto al sol da 0.49 en HSV y 0.63 en Okhsl, y el
> cobalto del jugador da 0.68 y 0.65. **No hay un solo número que los separe.**
>
> Lo que hace destacar al jugador no es el croma bruto: es que **sus tonos no
> existen en el entorno**. Por eso la regla real tiene dos partes.

→ **REGLA DURA DEL PROYECTO** (medida en Okhsl, `Color.ok_hsl_s`, que es perceptual):

**a) Techo de croma por familia**

| Familia | Límite | Medido |
|---|---|---|
| Neutros (piedra, bruma, lavanda) | ≤ **0.40** | 0.11 – 0.36 ✓ |
| Vegetación (musgo, pasto) | ≤ **0.66** | 0.29 – 0.63 ✓ |
| Acentos (jugador, peligro, objetivos) | ≥ **0.65** | 0.65 – 0.90 ✓ |

**b) Tonos reservados**

Las bandas **200–265°** (el azul del jugador) y **335–25°** (el rojo del peligro)
están prohibidas al entorno por encima de croma 0.35. Un neutro puede rozarlas si
se mantiene por debajo — así el lavanda profundo (255°, croma 0.18) es legal.

El oro es la excepción elegante: **comparte tono con la crema** (≈42°) y se
distingue solo por croma (0.73 contra 0.36). Es exactamente lo que pasa con el
pelo rubio del personaje contra el cielo en la ilustración.

Implementado en `Palette.validar()`. El validador de editor de la Fase 5 corre lo
mismo sobre todos los materiales del proyecto.

Esto resuelve la legibilidad sin marcadores ni HUD: si algo brilla de color, importa.

### 2.4 Las sombras están tintadas, no oscurecidas
No hay negro en la referencia. La sombra de la piedra es **lavanda** (`#B6AFC0`), la de la
vegetación es **verde profundo** (`#24301C`).
→ **En el juego:** shader con sombra tintada, nunca `albedo * 0.2`.

---

## 3. Reparto en pantalla (objetivo por frame)

```
██████████████████████████████████████████████████████████  60%  Verde + piedra desaturados
                                                                 (terreno, ruinas, arquitectura)
████████████████████████████████                            30%  Crema + lavanda
                                                                 (cielo, bruma, profundidad, luz volumétrica)
██████████                                                  10%  Acentos
                                                                 (jugador, weakpoints, VFX, objetivos)
```

**Excepción autorizada:** durante un golpe de parry perfecto o el impacto en un punto débil,
el acento puede subir a ~25% del frame durante 150–300 ms. Ese contraste con el silencio
cromático habitual es lo que hace que el combate se sienta *flashy* sin ser ruidoso.

---

## 4. Implementación técnica del look (Godot 4.7, Forward+)

### 4.1 Paleta como Resource
`res://src/art/palette/Palette.gd` → `class_name Palette extends Resource`
con todos los colores nombrados y exportados. Todos los materiales y shaders leen de ahí.
Una `Palette` por zona permite virar el mood (amanecer, tormenta) sin tocar assets.

### 4.2 Shader base de superficie — `banded_surface.gdshader`
- Iluminación **cuantizada en 3 bandas** en la función `light()`.
- **Sin outline negro.** La referencia no tiene contornos; el volumen lo da el valor.
- `shadow_tint` como uniform: color de sombra = `mix(albedo * ambient, shadow_tint, 0.35)`.
- `rim_light` muy sutil en color crema para separar siluetas contra la bruma.

### 4.3 WorldEnvironment
- `fog_enabled = true`, `fog_mode = EXPONENTIAL`, `fog_light_color = #EFE8D8`
- `fog_aerial_perspective ≈ 0.7` (esto es lo que vende la profundidad de la ilustración)
- `tonemap = FILMIC`, whitepoint bajo, exposición ligeramente sobre-expuesta
- `glow` ancho y de baja intensidad (halo suave, nunca bloom de anime)
- `adjustment_color_correction` con LUT de la paleta

### 4.4 Post-proceso propio (`CompositorEffect` o quad fullscreen)
1. **Desaturación por profundidad** — refuerza el 60/30/10 automáticamente.
2. **Overlay de pinceladas** — textura de brochazos en screen-space, opacidad 4–8%,
   **animada a 12 fps** (no por frame, o "hierve" y marea).
3. Viñeta cálida muy leve.

### 4.5 Vegetación
Hierba en `MultiMesh` con shader de viento, color por gradiente de altura
(`#3E5230` en la base → `#B0C46B` en la punta). El viento es un personaje del juego:
que las ondas de hierba se vean desde lejos.

### 4.6 Fauna atmosférica
Bandadas de pájaros blancos (`#F2F0E6`) con boids simples. Salen al pasar. Sale gratis
en presupuesto y es el 30% del alma de la referencia.

---

## 5. Test de aceptación estético
Toma un screenshot cualquiera del juego y comprueba:
1. ¿Puedo señalar al jugador en menos de 0.5 s? → si no, hay demasiado acento en el entorno.
2. ¿El punto más claro de la imagen es el cielo/bruma? → si no, revisa exposición.
3. ¿Hay algún píxel negro puro o blanco puro? → no debería haberlo.
4. ¿El horizonte se disuelve? → si se ve nítido, sube `fog_aerial_perspective`.
5. En escala de grises, ¿la composición sigue leyéndose? → si no, el color está tapando un
   problema de valor.
