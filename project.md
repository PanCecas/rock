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

### 3. Bestiario — tres escalones, no tres enemigos

El bestiario tiene **tres escalones de tamaño**, y cada uno enseña exactamente una
cosa que el siguiente da por sabida. Esa es la razón de que sean tres y no dos: sin
el escalón intermedio, el primer coloso enseña tres lecciones a la vez.

```
Guardián de Ruina  ->  el combate      (existe)
Coloso mediano     ->  agarrarse a algo que se mueve
Coloso             ->  el nivel que respira
```

---

#### 3.1 · Enemigos normales — el saco de boxeo **que sabe agruparse**

Los Guardianes de Ruina actuales. Individualmente son un saco de boxeo a
propósito: existen para que el jugador practique el moveset sin miedo.

**La dificultad no sale de hacerlos más duros, sale de agruparlos.** Un Guardián
con el doble de vida es el mismo enemigo durante el doble de tiempo, que es
aburrimiento, no dificultad. Tres Guardianes coordinados son un problema distinto:
obligan a mirar fuera del enemigo que tienes delante.

Lo que hace falta construir, por orden:

1. **`SquadDirector`** — un director de grupo que decide *quién ataca ahora*. La
   regla clásica y la que mejor funciona: **solo uno o dos atacan a la vez**, el
   resto rodea y espera turno. Sin esto, cinco enemigos son cinco ataques
   simultáneos y el combate se vuelve injusto en vez de difícil.
2. **Anillo de posicionamiento** — los que esperan mantienen distancia y se
   reparten el círculo, en vez de amontonarse en tu cara.
3. **Telegrafía escalonada** — dos enemigos no pueden telegrafiar en el mismo
   frame. El director separa los avisos.
4. **Presupuesto de agresión** — un número por encuentro: cuántos ataques
   simultáneos permite. Es el dial de dificultad real, y es *uno solo*.

**Riesgo técnico ya anotado:** `Guardian.gd` asume suelo (`is_on_floor()`, gravedad
manual) y tiene su FSM metida en el cuerpo. Antes de escribir un director de
grupo hay que **extraer esa FSM**, o el director acabará hablando con un script que
mezcla IA, física y presentación.

---

#### 3.2 · Coloso mediano — torso escalable

Un tercer escalón entre el Guardián y el coloso. Su particularidad no es la vida ni
el daño: **su cuerpo se puede escalar**.

Por qué importa más de lo que parece: es el **puente pedagógico** hacia los
colosos. El jugador aprende a agarrarse a algo que se mueve y se sacude en un
enemigo que cabe en pantalla, antes de tener que hacerlo a sesenta metros del
suelo.

Implicaciones técnicas que ya condicionan el presente:
- Necesita `SurfaceContext` con un marco móvil de verdad. Es el primer consumidor
  real del sistema, antes que el coloso.
- Necesita `GripSurface` sobre huesos y una versión pequeña del `ShakeDirector`.
- Es el banco de pruebas natural del **Active Ragdoll** (`docs/03 §11`): cuerpo
  mediano, fallos baratos.
- La escalada ya acepta superficies de 45° a 110° y el cuerpo se inclina con la
  normal real (correcciones 2.02–2.04). Un torso es una superficie curva: **el
  domo de calibración del Gym es exactamente ese problema, quieto**.

**Orden sugerido:** este enemigo debería construirse ANTES del coloso #1, no
después. Lo que se aprenda aquí se paga solo en la Fase 4.

---

### 4. El lobo — montura viva **idea, no implementar**

Un **lobo** que el jugador pueda montar y controlar para cruzar distancia. La
variante mecánica queda descartada: un animal vivo aporta algo que un vehículo no
—compañía— y este juego va de estar solo en un sitio enorme. Un lobo que te espera
es una decisión narrativa además de una mecánica.

**No hay código, ni estado, ni escena**, y no debe haberlos hasta que la Fase 3
esté cerrada.

Lo que sí conviene saber ya, porque condiciona decisiones del presente:

- **La arquitectura lo aguanta sin tocarla.** Una montura es un `SurfaceContext`
  con marco móvil —exactamente el mismo problema que el coloso y que el enemigo
  mediano—, más un grupo de estados nuevo (`Mounted`) colgando de la FSM. No pide
  ni herencia nueva ni un segundo controlador.
- **El riesgo no es montar, es desmontar.** Saltar de una montura en movimiento
  tiene que heredar su velocidad, y ese es el mismo camino de código que
  `SurfaceContext.arrastrar()` ya recorre para el suelo móvil. Si ese camino está
  bien hecho para el coloso, la montura sale casi gratis.
- **Orden correcto:** después del coloso mediano. Construir la montura antes
  significaría estrenar el marco móvil en un sistema donde además hay que diseñar
  controles nuevos, que es hacer dos cosas difíciles a la vez.
- **Lo que un lobo pide y un vehículo no:** que se comporte cuando NO lo montas.
  Seguirte, esperarte, perderte de vista. Ese comportamiento es la mitad del
  trabajo y no tiene nada que ver con montar.

No añadir `MountPoint`, `RiderComponent` ni ganchos "por si acaso": un hueco vacío
en la arquitectura envejece peor que un hueco inexistente.

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
