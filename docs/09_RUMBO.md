# ROCK — El rumbo

> Escrito el 14/09/2026, a petición de *«siento que estoy haciendo muchas
> iteraciones pero sin un rumbo»*. No es una sensación: es diagnosticable, y
> abajo están los números.

---

## 1. Dónde estás, en números

| | |
|---|---|
| Código de juego (`src/`) | **16.113 líneas** |
| Código de bancos y tests (`tools/`) | **10.300 líneas** — el 64% de lo anterior |
| Documentación (`docs/` + `CLAUDE.md` + `project.md`) | **5.226 líneas** |
| Estados del jugador | **28** en escena |
| Comprobaciones automáticas | **~325**, en 11 suites |
| Commits | **73** en dos meses |
| **Niveles del juego** | **1** — `Main.tscn`, que es el Gym + el Circuito + la Arena |
| **Colosos** | **0** |
| **Minutos de juego que alguien podría jugar** | **0** |

Fases 0, 1, 2 y 3: cerradas. **Fase 4 —el *vertical slice*— va por 1 de 7
piezas** (existe `WeakPoint`; no existen `ColossusController`, `GripSurface`,
`ColossusPhase`, `ShakeDirector`, `ClimbBrace` ni `FramingDirector`). El
`ColossusTestRoom` que `CLAUDE.md` anuncia en su propia sección de estructura
**no existe**.

---

## 2. La contradicción central

**Tus propios documentos describen un juego distinto del que hay en el repo.**
No es un matiz de redacción; son cuatro afirmaciones que hoy son falsas:

| Lo que dice el doc | Lo que hay |
|---|---|
| `CLAUDE.md`, línea 8: *«Verbos del jugador: … **espada**, lanza, lazo, **arco**»* | La espada se retiró entera en el 4.00. El arco no ha existido nunca. Hay **una patada**. |
| `00_VISION.md`: *«No tiene inventario ni crafteo»* | **46 MB** de un sistema de inventario en C++ dentro de `addons/` |
| `00_VISION.md`: *«El contenido real son los colosos»* | Cero colosos. Cero niveles. La única escena es el gimnasio. |
| `04_ROADMAP.md`: *«FASE 4 — el vertical slice»* | 1 de 7 piezas, y la primera de la lista (`ColossusTestRoom`) sin empezar |

Un documento que lleva meses mintiendo deja de ser una referencia y pasa a ser
decoración. Y cuando la referencia no manda, cada sesión decide su propio rumbo
— que es exactamente el síntoma.

---

## 3. Por qué se siente sin rumbo

Tres causas, y ninguna es falta de trabajo.

**3.1. La puerta de la Fase 1 se pasó hace meses y se siguió puliendo.**
`00_VISION.md` escribe el criterio: *«Si la Fase 1 no es divertida sin combate,
el proyecto no avanza. Esto no es negociable.»* Es divertida. Se pasó. Y desde
entonces se han hecho ~40 commits más de movimiento.

**3.2. Los números del moveset se calibran contra el gimnasio, y el gimnasio lo
inventaste tú para calibrarlos.** Es un bucle cerrado:

- `cuerda_rango` = 19 m **porque las anclas del Gym están a 13–18 m**.
- `hueco` del circuito = 26 m **porque es lo que cruza la patada**.
- La patada cruza 4.5 m **porque `patada_duracion` × `patada_velocidad`**.

Ninguno de esos tres números lo ha pedido un nivel. Un nivel es lo único que
puede decir «esto es demasiado corto» sin que la respuesta sea otra opinión.

**3.3. Un tercio del sistema de tests protege cosas que no están en la visión.**
De las ~325 comprobaciones, **100** son de `TestJam`, `TestEnjambre` y
`TestMundoVivo`. La palabra «música» no aparece en `00_VISION.md`.

---

## 4. Qué se queda — y es mucho

Nada de lo de abajo es una crítica al trabajo. **El movimiento es bueno de
verdad**, y se nota que está medido:

- **El núcleo de locomoción**: `SurfaceContext`, `LocomotionMotor`, la FSM
  jerárquica. Es la parte más sólida del proyecto y la que menos hay que tocar.
