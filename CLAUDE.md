# ROCK — Contexto del proyecto

Juego 3D en **Godot 4.7** (Forward+, Jolt Physics, D3D12). Español para docs y comentarios.

## Qué es
Un clon de *Shadow of the Colossus* con la movilidad de un plataformero 3D moderno
(*Tears of the Kingdom*) y combate cuerpo a cuerpo estilizado. Verbos del jugador:
correr, saltar, doble salto, dash, planear, deslizarse, wall-run, agarrarse de bordes,
escalar, parry, esquiva, espada, **lanza equipable y lanzable**, lazo/gancho, arco.
El contenido real son los **colosos**: bosses gigantes que funcionan como niveles de
plataformas en movimiento.

## Documentación — leer antes de tocar nada
| Doc | Contiene |
|---|---|
| `project.md` | **Ideas futuras sin implementar.** Aros, parkour, enemigo mediano. |
| `docs/00_VISION.md` | Pilares. Toda decisión se justifica contra ellos. |
| `docs/01_DIRECCION_ARTE.md` | **Paleta con hex exactos, regla 60/30/10, shaders, post.** |
| `docs/02_PIPELINE_PERSONAJES_ANIM.md` | Rig, ~205 clips por tiers, concept art, export. |
| `docs/03_ARQUITECTURA_MECANICAS.md` | **Arquitectura completa. La referencia técnica.** |
| `docs/04_ROADMAP.md` | Fases, hitos, orden de construcción. |
| `docs/05_TABLERO.md` | **Qué está listo, en proceso, bugueado y pendiente.** Se actualiza en el MISMO commit que el cambio. |
| `docs/07_SHADERS.md` | **Como se construye el look**: shader de bandas con sombra tintada, niebla, post-proceso, hierba. Con la API verificada y fuentes. |
| `docs/06_INTEGRACION_3D.md` | **Llevar todo esto a modelos, animaciones y escenarios de Blender.** Export, AnimationTree, IK, navmesh. **Se usa DESPUES de cerrar los tweaks.** |
| `docs/08_MANUAL.md` | **RECETARIO: como se USA cada sistema.** Donde esta, que hay que escribir para meterlo en una escena, que numeros tocar y por donde entran tus modelos de Blender. Es el doc que se abre para trabajar; los demas dicen por que. |

## Reglas duras del código
1. **Ningún número mágico en `.gd`.** Todo valor que se toque para "que se sienta bien" vive en
   `PlayerTuning.tres`, `AttackData.tres` o `Palette.tres`.
2. **La FSM manda.** Prohibido `if state == "x"` fuera de la máquina de estados. Cada estado es
   un `Node` con `enter/exit/physics_update/handle_input` y declara sus transiciones.
3. **`SurfaceContext` siempre.** El jugador nunca asume `Vector3.UP` ni un mundo quieto. El
   suelo estático es solo el caso `frame == null`. Nunca se reparenta el jugador a un coloso.
4. **Input solo por `InputBuffer`.** Nada de `Input.is_action_just_pressed()` en los estados.
5. **Hitstop congela `AnimationTree`, nunca `Engine.time_scale`.**
6. **Composición sobre herencia.** Nodos-componente, no jerarquías de clases.
7. **El feel se prueba con cápsulas grises** antes de que exista una sola animación.
8. **Croma (medido en Okhsl, no HSV):** neutros ≤ 0.40 · vegetación ≤ 0.66 ·
   acentos ≥ 0.65. Y los tonos 200–265° (azul) y 335–25° (rojo) están **reservados**:
   ningún material de entorno entra ahí por encima de croma 0.35. Lo valida
   `Palette.validar()`.
9. Colores solo desde `Palette.tres`. Nunca un hex escrito a mano en un shader o material.
10. **Exports a nodos siempre como `NodePath` + `get_node_or_null()`**, nunca
	`@export var x: Node3D`. Los exports tipados a Node no se resuelven al
	instanciar la escena y dejan la referencia en null sin avisar.
11. **Todos los saltos pasan por `PlayerController.consumir_salto()`** y piden
	`fsm.cambiar(..., true)`: casi siempre se salta estando ya en `Jump`, y sin
	reentrada la FSM se traga la pulsacion en silencio.
12. **La velocidad horizontal se limita en un solo sitio** (`_limitar_velocidad()`,
	justo antes de `move_and_slide`). Nunca en un estado.
13. **Los grupos corren ANTES que las hojas y les roban el input.** Si una hoja
	tiene su version propia de una accion compartida, tiene que reclamarla con
	`maneja_ataques()` o `maneja_salto()`, **y el guardia tiene que existir en
	TODOS los grupos**, no solo en el de suelo. Es el fallo que mas veces ha
	aparecido en este proyecto —cadena de combos, ataques de surf, salto alto,
	DiveAttack— y siempre es silencioso: se ejecuta la accion generica y la
	especifica no llega a existir nunca.
	**Corolario:** ese guardia hace `return` en mitad de `shared_update`, asi que
	todo lo que quede DEBAJO deja de existir para las hojas que lo declaran. Por
	eso las preguntas de TERRENO —perder el suelo, pendiente, techo, agarre— van
	siempre ANTES que las de accion. Ahi vivio el "floating fall": salirse de una
	plataforma surfeando no cambiaba de estado nunca. Un guardia de INPUT no puede
	cancelar una transicion de TERRENO.
	**Y la misma regla al reves:** una ACCION COMPARTIDA tiene que estar en TODOS
	los grupos donde exista. `intentar_cuerda()` vivia en `Grounded` y en
	`Airborne` y no en `Attached`, asi que **escalando o colgado de un canto la Z
	no hacia absolutamente nada** —ni balanceo, ni zip, ni resortera, ni
	zarandeo—. Mismo sintoma de siempre: silencio. Y su guardia, `maneja_cuerda()`,
	tuvo que existir a la vez, porque los cuatro verbos de cuerda VIVEN en
	`Attached`: sin el, la resortera se rearmaba cada frame y no disparaba nunca.
