# ROCK — Ideas y backlog

Este archivo recoge lo que **todavía no se construye**. La referencia viva del
proyecto es `CLAUDE.md` y los cinco documentos de `docs/`; aquí solo se aparcan
ideas para que no se pierdan y para que condicionen las decisiones de hoy cuando
toque.

---

## Ideas Futuras (Por Implementar)

> **Nada de esta sección está implementado.** No se empieza sin cerrar antes la
> fase que toque en `docs/04_ROADMAP.md`.

### 1. Minijuego: aros en el aire
Pasar por dentro de una secuencia de aros **sin tocar el suelo**. Encadena planeo,
doble salto, dash aéreo y —cuando exista— el lazo.

Por qué encaja: obliga a leer una ruta aérea completa antes de saltar, que es
justo la habilidad que pide un coloso. Es el mismo examen, en pequeño y sin
riesgo. El fallo se castiga solo (tocas el suelo, se acabó), así que no necesita
ni cronómetro ni vidas.

Notas de diseño para cuando toque: los aros marcan la ruta, pero deberían admitir
más de una línea buena. Un aro que solo se pasa de una forma es un tutorial, no
un minijuego.

### 2. Minijuego: circuito de parkour
Completar un recorrido de obstáculos escalando y encadenando los verbos de
traversal. Es la evolución de `tools/Circuito.gd`, que ya cronometra, pero llevado
a contenido de verdad dentro del mundo.

Por qué encaja: cierra el pilar P1 (`docs/00_VISION.md`) dándole un sitio propio
dentro del juego, no solo en la sala de pruebas.

### 3. Enemigo Mediano — torso escalable
Un tercer escalón entre el Guardián de Ruina y el coloso. Su particularidad no es
la vida ni el daño: **su torso se puede escalar**.

Por qué importa más de lo que parece: es el **puente pedagógico** hacia los
colosos. El jugador aprende a agarrarse a algo que se mueve y se sacude en un
enemigo que cabe en pantalla, antes de tener que hacerlo a sesenta metros del
suelo. Sin este escalón, el primer coloso enseña tres cosas a la vez.

Implicaciones técnicas que ya condicionan el presente:
- Necesita `SurfaceContext` con un marco móvil de verdad. Es el primer consumidor
  real del sistema, antes que el coloso.
- Necesita `GripSurface` sobre huesos y una versión pequeña del `ShakeDirector`.
- Es el banco de pruebas natural del **Active Ragdoll** (`docs/03 §11`): cuerpo
  mediano, fallos baratos.

**Orden sugerido:** este enemigo debería construirse ANTES del coloso #1, no
después. Lo que se aprenda aquí se paga solo en la Fase 4.

---

## Agua — Fase 2

El **combate acuático por dash ya está implementado** (corrección 2.01):
`agua_ligero.tres` y `agua_pesado.tres`, idénticos en superficie y buceando,
como impulsos con hitbox. Bajo el agua no hay suelo del que empujar, así que un
golpe *es* un desplazamiento — no era una limitación técnica, era la lectura
correcta del medio.

Lo que sigue **pendiente**:

### Enemigos acuáticos
Reutilizan el árbol de comportamiento de los Guardianes terrestres —los mismos
estados: dormido, acercarse, telegrafiar, atacar, recuperar— adaptados al volumen
de navegación. Lo único que cambia de verdad es que el movimiento es 3D y que la
gravedad no existe.

**Riesgo anotado:** el `Guardian` actual asume suelo (`is_on_floor()`, gravedad
manual). Antes de escribir un enemigo acuático hay que extraer su FSM del cuerpo,
o se acabará duplicando el script entero.

## Backlog técnico

El diseño de **Active Ragdoll** y del **grappler con cuerda física real** vive en
`docs/03_ARQUITECTURA_MECANICAS.md §11`, también sin implementar.