- **La cuerda, la patada y la cadena entre las dos.** Ahí está la identidad del
  juego, y es lo único que un jugador recordaría.
- **La disciplina de banco**: escribir la medida antes del arreglo y exigir fila
  de control. Ha cazado una docena de bugs que un test funcional no veía. **Se
  queda entera** — lo que cambia es a qué se apunta.
- **El screenshot test y la paleta.** Baratos y han salvado el proyecto dos veces.
- **Los 31 archivos de estado.** Son muchos, pero cada uno es corto y está
  aislado; el coste de mantenerlos es bajo y el de refactorizarlos, alto. No se
  tocan.

---

## 5. Qué se quita

Por orden de cuánto devuelve por lo que cuesta.

### 5.1. El inventario en C++ — **borrar hoy**

46 MB de GDExtension para una característica que tu propia visión **prohíbe por
escrito**. No se usa en ninguna línea del juego. Es la decisión más fácil del
documento.

### 5.2. La estación de jam y la hoja de notas — **congelar**

| | líneas |
|---|---|
| `src/world/EstacionJam.gd` | 1.049 |
| `src/ui/PanelJam.gd` | 408 |
| `tools/test_jam.gd` + `tools/jam.gd` | 785 |
| **Total** | **~2.240**, más 42 comprobaciones |

Está bien hecho y no es este juego. Es un juego social a lo *Sky* metido dentro
de un clon de *Shadow of the Colossus*. **Congelar, no borrar**: sacarlo del Gym
y dejarlo en su banco, marcado como módulo aparcado. El día que exista un pueblo
o un santuario, se descongela en una tarde.

### 5.3. El enjambre, la bandada y las luciérnagas — **mitad y mitad**

| | líneas | veredicto |
|---|---|---|
| `src/generative/` (Kuramoto) | 964 | **congelar** — es un modelo, no un verbo |
| `Bandada` + `Luciernagas` | 781 | **queda**, sirven a P3 (silencio y escala) |
| `Pasto` (hierba interactiva) | 485 | **queda**, es la mitad del look |
| `tools/test_enjambre` + `test_mundo_vivo` + bancos | 1.517 | **recortar a la mitad** |

La bandada y la hierba **sí** están en la dirección de arte. El modelo de
Kuramoto con histéresis, marcapasos y parámetro de orden es investigación
preciosa que hoy mueve catorce pájaros.

### 5.4. La lanza, a la mitad — **recortar**

Siete estados para un arma que tú mismo dijiste que no usabas. Después del 4.00
perdió la cuerda, y `CLAUDE.md` reconoce que empuñarla **ya no cambia cómo
pegas**: o sea que **Tab es un botón que no hace nada**.

- **Se queda**: tirar, clavarse, ser plataforma, **quedarse flotando como diana
  de pogo** (que es su único uso probado) y volver.
- **Se va**: `SpearWielded` y la tecla Tab. Un botón que no cambia nada es peor
  que no tenerlo: enseña que los botones de este juego no significan nada.

### 5.5. La cámara cinematográfica escrita y sin cablear — **decidir**

`CameraTuning.gd`, `PhantomDirector.gd` y `PhantomRig.tscn` llevan desde el 3.03
escritos y sin conectar (651 líneas en `src/camera/`). O se cablea cuando el
coloso lo pida —que es cuando hace falta de verdad, para encuadrar algo enorme—
o se borra. Lo que no puede seguir es «escrito por si acaso».

### 5.6. Los tres plugins sin integrar

`phantom_camera`, `cyclops_level_builder` y `dialogic`: desactivados pero
presentes. `cyclops` **modifica escenas al abrirlas** y ya rompió el entorno una
vez. Si el blockout del coloso se va a hacer por código —que es lo que hace este
proyecto—, `cyclops` sobra.

---

## 6. Qué cambia de método

**6.1. `CLAUDE.md` está convirtiéndose en un changelog de 750 líneas.** Las 31
reglas duras son oro y hay que mantenerlas. La historia de cada parche —3.08,
3.12, 3.13, 3.15, 3.16, 4.00, 4.02— no: eso es `05_TABLERO.md`. Cada cambio hoy
cuesta actualizar un documento que nadie puede leer entero.