14. **La postura la resuelve el controlador, no las transiciones.** Un estado
	PIDE altura con `pedir_postura()` cada frame; nadie la restaura al salir. La
	altura de la capsula solo la cambian dos cosas: que alguien la pida, o que no
	quepas de pie. **Detectar una pared, una pendiente o una superficie escalable
	NO es motivo para agacharse** — ese acoplamiento fue el bug del cambio brusco
	de altura junto a las rampas.
15. **Un solo numero clasifica las superficies** (`PlayerTuning.clasificar`):
	`<45° camina · 45–110° escala · >110° nada`.
	El wall-run pide ADEMAS `wallrun_angulo_min` (70°), pero eso no es una
	segunda clasificacion: es un requisito extra del verbo. Correr en horizontal
	por una ladera de 50° no es una mecanica, es un error. De ahi salen el sensor de suelo,
	el de pared, la escalada y el `floor_max_angle` del cuerpo. Dos criterios
	distintos para la misma rampa es como se llega a que sea "demasiado empinada
	para andar" y "demasiado tumbada para escalar" a la vez.
16. **La gravedad del juego es ASIMETRICA** (-38 cayendo, -22 subiendo) y eso es
	medio game feel gratis en un salto —flotas al subir, caes con peso—, pero
	**rompe cualquier cosa que tenga que conservar energia**. Un pendulo con
	gravedad asimetrica sube mas alto de lo que cayo: medido, el balanceo salia
	6 m por encima de donde empezaba. Todo lo que sea un sistema cerrado usa su
	propia gravedad simetrica, no `motor.aplicar_gravedad()`.
17. **La orientacion del visual la escribe UN solo sitio** (`PlayerController`).
	El nado y la escalada escriben pitch y roll; la logica de tierra solo escribe
	yaw. Todo estado que incline el cuerpo tiene que llamar a `enderezar()` al
	salir, o el personaje se queda torcido para siempre. Y se hace en la
	TRANSICION, nunca como guardia por frame: un reset cada frame se pelearia con
	el dash, el agachado y el planeo.
18. **EL SCREENSHOT TEST SE CORRE SIEMPRE.** No es opcional, no se salta "porque
	este cambio no toca lo visual", y no se da por bueno sin ejecutarlo. Los tres
	tests van juntos en cada entrega: funcional, de estados y **visual**.
	**Y no se hace trampa:** regenerar una baseline con `-- actualizar` para que
	pase es convertir el test en un sello de goma. Una referencia solo se
	regenera cuando el cambio visual era EL QUE SE BUSCABA, y solo despues de
	mirar el mapa de diff en `user://visual/` y comprobar que lo que ha cambiado
	es lo que tenia que cambiar. Si el diff muestra algo que no esperabas, eso no
	es una baseline vieja: es un bug.
19. **UN SOLO mecanismo mueve al jugador con una superficie movil, y es
	`SurfaceContext`.** El acarreo de `move_and_slide` esta acotado a `WORLD`
	(`platform_floor_layers` / `platform_wall_layers`), y un cuerpo solo arrastra
	si se declara en el grupo `marcos_moviles` —lista blanca, hoy vacia—. Los dos
	defaults de Godot son "todas las capas", asi que el coloso escalable acababa
	moviendo al jugador DOS VECES: una por el motor y otra por `arrastrar()`.
	Montarse encima era un caos y costo dos rondas encontrarlo, porque `velocity`
	marcaba 0.00 mientras el cuerpo se desplazaba metros.
20. **Prioridad en las paredes:** agarre > angulo. Mantener agarre SIEMPRE escala;
	sin agarre, **UN SOLO numero** decide —`player.angulo_contra_pared()`, entre tu
	avance y la normal— y `pared_umbral_frontal` lo parte en dos mitades sin hueco
	ni solape: de frente escalas o resbalas, rozando corres. Nunca por
	`pared.lado`: eso es del sensor, no del jugador.
	Estuvo roto de la misma forma que las superficies antes de la regla #15: la
	adherencia media el input DESEADO (49.5°) y el wall-run el movimiento REAL
	(55°). Dos vectores decidiendo lo mismo divergen con momentum, asi que las dos
	condiciones podian ser ciertas a la vez —"quiere hacer todo a la vez"— y entre
	49.5 y 55 no saltaba ninguna.
	**Y el agarre AUTOMATICO es para quien CAMINA contra el muro**, que es lo que
	su propio numero dice (`escalada_auto_tiempo`). Llegar a 15 m/s surfeando no es
	insistir, es chocar, y el codigo no distinguia las dos cosas: medido, 4 de las
	5 adherencias automaticas de 60 s de juego salian directamente de `Surf`, y la
	salida del surf acababa pegada a la geometria con la velocidad a cero. Lo
	declara cada estado con `adherencia_automatica()`; el agarre a mano no cambia.
