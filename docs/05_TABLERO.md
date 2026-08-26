# ROCK — Tablero de estado

Registro vivo de en qué punto está cada cosa. **Esta es la fuente de verdad**: si
una entrada de aquí y un comentario del código se contradicen, gana lo que diga
el código y se corrige el tablero en el mismo commit.

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
| **FSM de enemigos extraída** (P0.1) — `Guardian.gd` de 372 a ~100 líneas | `TestEnemigos` 9/9 |
| Embestidor · Volador · ColosoMediano | `TestEnemigos` 9/9 |
| Los dos clavados diferenciados: ligero rebota, pesado levanta | `TestFase2` |
| Screenshot test, 10 tomas | `TestVisual` 10/10 |
| Mallas de los tres enemigos (collider ≠ visual) | `TestVisual` · toma `corral_enemigos` |
| ProtonScatter compilando en 4.7 | arranque limpio |
| **Portabilidad**: Player, Volador, Guardián y Coloso arrancan en escena desnuda | medido, ver §Notas |

Jefe Kuramoto **documentado** en `project.md §5`. Documentar es el entregable; no
se implementa.

---

## EN PROCESO

- **Parche 3.05.** Remate aéreo y entorno modular. Rama `Ver3.05`.

---

## BUGUEADO

Ordenados por lo que más estorba para jugar.

### 1 · El coloso te arrastra — **crítico**
Estar encima o pegado al ColosoMediano te lanza girando por el escenario.

**Causa medida:** es acarreo de plataforma móvil, no una fuerza. El jugador se
desplazó **3.11 m con `velocity = 0.00` en todo momento**: `move_and_slide` lo
mueve por posición, sin pasar por la velocidad, porque `_marcar_escalable()`
pone al coloso en la **capa 1 (WORLD)**.

La magnitud es ω·r y sale de `Enemigo.encarar()`, que gira hasta a **360°/s**.
Con radio 2.2 m eso son **13.8 m/s en el borde** — más rápido que correr (9.4).
Y la velocidad angular que hace falta para seguir a un objetivo a distancia `d`
es ≈ v/d: cuanto más cerca estás, más rápido gira. Por eso empeora al acercarte
y al subirte del todo.

### 2 · El volador es inalcanzable
`punto_de_vuelo()` devuelve `objetivo.global_position + UP * altura_vuelo`, o
sea **anclado a TU Y**: saltas y sube contigo. Está definido como inalcanzable.
Fijado como referencia visual en la toma `volador_alcance`.

### 3 · El apuntado aplasta la Y
`TargetingSystem._buscar()` hace `hacia.y = 0.0` → un enemigo justo encima da
vector cero y cae en `continue`: **es inseleccionable**. Y
`direccion_a_objetivo()` devuelve un vector plano, así que no se puede apuntar
hacia arriba. Bloquea el remate aéreo.

### 4 · Los verbos de pared se pisan
La adherencia automática mide la **dirección de input deseada**
(`dot(-normal) ≥ 0.65`, o sea ≤ 49.5°); el wall-run mide la **dirección real de
movimiento** (≥ 55°). Dos vectores distintos que con momentum divergen: **las
dos condiciones pueden ser ciertas a la vez** y decide un temporizador de 0.35 s.
Además queda una zona muerta entre 49.5° y 55°, y el wall-slide exige
`get_vertical() < 0.0`, así que subiendo no ocurre nada.

### 5 · `GroupAirborne` no comprueba `maneja_salto()`
Solo lo hace `GroupGrounded`. Es el corolario de la regla dura #13 escrito en
`CLAUDE.md` y aun así incumplido: en el aire, una hoja no puede reclamar el
salto. En su lugar hay `fsm.actual.name != &"WallRun"`, que es el
`if state == "x"` que prohíbe la regla #2.

### 6 · `direccion_frontal()` devuelve +Z
Devuelve `visual.global_basis.z`, no `-z`. Cazado montando el screenshot test:
un jugador colocado sin girar sondea **en dirección contraria** a la pared que
tiene delante.

---

## BLOQUEADO

| Qué | Bloqueado por |
|---|---|
| **Cámara cinematográfica** | `CameraTuning` / `PhantomDirector` / `PhantomRig` están escritos pero sin cablear. Phantom se queda con el `transform` y todo el movimiento deduce la dirección de `player.camara()`: cablearlo tal cual son **18 tests en rojo**. |
| **Remate aéreo 3+1** | El bug #3. Sin apuntado en 3D no puede perseguir a un enemigo que acaba de salir volando. |
| **Inventario BotW** | `src/ui/` está vacío. No es una funcionalidad, es la primera capa de UI del proyecto. |

---

## FALTA

**Deuda del roadmap (P0):**
- Escala unificada de screen shake — hoy sale de ~15 sitios con valores a mano.
- Audio mínimo — `content/audio/` está vacío. El multiplicador de juice más barato.
- Sincronizar los números del roadmap con la realidad.

**Contenido:**
- Fase 3: lanza y lazo.
- `SquadDirector` — grupos de enemigos.
- IA acuática.
- Fase 4: el coloso.

**Herramientas y entorno:**
- Plantilla de nivel vacía + comprobador de geometría importada.
- Guía de uso de ProtonScatter.

**Ideas documentadas, NO implementar:** jefe Kuramoto (`project.md §5`),
el lobo (`project.md §4`).

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
