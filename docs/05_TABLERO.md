# ROCK — Tablero de estado

Registro vivo de en qué punto está cada cosa. **Esta es la fuente de verdad**: si
una entrada de aquí y un comentario del código se contradicen, gana lo que diga
el código y se corrige el tablero en el mismo commit.

**Se actualiza en el MISMO commit que el cambio.** Un tablero que se pone al día
"cuando toque" miente exactamente igual que la tabla de controles que obligó a
escribir el menú del juego: no se nota que está mal hasta que alguien lo cree.

Cinco estados, y la diferencia entre ellos importa:

| Estado | Qué significa exactamente |
|---|---|
| **LISTO** | Hecho **y verificado por un test**. Sin test que lo cubra no es listo, es "creo que funciona". |
| **EN PROCESO** | Hay código escrito ahora mismo. Como mucho dos o tres cosas a la vez. |
| **BUGUEADO** | Funciona mal **y la causa está medida**. Un bug sin causa medida va a EN PROCESO hasta que se mida. |
| **BLOQUEADO** | No se puede empezar hasta que otra cosa termine, y esa cosa está nombrada. |
| **FALTA** | Ni empezado. Sin nada que lo impida salvo el orden. |

---

## LISTO

**Fases 0, 1 y 2 cerradas.**

| | Verificado por |
|---|---|
| Traversal: FSM jerárquica de 5 grupos y 27 estados | `TestFase1` 12/12 |
| `SurfaceContext` + `LocomotionMotor`, escalada 45–110° | `TestFase1` · `TestVisual` |
| Combate: `AttackData`, hitbox por consulta, hitstop, parry, poise, ragdoll | `TestFase2` 129/129 |
| **FSM de enemigos extraída** (P0.1) — `Guardian.gd` de 372 a ~100 líneas | `TestEnemigos` 17/17 |
| Embestidor · Volador · ColosoMediano | `TestEnemigos` 17/17 |
| Los dos clavados diferenciados: ligero rebota, pesado levanta | `TestFase2` |
| Screenshot test, 10 tomas | `TestVisual` 10/10 |
| Mallas de los tres enemigos (collider ≠ visual) | `TestVisual` · toma `corral_enemigos` |
| ProtonScatter compilando en 4.7 | arranque limpio |
| **Portabilidad**: Player, Volador, Guardián y Coloso arrancan en escena desnuda | medido, ver §Notas |
| **Apuntado en 3D** — un enemigo encima ya se puede fijar | `TestEnemigos` |
| **El arrastre del coloso** — de 3.11 m de acarreo a **0.00**. Se aplicaba dos veces | `TestEnemigos`, 4 invariantes |
| **La altura del volador** — medida sobre el suelo, no sobre tu cabeza | `TestEnemigos` |
| **`TestFase2` deja de ser intermitente** — fallaba 1 de cada 4 | 11 pasadas seguidas en verde |
| **Menú de controles (Escape)** — primera UI del proyecto, lee el InputMap en vivo | `TestMenu` 4/4 |
| **Fase 3 completa** — lanza, cordón, balanceo, moveset, pértiga, `WeakPoint` | `TestLanza` · `TestEnemigos` |
| **El frente de los enemigos estaba INVERTIDO** — `encarar()` apuntaba `+basis.z` mientras los cinco lectores leían `-basis.z`. El embestidor cargaba huyendo | `TestEnemigos`, 2 chequeos nuevos |
| **Combo pesado** — giro de dos impactos + remate descendente, encadenado con el botón pesado | `TestFase2`, 5 chequeos |
| **La resortera** — dos cuerdas, tensión elástica y disparo de 33 m/s medidos | `TestLanza`, 12 chequeos |
| **EL JITTER DEL PERSONAJE** — `physics_interpolation` estaba apagada con la física a 60 Hz y la pantalla a 144. **63.5% de los frames dibujaban al personaje congelado; ahora 0.0%** | `MedirJitter`, A/B en la misma pasada |
| **Cámara con papel protagónico** — FOV asimétrico (abre rápido, cierra lento), look-ahead con componente vertical y sacudida por ruido en `h_offset`/`v_offset` | `TestVisual` |
| **Patrulla** — los enemigos rondan en vez de esperar clavados. Opcional: sin `ruta` nada cambia | `TestEnemigos`, 3 chequeos |
| **Arquetipo a distancia** — sin línea de visión NO dispara, y se desplaza buscando ángulo | `TestEnemigos`, 3 chequeos |
| **Navegación opcional** (`NavigationAgent3D`) con fallback a línea recta | `TestEnemigos` |
| **El anclaje vuelve volando**, con el mismo arco que la lanza | `TestLanza` |
| **MODO DEBUG VISUAL (F7)** — gizmos 3D: la hitbox que se consulta con su arco, el cono de vision y la ruta de cada enemigo, la linea de vision, las cuerdas con su radio y la normal del suelo coloreada por su clasificacion | `TestVisual` 11/11 con los gizmos apagados |
| **La lanza y el anclaje clavados VIAJAN con el cuerpo** — se quedaban flotando cuando el coloso se movia | `TestEnemigos` |
| **La Z con la lanza GUARDADA te lanzaba al spawn** — el guardia preguntaba `en_mano()`, cierto solo en `Wielded`, y `Holstered` ni actualizaba su posición | `TestLanza`, 2 chequeos |
| **El botón de la lanza no hacía NADA al arrancar** — mismo fallo: guardada caía en «recuperar», que se niega. La partida empieza guardada | `TestLanza` |
| **El anclaje perseguía para siempre a un jugador que se aleja** — el retorno interpolaba contra una distancia recalculada cada frame | `TestLanza` |
| **ZARANDEAR ENEMIGOS (opción 2)** — daga en carne, giro con el stick, estampido con daño en área escalado por la velocidad. El balanceo con los papeles invertidos: tú eres el ancla, el enemigo la masa | `TestEnemigos`, 6 chequeos |
| **Las dagas son DOS** — `PlayerController.dagas` como lista, no dos campos. Un botón las reparte: tira mientras queda alguna, recoge cuando no | `TestLanza`, 2 chequeos |
| **`lanza = mundo · daga = carne`** — la daga se clava en enemigos; la lanza los sigue atravesando. Un enemigo agarrado NO cuenta como punto de resortera | `TestEnemigos` · `TestLanza` 12/12 de resortera intactas |