21. **CADA BANDO TIENE SU FRENTE, Y ES UNO SOLO.** El jugador mira a **+Z** en su
	nodo `Visual`; los enemigos miran a **−Z** en su cuerpo. Los dos convenios son
	correctos, conviven a proposito y **no hay que unificarlos**: lo prohibido es
	un TERCER criterio dentro de uno de los dos.
	Eso fue el bug de la 3.08. `Enemigo.encarar()` usaba `atan2(d.x, d.z)`, que
	deja `+basis.z` mirando al objetivo —medido—, mientras los cinco lectores del
	bando enemigo y los cuatro marcadores `Marca` de las escenas leian `−basis.z`.
	El embestidor te detectaba solo por la espalda y **cargaba huyendo**; el
	guardian empujaba al jugador HACIA si mismo. Un signo, cinco sintomas que no
	se parecian entre si.
	Por eso el signo se escribe en UN sitio —`Enemigo.frente()`— y nadie mas pone
	`-global_basis.z` a mano. Y el test lo comprueba dejando correr `encarar()`
	antes de mirar: fijar `rotation.y` a mano y despues preguntar por el cono de
	vision pasa igual de verde con el bug puesto.
21bis. **LA INTERPOLACION DE FISICA ESTA ENCENDIDA** (`physics/common/physics_interpolation`),
	porque la fisica va a 60 Hz y la pantalla a 144: sin ella, **el 63.5% de los
	frames dibujaban al personaje congelado** y eso es todo el "se ve borroso"
	que se reporto. Medido con `tools/MedirJitter.tscn`, A/B en la misma pasada.
	Tres consecuencias que hay que respetar o se rompe:
	· **Lo que se mueve por CODIGO en `_process` va FUERA**
	  (`physics_interpolation_mode = OFF`): el `CameraRig` y el `Cordon`. Dentro
	  se interpolarian dos veces.
	· **Quien siga a un cuerpo desde `_process` usa
	  `get_global_transform_interpolated()`**, no `global_position`. La segunda
	  sigue siendo la del ultimo tick —escalonada— y perseguirla deja a la camara
	  siguiendo algo distinto de lo que se ve.
	· **Todo teletransporte llama a `reset_physics_interpolation()`.** Sin eso, un
	  respawn se dibuja como un barrido cruzando el mapa entero en un frame.
22. **Un valor absoluto no distingue "va hacia ti" de "se va de ti".** El chequeo
	de la carga del embestidor midio `absf(position.z)` durante dos parches y
	estuvo en verde todo ese tiempo con la carga saliendo al reves: la fuga
	tambien recorre metros. Cuando lo que se prueba es un SENTIDO —perseguir,
	huir, acercarse, empujar—, se mide con signo o comparando distancias antes y
	despues. Nunca con un modulo.
23. **AL SERVIDOR DE RENDER NO SE LE PREGUNTA EL ESTADO DEL JUEGO.** Lo que se le
	manda, se guarda tambien de este lado. `MultiMesh.get_instance_transform()`
	devuelve la IDENTIDAD en headless —ahi el servidor es un maniqui que no guarda
	el buffer—, asi que cualquier logica que lea de ahi funciona en pantalla y
	falla en un test sin decir por que. Paso con la bandada y las luciernagas:
	`perturbar_cerca()` media contra doce criaturas todas en el origen y elegia
	siempre la primera; en el juego se veia perfecto. Es la version de render de
	la regla de los tests —el sitio donde se AFIRMA algo no puede ser el sitio
	donde se DIBUJA—, y el precio es un `Array` por sistema.

## Autoloads
Propios: `EventBus`, `GameState`, `HitstopManager`, `DebugOverlay`, `DebugDraw`, `MenuControles`.
De plugins: `PhantomCameraManager`, `Dialogic`, `CyclopsAutoload`.

Los tres de plugin los registra el editor al activarlos. Estan escritos a mano en
`project.godot` porque los plugins se instalaron por linea de comandos y
`_enable_plugin()` no llego a ejecutarse: si algun dia se desactiva un plugin desde
el editor, hay que quitar su autoload tambien a mano.

## Plugins (`addons/`)

**Solo se activa lo que se USA.** Los cinco estan instalados, pero en
`[editor_plugins]` solo queda `proton_scatter`. Los demas se activan cuando se
integren y no antes, por dos razones medidas:

1. **Ensucian la consola con bugs suyos.** Cyclops y Phantom Camera tienen
   teardown incondicional —`_exit_tree()` libera cosas que su `_enter_tree()` no
   llego a crear— y sueltan tres errores en cada arranque del editor. Reproducido
   en un proyecto VACIO con solo esos dos: no es culpa de este proyecto.
2. **Cyclops MODIFICA las escenas abiertas.** Con el plugin activo, abrir
   `Main.tscn` en el editor le inyecta nodos `CyclopsBlock` y sube el formato de
   escena de 3 a 4. Si despues se desactiva el plugin, la escena queda con
   referencias colgando y **deja de cargar el entorno**. Paso de verdad, y solo lo
   cazo el screenshot test: los 131 funcionales seguian en verde.

