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
| **`lanza = mundo · daga = carne`, con matiz** — la daga se clava en enemigos, y la lanza tambien **en los agarrables**: atraviesa lo que no se puede zarandear. Asi se llega a dos presas con dos armas, sin una segunda daga | `TestEnemigos` · `TestLanza` |
| **UNA daga, no dos** — dos armas iguales con el mismo boton obligaban a llevar la cuenta de cual estaba donde, y eso no es una decision: es contabilidad | `TestLanza` |
| **EL ZARANDEO NO FUNCIONABA** — `intentar_cuerda()` abortaba entero si la LANZA no estaba fuera, asi que agarrar con la daga exigia haber tirado la lanza antes. El guardia de la lanza ahora solo manda sobre los verbos de la lanza | `TestEnemigos`, chequeo por el camino real |
| **AGUA por derivadas analiticas** — suma de senos en octavas, normal desde ∂h/∂x y ∂h/∂z. Sin simulacion. El primer shader propio del proyecto | `TestVisual`, toma `agua` |
| **Tres tomas del visual dejan de derivar** — el cordon (ya estaba), la postura agachada y el agua. Una referencia no puede fotografiar una animacion en curso | 3 pasadas a 0.000%, 0.035% |

**SISTEMA GENERATIVO** (`src/generative/`), aparte del juego y con su propio banco:

| | Verificado por |
|---|---|
| **El enjambre de Kuramoto** — N agentes, cada uno con su frecuencia propia. Reparto de fases por ángulo áureo: uniformes es un equilibrio del modelo y no sincroniza nunca | `TestEnjambre` |
| **La inestabilidad, en UNA regla** — el orden realimenta el acoplamiento con histéresis. Medido: 9.6 s al orden, 19.6 al caos, 7.3 al orden otra vez. Respira y no termina | `TestEnjambre`, 4 chequeos |
| **El control sin acoplamiento** — con las frecuencias a intervalos iguales, las fases se realinean solas cada 2π/δω y r sube casi a 1 sin haber sincronizado nada. Lo que separa la coincidencia del enganche es cuanto DURA: 1.2 s de racha contra 16.2 | `TestEnjambre`, 2 chequeos |
| **Perturbar y resincronizar** — r 0.954 → 0.783 → 0.984. La sordera alarga la vuelta: desvío acumulado 0.353 contra 0.185 sin ella | `TestEnjambre`, 5 chequeos |
| **NO HAY ROTACIÓN** — ni un frame, y si alguien le mete una a mano se la quita | `TestEnjambre`, 2 chequeos |
| **Las Criaturas de Tela** — color, opacidad, escala, recorrido y pitch, todos colgando del MISMO número. El desvío desatura: al unísono el enjambre es un solo color latiendo | `TestEnjambre` · `TestVisual`, toma `enjambre` |
| **La cola procedural** — persecución en cadena con restricción de distancia, retraso independiente del framerate | `TestEnjambre`, 3 chequeos |
| **La cola nacía PLEGADA** — todos los nudos en el mismo punto deja la dirección de la restricción sin significado y la cadena se doblaba en zigzag: 1.17 m de cuerda ocupando 0.125. Nace estirada | `TestEnjambre` |
| **Una criatura que desliza por UN eje adelanta a su propia cola** — va y vuelve por su rastro: 119 frames detrás contra 138 delante. Con un segundo eje al doble de frecuencia el recorrido es un ocho | `TestEnjambre`, con signo (regla dura #22) |

El **jefe** Kuramoto sigue solo **documentado** en `project.md §5`. Lo implementado
es el sistema audiovisual, no un boss: comparten el modelo y nada más.

### Parche 3.16 — pulido de la jam: notas, agentes y modo escritura

| Qué | Cómo se comprueba |
|---|---|
| **Escribir no es jugar** — abrir la hoja desconecta al jugador: ni mueve, ni ataca, ni gira la cámara. No es una pausa; el mundo sigue corriendo porque la hoja se abre para escuchar | `TestJam`, 4 chequeos por el camino real (`panel.abrir()`) · `TestFase2`, 2 más con el cuerpo |
| **Y se corta donde se LEE** — en el `InputBuffer`, que la regla #4 ya garantiza que es el único que habla con `Input`. Ahí se apagan de una vez movimiento, ataques, salto, lanza y cuerda | Regla dura #26 |
| **Sin pulsaciones fantasma** — el buffer se vacía al cortar: lo guardado justo antes de abrir se ejecutaría al cerrar | `TestJam` |
| **Las notas dejaban un CHASQUIDO** — ataque instantáneo es una discontinuidad, y con ocho puestos atacando cinco veces por segundo el corro sonaba a estática. 8 ms de rampa | A oído en `tools/Jam.tscn` |
| **Y las graves resuenan más** — como una cuerda larga. Sin eso los ocho registros se apagaban a la vez y el corro no tenía suelo | `decaimiento_grave` = 0.6: el bajo dura casi el doble que el agudo |
| **Los ocho se distinguen** — el TAMAÑO sale del registro, el COLOR del grado en la escala (el mismo que decide rombo o círculo en la rejilla), y el brillo queda libre para el golpe. Más instrumento delante: tres siluetas | `TestVisual` 14/14 sin tocar baselines: están demasiado lejos en las 14 tomas |
| **Los nombres de las notas** — solfeo con octava en cada tecla, y la nota raíz de cada músico como cabecera de columna. Sin nombres la rejilla es bonita y muda | En pantalla: SOL LA SI RE MI, la pentatónica de sol |
| **Compás y tono en vivo** — `cambiar_compas()` reescala el modelo entero con las potencias de `a_ritmo()` sobre el tuning que ya corre, sin devolver el corro al caos | `TestJam` 33/33 |

---

### Parche 3.15 — la estación de jam y su hoja de notas

| Qué | Cómo se comprueba |
|---|---|
| **Ocho puestos en corro que tocan juntos**, estilo *Sky*. Tercera manifestación del mismo Kuramoto —bandada, luciérnagas, esto— y la primera que consume el `pitch`/`amplitud` que `Enjambre` publicaba desde el 3.11 sin oyente | `TestJam`, 22 comprobaciones |
| **El instrumento es el PUESTO, no el agente** — el agente trae el ritmo, el puesto el registro. Sin eso el unísono sería una sola voz más fuerte, no un acorde | `TestJam` — 220 Hz el grave, 880 el agudo, dos octavas justas |
| **Pentatónica, y es la regla entera** — sin segundas menores ni tritonos, ocho voces sin director no pueden chocar. Por eso no hace falta un director | `TestJam` — 480 combinaciones de puesto y ciclo, **0 fuera de la escala** |
| **Y el registro va en GRADOS, no en semitonos** — repartir 24 semitonos entre ocho puestos da saltos de 3.43, y redondeando salen notas de fuera: sumar un grado bueno a un registro malo da una nota mala | Nació roja: **143 de 480** caían fuera |
| **Notas, no un zumbido** — el puesto golpea cuando su fase cruza una subdivisión del compás. La fase no modula un tono: ES el pulso | `TestJam` — 290 ataques en 30 s contra ~282 esperados |
| **Al unísono los ataques se JUNTAN** — 41 ms al vecino con r>0.82 contra 59 con r<0.40. Se aprieta un 30% y no un 90% **a propósito**: el acoplamiento se suelta en 0.86, así que el corro nunca cuadra del todo | `TestJam`, y costó tres métricas: contar racimos y contar compañía daban 1.43 vs 1.36 y 62% vs 52% — ciertos e inútiles |
| **Y los desviados cantan más flojo** — es lo que convierte el orden en volumen: disperso un murmullo, al unísono un acorde | `TestJam` — factor 0.44 el más desviado contra 0.97 el más centrado |
| **El jugador es el marcapasos** — te acercas y algunos te cogen el compás. Misma pieza que la escolta de la bandada | `TestJam` — 3 de 8, y 0 con el visitante a 400 m |
| **Y hicieron falta LAS DOS cosas** — bajar `A` al orden de la dispersión (a 1.1 enganchaban los ocho) **y** la `curiosidad`, porque el acoplamiento del grupo arrastra detrás a quien solo no podría | `TestJam` — curiosidad media 0.24 los que vienen contra 0.52 los que no |
| **Un solo altavoz, no ocho** — la estación es el instrumento; la mezcla ocurre antes. Síntesis por tabla de onda: ~2.900 vueltas de bucle por frame en vez de 5.900 `sin()` | `TestJam` — se monta sin tarjeta de sonido (driver Dummy) |
| **Y no lleva colisión** — tarima, taburetes y músicos son escenografía: un obstáculo en medio del Gym rompería las medidas de movimiento sin avisar | `TestFase1` 12/12 y `MedirMovimiento` sin cambios |
| **LA HOJA DE NOTAS** (`src/ui/PanelJam.gd`), con **E**. Rejilla de rombos y círculos dibujada con `_draw()`: teclado 5×3 que suena y no escribe, y hoja de **una columna por músico y una fila por paso** | `TestJam`, 7 chequeos |
| **El cabezal corre con la fase MEDIA del enjambre**, no con un temporizador propio. Cuanto más juntos van, mejor tocan lo escrito | `TestJam` — 6 ataques en 40 s contra ~6 esperados |
| **Con la hoja escrita callan los que no marcaste**, y borrarla los devuelve a improvisar | `TestJam` — 0 ataques ajenos en 40 s; 8 de 8 vuelven en 12 s |
| **Y son SIEMPRE los mismos los que te siguen** — `[0, 2, 4, 5, 7]` desde dos puntos de partida distintos | `TestJam`. Estuvo rebajado a "salen de la mitad curiosa" por un vistazo mal puesto: se miraba el enganche AL FINAL de la ventana y el acoplamiento respira |
| **El sitio se eligió midiendo** — barrido del suelo con consulta de caja. El hueco más grande caía en la ronda del `GuardianPatrulla`, que una consulta de formas no ve | Lo cantó la partida: el soft-lock lo tenía fijado al abrir la hoja |

---

### Parche 3.14 — control total del movimiento, y la cámara fuera del agua

| Qué | Cómo se comprueba |
|---|---|
| **Girar deja de costar lo que cuesta frenar.** `frenado_momentum` bajaba la tasa del vector entero, así que salir del surf cuesta abajo a 15.8 m/s eran **1.43 s de línea recta**. Ahora el momentum baja el OBJETIVO y el giro conserva `aceleracion_suelo` | Barrido de 144 ensayos por el Gym: **12 fallos → 5**, y el peor caso en suelo desaparece |
| **Y en el aire igual**, con número propio (`giro_aire`, 38 m/s²): por encima del techo el objetivo ES tu rapidez, o sea que esa llamada no acelera, gira | `MedirMovimiento`: la inversión en el aire pasa de *«aún avanzando»* a **invertida del todo** a 0.55 s |
| **Los siete números de locomoción, intactos** — arranque 1.22 s, frenada al soltar 0.28 s / 1.29 m, pivote 0.17 s / 0.65 m, salto parado 3.2 m/s | `MedirMovimiento`, antes y después |
| **La cámara ya no se mete en la piscina.** El brazo esquiva geometría pero una `ZonaAgua` es un `Area3D` y no existe para él: mirando hacia arriba la lente bajaba hasta **4.21 m bajo el agua**, y la superficie tiene `cull_disabled`, así que tapaba la pantalla | Barrido de pitch: −0.54 / −2.40 / −4.21 m → **+0.54 / +0.53 / +0.52** |
| **Buceando NO se toca** — ahí la cámara tiene que estar debajo. La condición es nadar en superficie, no estar mojado | Mismo barrido: con la lente ya despejada el alza es cero |
| **La hierba se leía como paja sobre el césped** — nacía en `musgo_medio` sobre un suelo `pasto_medio` y moría en `hierba_highlight`: medio círculo cromático en 78 cm. Ahora nace del color del suelo | `TestVisual`, tomas `claro` y `gym_general` |
| **Y el parche terminaba en LÍNEA RECTA** — se leía como una alfombra. Densidad 11 → 34 briznas/m² y un borde que se apaga con ruido (`borde_difuso`, `borde_ruido`) | Ídem |
| **El agua hervía** — `escala` 1.5 daba una onda de 48 cm, casi cuarenta rizos en un vaso de 18 m: de lejos eso no es agua, es aliasing. 0.95, y el brillo ensanchado (`rugosidad` 0.16) | `TestVisual`, toma `agua` |
| **El rendimiento NO era el problema.** A/B en la misma pasada, sin vsync, 1280×720: con SSAO, glow, niebla, MSAA 4×, sombras suaves altas y el claro entero puestos, **1.44 ms — 695 fps**. Los 26–76 fps que se ven son los primeros segundos compilando shaders | `tools/_diag_perf` (temporal), con una fila de CONTROL que vuelve a encenderlo todo |
| **Las 14 tomas rotas eran ediciones del EDITOR**, no código: `caliza_sol` a lavanda, `oro_palido` de oro a rosa, `energia_solar` 1.15 → 1.871, `domo_radio` 8 → 11 | Con `default_palette.tres` y `Main.tscn` en su sitio: **11 de 14 vuelven a 0.000%** |

---

### Parche 3.13 — el marcapasos

| Qué | Cómo se comprueba |
|---|---|
| **Kuramoto con FORZAMIENTO externo** — un oscilador de fuera que tira de quien tenga cerca. `Enjambre.pedir_tiron()`, y caduca cada frame como `pedir_postura()` | `TestEnjambre` sigue en 31/31: sin tirón el modelo es idéntico |
| **La bandada te ESCOLTA** — unas cuantas dejan el circuito y te rodean en círculo. No hay estado ni transición: se mezclan las posiciones de dos curvas con un peso | `TestMundoVivo`, 5 chequeos |
| **"Algunas, no todas" sale de la ECUACIÓN** — engancha quien cumple `\|ωᵢ−Ω\| ≤ A`, y eso lo decide la frecuencia propia, que es la personalidad | `TestMundoVivo` — toda escolta cumple la condición |
| **Y de un SEGUNDO rasgo fijo, la `curiosidad`** — sin él, el acoplamiento del grupo arrastraba al resto detrás de las primeras y a los 30 s escoltaban **las 14**. Con él: **7 de 14, estable**, y siempre las mismas | `TestMundoVivo` — curiosidad media 0.19 las que vienen contra 0.72 las que no |
| **Quien se va deja de contar para el grupo** — el orden pesa por `1 − enganche`; si no, la bandada persigue a sus propias escoltas | `TestEnjambre` 31/31 sin cambios |
| **Y vuelven solas** — la llamada se mide al TERRITORIO, no a cada criatura: una escolta orbita a 5 m de ti por definición y su distancia nunca sube. Medido: el jugador se iba a 90 m y dos se iban con él para siempre | `TestMundoVivo`, 2 chequeos |
| **Luciérnagas = ENJAMBRE.** La nube se aprieta al sincronizarse: mismo `r` que decide el parpadeo, otro canal. Y cruzarlas las desordena, con techo de cadencia | `TestMundoVivo`, 3 chequeos |
| **La bandada era INVISIBLE** — §4.6 pide blanco `#F2F0E6` y la niebla es `#EFE8D8`: el mismo color. Contra cielo abierto la silueta tiene que ser más oscura que el fondo | `TestVisual`, tomas `gym_general` y `claro` |
| **La toma del claro no convergía** — el enjambre corre desde que entra en el árbol, así que `avanzar(11)` sumaba once segundos exactos sobre un punto de partida distinto cada vez. Se reinicia antes de congelar | `TestVisual` — 0.000% en dos pasadas |

---

### Parche 3.12 — dos bugs de movimiento y el mundo vivo

| Qué | Cómo se comprueba |
|---|---|
| **La Z estaba MUERTA estando adherido** — `intentar_cuerda()` vivía en `Grounded` y en `Airborne` y no en `Attached`, que es justo donde viven los cuatro verbos de cuerda. Escalando o colgado de un canto no había ni balanceo, ni zip, ni resortera, ni zarandeo, y el síntoma era silencio | `TestLanza`, 2 chequeos por el camino de entrada real |
| **`maneja_cuerda()`**, el guardia que hacía falta a la vez: sin él la resortera se rearmaba cada frame y no disparaba nunca | `TestLanza` — los 12 chequeos de resortera siguen verdes |
| **El surf te PEGABA a la pared** — el agarre automático es para quien camina contra el muro, no para quien llega a 15 m/s. Medido: 4 de las 5 adherencias automáticas de 60 s de juego salían directamente de `Surf` | `TestFase2`, 2 chequeos: no engancha solo, y con `GRAB` sí |
| **El surf en sí sale limpio** — ocho caminos de salida medidos en pista libre, los ocho obedeciendo la dirección nueva, con el alabeo a 0.0° y la cápsula de pie | medido con la matriz de salidas del 3.12 |
| **EL CLARO, plantado en el Gym** — hierba, luciérnagas y bandada en (9, 0, −13), a 18 m del spawn. El sitio se eligió mirando: el primer intento caía a un metro de las rampas de calibración y una luciérnaga a dos metros de la cámara tapaba media toma (8.47% de diferencia) | `TestVisual` — `gym_general`, `postura_*` y `claro` regeneradas mirando el diff; las otras diez intactas |
| **Hierba en MultiMesh con viento** — doblado cuadrático, `UV.y = 0` en la punta, ruido FBM y color por instancia. Lo que `07_SHADERS.md §4` ya tenía diseñado | `TestMundoVivo` · `TestVisual`, toma `claro` |
| **El viento es un CAMPO, no un parámetro por parche** — `shader_globals` + `TIME` y posición de mundo: dos parches separados por medio mapa sacan el mismo valor sin coordinarse | `TestMundoVivo` — los cinco globales registrados |
| **La hierba se aplasta y deja rastro** — doce huellas con su frescura; la 0 es el jugador en vivo, las once restantes se levantan solas | `TestMundoVivo`, 4 chequeos · `TestVisual` |
| **Bandada de criaturas de tela** — apretada cuando el enjambre se ordena, estirada cuando se deshace: 151° de arco contra 325° | `TestMundoVivo`, 4 chequeos |
| **Luciérnagas que parpadean juntas** — el destello es `pow(ciclo, 7)`, un pulso y no un brillo: ciclo medio 0.52 contra brillo medio 0.23 | `TestMundoVivo`, 4 chequeos |
| **Kuramoto en CAMPO MEDIO** — `(1/N)Σ sin(θⱼ−θᵢ) ≡ r·sin(ψ−θᵢ)`, identidad exacta: O(N²) → O(N). Es lo que permite 180 luciérnagas con el modelo ya medido | `TestMundoVivo` — diferencia < 1e-5 en 300 pasos · `TestEnjambre` sigue dando 9.6 / 19.6 / 7.3 s |
| **`a_ritmo()` escalaba mal** — `k_subida` y `k_bajada` son 1/s², no 1/s. A mitad de reloj el sistema sincronizaba en 8.6 s en vez de 19.2, ANTES que el normal | `TestMundoVivo` — razón 2.00 |
| **Al servidor de render no se le pregunta el estado del juego** (regla dura #23) — `MultiMesh.get_instance_transform()` da la identidad en headless | `TestMundoVivo` — `perturbar_cerca` acierta la criatura pedida |

---

## PRUEBAS — el estado de verdad

| Suite | |
|---|---|
| `TestFase1` — FSM | **12/12** |
| `TestFase2` — combate, postura, agua, escalada, paredes, combo pesado, adherencia | **137/137** |
| `TestEnemigos` — cono, carga, patrulla, arquetipos, zarandeo | **36/36** |
| `TestLanza` — lanza, resortera, la daga y la cuerda estando adherido | **53/53** |
| `TestMenu` | **4/4** |
| `TestEnjambre` — modelo en seco y manifestación en vivo | **31/31** |
| `TestMundoVivo` — hierba, luciérnagas, bandada y escolta | **27/27** |
| `TestVisual` — 14 tomas, con el agua, el enjambre y el claro | **14/14** |
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

*Revisado y MEDIDO contra el código el 3.13. Lo que había aquí estaba desfasado en
media docena de líneas: decía que no existía ni un shader propio (hay cuatro), que
la perspectiva aérea estaba en 0 (está en 0.78) y que la hierba no existía.*

**Deuda del roadmap (P0):**
- **Audio mínimo.** `content/audio/` sigue **vacío**, contado: no hay un solo
  sample en el proyecto, y golpes, pasos y aterrizajes siguen mudos. Lo que SÍ
  suena desde el 3.15 es la estación de jam, y suena **sintetizado** —tabla de
  onda, sin ficheros—, así que cierra el encargo del enjambre pero no este punto.
  Sigue siendo el multiplicador de juice más barato que queda: el enjambre publica `pitch` y `amplitud` por
  agente y por frame esperando a que alguien los toque.
- **Escala unificada de screen shake** — medido: **40 llamadas a
  `EventBus.camara_shake.emit()`** con valores a mano repartidas por el código.
- Sincronizar los números del roadmap con la realidad.

**El look (P1).** Ver `docs/07_SHADERS.md`. Lo que YA está, medido:
`perspectiva_aerea = 0.78` (paso 1 de §5, hecho), cuatro shaders propios
—`agua`, `hierba`, `bandada`, `luciernaga`—, hierba en MultiMesh con viento e
interacción, y fauna atmosférica. Lo que falta, por rentabilidad:
- Probar tonemap **AGX** contra el `FILMIC` actual. Un número.
- **`banded_surface.gdshader`** — el shader de tres bandas con sombra tintada. Es
  EL look de ilustración y **no existe**: `find` devuelve cero.
- Quad de pantalla: desaturación por profundidad + overlay de pinceladas a 12 fps.
- LUT de corrección de color.

**Contenido:**
- **Fase 4: EL COLOSO.** Es el contenido real del juego y no está empezado. Las
  piezas sí: `WeakPoint`, `ColosoMediano` escalable, `SurfaceContext` con marco
  móvil, la lanza como asidero. Falta el bicho de verdad y su pelea.
- **Ataques aéreos** — evaluados y con dirección propuesta en `project.md §8`.
  Medido: cinco de los seis son ataques de VIAJE, y `dive_attack`/`dive_pesado`
  tienen la hitbox viva **120 frames**. **Pendiente de una decisión de diseño**,
  no de código: son seis `.tres`.
- **Remate aéreo 3+1** — pesado en el aire: tres golpes que persiguen recalculando
  cada frame y un cuarto que estampa. **Desbloqueado**: el apuntado en 3D ya
  existe. Ojo con `velocidad_maxima = 22`, que recorta en silencio, y con
  `cd_dive`, que estrangula la cadena.
- `SquadDirector` — grupos de enemigos. No existe.
- IA acuática.

**Herramientas y entorno:**
- **La respuesta Blender → Godot / MCP**, pendiente desde el parche 3.10 y lo
  único de aquella lista que no se contestó.
- La cámara cinematográfica: `CameraTuning`, `PhantomDirector` y `PhantomRig.tscn`
  están escritos y **sin cablear**. El obstáculo está medido: Phantom se queda con
  el `transform` de la cámara y todo el movimiento deduce la dirección de
  `player.camara()`, así que cablearlo tal cual pone 18 tests en rojo.
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