**6.2. Los bancos se subordinan al nivel.** `MedirPatada`, `MedirCadena` y
`Moveset.tscn` contestan «¿se siente bien esto?». La pregunta que hace falta
ahora es **«¿se puede subir al coloso?»**, y esa se contesta con un coloso.

**6.3. Una regla para parar la deriva:**

> **No entra un verbo nuevo hasta que exista el coloso #1.**
> Toda idea se juzga contra una sola pregunta: *¿esto ayuda a subirse al coloso?*
> Si la respuesta es «no, pero molaría», va a `project.md` y se queda ahí.

---

## 7. El objetivo

**UN COLOSO. UNA RUTA. CINCO MINUTOS.**

La Fase 4 del roadmap pide tres fases, dos puntos débiles, muerte cinematográfica
y música dinámica, en 4–6 semanas. **Por eso no ha empezado nunca.** Recórtala
hasta lo más pequeño que siga siendo un *juego*:

### Definición de terminado

Alguien que no conoce el juego se planta delante, y **sin que le expliques nada**:

1. Ve una silueta enorme contra la bruma y camina hacia ella.
2. Se engancha con la **Z** a un ancla de su cuerpo y sube con el arco.
3. Pierde el agarre una vez porque el coloso **se sacude**, y lo vuelve a
   intentar.
4. Llega a la joroba, ve **la única cosa saturada en pantalla** y la patea.
5. El coloso cae.

Y al terminar dice *«qué grande era»*. Eso es el hito, y está copiado de tu
propio roadmap.

### Lo que NO lleva el coloso #1

Se corta a propósito, y cada corte tiene su motivo:

- **No camina.** Un coloso quieto que se sacude ya valida `SurfaceContext` sobre
  superficie móvil, que es la pieza técnica de riesgo. Que además se desplace es
  otro problema y puede esperar.
- **Una sola fase.** Las tres fases son contenido, no mecánica.
- **Un solo punto débil.**
- **Sin muerte cinematográfica, sin música dinámica.** Eso es la Fase 5.
- **Sin bestiario nuevo.** Los seis enemigos que hay sobran para lo que viene.

### El orden, y el primero importa

1. **`ColossusTestRoom`** — una plataforma que se traslada, rota y **sacude**.
   Es la primera línea de la Fase 4 en tu roadmap y la que no se ha escrito. Sin
   esto, todo lo demás se construye sobre una suposición: que la FSM del jugador
   aguanta un suelo que se mueve. **La regla dura #19 ya avisa de que ese terreno
   es traicionero** — montarse encima movía al jugador dos veces y costó dos
   rondas encontrarlo, con `velocity` marcando 0.00 mientras el cuerpo se
   desplazaba metros.
2. **Un coloso de cajas grises**: torso, brazo, hombro, joroba. Blockout por
   código, como el Gym. Todavía sin anatomía.
3. **La ruta**: anclas en su cuerpo, salientes agarrables, un hueco que pide
   patada. **Aquí es donde los números del moveset dejan de ser circulares.**
4. **La sacudida** (`ShakeDirector`) y aguantarla (`ClimbBrace`).
5. **El punto débil** y el final.

### La prueba de que el rumbo funciona

Cuando exista el paso 3, **`cuerda_rango` dejará de valer 19 m porque las anclas
del Gym están a 18**. Valdrá lo que el cuerpo del coloso pida. Ese día el
proyecto habrá dejado de girar sobre sí mismo.

---

## 8. Lo que yo haría el lunes

En este orden, y nada más hasta terminarlo:

1. Borrar `addons/inventory-system` (una línea, 46 MB, cero riesgo).
2. Quitar la estación de jam del Gym y marcarla como congelada.
3. Quitar `SpearWielded` y la tecla Tab.
4. Escribir `tools/ColossusTestRoom.tscn`: una plataforma que se traslada, rota y
   sacude, con el jugador encima y el panel puesto.
5. No tocar un solo número del moveset hasta que el paso 4 esté en verde.