| Plugin | Version | Para que |
|---|---|---|
| `phantom_camera` | v0.11.0.3 | Camaras estilo Cinemachine. **Sin integrar todavia**: el `CameraRig` propio sigue mandando. |
| `proton_scatter` | 4.2.0 (`main`) | Dispersion procedural de props. **Desde `main`, NO desde la Asset Library**: la version publicada alli es de 2023 y no compila en 4.7. |
| `cyclops_level_builder` | v1.5.0_dev_2 | Blockout en el viewport. Para el MUNDO real; las salas de prueba se siguen generando por codigo. |
| `dialogic` | 2.0-alpha-20 | Dialogos. Sin usar todavia. |
| `inventory-system` | addon-2.13.0 | GDExtension en C++. Registra `Inventory`, `ItemDefinition`… |

**Los binarios del inventario estan RECORTADOS A WINDOWS.** El release trae 125 MB
de `.dll`/`.so` para seis plataformas; en el repo solo quedan los 19 MB de Windows,
que es donde se desarrolla. Para exportar a Linux, Android, web, macOS o iOS hay
que recuperar `addons/inventory-system/bin/<plataforma>/` del release
`addon-2.13.0`.

**Regla:** un addon es codigo que no controlas metido en tu repo, y las reglas
duras de este documento NO le aplican. No modifiques nada dentro de `addons/`:
cualquier cambio se pierde al actualizar. Si hace falta adaptar algo, se envuelve
desde `src/`.

## Estructura
Ver `docs/03_ARQUITECTURA_MECANICAS.md §0`. Resumen: `src/` (código por sistema),
`content/` (assets y datos), `tools/` (Gym, ColossusTestRoom), `docs/`.

## Controles

**La fuente de verdad es el menu del juego (Escape), no esta tabla.** El menu lee las
teclas del InputMap en vivo, asi que no puede mentir; esta tabla es papel y ya se
desincronizo una vez —siguio anunciando la embestida en primera persona semanas
despues de que se retirara—. Si las dos discrepan, gana el menu y se corrige aqui.


| Accion | Teclado / raton | Mando |
|---|---|---|
| Mover / camara | WASD / raton | Stick izq. / stick der. |
| Saltar | Espacio | A |
| **Planear** | **Ctrl** o **Mouse 4** (mantener) | LB (mantener) |
| Dash / sprint / esquiva | Shift | B |
| Agacharse / slide | C | D-pad abajo |
| Salto fuerte | C (quieto) + Espacio | |
| Side jump | Correr, girar en seco y saltar (planta y luego sale) | |
| Slide kick | C con velocidad + click izq. (con espera) | |
| Long jump | Shift + C + Espacio | |
| Patada baja (derriba) | C + click | |
| **Clavado ligero (rebota en cabezas)** | **Click izq. en el aire** (siempre) | RB |
| | *Rebotar da gravedad cero un instante, pero NO devuelve el doble salto* | |
| **Clavado pesado (LEVANTA al enemigo)** | **Click der. en el aire** | RT |
| | *No rebota: se planta. Manda al enemigo por los aires unos segundos* | |
| Picado vertical (ground pound) | C + click der. en el aire | |
| | *Su area y su dano crecen con la altura desde la que caes* | |
| Escalar | Insistir contra el muro · Shift impulsa | |
| Nadar / bucear | C bucea · mantener Espacio sube · Shift acelera | |
| Ataque acuatico | Click izq. / der. en el agua (impulso) | |
| Landing slide | Aterrizar con velocidad manteniendo C | |
| Agarrar / escalar | F (tambien desde el suelo) | Y |
| Ataque ligero / pesado | Click izq. / Click der. | RB / RT |
| **Combo pesado** | Click der. **otra vez** durante el giro | RT |
| | *Giro (2 impactos, en area) -> remate descendente (1, con empuje)* | |
| Ataque de dash (estocada) | Click izq. durante dash | RB |
| Estocada de surf | **Shift** + click izq. | LB + RB |
| Frenazo de surf | **Shift** + click der. | LB + RT |
| Parry | Q | LT |
| Fijar objetivo | Click medio | R3 |
| Apuntar | R | L3 |
| **Lanza: tirar / recuperar** | **V** o **Mouse 5** | D-pad arriba |
| **Empunar / guardar la lanza** | **Tab** | Back |
| **Carga en viaje** | Click izq. / der. mientras la cuerda te lleva | RB / RT |
| | *Ligero atraviesa · pesado los manda a volar con tu inercia* | |
| | *Empunada cambia el moveset entero. Tirarla la desempuna* | |
| **Cuerda** — clavada: te recoge y te cuelga · en vuelo: te lleva a ella | **Z** | D-pad der. |
| **Daga: tirar / recoger** | **X** | *sin asignar* |
| | *la lanza tambien se clava en enemigos pequenos: dos presas, dos armas* | |
| **Zarandear** — daga O lanza clavada en un enemigo + **Z** | **Z** | D-pad der. |
| | *el stick lo hace girar · **click der.** lo estampa con dano en area* | |
| **Resortera** — con lanza Y anclaje puestos, la misma **Z** tensa | **Z** (mantener) | D-pad der. |
| | *Tira hacia atras con el stick y SUELTA: sales catapultado* | |
| Recuperar (aparte) | Y | D-pad izq. |
| **Menu de controles** | **Escape** (F1 tambien) | Start |
| Debug | F3 panel · **F7 gizmos 3D** · F5 tuning · F6 paleta · F4 respawn arena | |

