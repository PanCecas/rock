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

### 5. BOSS: el sincronizador — modelo de Kuramoto **idea, no implementar**

Un jefe que proyecta **dos copias de sí mismo**. Tres cuerpos en pantalla, uno
solo real. Cuando el real se mueve o ataca, las copias repiten lo mismo **con
desfase**, y el sistema entero tiende a sincronizarse solo.

#### Qué es el modelo de Kuramoto, y por qué no es decoración

Es el modelo estándar de sincronización espontánea: N osciladores, cada uno con
una fase `θᵢ` y una frecuencia propia `ωᵢ`, acoplados entre sí.

```
dθᵢ/dt = ωᵢ + (K/N) · Σⱼ sin(θⱼ − θᵢ)
```

Por debajo de un acoplamiento crítico `Kc` cada uno va a su ritmo. Por encima,
**se enganchan solos** y acaban latiendo como uno. Lo que mide cuánto lo están es
el *parámetro de orden*:

```
r = | (1/N) · Σⱼ e^{iθⱼ} |          r = 0 disperso · r = 1 al unísono
```

Importa porque esas dos fórmulas **son las reglas del combate**, no una excusa
temática. `r` es la amenaza y `K` es la dificultad, y las dos son un solo número
que ya significa algo por sí mismo.

#### La mecánica que sale de ahí

- **`r` es el peligro.** Con `r → 1` los tres golpean en el mismo instante y el
  ataque es imparable. Con `r → 0` llegan escalonados y hay hueco entre golpe y
  golpe. El jugador no lucha contra puntos de vida: **lucha por mantener `r`
  bajo**.
- **Pegar desfasa.** Un impacto perturba la fase del cuerpo que lo recibe. Esa es
  la acción principal, y por eso el jefe no se mata a base de daño: se
  *desordena*.
- **`K` sube durante la pelea.** Cuanto más avanza, más fuerte tiran de volver a
  engancharse. Un solo número controla toda la curva de dificultad, y el
  jugador la siente como "cada vez cuesta más mantenerlos separados".

#### Cómo se sabe cuál es el real — y por qué esto es lo bueno

**Que la respuesta salga de las propias matemáticas, no de un truco visual.**

Las copias están esclavizadas al real: es el marcapasos. Entonces

- golpear una **copia** la desfasa a ella, y vuelve a engancharse enseguida;
- golpear al **real** desfasa a los tres, porque las otras dos están acopladas
  a él.

O sea: **pega a uno y mira a los otros dos.** Si el sistema entero se tambalea,
ese era el bueno. No hace falta un brillo distinto, ni una barra, ni un tell
animado. La identificación es una *lectura del sistema*, que es exactamente la
habilidad que pide el resto del juego.

#### Legibilidad: la fase se ve

Tres cuerpos atacando a la vez es un caos ilegible salvo que la fase se lea de un
vistazo. La vía barata y consistente con lo que ya hay: **fase → color**, igual
que `Enemigo._actualizar_color()` ya usa el color para decir el estado.
Sincronizados laten del mismo color a la vez; desincronizados son tres colores
corridos. `r` se ve sin números.

Ojo con la regla dura #8: los tonos azul y rojo están reservados y el croma de
los acentos tiene mínimo. La rueda de fase tendrá que vivir dentro de lo que
`Palette.validar()` permita, o ser el caso justificado que la rompe a propósito.

#### Riesgos, dichos ahora y no cuando duela

- **Tres hitboxes vivas a la vez no se pueden leer.** Casi seguro solo uno puede
  tener hitbox activa mientras están desincronizados; sincronizados es cuando el
  golpe triple existe, y por eso da miedo.
- **Un ataque en área lo rompe.** Si se puede pegar a los tres de golpe, la
  identificación sobra y la mecánica se cae. Las copias tienen que ser inmunes,
  o castigar al que pega a ciegas.
- **Kuramoto es tiempo continuo.** En un juego es integrar una ODE por frame:
  trivial. Lo que no es trivial es elegir `ωᵢ` y `K` para que el resultado sea
  *jugable* y no un péndulo caótico. Eso se calibra en el Gym con capsulas
  grises, como todo lo demás.

#### Qué NO hace falta construir antes

Nada nuevo. La FSM de enemigos extraída en la 3.03 ya deja que cada enemigo
declare sus estados en su escena, y una fase es un `float`. El jefe es un
`Enemigo` con tres cuerpos y un director que integra las fases.

Dónde encaja: **después** del coloso mediano y probablemente junto a la Fase 4.
Es un jefe de *ritmo*, no de escalada, así que complementa al coloso en vez de
competir con él — pero pide que el combate base esté cerrado, porque toda su
gracia depende de que pegar y esquivar ya se sientan bien.

### 6. Moveset de la lanza — **etapa 5 de la Fase 3**

Con la lanza equipada, el clic derecho cambia el moveset entero (`docs/03 §4.1`).
El eje que lo ordena, dicho por el usuario:

> *pesados lentos, y rápidos y precisos*

Dos familias, y la lanza es el arma que mejor las separa porque **su alcance es
su identidad**:

- **Pesados y lentos.** Barrido en área (`spear_sweep`), mucho windup que se ve
  venir, y sitio para que el enemigo reaccione. Es el que paga el alcance con
  compromiso: si fallas, estás vendido.
- **Rápidos y precisos.** Estocadas cortas, recuperación breve, poco daño y
  mucho control. Es el que mantiene la distancia sin cerrarla.

Por qué esta pareja y no la de la espada: con la espada el reparto es *corto y
seguro* contra *largo y arriesgado*, y ahí el alcance no cambia. Con la lanza el
alcance ya es largo siempre, así que lo que se negocia es **precisión contra
área**, que es una decisión distinta y da un moveset que no se siente el mismo
con otro modelo encima.

Y `spear_vault` (`docs/03 §4.1`): si hay una lanza clavada cerca, te impulsas con
ella como con una pértiga. Plataformeo disfrazado de arma.

**Regla dura del cambio:** es un INTERCAMBIO de moveset, no un remapeo. Sin lanza,
el kit a mano sigue intacto y las 130 comprobaciones de la Fase 2 siguen verdes.
Si se ponen rojas, es que se remapeó.

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