Jefe Kuramoto **documentado** en `project.md §5`. Documentar es el entregable; no
se implementa.

---

## PRUEBAS — el estado de verdad

| Suite | |
|---|---|
| `TestFase1` — FSM | **12/12** |
| `TestFase2` — combate, postura, agua, escalada, paredes, combo pesado | **135/135** |
| `TestEnemigos` — cono, carga, patrulla, arquetipos, zarandeo | **35/35** |
| `TestLanza` — lanza, resortera y las dos dagas | **52/52** |
| `TestMenu` | **4/4** |
| `TestVisual` | **11/11** |
| humo | 0 infracciones |

---

## EN PROCESO

*Vacío.* **La Fase 3 está cerrada.**

---

## BUGUEADO

Ordenados por lo que más estorba para jugar.

*Vacio.* Los tres que quedaban se cerraron:

- **Los verbos de pared se pisaban** y **faltaba el guardia de salto en el aire**:
  arreglados, con invariante en `TestFase2`.
- **`direccion_frontal()` devuelve +Z** — **NO era un bug.** `orientar_a()` escribe
  `visual.rotation.y = atan2(d.x, d.z)`, lo que hace que `visual.basis.z` **sea**
  la direccion encarada, y el marcador `Frente` del visual esta en `z = +0.3`. La
  convencion del JUGADOR es que el visual mira a +Z y las tres piezas son
  coherentes. Lo que se vio montando el screenshot test fue un fallo del test:
  colocaba al jugador sin orientarlo.
- **`Enemigo.encarar()` apuntaba el lado equivocado** (3.08) — **este SÍ era un
  bug**, y el que el usuario describió como *"la lógica está invertida y se siente
  poco natural"*. `atan2(d.x, d.z)` deja `+basis.z` mirando al objetivo, medido, y
  los **cinco** lectores del bando enemigo leen `-basis.z` como el morro —igual
  que los cuatro marcadores `Marca`, todos en `z` negativa—. Resultado: el
  embestidor te detectaba solo por la espalda y **cargaba huyendo**; el guardián
  empujaba al jugador *hacia* sí mismo; el volador "huía" acercándose. Un signo.

  Los dos convenios conviven **a propósito** y no hay que "arreglar" ninguno: el
  jugador mira a **+Z** en su nodo `Visual`, los enemigos miran a **−Z** en su
  cuerpo. Cada uno es coherente consigo mismo; lo que no puede haber es un tercer
  criterio dentro de uno de los dos, que es exactamente lo que había. Por eso
  `Enemigo.frente()` existe y es el único sitio con el signo escrito.

---

## BLOQUEADO

| Qué | Bloqueado por |
|---|---|
| **Cámara cinematográfica** | `CameraTuning` / `PhantomDirector` / `PhantomRig` están escritos pero sin cablear. Phantom se queda con el `transform` y todo el movimiento deduce la dirección de `player.camara()`: cablearlo tal cual son **18 tests en rojo**. |
| **Inventario BotW** | Sigue siendo la capa de UI que no existe. El menú de controles abrió `src/ui/` y fijó las costumbres —se construye por código, los colores salen de la `Palette`—, pero un inventario paginado con arrastrar y soltar pide navegación y gestión de foco, que es otro orden de magnitud. |