**El planeo esta separado del salto a proposito.** Compartir tecla obligaba a
negociar cada pulsacion entre doble salto y capa, y resultaba incomodo. Ahora
`glide` se mantiene y ya esta.

**La escalera de velocidad va con Shift, y solo con Shift:**

```
sin Shift ->  caminar -> trotar -> correr   (rampa continua por CARRERILLA)
con Shift ->  DASH (esquive corto, unidireccional) -> SURF (fluido, sostenido)
```

El dash es un **esquive**, no un desplazamiento: 0.12 s y casi sin giro. Quien
pilota es el `Surf`, que **no caduca**: se sostiene mientras mantengas Shift y su
unico limite es la stamina. Soltarlo lo corta en el acto.

La locomocion sin Shift no tiene peldanos: acumula **carrerilla** (segundos
manteniendo la direccion) y la velocidad recorre caminar -> trotar -> correr de
forma continua, con suavizado exponencial (`suavizado_velocidad`, constante de
tiempo en segundos, independiente del framerate). El stick solo pone el techo:
empujar a medias camina aunque lleves carrerilla.

**Pivote del dash:** pedir la direccion CONTRARIA en pleno dash frena en seco y
salta (estilo Mario 64). Ese salto esta exento de jump cut: no lo pidio el boton.

Colgado de un canto: **empujar arriba sube**, **saltar salta desde el canto**.
Junto a una pared, **saltar rebota** en vez de gastar el salto aereo, y sigue
disponible durante `pared_coyote` segundos tras perder el contacto.

## Herramientas
| Script | Para qué |
|---|---|
| `tools/Gym.gd` | Sala de pruebas por código. Editar parámetros, no cubos. Incluye las rampas de calibración de escalada (45–90°, con el pie en la misma línea) y **EL CLARO** (hierba interactiva, luciérnagas y bandada) en (9, 0, −13). Se apaga con `con_claro`. |
| `tools/smoke_test.gd` | Comprobación de humo. `godot --headless --path . --script tools/smoke_test.gd` |
| `tools/medir_paleta.gd` | Imprime croma y luminancia de cada color. Mide antes de inventar umbrales. |
| `tools/MedirMovimiento.tscn` | Cronometra el feel de la locomocion: frenada, patinaje, control aereo. `-- antes` compara con los valores previos. |
| `tools/captura.gd` | Guarda capturas del Gym y del circuito sin abrir el editor. |
| `tools/TestVisual.tscn` | **Screenshot tests.** Compara 14 tomas contra `tools/baseline/`. Necesita GPU: `godot --path . --resolution 960x540 tools/TestVisual.tscn`. Con `-- actualizar` regenera las referencias. |
| `tools/Circuito.gd` | La carrera de obstaculos del Hito 1, con cronometro. |
| `tools/Arena.gd` | Patio de combate del Hito 2. F4 respawnea a los Guardianes. **Su poblacion es load-bearing para `TestFase2`: no metas enemigos aqui.** |
| `tools/TestFase2.tscn` | Test funcional de combate, postura, agua, escalada, la particion de los verbos de pared, el combo pesado y que el surf no te pega a la pared. 137 comprobaciones. |
| `tools/TestEnemigos.tscn` | Test funcional de los tres enemigos: cono de vision, carga que no persigue, rafaga, zigzag, torso escalable, apuntado en 3D, las invariantes del arrastre y el punto debil, la carga que va HACIA el jugador sin perseguirle, la patrulla, los dos arquetipos, que una lanza clavada viaja con el cuerpo y el ZARANDEO de enemigos. 36 comprobaciones. |
| `tools/TestLanza.tscn` | Test funcional de la lanza (Fase 3): vuelo, clavado, plataforma, cuerda, balanceo, moveset de suelo y aire, pertiga, carga en viaje, la RESORTERA, la daga y que la Z existe estando adherido. 53 comprobaciones. |
| `tools/Jardin.tscn` | **El banco del sistema generativo**, lo que el Gym es al movimiento: el enjambre de Kuramoto con sus Criaturas de Tela. Clic izq. perturba una · rueda/flechas mueven el pitch · R reinicia al caos · F7 dibuja la RUEDA DE FASES. `godot --path . --resolution 960x540 tools/Jardin.tscn` |
| `tools/Claro.tscn` | **El banco del mundo vivo**, lo que el Gym es al movimiento y el Jardin al sistema generativo: hierba con viento e interaccion, luciernagas y una bandada de criaturas de tela. Corre por la hierba y mira el rastro; espera y mira respirar a los dos enjambres. **F7** dibuja el orden de cada uno y las huellas que el shader esta leyendo. `godot --path . --resolution 960x540 tools/Claro.tscn` |
| `tools/TestMundoVivo.tscn` | Test de la capa atmosferica, en las mismas dos mitades que `TestEnjambre`: en SECO comprueba que el campo medio es una identidad exacta y que `a_ritmo()` es un cambio de reloj; EN VIVO, que la hierba nace pegada al suelo y no en las paredes, que el rastro sigue al jugador y se desvanece, que el destello es un pulso y no un brillo, que las cintas miran hacia donde vuelan, y la ESCOLTA entera —algunas y no todas, que rodean de verdad, y que vuelven solas cuando te vas—. 27 comprobaciones. |
| `tools/TestEnjambre.tscn` | Test del sistema generativo, en dos mitades: el MODELO en seco —a pasos de dt fijo, minutos de simulacion en milisegundos— y la MANIFESTACION en vivo. Mide la respiracion caos↔orden, la perturbacion y su resincronizacion, el control sin acoplamiento, y que nadie rota ni un frame. 31 comprobaciones. |
| `tools/TestMenu.tscn` | Test del menu de controles: comprueba que toda accion que el menu nombra existe de verdad en el InputMap. 4 comprobaciones. |
| `tools/TestFase1.tscn` | Test funcional de la FSM. `godot --headless --path . tools/TestFase1.tscn` |
| `src/core/DebugDraw.gd` | **Gizmos 3D en el mundo (F7).** Modo inmediato: `DebugDraw.esfera(...)`, `.cono(...)`, `.linea(...)`, `.rayo(...)`, `.caja(...)`, `.punto(...)`. Dibuja la hitbox que se consulta, el cono de vision y la ruta de cada enemigo, y las cuerdas con su radio. **Cuesta cero apagado**: toda entrada sale por `if not activo: return`. |
| `tools/MedirJitter.tscn` | **Mide el jitter**, no lo supone. Corre las dos condiciones —interpolacion si/no— en la MISMA pasada y cuenta que fraccion de frames dibuja al personaje congelado. Necesita GPU: `godot --path . --resolution 960x540 tools/MedirJitter.tscn` |

