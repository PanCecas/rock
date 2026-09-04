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

### 7. Clavar en carne y ZARANDEAR — **propuesta, sin implementar**

> *"los dos proyectiles que tengo, la daga y la lanza, no se quedan acoplados a
> los enemigos. Quiero crear una mecánica que se pueda agarrar a los enemigos más
> pequeños y poder zarandearlos, y que hagan daño."*

#### Lo que hay hoy, y por qué está así

**La lanza atraviesa a los enemigos a propósito.** No es un olvido: es la
invariante nº 1 de `SpearInFlight`, tiene comentario y tiene test
(*"atravesar es herir sin pararse; si te frena, es un muro y no un enemigo"*).
La asimetría —**los cuerpos sí, la piedra no**— es lo que convierte la lanza en
herramienta de posición y no solo en un arma.

Así que esto no es "arreglar que no se clava". Es **añadirle un tercer resultado
al impacto**, y hay que decidir cuál se lleva cada cosa o se pierde lo que ya
funciona.

#### El reparto propuesto

| Contra qué | Qué pasa | Por qué |
|---|---|---|
| Piedra y mundo | **Se clava.** Plataforma, ancla de cuerda, pértiga. | Es la Fase 3 entera. Intacta. |
| Coloso y enemigo grande | **Atraviesa e hiere**, como hoy. | Zarandear algo de siete metros no es creíble, y el punto débil ya tiene su verbo. |
| Enemigo **pequeño** | **Se clava en él** y queda atado por la cuerda. | La mecánica nueva. |

Quién es "pequeño" **lo declara el enemigo**, no lo adivina la lanza — mismo
patrón que `WeakPoint.llave` y que `AttackData.etiquetas`, y por la misma razón:
con una propiedad en el enemigo, añadir un bicho agarrable es escribirle un `true`
en su `.tscn`; con un `if enemigo is Embestidor` dentro de la lanza, cada enemigo
nuevo obliga a abrir el arma.

Un `@export var agarrable: bool` en `Enemigo` (falso por defecto) más un
`@export var masa: float`, que además sirve para escalar cuánto te frena mientras
lo llevas colgando.

#### La física: NO es un joint, y eso está confirmado

Lo tentador es `PinJoint3D` o `Generic6DOFJoint3D` entre el jugador y el enemigo.
**No funciona, y ya lo sabemos por escrito:** los joints de Godot restringen
dinámicas de `RigidBody3D`, y el jugador es un `CharacterBody3D` —cinemático—.
`StateSpearSwing` lo tiene documentado desde la etapa 4 de la Fase 3, y la
comunidad dice lo mismo: `CharacterBody3D` *ignora las fuerzas entrantes y empuja
a los demás fuera de su camino*; moverlo como rígido *pelea contra el solver*.

La pieza correcta **ya existe en este proyecto**: `Ragdoll`. Un enemigo muerto ya
se convierte en un `RigidBody3D` que sale despedido. Un enemigo **agarrado** es lo
mismo pero vivo, y el montaje sale de dos cosas escritas:

```
jugador (CharacterBody3D, cinemático)   ← el ANCLA
   │  restricción analítica de distancia   ← la de StateSpearSwing, invertida
   ▼
enemigo (RigidBody3D vivo)              ← la MASA
```

En `StateSpearSwing` el ancla es la lanza clavada y la masa es el jugador. Aquí se
cambian los papeles y **la misma matemática vale**: si la separación pasa del
largo de cuerda, se corrige la posición del enemigo y se le quita la componente
radial de la velocidad. La tangencial se conserva entera, y eso es lo que hace que
gire en vez de frenarse.

Dos avisos que salen de lo ya medido:

- **Gravedad propia y simétrica** (regla dura #16). Un péndulo con la gravedad
  asimétrica del juego gana altura sola: medido, 6 m por pasada.
- **El enemigo colgando es un `RigidBody3D` en la capa `RAGDOLL`**, que el jugador
  no pisa. Si entrara en `WORLD` sería una plataforma móvil y `move_and_slide`
  lo acarrearía —regla dura #19, el bug que costó dos rondas encontrar—.

#### El daño

Dos fuentes, y las dos ya tienen precedente:

1. **Por velocidad de impacto.** Cuando el enemigo colgando choca contra algo, el
   daño escala con su rapidez. Es exactamente `escalar_por_inercia()`, que ya
   existe para la carga en viaje.
2. **Al soltarlo**, sale despedido con la velocidad tangencial que llevara. Eso
   es `Ragdoll.lanzar()` con la velocidad ya calculada.

Y el enemigo zarandeado **hiere a los demás**: un cuerpo a 15 m/s es un arma. Su
hitbox pasa a equipo 0 mientras lo llevas, que es una línea.

#### Riesgos, dichos ahora

- **Se come al enemigo como amenaza.** Si agarrar es fácil y seguro, todo combate
  contra bichos pequeños se reduce a agarrar-zarandear. La respuesta es coste:
  stamina mientras lo sostienes, y que el enemigo agarrado **siga golpeando** si
  lo dejas cerca.
- **Enredo con la resortera.** Con lanza y anclaje puestos, la Z da resortera. Si
  la lanza está clavada en un bicho que se mueve, la resortera tiene un anclaje
  móvil y su energía deja de conservarse. Lo más limpio: un enemigo agarrado
  **no** cuenta como punto de resortera.
- **La cámara.** Un cuerpo girando alrededor tuyo tapa la pantalla. El look-ahead
  y el FOV dinámico de la 3.09 ayudan, pero habría que probarlo.

---

### 7bis. La daga necesita su propio verbo — **propuesta**

> *"siento que debería tener un gimmick diferente la daga, ya que la verdad se
> siente muy parecida a la lanza."*

Tiene razón, y se puede decir con precisión **por qué**: hoy el anclaje se
diferencia de la lanza por lo que **NO** hace —no daña, no es plataforma, no se
empuña—. Es la lanza **menos** cosas. Un objeto definido por sus carencias no
tiene identidad, tiene huecos.

Y el gesto es idéntico: apuntas, tiras, se clava. Los dos.

#### La propuesta: **la lanza es del MUNDO, la daga es de la CARNE**

Un dominio para cada una, y de ahí sale todo lo demás solo:

| | Lanza | Daga |
|---|---|---|
| Se clava en | **piedra y mundo** | **enemigos** |
| Atraviesa | los cuerpos | la piedra no la para: rebota |
| Es plataforma | sí | no |
| Vuelve sola | **no** — la dejas donde la pusiste | **sí** |
| Ritmo | decisión que **mantienes** | gesto que **repites** |

Eso resuelve las tres cosas a la vez:

1. **La daga deja de ser una lanza descafeinada.** Es la herramienta de combate;
   la lanza es la de traversal. Cada una hace lo que la otra no puede.
2. **El retorno automático pasa a significar algo.** El usuario ya dijo que le
   gusta que la daga vuelva sola y la lanza no. Con dominios separados eso deja
   de ser un detalle y pasa a ser la regla: lo que se **repite** vuelve solo, lo
   que se **coloca** se queda. La asimetría se justifica.
3. **Es exactamente la pieza que falta para zarandear enemigos** (§7). La daga
   clavada en un bicho pequeño ES la cuerda de la que tiras.

#### Por qué NO al revés

Se podría hacer que la lanza se clave en enemigos y la daga en el mundo. Sería
peor: la lanza ya es plataforma, ancla de balanceo y pértiga —tiene tres verbos
de mundo— y quitarle el mundo la vacía. Y una daga-plataforma no se cree.

#### Lo que cuesta

Menos de lo que parece, porque la mitad ya está escrita:

- `Anclaje.capas_clavado` pasa a incluir `ENEMY` y a **excluir** `WORLD`. Es un
  flag de escena.
- La lanza ya atraviesa cuerpos: eso **no se toca**. Es la invariante nº 1 de
  `SpearInFlight`.
- El rebote de la daga contra piedra: el rayo de `_volar()` ya detecta el
  impacto; en vez de clavarse, invierte `_dir` y sigue. Cinco líneas.
- Colgar del enemigo reusa `Ragdoll` + la restricción de `StateSpearSwing` con
  los papeles invertidos, que es lo que §7 ya describe.

#### DECIDIDO: la daga es un PAR, no una

El usuario quiere agarrar **dos enemigos distintos** y estamparlos entre sí. Con
una sola daga es imposible, así que son **dos**.

Y no contradice la escasez de la lanza: ese argumento es **específico de ella**.
Colocar la lanza es un compromiso; una daga que vuelve sola es un **ritmo**. Dos
dagas pequeñas son creíbles donde dos lanzas no lo serían, y el reparto queda más
claro que antes:

> **La lanza es UNA porque colocarla es una decisión.
> Las dagas son DOS porque tirarlas es un compás.**

#### Las tres formas de rematar, y en qué orden

El usuario planteó tres y preguntó si aplicarlas todas. Sí, pero por este orden:

1. **Voltear y estampar contra el suelo.** El núcleo, y funciona con UN enemigo.
   Es un **verbo**: tú controlas el giro y eliges el momento. Reusa la
   restricción analítica, `Ragdoll` y `escalar_por_inercia()`, las tres escritas.
2. **Estamparlos uno contra otro (estilo Zac).** Necesita las dos dagas. El daño
   escala con la velocidad **relativa** entre los dos cuerpos, no con la absoluta:
   dos cuerpos que viajan juntos a 20 m/s no se hacen nada.
3. **La secuencia de torbellino.** Va la última, y no por dificultad: las otras
   dos son verbos y **esta es una secuencia** —el jugador pulsa y mira—. Depende
   del rig, que no existe (regla dura #7), y se salta las restricciones
   analíticas sobre las que está montado todo el juego.

   **Pero encaja perfecta en otro sitio:** es un **REMATE**. La señal ya existe
   —`WeakPoint.remate_disponible`, descrita como *"un evento de guion, no un
   impacto más"*— y está esperando exactamente esto. Ahí es donde va.

#### Lo que hay que decidir antes

**La resortera necesita DOS puntos fijos.** Si la daga solo se clava en carne, la
resortera pasa a pedir *un punto de mundo y un enemigo*, y un enemigo se mueve —
la energía deja de conservarse. Dos salidas:

- **A.** La daga se clava en las dos cosas, pero solo **en carne** engancha para
  zarandear. La resortera sigue funcionando igual. Más simple, menos limpio.
- **B.** Dominios estrictos, y la resortera pasa a necesitar **la lanza clavada +
  un enemigo anclado**: tirachinas contra un bicho que forcejea. Más arriesgado y
  mucho más interesante.

**Recomendación: A para empezar**, porque no rompe las 12 comprobaciones de
resortera que ya están en verde, y B queda como evolución cuando zarandear ya se
sienta bien.

---

### 8. Los ataques aéreos — **evaluación, sin implementar**

> *"hay que cambiar los ataques aéreos por unos que tengan más sentido, ya que
> parece más como un juego de Attack on Titan."*

#### Por qué se lee así — está en los números, no en la impresión

El kit aéreo entero son **ataques de viaje**: todos te convierten en proyectil.

| Ataque | Frames activos | Avance | Qué es de verdad |
|---|---|---|---|
| `dive_attack` | **120** | 0 | Hitbox viva **2 segundos enteros** de trayectoria |
| `dive_pesado` | **120** | 0 | Igual, con `lanzamiento = 20` |
| `aereo_1` | 4 | **8.0** | Empujón hacia delante |
| `aereo_2` | 5 | **9.0** | Empujón mayor |
| `lanza_aereo` | 3 | estocada a **13 m/s** | Lanza-misil |
| `lanza_giro` | 7 | 1.2 | El único que se planta |

Cinco de seis te mueven. Un ataque con la hitbox viva 120 frames no es un golpe:
es **un trayecto que hace daño**, que es literalmente el verbo del equipo de
maniobras. Y como la resortera es una referencia declarada de *Attack on Titan*,
el conjunto refuerza esa lectura en vez de contrastarla.

#### Contra qué se compara

Los pilares dicen *Shadow of the Colossus* con movilidad de *Tears of the
Kingdom*. En SotC el aire no es un sitio donde se pelea: es un sitio donde se
**aguanta**. Lo que uno hace en el aire es agarrarse, esperar el momento y clavar.

#### La dirección propuesta

Cambiar el eje de **atravesar** a **comprometerse con un punto**:

- **El clavado ligero** se queda: rebotar en cabezas es plataformeo y encaja.
- **El clavado pesado** deja de ser una diagonal de 25 m/s y pasa a ser un
  **descenso plantado**: caes sobre el objetivo y te quedas. Contra un coloso eso
  es lo que tiene que pasar —clavar y no salir despedido—.
- **`aereo_1`/`aereo_2`** pierden el avance de 8–9 y ganan **hangtime**: golpes
  que te sostienen en el aire en vez de lanzarte. Ya existe el mecanismo
  (`player.hangtime`, que usa el rebote del clavado pesado).
- **La ventana activa de 120 frames se parte**: anticipación corta, activo real
  de 6–10 frames al tocar, y recuperación. Un golpe se lee cuando tiene principio
  y final.

**Nada de esto es código.** Los seis son `.tres` con `frames_activo`, `avance`,
`estocada` y `lanzamiento`. El cambio se prueba moviendo números y jugando, que
es exactamente para lo que existe F5.

**Antes de tocarlo hace falta una decisión tuya:** el kit aéreo actual es
coherente con la resortera. Si los aéreos se plantan y la resortera te dispara a
33 m/s, hay que decidir si eso es un contraste bueno —te mueves volando, pegas
parado— o una incoherencia. Yo apostaría por el contraste, pero es tu llamada.

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