---

## FALTA

**Deuda del roadmap (P0):**
- Escala unificada de screen shake — hoy sale de ~15 sitios con valores a mano.
- Audio mínimo — `content/audio/` está vacío. El multiplicador de juice más barato.
- Sincronizar los números del roadmap con la realidad.

**El look (P1) — nada de esto existe todavía.** Ver `docs/07_SHADERS.md`, que
tiene la API verificada y las fuentes. Ordenado por rentabilidad:
- **`fog_aerial_perspective ≈ 0.7`** — dos números, y es lo que más cambia la
  imagen. Hoy está sin poner, o sea en 0.
- Probar tonemap **AGX** contra el FILMIC actual.
- **`banded_surface.gdshader`** — el shader de tres bandas con sombra tintada.
  `find` devuelve **cero** shaders propios en el proyecto.
- Quad de pantalla: desaturación por profundidad + overlay de pinceladas a 12 fps.
- Hierba en MultiMesh con viento.

**Contenido:**
- **Ataques aéreos** — evaluados y con dirección propuesta en `project.md §8`.
  Medido: cinco de los seis son ataques de VIAJE, y `dive_attack`/`dive_pesado`
  tienen la hitbox viva **120 frames**. De ahí sale la lectura de *Attack on
  Titan*. **Pendiente de una decisión de diseño**, no de código: son seis `.tres`.
- **La daga necesita su propio verbo** — propuesta en `project.md §7bis`. Hoy se
  define por lo que NO hace (ni daña, ni es plataforma, ni se empuña): es la
  lanza **menos** cosas, y un objeto definido por sus carencias no tiene
  identidad. Propuesta: **lanza = mundo, daga = carne.**
- **Clavar en carne y zarandear** — propuesta completa en `project.md §7`. La
  lanza atraviesa a los enemigos **a propósito** (invariante de `SpearInFlight`,
  con test), así que esto añade un tercer resultado al impacto, no arregla un
  fallo. La física sale de piezas que ya existen: `Ragdoll` + la restricción
  analítica de `StateSpearSwing`, con los papeles invertidos.
- **Remate aéreo 3+1** — pesado en el aire: tres golpes que persiguen
  recalculando cada frame y un cuarto que estampa. **Desbloqueado**: el apuntado
  en 3D ya existe. Ojo con `velocidad_maxima = 22`, que recorta en silencio, y
  con `cd_dive`, que estrangula la cadena.
- `SquadDirector` — grupos de enemigos.
- IA acuática.
- Fase 4: el coloso.

**Herramientas y entorno:**
- Plantilla de nivel vacía + comprobador de geometría importada.
- Guía de uso de ProtonScatter.

---

## APARCADO A PROPÓSITO

No es que falte: es que **se decidió no hacerlo todavía**, y el motivo está
escrito. Distinguirlo de FALTA importa, porque una idea aparcada que se cuela en
la lista de pendientes acaba construyéndose sin que nadie decida construirla.

| Idea | Dónde | Por qué espera |
|---|---|---|
| **El lobo** — montura viva | `project.md §4` | Va **después** del coloso mediano. Construir la montura antes significaría estrenar el marco móvil a la vez que se diseñan controles nuevos: dos cosas difíciles al mismo tiempo. Y la mitad del trabajo de un lobo no es montarlo, es cómo se comporta cuando **no** lo montas — seguirte, esperarte, perderte de vista. |
| **Jefe Kuramoto** — el sincronizador | `project.md §5` | Es un jefe de *ritmo*, no de escalada. Toda su gracia depende de que pegar y esquivar ya se sientan bien, así que pide el combate base cerrado. |

Regla que aplica a los dos: **no se añaden ganchos "por si acaso"**. Un hueco
vacío en la arquitectura envejece peor que un hueco inexistente.

---

## Notas

**Los PR se acumulan.** #2, #3 y #4 siguen abiertos sin mergear. Cada rama
parte de la anterior, así que cuanto más se tarde, más caro sale.

**GitHub Desktop hace stash del trabajo sin avisar.** Ha pasado dos veces
(`stash@{1}` en la 2.01, `stash@{0}` en la 3.04) y las dos veces el árbol
apareció limpio con el trabajo escondido. Si algo "desapareció",
`git stash list` antes que nada.

**Portabilidad, medida y no supuesta.** `Player.tscn` en una escena con solo
suelo y cámara: aterriza, se desplaza 4.11 m con input y llega a `Move`. Volador,
Guardián y Coloso arrancan igual. Funciona porque todo el acoplamiento va por
autoloads, por `class_name` estáticos y por Resources — nada apunta a
`Main.tscn`— y `camara()` es `get_viewport().get_camera_3d()`.
Las tres condiciones para geometría nueva: **collider en capa 1**, escalable en
**capa 4**, y nada más empinado de **45°** es caminable.