Tras crear o renombrar una clase con `class_name`, corre
`godot --headless --path . --import` o el proyecto no la encontrará.

**Un test no puede depender de la IA.** `TestFase2` fue intermitente durante un
tiempo —fallaba 1 de cada 4 veces— por dos causas de la misma familia: los
enemigos atacaban al jugador en mitad de una medicion, y tres comprobaciones del
clavado pasaban solo porque el Guardian CAMINABA hasta meterse debajo. Ahora la
suite pacifica a todos los enemigos (`_pacificar()`) y coloca al jugador donde el
ataque llega de verdad. Si una comprobacion necesita un golpe enemigo, se entrega
a mano con `recibir_golpe()`; orquestar la IA para que ataque en el frame exacto
hace el test fragil sin probar nada mas.

**Un test que fuerza el estado no prueba que se pueda LLEGAR a el.** El balanceo
tuvo cuatro comprobaciones en verde mientras el usuario reportaba que no se
balanceaba, porque el test hacia `fsm.cambiar(&"SpearSwing")` en vez de pulsar la
tecla: media la fisica del pendulo y no la ENTRADA. Todo verbo nuevo se prueba por
su camino de entrada real —`Input.action_press()` y el `InputBuffer`— aunque
ademas se mida su fisica aparte.

**Los tres tests son complementarios y ninguno sustituye a otro:** el funcional
comprueba que la FSM llega a un estado, el de medicion cronometra como se siente,
y el visual comprueba que el personaje se VE bien estando ahi. Media docena de
bugs de este proyecto —el cuerpo torcido al salir del agua, la capsula partida por
la mitad junto a una rampa— pasaron los 122 funcionales sin despeinarse.

**Corre el visual SIEMPRE que toques postura, orientacion, camara, paleta o
geometria del Gym.** Y mira el diff antes de regenerar una referencia: una
baseline actualizada a ciegas convierte el test en un sello de goma.

## Estado actual
**Fases 0, 1 y 2 cerradas.**

- **Traversal completo:** `SurfaceContext` + `LocomotionMotor`, FSM jerarquica de
  5 grupos y 27 estados, correr/esprintar/saltar/doble salto/dash/planeo/slide/
  wall-run/wall-slide/wall-jump/cantos/shimmy/escalada. Stamina unica.
  La escalada acepta **cualquier superficie de 45 a 110 grados**, desplomes
  incluidos, y el cuerpo se inclina con ella. Por debajo de 45 se anda; por
  encima, o trepas o resbalas.
- **Combate:** `AttackData` como Resource (tiempos en frames a 60 Hz), hitbox por
  consulta de forma, hitstop, ventanas de cancelacion, cadena ligera con finisher,
  pesado con knockback terrestre + stagger, aereos que reponen el dash, picado,
  parry normal y perfecto, poise con GuardBreak, soft-lock y 3 Guardianes.
  **El jugador se mueve mientras ataca** (`AttackData.movilidad`) y al morir los
  enemigos salen despedidos como cadaver fisico (`Ragdoll`).
- **Enemigos con FSM propia.** `Enemigo` (cuerpo) + `EnemyMotor` (fisica) +
  `EnemyStateMachine`/`EnemyState`, el mismo patron que el jugador. Cada enemigo
  declara SUS estados en su `.tscn`, asi que anadir uno no toca a los demas: el
  volador no comparte una linea de IA con el guardian terrestre, y su unica
  diferencia de fisica es `vuela = true`. Hoy son seis: los 3 Guardianes
  (Lancero/Escudo/Vigia), el **Embestidor**, el **Volador** y el
  **ColosoMediano** escalable. Viven en `Gym._corral()`, nunca en la Arena.

Ademas: agachado con side hop, escalada BotW con wall lunge, Dive y DiveAttack,
aterrizajes agachado (slide con velocidad, recepcion en cuclillas sin ella) y el
agua completa: nado en superficie, buceo, clavado y combate acuatico. Falta solo
la **IA acuatica**, documentada en `project.md`.

**Fase 3 en marcha.** Etapa 1 hecha: la lanza existe, vuela atravesando cuerpos,
se para en seco contra piedra y al clavarse es **plataforma** — tirarla a lo alto
y subirse encima ya funciona. FSM propia en `src/weapons/`, con el mismo patron
que la de enemigos. Etapa 2 tambien: **zip** hasta la lanza, con impulso y
no teletransporte, conservando momentum al llegar. **Etapas 3 y 4**: el cordon
(verlet de paso fijo, **puramente visual**) y el **balanceo**, con restriccion
analitica y gravedad simetrica propia. Y **etapa 5**: el moveset —empunarla con
Tab cambia los dos ataques, ligero preciso contra pesado en area— mas la
pertiga. Y **etapa 6**: `WeakPoint`, la interfaz
contra colosos. **Fase 3 CERRADA.**

**Parche 3.08 — tres correcciones.**

- **La resortera.** Una SEGUNDA cuerda (`Anclaje`, `src/weapons/`) que no es una
  segunda lanza: no hace dano, no es plataforma y no se empuna, solo es un punto
  fijo. Con los dos puestos, la misma **Z** deja de dar pendulo y da **elastico**:
  mantienes para tensar y sueltas para salir catapultado. No hay tecla nueva ni
  menu —lo que decide es cuantas cuerdas hay puestas, y eso se ve—.
  Un pendulo CONSERVA energia y una resortera la ALMACENA, asi que son dos
  estados distintos y no un numero: `StateSlingshot` trata cada cuerda como un
  muelle y dispara por la SUMA de las dos, no por la bisectriz.
  El disparo medido es de **33 m/s**, y por eso existe `momentum_libre`: el clamp
  global (22) se lo comia entero, en silencio y solo en horizontal.
- **El frente de los enemigos estaba invertido.** Ver regla dura #21. Un signo en
  `encarar()`, cinco sintomas: el embestidor cargaba HUYENDO.
- **Combo pesado.** Giro de **dos impactos con un solo gesto** (`AttackData.golpes`)
  encadenado al **remate descendente** con el propio boton pesado
  (`AttackData.boton_cadena`), para que los dos botones sigan significando lo
  mismo dentro de un combo y fuera de el.

**Sistema generativo (`src/generative/`).** Aparte del juego, con su propio banco
(`tools/Jardin.tscn`). N agentes acoplados como osciladores de Kuramoto: cada uno
nace con su frecuencia propia —eso es la personalidad, y no cambia nunca— y el ciclo
del oscilador es lo UNICO que existe. De ese numero salen a la vez el color, la
opacidad, la escala, el recorrido y el pitch; del desvio respecto al grupo salen la
desaturacion y el volumen. Que todo cuelgue del mismo sitio es lo que hace que se
lea como una cosa viva y no como cinco efectos sueltos.

Cuatro cosas que lo definen y no se negocian:

- **NO HAY ROTACION.** Ninguna criatura gira nunca; hay un guardia en modo debug que
  lo reafirma cada frame. Sin giro, un cuerpo solo puede expresarse con donde esta,
  cuanto ocupa y de que color es —y doce cuerpos girando a la vez son ilegibles—.
- **La inestabilidad es UNA regla, no una maquina de estados:** el parametro de orden
  realimenta el acoplamiento, con histeresis. Medido: sincroniza en 9.6 s, se
  deshace en 19.6, y vuelve en 7.3. Respira y no termina nunca.
- **El sonido es externo por encargo.** `Enjambre` publica `pitch` y `amplitud` por
  agente y por frame y ahi acaba. No hay un solo `AudioStreamPlayer`.
- **La cola es persecucion en cadena, no verlet.** El `Cordon` de la lanza cuelga
  entre dos puntos y por eso usa verlet; esta va DETRAS, que es otro problema.

El modelo no dibuja ni suena a proposito: es determinista y se puede afirmar cosas de
el con un test —que es lo que hace `TestEnjambre`—, y el render no.

**Parche 3.12 — dos bugs de movimiento y el MUNDO VIVO (`src/world/`).**

Los dos bugs, con lo que se midio para encontrarlos:

- **La Z estaba muerta estando adherido.** `GroupAttached` no llamaba a
  `intentar_cuerda()`. Ver la ampliacion de la regla dura #13.
- **El surf te pegaba a la pared.** El surf en si sale limpio —ocho caminos de
  salida medidos en pista libre, los ocho obedeciendo, con el alabeo deshecho y la
  capsula de pie—; lo que bloqueaba era el agarre automatico enganchandote al muro
  contra el que terminabas la linea. Ver la ampliacion de la regla dura #20.

Y la capa atmosferica. **Esta plantada en el Gym** —`Gym._claro()`, en
(9, 0, -13), a dieciocho metros del spawn— y ademas tiene banco propio en
`tools/Claro.tscn` para afinarla sin abrir una partida. Las dos cosas hacen falta:
un sistema que solo existe en su banco es un sistema que nadie ve jugando, y
entonces no esta puesto.

- **Hierba en MultiMesh** (`src/world/Pasto.gd` + `src/art/shaders/hierba.gdshader`).
  Es lo que `docs/07_SHADERS.md §4` ya tenia diseñado, implementado tal cual:
  doblado cuadratico con la altura, `UV.y = 0` en la punta, ruido FBM y color por
  instancia. **El viento es un CAMPO, no un parametro por parche**: vive en
  `project.godot > shader_globals` y el shader lo evalua desde `TIME` y la posicion
  de mundo, asi que dos parches separados por medio mapa sacan el mismo valor sin
  hablar entre ellos. Y se APLASTA al pasar: doce huellas con su frescura, la 0 es
  el jugador en vivo y las once restantes son el rastro, que se levanta solo.
- **Bandada y luciernagas** (`src/world/Bandada.gd`, `Luciernagas.gd`). No traen
  modelo propio: son dos manifestaciones mas del `Enjambre` de Kuramoto que ya
  estaba medido. La bandada apretada o estirada segun `r`; las luciernagas
  parpadeando todas a la vez o en desorden. `EnjambreTuning.a_ritmo()` las pone a
  su velocidad —**cada magnitud por su potencia de `f`**: `ω` y `K` son 1/s, pero
  `k_subida` y `k_bajada` son 1/s²—.
- Y por eso el modelo pasa a **campo medio**: `(1/N)Σⱼ sin(θⱼ−θᵢ) ≡ r·sin(ψ−θᵢ)` es
  una identidad exacta, no un promedio, y baja el coste de O(N²) a O(N). Con la
  suma doble, 180 luciernagas costarian 32.400 senos por frame en GDScript.

**Parche 3.13 — EL MARCAPASOS.** Kuramoto con forzamiento externo: un oscilador
de fuera que tira de los agentes que lo tengan cerca. Una pieza, dos verbos.

- **La bandada te ESCOLTA.** Te acercas y unas cuantas dejan el circuito y te
  rodean en circulo; te vas y se sueltan y vuelven. No hay estado "escoltando" ni
  transicion que programar: se mezclan las POSICIONES de dos curvas —el circuito y
  la orbita— con un peso, y la fase sigue corriendo sin enterarse.
- **"Algunas, no todas" no se programa, se deduce.** El criterio de enganche sale
  de la propia ecuacion: en el marco que gira con el marcapasos,
  `dφ/dt = (ωᵢ−Ω) − A·sin(φ)` tiene punto fijo **si y solo si `|ωᵢ − Ω| ≤ A`**.
  Enganchan las que PUEDEN seguirle el ritmo.
- **Y hace falta un SEGUNDO rasgo fijo: la `curiosidad`.** Medido: con la llamada
  igual para todas, el marcapasos capturaba unas pocas, el acoplamiento del grupo
  arrastraba al resto detras y a los treinta segundos escoltaban **las catorce**.
  Es fisica correcta —un enjambre muy acoplado se mueve como una cosa— y es lo
  contrario de lo que se busca. Con el rasgo: **7 de 14, estable**, y siempre las
  mismas, que es mejor que un sorteo porque se aprende a reconocerlas.
- **Quien se va deja de contar para el grupo.** El parametro de orden pesa cada
  agente por `1 − enganche`. Sin eso la bandada persigue a sus propias escoltas.
  Con `enganche = 0` es la formula de siempre: `TestEnjambre` sigue en 9.6 / 19.6 / 7.3.
- **Las luciernagas son un ENJAMBRE, no 180 bichos.** La nube se APRIETA al
  sincronizarse —mismo `r` que decide el parpadeo, otro canal— y cruzarlas las
  desordena por delante de ti y se recomponen detras.
- **Y la bandada era invisible.** `01_DIRECCION_ARTE §4.6` pide pajaros blancos
  `#F2F0E6`; la niebla del juego es `#EFE8D8`. **El mismo color.** El blanco de la
  referencia funciona contra los arcos oscuros; contra cielo abierto la silueta
  tiene que ser MAS OSCURA que el fondo. Ahora es `lavanda_profundo`.

Siguiente paso original: **Fase 3** — lanza y lazo. La lanza clavada como `ClimbAnchor` +
`PlatformSurface` es la herramienta de progresion vertical del juego.

Pendiente de la lista del parche 3.03: **la camara cinematografica**.
`src/camera/CameraTuning.gd` (valores / influencias / curvas), `PhantomDirector.gd`
y `PhantomRig.tscn` estan escritos pero **sin cablear** —`Main.tscn` sigue con
`CameraRig.tscn`—. El obstaculo esta medido: Phantom Camera se queda con el
`transform` de la camara, y **todo el movimiento deduce la direccion de
`player.camara()`**, asi que cablearlo tal cual pone 18 tests en rojo. Migrar
significa darle a Phantom el rig y dejar que `player.camara()` siga leyendo un
`Camera3D` valido, no colgar el plugin al lado del propio.
