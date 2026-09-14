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
| `docs/09_RUMBO.md` | **EL CORTE Y EL OBJETIVO.** Que se queda, que se quita y hacia donde se va, con los numeros que lo justifican. Se escribio porque el proyecto llevaba 73 commits y 0 minutos de juego. **La regla que sale de ahi: no entra un verbo nuevo hasta que exista el coloso #1.** |
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
	**Y EL TOPE ES UN OBJETIVO, NO UN CORTE.** Desde el 4.00 la rapidez por encima
	del techo DECAE hacia el con `velocidad_drag` en vez de recortarse: medido con
	el clamp duro, salir de un arco a 34 m/s te dejaba a **22.0 en el primer
	frame**, y todo lo que habias construido encadenando desaparecia sin que nada
	lo explicara en pantalla. Con drag, 34 -> 29.9 a los 12 frames y 23.5 a los 48:
	sigues siendo rapido un rato y lo vas perdiendo.
	El unico corte que queda es `velocidad_tope_duro` (55), y ese no es de game
	feel: a 60 Hz son 0.92 m por tick, y por encima un muro de un metro deja de ser
	un muro.
	Corolario: **eso mato a `momentum_libre`**. Existia para que la salida de la
	cuerda no se la comiera el corte, o sea que era un parche a este mismo
	problema. Dos mecanismos para un trabajo es como se llega a que uno de los dos
	mienta.
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
	no hacia absolutamente nada**. Mismo sintoma de siempre: silencio. Y su
	guardia, `maneja_cuerda()`, tuvo que existir a la vez, porque la cuerda VIVE
	en `Attached`: sin el, colgado y con la Z pulsada se reentra en el estado cada
	frame y el arco no avanza nunca.
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
24. **BAJAR LA TASA NO SOLO FRENA: TAMBIEN IMPIDE GIRAR.** `motor.acelerar()` mueve
	el VECTOR entero hacia el deseado con un solo numero, asi que esa tasa contesta
	a la vez dos preguntas que no se parecen —cuanto tardas en FRENAR y cuanto
	tardas en OBEDECER—. Mientras las dos valen lo mismo no se nota; en cuanto una
	se baja a proposito, el jugador pierde el control sin que nadie lo pidiera.
	Paso dos veces con el mismo sintoma —"sigue en linea recta y no puedo
	direccionarlo"— y en dos sitios distintos: `frenado_momentum` (6 m/s²) en
	`Move`, que costaba **1.43 s de linea recta** saliendo del surf cuesta abajo, y
	`aceleracion_aire` (12) en el aire, donde una inversion a 9.4 m/s no llegaba a
	completarse nunca.
	**Se arregla bajando el OBJETIVO, no la tasa**: un techo de rapidez que se
	acerca a la rampa a `frenado_momentum` conserva la regla del momentum entera
	—la velocidad extra se sigue perdiendo despacio— y deja el giro con la
	autoridad de siempre. En el aire, donde el objetivo YA es tu propia rapidez, la
	llamada no acelera nada: gira, y por eso tiene su propio numero (`giro_aire`).
	Corolario: **el `move_toward` sobre el vector es el primitivo correcto y no se
	sustituye por un `slerp`**. Pedir la direccion contraria traza una recta que
	pasa por el cero —frenada en seco y pivote de Mario 64—; un slerp da un giro en
	U con radio. Medido al intentarlo: la frenada pidiendo lo contrario pasaba de
	0.17 s / 0.65 m a 2.75 s / 21.76 m.
25. **UN NUMERO TOCADO EN EL EDITOR ES UN CAMBIO DE CODIGO SIN REVISAR.** El
	screenshot test salio 0/14 y las 14 tomas parecian rotas por lo ultimo que se
	habia tocado. No lo estaban: `default_palette.tres` y `Main.tscn` traian
	ediciones del editor —`caliza_sol` a lavanda, `oro_palido` de oro a rosa,
	`energia_solar` de 1.15 a 1.871, `domo_radio` de 8 a 11— y eso cambia TODAS las
	tomas a la vez. Con esos dos ficheros en su sitio, 11 de 14 volvieron a 0.000%.
	Dos cosas de aqui: **antes de culpar al codigo, `git diff` de los datos**, y
	**el validador ya lo estaba diciendo** —`Palette.validar()` avisaba de `carmesi`
	y `oro_palido` en cada arranque y el aviso se leyo como ruido—. Un warning que
	se ignora por costumbre es un test que no existe.
26. **UNA INTERFAZ MODAL NO ES UNA PAUSA, Y SE CORTA DONDE SE LEE.** Son dos
	cosas distintas y el proyecto necesita las dos: `MenuControles` PAUSA el arbol
	—se abre para pararse a leerlo—, pero la hoja de notas de la jam se abre para
	ESCUCHAR el corro, asi que el mundo tiene que seguir corriendo debajo. Y eso
	deja al jugador vivo: sin cortarle el input, escribir una nota es tambien
	correr, saltar y atacar.
	El corte va en el `InputBuffer` y en ningun otro sitio, porque la regla dura #4
	ya garantiza que es el UNICO que habla con `Input`: apagarlo ahi apaga de una
	vez el movimiento, los ataques, el salto, la lanza y la cuerda —y lo seguira
	haciendo con el verbo que nazca manana—. Cualquier otro sitio es una lista que
	hay que acordarse de ampliar. Se anuncia con `EventBus.interfaz_modal` y no con
	un flag pasado a mano, porque ya son dos los que escuchan —el buffer y la
	camara, que con mando seguia girando— y manana sera el HUD.
	**Y al cortar se VACIA el buffer**: una pulsacion guardada justo antes de abrir
	se ejecutaria al cerrar, y eso se siente como un fantasma.
27. **UN MOVIMIENTO TERMINA SOLO; UN MODO LO TERMINA EL JUGADOR.** Es la
	diferencia que define el moveset desde el parche 4.00, y no es de matiz: si
	quien decide cuando acaba una accion es el jugador soltando un boton, entonces
	mientras lo sostenga el juego es OTRO juego —otras fisicas, otras
	transiciones, otro techo de velocidad— y el resto del moveset deja de
	aplicarse. Eso es lo que eran los cuatro verbos de cuerda del 3.16, y es por
	lo que se sentian lentos aunque cada uno estuviera bien medido por dentro.
	**Todo verbo nuevo declara su duracion maxima y se acaba al cumplirla**, pase
	lo que pase. El jugador decide CUANDO EMPIEZA y HACIA DONDE va; cuando acaba
	lo decide el numero.
	Corolario: **si un verbo ademas se gasta, se gasta AL ENTRAR y no al salir.**
	Una carga que se cobra a la salida deja abierta la ventana de volver a
	entrar durante el propio movimiento, y eso es el modo otra vez con pasos
	extra.
28. **UNA RESTRICCION DE POSICION CORRE DESPUES DE `move_and_slide()`.** Va en
	`PlayerState.post_move()`, que la FSM llama una vez por frame solo para el
	estado activo. El motivo es literal: una restriccion corrige una POSICION, asi
	que la que tiene que corregir es la DEFINITIVA, la que ya paso por las
	colisiones. Reproyectar antes de mover restringe una posicion que el motor
	todavia va a cambiar, el jugador cierra el frame fuera de la esfera y el error
	se hereda al siguiente.
	No rompe la regla #12 ni la del `move_and_slide` unico: ahi no se mueve a
	nadie, se corrige lo ya movido. Y la correccion de `global_position` va
	ACOTADA por frame, porque escribirla salta por encima de las colisiones.
29. **`motor.impulso()` REEMPLAZA EL VECTOR HORIZONTAL ENTERO**, no lo empuja.
	Con `conservar = false` —que es el defecto— la llamada escribe
	`velocity = direccion * magnitud`, asi que un numero pequeño puesto con la
	intencion de "empujar un poco" BORRA todo lo que llevabas.
	Ha mordido dos veces en el mismo parche y de la misma forma. En `StateKick`,
	escribir 18 m/s cada frame hacia que entrar lanzado a 29.8 te dejara a 18.0:
	**la patada te quitaba velocidad por usar tu propio moveset**. Y en
	`StateWallSlide`, un `impulso(-normal, 1.2)` cuyo comentario decia "pegarse
	ligeramente a la pared para no despegarse solo" dejaba a 1.2 a quien llegaba
	rozando a 30 — la componente que iba A LO LARGO del muro desaparecia entera.
	**Cuando lo que se quiere es un SUELO o un EMPUJON, no se usa `impulso()` a
	secas:** o `maxf(rapidez_actual, minimo)` para un suelo, o se parte la
	velocidad en componentes y se trata cada una como toca —la que va contra el
	muro se sustituye, la que va a lo largo se conserva y se le aplica rozamiento—.
	Un roce que borra la linea convierte cada pared en un castigo, y eso choca de
	frente con la ley del moveset: encadenar limpio acumula velocidad.
30. **ESCALAR ES UNA HABILIDAD QUE SE LLEVA PUESTA** (`puede_escalar`), y por una
	razon de sistema y no de progresion: **es el unico verbo que APAGA el moveset
	en vez de encadenarlo**. La adherencia automatica te agarra al muro en 0.35 s
	de insistir y `StateClimb` escribe `velocity = Vector3.ZERO` cada frame.
	Medido con `MedirCadena`: llegar a un muro a 30 m/s empujando daba
	`Fall > WallSlide > Climb` y **30.0 -> 0.0 m/s**; sin la habilidad, el mismo
	gesto da `Fall > WallSlide > Move` y aterrizas corriendo.
	Lo comprueban las TRES puertas —los dos grupos que proponen `Climb` y la
	adherencia automatica— mas un guardia defensivo en `StateClimb.enter()`. Cuatro
	sitios y una sola condicion, `escalada_habilitada()`: repartir la condicion
	seria la regla dura #13 otra vez.

31. **UN BOTON QUE CAMBIA DE ESTADO NO ES UN BOTON QUE FUNCIONA.** Saltar desde
	el arco tuvo un chequeo en verde todo el 4.00 mientras el boton solo SOLTABA:
	el chequeo preguntaba si se habia entrado en `Jump`, y se entraba. Lo que no
	miraba era la MAGNITUD. `Jump` con la vertical negativa se va a `Fall` en el
	mismo frame, asi que entrar en el no prueba absolutamente nada — medido,
	`vy -8.8 -> -10.0` con la fila de control del doble salto en `+10.7`.
	**Todo verbo que produzca un impulso se comprueba por el numero que produce**,
	no por el nombre del estado al que lleva. Es la misma familia que el fallo de
	la patada —contar frames de anticipacion medía el orden de los nodos, no la
	ley— y que la regla #22: el sitio donde se AFIRMA no puede ser el nombre de la
	casilla.
	Corolario para los BANCOS: una medida de un verbo imprime **el estado en el
	que se tomó**. «saltar desde el arco: -15.2 -> +10.7» estuvo en el informe del
	4.00 y era correcto y era de otra cosa: se pulsaba antes de que el jugador
	llegara a `Grapple` y lo que media era un doble salto en el aire.

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
| **Shift en el SUELO — DESLIZARSE** | Shift | B |
| | *el slide lee el terreno: acelera cuesta abajo y frena cuesta arriba* | |
| | ***Shift + Espacio = SLIDE-JUMP***, con altura extra | |
| | *pedir la direccion CONTRARIA en pleno slide frena en seco y salta (pivote Mario 64)* | |
| **Shift MANTENIDO — SURF** | Shift (mantener) | B |
| **Shift EN EL AIRE — dash** (esquive de 0.12 s) | Shift | B |
| Agacharse / slide | C | D-pad abajo |
| Salto fuerte | C (quieto) + Espacio | |
| Side jump | Correr, girar en seco y saltar (planta y luego sale) | |
| Long jump | Shift + C + Espacio | |
| **Escalar** — pide la HABILIDAD equipada (`puede_escalar`) | Insistir contra el muro · Shift impulsa | |
| | *sin ella la pared solo da wall-slide y wall-jump, y conservas la linea* | |
| Nadar / bucear | C bucea · mantener Espacio sube · Shift acelera | |
| | *nadar es traversal puro: en el agua no se pega* | |
| Landing slide | Aterrizar con velocidad manteniendo C | |
| Agarrar / escalar | F (tambien desde el suelo) | Y |
| **PATADA** — **es el SALTO AEREO**, no un ataque | **Espacio en el aire** | A |
| | *impulso corto y dirigido, 0.25 s, sin gravedad* | |
| | *18 m/s es un SUELO, no un techo: llegas a 30, sales a 30* | |
| | *cruza huecos aunque no haya nada que golpear* | |
| | *el stick la dirige durante TODO el gesto, no solo al empezar* | |
| | *saltar o tirar de la cuerda la cortan: no hay compromiso* | |
| | *si conecta, DERROTA, te REBOTA arriba y recarga las dos cargas* | |
| | *y PARA el juego 4 frames — es lo unico de un golpe que hoy se ve* | |
| | *NO hay doble salto: en el aire, Espacio patea. Las Sun Greaves de* Pseudoregalia *SON el salto aereo* | |
| | *describe un ARCO: sube, se dobla y cae. Con la gravedad apagada del todo parecia que volabas* | |
| | *TRES por tiempo de vuelo. Vuelven al TOCAR suelo, pared o enemigo —al tocar, no mientras tocas* | |
| Parry | Q | LT |
| | *el perfecto quiebra al atacante y te devuelve las dos cargas* | |
| Fijar objetivo | Click medio | R3 |
| Apuntar | R | L3 |
| **LANZA: tirarla** — y desde el 4.02 es **LA DIANA DE POGO** | **V** o **Mouse 5** | D-pad arriba |
| | *vuela 11 m, se PARA y se queda flotando 2.5 s* | |
| | *mientras flota se le puede dar una patada: rebotas y ella se cae* | |
| | *una lanzada, un pogo — un escalon que te fabricas donde no hay nada* | |
| | *el rebote SI, la recarga NO: tu lanza la pones tu* | |
| **Empunar / guardar la lanza** | **Tab** | Back |
| | *Tirarla la desempuna. Ya no cambia como pegas: solo hay una forma* | |
| **CUERDA** — engancha al `Ancla` que estes MIRANDO, dentro de alcance | **Z** (mantener) | D-pad der. |
| | *instantanea: no hay nada que tirar ni tiempo de viaje* | |
| | *MANTIENES y te quedas colgado · SUELTAS y te sueltas* | |
| | *un toque da un gancho corto; mantener, el arco entero* | |
| | *el stick dirige el arco entero — lo abre, lo cierra, lo inclina* | |
| | ***Espacio** salta DE VERDAD desde el arco —salto entero— y conserva tu velocidad* | |
| | *tope de 3 s por si no sueltas. Lo que impide bombear no es el reloj: es la perdida* | |
| | *alcance 19 m, elegido mirando la separacion real entre anclas vecinas* | |
| | *UNA por tiempo de vuelo. La devuelven suelo, pared, enemigo **y soltarte de un ancla*** |
| | *asi que se encadena ancla -> ancla sin pisar nada; lo que no vale es la MISMA dos veces seguidas* | |
| Recuperar (aparte) | Y | D-pad izq. |
| **Hoja de notas** (junto a la jam) | **E** | Y |
| | *rejilla de rombos y circulos: una columna por musico, una fila por paso* | |
| | *mientras esta abierta NO se juega: ni mover, ni atacar, ni girar la camara* | |
| **Menu de controles** | **Escape** (F1 tambien) | Start |
| Debug | F3 panel · **F7 gizmos 3D** · F5 tuning · F6 paleta · F4 respawn arena | |

**EL 40% DEL FEEL NO ESTA EN LA FISICA** (`PlayerFeedback`). Lo dice el documento
de movimiento y aqui era cierto de la peor manera: el moveset medido al frame y
**ni una sola particula en todo `src/`**. La pantalla decia lo mismo a 30 m/s que
a 8, y por eso un golpe perfectamente cronometrado no se sentia.

- **Aplastado y estirado.** Aterrizar chafa la capsula en proporcion al impacto y
  se recupera en 0.12 s; subir rapido la estira. Conserva el volumen —lo que se
  quita de alto se pone de ancho— porque un aplastado que ademas encoge parece
  que el personaje se aleja.
- **Estela en el dash y la patada**, y solo ahi: capsulas fantasma que se
  desvanecen. Con capsulas grises una silueta repetida se lee como velocidad y
  ademas enseña la TRAYECTORIA, que es lo que un gesto te pide leer.
- **Polvo** al aterrizar y al entrar en slide.
- **El screenshake va SOLO en eventos discretos** y pequeño (0.25). Es la unica
  cosa que el documento subraya de esta seccion: sacudir de forma continua no
  comunica velocidad, comunica que la camara esta rota.
- **NO hay lineas de velocidad, y no por olvido.** Se intentaron dos veces con
  particulas —cremas contra un cielo crema, que es el bug de la bandada del 3.13
  otra vez, y despues oscuras y grandes— y la foto de las dos dice lo mismo: a
  distancia de tercera persona son cuatro motas flotando. **Una raya de velocidad
  no es un objeto del mundo, es un efecto de PANTALLA**, y su sitio es el
  post-proceso de la Fase 5. Mientras tanto la velocidad tiene su canal y
  funciona: el FOV dinamico.
- **`PlayerFeedback` no decide nada del juego.** Lee estado y dibuja; si se borra
  entero, el jugador se mueve igual. Y **no escribe la escala del visual, la
  PIDE**: el controlador la compone, igual que un estado pide postura (regla #14).

**El planeo esta separado del salto a proposito.** Compartir tecla obligaba a
negociar cada pulsacion entre doble salto y capa, y resultaba incomodo. Ahora
`glide` se mantiene y ya esta.

**La escalera de velocidad va con Shift, y solo con Shift:**

```
sin Shift ->  caminar -> trotar -> correr   (rampa continua por CARRERILLA)
con Shift ->  SLIDE (toque, lee el terreno) -> SURF (mantenido, fluido)
en el aire -> DASH (esquive corto, unidireccional)
```

**El dash de suelo se retiro en el 4.04.** El dash y el slide eran los dos «el
boton de ir rapido en linea recta», y el slide es el que lee el terreno: acelera
cuesta abajo, frena cuesta arriba y se encadena con el salto. El dash se queda
donde sigue significando algo —EN EL AIRE, como esquive de 0.12 s y casi sin
giro—. Quien pilota en suelo es el `Surf`, que **no caduca**: se sostiene
mientras mantengas Shift y su unico limite es la stamina.

**Y las hojas reclaman Shift con `maneja_deslizamiento()`** (regla dura #13). Sin
ese guardia el grupo se lo robaba a quien ya lo estaba usando: surfeando, una
pulsacion mas te sacaba del surf y te metia en un slide. Lo cazo `TestFase2`.

La locomocion sin Shift no tiene peldanos: acumula **carrerilla** (segundos
manteniendo la direccion) y la velocidad recorre caminar -> trotar -> correr de
forma continua, con suavizado exponencial (`suavizado_velocidad`, constante de
tiempo en segundos, independiente del framerate). El stick solo pone el techo:
empujar a medias camina aunque lleves carrerilla.

**Pivote del SLIDE:** pedir la direccion CONTRARIA en pleno deslizamiento frena
en seco y salta (estilo Mario 64). Ese salto esta exento de jump cut: no lo pidio
el boton.

**Se mudo del dash al slide en el 4.04, y no por gusto.** El pivote siempre fue
una maniobra de PIES —estaba prohibido en vuelo por su propio comentario: «en el
aire no hay de donde agarrarse»— asi que cuando el dash de suelo paso a ser el
slide, el pivote se quedo en codigo INALCANZABLE: el unico dash que queda es el
aereo, donde nunca se permitio. Lo cazo `TestFase2`, que seguia pidiendoselo al
dash.

Colgado de un canto: **empujar arriba sube**, **saltar salta desde el canto**.
Junto a una pared, **saltar rebota** en vez de gastar el salto aereo, y sigue
disponible durante `pared_coyote` segundos tras perder el contacto.

**EL WALL KICK ES UN ABANICO, Y ES LA MECANICA CON MAS TECHO DEL MOVESET.** El
angulo con el que SALES de una pared es funcion del angulo al que MIRAS al
tocarla: **de frente da ALTURA, rasante da DISTANCIA**, y todo lo de en medio
existe. Un boton, infinitos resultados.

```
mirando de frente al muro    vy 13.6   plano  6.3 m/s
mirando a 45 grados          vy 11.8   plano  7.9
mirando RASANTE              vy  8.1   plano 11.1
```

Antes de existir, las tres daban `vy 10.5 / plano 9.0`: el angulo era un dato que
el juego ignoraba. Lo abre `walljump_abanico` (0.30), y en 0.0 vuelve el salto de
pared fijo de siempre — se puede apagar y comparar.

**Lo decide la CAMARA y no el avance**, y eso no choca con la regla dura #20:
aquella decide QUE VERBO te da una pared —trepar, resbalar, correr— y por eso se
mide con el movimiento real; esto decide el ANGULO DE SALIDA de uno de esos
verbos, que es intencion. Corolario: **no se le roba la camara al jugador**, o se
le esta robando la mecanica.

## Herramientas
| Script | Para qué |
|---|---|
| `tools/Gym.gd` | Sala de pruebas por código. Editar parámetros, no cubos. Incluye las rampas de calibración de escalada (45–90°, con el pie en la misma línea) y **EL CLARO** (hierba interactiva, luciérnagas y bandada) en (9, 0, −13). Se apaga con `con_claro`. |
| `tools/smoke_test.gd` | Comprobación de humo. `godot --headless --path . --script tools/smoke_test.gd` |
| `tools/medir_paleta.gd` | Imprime croma y luminancia de cada color. Mide antes de inventar umbrales. |
| `tools/MedirMovimiento.tscn` | Cronometra el feel de la locomocion: frenada, patinaje, control aereo. `-- antes` compara con los valores previos. Y **LA ESQUINA**: se construye su propio alero —el Gym no tiene ninguno— y salta contra el borde con solapes crecientes. Es la medida que dijo que **la correccion de esquina no hace falta en este juego**: con la capsula, rozar el borde 35 cm de un radio de 40 no cuesta ni un centimetro de salto. |
| `tools/captura.gd` | Guarda capturas del Gym y del circuito sin abrir el editor. |
| `tools/TestVisual.tscn` | **Screenshot tests.** Compara 14 tomas contra `tools/baseline/`. Necesita GPU: `godot --path . --resolution 960x540 tools/TestVisual.tscn`. Con `-- actualizar` regenera las referencias. |
| `tools/Circuito.gd` | La carrera de obstaculos del Hito 1, con cronometro. |
| `tools/Arena.gd` | Patio de combate del Hito 2. F4 respawnea a los Guardianes. **Su poblacion es load-bearing para `TestFase2`: no metas enemigos aqui.** |
| `tools/TestFase2.tscn` | Test funcional de postura, agua, escalada, locomocion, la particion de los verbos de pared, el parry, el dano recibido, el CANDADO DE ESCALADA, que rozar un muro conserva la linea y que **el wall kick es un ABANICO y no un vector fijo** —comprobado por la magnitud y no por el estado, regla dura #31—. 97 comprobaciones. |
| `tools/TestEnemigos.tscn` | Test funcional de los tres enemigos: cono de vision, carga que no persigue, rafaga, zigzag, torso escalable, apuntado en 3D, las invariantes del arrastre y el punto debil, la carga que va HACIA el jugador sin perseguirle, la patrulla, los dos arquetipos, y que una lanza clavada viaja con el cuerpo. 31 comprobaciones. |
| `tools/TestLanza.tscn` | Test funcional de la lanza (Fase 3): vuelo, clavado, plataforma, recuperacion, empunar y desempunar, pertiga e imantado, **y que el vuelo termina FLOTANDO y caduca solo**. 19 comprobaciones. |
| `tools/TestPatada.tscn` | **Test del unico ataque.** Ademas de lo suyo, que conectar **PARA el juego** (regla dura #31: la magnitud, no el estado) y el bucle del pogo — que la lanza tirada se queda flotando, que se le puede patear, y que eso NO recarga el moveset. 26 comprobaciones. Que el boton patea sin anticipacion, que dura lo que dice y termina sola, que **entrando lanzado NO te quita velocidad**, que el stick la dirige A MITAD del gesto, que saltar la corta, que conectar DERROTA y te REBOTA arriba, que se puede patear DESDE el arco de la cuerda, que hay una por tiempo de vuelo, que en el agua no existe, y —la que importa— que **patear a ras de suelo NO la recarga**: la recarga es un flanco de contacto, no un nivel. 21 comprobaciones. |
| `tools/Moveset.tscn` | **EL CIRCUITO DEL MOVESET, y el unico sitio donde el criterio de exito se puede COMPROBAR jugando.** Cuatro hitos en fila y obligatorios —cuerda, patada, pared, cuerda— y **nada de suelo entre ellos**: la condicion «sin tocar el suelo» deja de ser una regla que vigilar y pasa a ser la forma del sitio. Lleva el marcador puesto: el panel dice que eslabones llevas y si has pisado algo. **F4 reinicia** y caerse tambien. `-- auto` lo corre solo con sus filas de control —¿se cruza el hueco pateando? ¿y sin patear?— y `-- foto` guarda el plano general en `user://moveset/`. `godot --path . --resolution 1280x720 tools/Moveset.tscn` |
| `tools/MedirCadena.tscn` | **¿Sobrevive la velocidad al tocar el mundo, y se encadena la cuerda?** Llega lanzado a un muro de frente, rozandolo a 16 y a 35 grados, y a un canto, y dice a que estado te manda el contacto y que queda de la rapidez. Ademas **encadena ancla -> ancla** por el camino real —la tecla, el cono y el buffer, con la camara conducida a mano porque el cono es parte de la mecanica— y dice cuantos TOQUES hicieron falta: `2 enganches tras 0 toques` es la cadena limpia. Y mide el salto desde el arco **imprimiendo el estado en el que se pulsa** (regla dura #31). Con filas de control. `godot --headless --path . tools/MedirCadena.tscn` |
| `tools/CapturaFeedback.tscn` | **Las fotos del FEEDBACK**, que es lo unico que no se puede medir con un numero: el aplastado al aterrizar, la estela de la patada y el polvo del slide, cada uno con su contraste al lado. Necesita GPU. **Aqui se cayo el viento**: tenia sus dos fotos y las dos salieron vacias. `godot --path . --resolution 1280x720 tools/CapturaFeedback.tscn` |
| `tools/CapturaEscalada.tscn` | **Cuatro fotos del candado de escalada**: el mismo gesto contra el mismo muro con la habilidad y sin ella, y un roce a 26 m/s. Necesita GPU. `godot --path . --resolution 1280x720 tools/CapturaEscalada.tscn` |
| `tools/MedirPatada.tscn` | **Cronometra la patada**, que es donde se vio que no se sentia bien: que le hace a la velocidad que ya llevabas, que le hace a la vertical, si se puede salir de ella, que pasa al conectar y cuanto terreno cubre. Las cinco lineas que dijeron los cuatro defectos de la primera version. `godot --headless --path . tools/MedirPatada.tscn` |
| `tools/CapturaPatada.tscn` | **Ocho fotos de la patada** con el panel de debug puesto, para leer el numero y la imagen juntos. Necesita GPU. Un numero no dice si el personaje sale por donde parecia que iba a salir; cazo que la patada no existia estando colgado del arco. `godot --path . --resolution 1280x720 tools/CapturaPatada.tscn` |
| `tools/TestCuerda.tscn` | **Test del arco.** Las leyes del moveset, una por una: que la Z engancha al ancla que miras y lo hace SIN tiron, que el arco no se pasa de su radio, que caduca solo, que no gana energia, que al soltar conserva la velocidad y la premia, que el stick lo dirige, que hay UNA por tiempo de vuelo y que suelo, pared **y soltarte de un ancla** la devuelven —pero que la MISMA ancla no vale dos veces seguidas—, y que saltar desde el arco SUBE y no solo suelta. Ademas los tres filtros del ancla: detras, fuera de alcance y tapada por el mundo. 23 comprobaciones. |
| `tools/Jardin.tscn` | **El banco del sistema generativo**, lo que el Gym es al movimiento: el enjambre de Kuramoto con sus Criaturas de Tela. Clic izq. perturba una · rueda/flechas mueven el pitch · R reinicia al caos · F7 dibuja la RUEDA DE FASES. `godot --path . --resolution 960x540 tools/Jardin.tscn` |
| `tools/Claro.tscn` | **El banco del mundo vivo**, lo que el Gym es al movimiento y el Jardin al sistema generativo: hierba con viento e interaccion, luciernagas y una bandada de criaturas de tela. Corre por la hierba y mira el rastro; espera y mira respirar a los dos enjambres. **F7** dibuja el orden de cada uno y las huellas que el shader esta leyendo. `godot --path . --resolution 960x540 tools/Claro.tscn` |
| `tools/Jam.tscn` | **El banco de la estacion de musica.** Ocho puestos en corro tocando el mismo Kuramoto: se ESCUCHA, no se mira. **E abre la hoja de notas** · acercate y unos cuantos te cogen el compas · **1..8** golpea un puesto a mano · **R** al caos · **F7** dibuja el orden y quien te sigue. `godot --path . --resolution 960x540 tools/Jam.tscn` |
| `tools/TestJam.tscn` | Test de la estacion y su hoja: que las notas caen en la pentatonica siempre, que el compas es el pedido, que al unisono los ataques se juntan (41 ms contra 59), que escribir en la rejilla calla a los que no marcaste y que el marcapasos engancha a algunos y no a todos —y siempre a los mismos—. 29 comprobaciones. |
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

**Parche 4.00 — EL MOVESET.** La referencia de feel pasa a ser **PSEUDOREGALIA**,
y eso manda sobre lo demas. La ley: el movimiento es un MOVESET de acciones
cortas y discretas, no una simulacion continua. En todo momento el jugador tiene
que sentir que la velocidad la puso el, no el motor.

- **Cada movimiento empieza en el frame en que se pulsa.** Startup cero.
- **Dura menos de 1.2 s y TERMINA SOLO.**
- **El jugador manda la direccion durante TODO el movimiento.**
- **Los aereos se gastan una vez y se RECARGAN** al tocar suelo, pared o enemigo.
- **Encadenar limpio acumula velocidad; fallar la pierde.**

Etapa 1: **LA CUERDA ES UN ARCO** (`StateGrapple`, `src/world/Ancla.gd`).

- **Una sola cuerda.** Se retiraron los cuatro verbos del 3.16 —balanceo, zip,
  resortera y zarandeo— y con ellos la segunda cuerda entera (`Anclaje`). No eran
  redundantes entre si —un punto da pendulo y dos dan elastico, son topologias
  distintas— pero los cuatro eran **MODOS**: los terminaba el jugador soltandolos,
  asi que mientras los sostuviera el juego era otro juego.
- **El ancla la pone el NIVEL, no la lanza.** Antes, para balancearte habia que
  tirar la lanza, acertar, y solo entonces existia un punto: un verbo de
  movimiento convertido en una cadena de tres acciones. Ahora el punto esta ahi y
  se ve, y engancharse es una pulsacion sin tiempo de viaje.
- **El radio se elige AL ENGANCHAR y es la distancia a la que estabas.** Por eso
  el enganche no da tiron —empiezas exactamente sobre la esfera, medido: 0.000 m—
  y ademas el jugador elige el arco con su posicion: de cerca sale corto y rapido,
  de lejos largo y amplio.
- **LA Z SE MANTIENE.** Mientras aguantes sigues colgado; al soltar te sueltas. Es
  el gesto natural, y ademas convierte el arco en un rango continuo de intenciones
  igual que el jump cut hace con el salto: un toque da un gancho corto
  (`cuerda_arco_min`), mantener da el arco entero.
  **Y por eso el freno del bombeo cambio de sitio.** Mientras el arco duraba un
  segundo, el reloj lo impedia: no habia segunda pasada que dar. Con la Z
  mantenida si la hay, asi que quien frena ahora es `cuerda_perdida` — sin ella,
  el stick metiendo tangencial cada frame convierte el arco en una escalera al
  cielo. `cuerda_arco_max` sube a 3 s y se queda solo como techo de seguridad.
  Comprobado aguantando el tope entero empujando: no sube.
- **LA RESTRICCION CORRE DESPUES DE `move_and_slide()`**, con el gancho
  `PlayerState.post_move()`. Una restriccion de distancia corrige una POSICION,
  asi que tiene que corregir la definitiva —la que ya paso por las colisiones—;
  reproyectar antes de mover deja al jugador fuera de la esfera al cerrar el frame
  y el error se hereda al siguiente. Sigue habiendo UN solo `move_and_slide`.
- **El alcance se mide desde el JUGADOR y el cono desde la CAMARA**, y no es un
  detalle: medirlo todo desde la camara le suma al alcance la distancia del brazo.
  Medido al cazarlo, `cuerda_rango` decia 12 y se enganchaba a **20.75 m** — y ese
  numero es justo el que dibuja los niveles.
- **EL ALCANCE SE ELIGE MIRANDO EL NIVEL, no a gusto.** Estaba en 12 m y de las
  cinco anclas del Gym —separadas 13.7, 18.3, 9.7, 18.3 y 16.7 m— **solo UNA
  pareja se podia encadenar**. La cuerda se sentia corta con razon: no habia
  cadena que dar. Con 19 llegan las cinco, y `MedirCadena` lo cuenta leyendo el
  mundo en vez de una tabla, asi que el dia que se muevan las anclas sigue
  diciendo la verdad.
- **EL ANCLA CUENTA COMO CONTACTO** (`cuerda_ancla_recarga`). Soltarte de un arco
  devuelve la cuerda, igual que tocar una pared: un ancla es algo que TOCAS y la
  ley 4 dice que los aereos vuelven al tocar. Sin eso, encadenar ancla -> ancla
  era imposible en aire limpio —medido: al pulsar la Z sobre la siguiente salia
  **«cuerda GASTADA» con esa ancla a 13.6 m**, en alcance y dentro del cono— y la
  cadena solo aparecia cuando un pilar se cruzaba por el camino. Eso es lo que se
  reporto como «a veces si puedo y a veces no».
  **Y la MISMA ancla no vale dos veces seguidas** (`ultima_ancla`). Es lo unico
  que separa encadenar de bombear: sin el veto, un solo punto se reengancha en el
  aire sin fin y el arco vuelve a ser un MODO (regla dura #27). Tocar el mundo la
  olvida, asi que el veto no te la prohibe, solo te obliga a pasar por otra cosa.
  El techo lo pone el NIVEL: encadenar exige que haya un ancla nueva a tiro.
- **SALTAR DESDE EL ARCO SALTA.** Pedia `conservar_vertical` a secas —que existe
  para el wall-jump, que ya ha fijado la suya— asi que el salto no tocaba la
  vertical: pulsar Espacio abajo del arco, que es donde se salta porque es donde
  vas rapido, entraba en `Jump` cayendo y `Jump` se va a `Fall` en el mismo frame.
  El boton SOLTABA y no saltaba. Medido: `vy -8.8 -> -10.0`, con la fila de
  control del doble salto en `+10.7`. Ahora pasa un `piso_vertical`, aplicado con
  `maxf` y no con una asignacion: garantiza un salto entero sin quitarte el que ya
  llevabas si saltas desde la subida del arco. Misma forma que el suelo de la
  patada (regla dura #29).
- **LOS TRES RECURSOS AEREOS SON UN PRESUPUESTO**, no tres cuentas. El salto
  aereo lo reponia solo `recargar_aire()` —suelo, agua, canto, parry, wall-jump—
  mientras que la cuerda y las patadas volvian tambien al tocar PARED o acertar
  una patada. En mitad de una cadena el boton de salto dejaba de responder con los
  otros dos vivos, y eso se lee como que el salto esta roto y no como que se ha
  gastado. Ahora `recargar_moveset()` repone los tres con un gesto: tocar algo.
- **El tope de velocidad pasa a ser un OBJETIVO** (regla dura #12): salir del arco
  a 34 m/s ya no se corta a 22 en un frame, decae. Con eso desaparece
  `momentum_libre`, que era el parche que hacia falta mientras el corte existia.
- **Una por tiempo de vuelo**, y la recarga vive en UN solo sitio: en
  `_physics_process`, despues de mover, cuando hay suelo o pared. La condicion se
  lee igual que la regla.

Etapa 3: **EL CIRCUITO** (`tools/Moveset.tscn`). El criterio de exito del parche
esta escrito como una frase —«encadeno cuerda -> patada -> pared -> cuerda sin
tocar el suelo»— y hasta ahora no habia ningun sitio donde comprobarla: el Gym
tiene las piezas sueltas, pero una cadena que se puede esquivar no prueba nada.

- **No hay suelo.** Solo tres sitios donde se aterriza —SALIDA, PARED y META— y
  entre ellos vacio. La condicion «sin tocar el suelo» no es una regla que haya
  que vigilar: es la forma del sitio.
- **EL HUECO SALE DE `-- auto`, NO DE UNA CUENTA.** La cuenta a mano daba 22 m y
  era optimista: medido, con 22 la fila sin patear se quedaba a **4.2 m** de la
  pared, o sea que una suelta un poco mejor lo cruzaba sin patear y el eslabon
  dejaba de ser obligatorio. Con 26 las tres filas dicen lo que tienen que decir
  —pateando toca la pared, sin patear se queda a 8.2 m, y sin la pared delante
  sobran 9.5 m—. **La tercera fila existe porque las otras dos no bastan**: con la
  pared puesta el vuelo se PARA en ella, asi que "toca la pared" no distingue
  llegar justo de llegar de sobra.
- **EL CIRCUITO DA LA VUELTA, y no por gusto.** La primera version ponia el cuarto
  ancla detras de la pared y el banco dijo `cadena 3/4`: se llega a la pared a
  **y=17.4** y la pared mide 22, asi que la linea de vision a cualquier cosa
  detras entra en el muro y el filtro la descarta —correctamente—. Y subir a verla
  tampoco vale, porque **un pendulo no gana altura**: el arco devuelve como mucho
  lo que caiste. Un circuito que lo pidiera seria imposible y pareceria un bug del
  jugador. Con el ancla en ESTE lado sale `cadena 4/4 sin pisar`, y ademas mejora:
  obliga a girar la camara en el aire, que es la habilidad de verdad.
- **Y el cartel de la salida dice el gesto que funciona, no el que uno supone.**
  De pie sobre la plataforma la Z engancha pero el arco no arranca —el suelo te
  sostiene y la restriccion no EMPUJA, solo impide alejarse—. Lo cazo `-- auto` en
  su primera pasada: la traza decia `Grapple > Idle` y x=2.5. El gesto es mantener
  la Z y **andar al vacio**.

Etapa 2: **LA PATADA** (`StateKick`, `content/data/attacks/patada.tres`). Un solo
movimiento ofensivo donde habia doce entradas de combate y 26 `AttackData`.

**Se escribio DOS VECES, y la segunda por una razon que conviene no olvidar.** La
primera version cumplia el encargo sobre el papel y se sentia mal. El banco
—`tools/MedirPatada.tscn`, escrito ANTES de tocar nada— lo dijo en cinco lineas:

| | antes | ahora |
|---|---|---|
| entrando a 29.8 m/s | salia a **18.0** (−11.8) | sale a **29.8** (+0.0) |
| entrando cayendo a −19.9 | salia a **0.0** | sale a **+2.0** |
| saltar a mitad | seguia en `Kick` | `Jump` |
| conectar | vy **0.0** | vy **+10.0** y las dos cargas |

- **LA VELOCIDAD ES UN SUELO, NO UN VALOR.** Escribia 18 m/s cada frame, o sea que
  **te quitaba velocidad por usar tu propio moveset**. Eso rompe de frente la ley 5
  del rediseño y, peor, el principio rector. Ahora garantiza 18 y no resta nada.
- **La gravedad se SUSPENDE y se DEVUELVE.** Ponia la vertical a cero y te soltaba
  a cero: caias a plomo desde parado. Ahora flota durante el gesto y al salir
  devuelve `max(la que traias, patada_salida_vertical)` — **y el respiro es solo
  para el AIRE**: darselo a ras de suelo te despega, el contacto se rompe y se
  rearma, y el flanco de recarga reabre el spam por la puerta de atras.
- **SE PUEDE SALIR DE ELLA.** Saltar o tirar de la cuerda la cortan. Se miran con
  `peek()` y no se consumen: el frame siguiente lo resuelve quien sabe hacerlo
  —`GroupAirborne`, con su wall-jump y su coyote— en vez de duplicar aqui media
  docena de reglas que ya existen.
- **Es traversal antes que ataque.** 0.25 s sin gravedad: 4.5 m de hueco cruzados
  en linea recta como minimo, y mas si venias mas rapido. Fisica de Mario 64, y
  por eso la trayectoria se puede leer entera antes de pulsar.
- **Conectar DERROTA, REBOTA y RECARGA.** El rebote es lo que convierte a un
  enemigo en una plataforma: sin el, golpear era el final de una linea en vez de un
  eslabon. El gesto TERMINA en el impacto para que puedas elegir lo siguiente
  mientras subes.
- **`patada_cargas` esta en TRES.** Es el numero que mas cambia como se siente el
  aire, y por eso es un entero y no un `bool`. Medido con su fila de control: la
  misma caida da **0.95 s de aire y 6.7 m** sin patear y **2.05 s y 34.1 m**
  encadenando. Con una sola carga el aire era un compromiso que se resolvia en el
  primer medio segundo; con tres es un sitio donde se vive, que es lo que hace
  *Pseudoregalia* con las Sun Greaves al completo.
  El tope se respeta: en caida limpia y sin nada que rozar salen **3 y no mas**. Si
  cruzas terreno salen mas, y eso es la mecanica funcionando —tocar pared recarga—,
  no un agujero.
- **LA RECARGA ES UN FLANCO DE CONTACTO, NO UN NIVEL**, y ahi esta el anti-spam.
  Con un nivel —"recarga mientras haya suelo"— la patada se devuelve el mismo
  frame en que se gasta: patear a ras de suelo, seguir pisando, recargar, y
  machacar el boton es un dash continuo a 18 m/s. Con un flanco hay que SALIR y
  VOLVER, y eso convierte la recarga en un gesto. Se lee igual que la regla
  escrita: "se recarga AL TOCAR" es un evento, no un estado.
- **Y LA PATADA TAMPOCO ESTABA EN `Attached`.** Mismo fallo de la regla dura #13
  que la cuerda tuvo en la 3.12, visto otra vez: una accion compartida que existe
  en `Grounded` y en `Airborne` y no en el tercero. Con eso, **colgado del arco el
  boton de ataque no hacia nada** y la cadena cuerda → patada —que es el criterio
  de exito del rediseño— no se podia ejecutar. Lo cazo una CAPTURA, no un test: el
  panel decia `Grapple` con `attack_light` en el buffer sin consumir.
- **Se quedan el parry, el wall-run y el nado**, pedidos expresamente. El parry
  perfecto ya no contraataca —ese `AttackData` se fue con los otros— sino que
  **quiebra al atacante y devuelve las dos cargas**: el premio pasa de daño a
  movilidad, que es la moneda del juego que hay ahora.
- **En el agua no se pega.** `StateSwim` y `StateUnderwater` reclaman la pulsacion
  sin hacer nada con ella, y eso es la decision: nadar es traversal puro, y una
  patada de 18 m/s con gravedad cero dentro del agua seria un atajo que se salta
  la fisica del medio entero.
- **EL GOLPE NO SE SENTIA, Y ERAN TRES NUMEROS.** Reportado como «la patada se
  siente meh, no es como que sienta que conecte». El banco lo dijo en una linea:
  `conectar con un enemigo   PAUSA 0 frames   victima: MURIO en el acto`.
  · **La pausa global duraba CERO.** Se pedia desde el `_physics_process` del
	jugador y se descontaba en el del autoload, que corre ANTES: la pausa de un
	frame se apagaba antes de que nadie llegara a leerla. Ahora es un NUMERO DE
	FRAME absoluto (`Engine.get_physics_frames() + n`), contra el que no hay orden
	que respetar. Medido: 0 -> 4 frames.
	Y la tabla que la calculaba producia 1..3 frames donde `docs/03 §3.2`
	documenta 50/90/160/250 ms: llevaba mintiendo desde el 3.03.
  · **No congelaba a la VICTIMA.** `StateKick` pasaba solo `[player]` y era el
	unico sitio del proyecto que lo hacia. El enemigo seguia moviendose mientras
	tu te congelabas, y eso no se lee como un impacto sino como que te ha pasado
	algo A TI. `Golpe` lleva ahora `victima`, que la rellena la `Hurtbox`.
  · **El impacto se dibujaba en el pecho del jugador**, a un metro largo de lo
	golpeado. Ahora sale en `golpe.punto`.
  **Y LO QUE HOY SE VE DE UN GOLPE ES SOLO LA PAUSA.** `HitstopManager.congelar()`
  para `AnimationTree`s y este juego se prueba con capsulas grises (regla dura
  #7): no hay animacion que parar. Hasta que existan, un impacto se comunica
  parando el mundo y moviendo a la victima, y nada mas.
- **LA LANZA PASA A SER LA DIANA DE POGO** (`SpearSuspendida`). Reportado: *«no
  le veo mucho uso a la lanza»* y *«tenia pensado un proyectil que se le pueda
  hacer pogo»*. Son el mismo hueco visto por los dos lados.
  Conectar con un enemigo lo MATA en el acto —200 de dano, 999 de poise—, asi que
  sobre el no hay segundo pogo: hay un rebote y se acabo lo que habia que pisar.
  Para que «conectar y rebotar» sea un BUCLE hace falta algo que SOBREVIVA al
  golpe, y eso no se arregla bajando un numero de dano —eso es balance— sino
  teniendo un objeto que no es un enemigo.
  Ahora el vuelo no termina en el suelo: la lanza se para a los 11 m y **se queda
  flotando 2.5 s**. Mientras flota lleva una `Hurtbox` del bando enemigo, asi que
  **la patada no sabe que esto existe**: la consulta de `Hitbox` es la de siempre
  y encuentra una hurtbox mas. Un verbo nuevo que no toca el verbo viejo.
  · **Una lanzada, un pogo.** Al recibir la patada se cae. Si se quedara flotando
	se podria subir por ella sin fin, y eso es una escalera al cielo (regla #27).
  · **El rebote SI, la recarga NO.** La ley 4 recarga al tocar suelo, pared o
	enemigo: tres cosas que pone el NIVEL. Tu lanza la pones tu, y recargar
	pateandola seria movimiento perpetuo con dos pasos.
  · **NO es un ancla de cuerda**, y se descarto a proposito: el 4.00 quito justo
	eso —tirar la lanza, acertar, y solo entonces tener un punto— por ser un verbo
	de movimiento convertido en una cadena de tres acciones. Y ademas la
	COLOCACION de las anclas es el diseño de nivel (es contra lo que se eligio el
	alcance de 19 m): un ancla portatil hace cualquier pared enganchable y el
	nivel deja de importar.
  · **Y una hurtbox se apaga por CAPA, no por `monitorable`.** Lo cazo el banco:
	con la lanza guardada en la mano, «conectar con un enemigo» pasaba a decir
	`victima: sigue en pie` — la patada estaba golpeando la lanza del propio
	jugador a distancia cero, y como `max_objetivos` es 1 el enemigo no llegaba a
	existir para el golpe. `monitorable` solo decide si otras areas la detectan
	monitorizando; `intersect_shape` encuentra cualquier area por su capa.
- **La patada es la LLAVE del punto debil** (`etiquetas = [perforante]`). Con un
  solo ataque tiene que serlo, o un coloso seria invencible. Y por eso el
  `ColosoMediano` pasa de 400 de vida a **3000**: con la llave la patada hace
  200 x 3.5 = 700 en el punto debil, asi que con 400 moria de un golpe — y un
  coloso no se mata a golpes, se abre.

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

**Parche 3.15 — LA ESTACION DE JAM** (`src/world/EstacionJam.gd`). Ocho puestos en
corro que tocan juntos, estilo *Sky*. Tercera manifestacion del mismo Kuramoto
—bandada, luciernagas, esto— y la primera que CONSUME el `pitch` y la `amplitud`
que `Enjambre` publicaba desde el 3.11 sin oyente. Esta plantada en el Gym
(-16, 0, 14) y ademas tiene banco propio en `tools/Jam.tscn`.

- **El instrumento es el PUESTO, no el agente.** El agente trae el ritmo y el
  puesto el registro. Sin eso el unisono seria una sola voz mas fuerte y no un
  acorde.
- **PENTATONICA, y esa es la regla entera.** Sin segundas menores ni tritonos,
  ocho voces sin director no pueden chocar — es lo que en *Sky* deja tocar juntos
  a dos desconocidos. Y por eso **el registro se cuenta en GRADOS de la escala y
  no en semitonos**: repartir 24 semitonos entre ocho puestos da saltos de 3.43 y
  redondeando salen notas de fuera. Medido, **143 de 480 combinaciones**.
- **Notas, no un zumbido.** La fase del Kuramoto no modula un tono continuo: ES el
  pulso. Sincronizarse se OYE como que se juntan los ataques —41 ms al vecino con
  r>0.82 contra 59 con r<0.40—, y **se aprieta un 30% y no un 90% a proposito**:
  el acoplamiento se suelta en `orden_saciedad` = 0.86, asi que el corro nunca
  cuadra del todo. Una banda perfectamente cuadrada suena a secuenciador.
- **Un solo altavoz, no ocho**, y sintesis por tabla de onda. Ocho
  `AudioStreamPlayer3D` son ocho buffers que rellenar desde GDScript cada frame
  para una cosa que siempre se escucha como un conjunto.
- **Sin colision.** Tarima, taburetes y musicos son escenografia: un obstaculo en
  medio del Gym rompe las medidas de movimiento sin avisar.
- **LA HOJA DE NOTAS** (`src/ui/PanelJam.gd`), que se abre con **E** estando al
  lado. Es la rejilla de rombos y circulos de la referencia, dibujada con `_draw()`
  y no con 143 botones. Dos rejillas: el TECLADO de 5x3 suena y no escribe —es la
  audicion—, y la HOJA es **una columna por musico y una fila por paso**, asi que
  marcar una celda es decirle a ESE de los ocho que ataque en ESE momento.
  · **El cabezal corre con la fase MEDIA del enjambre**, no con un temporizador
	propio. Eso fusiona las dos mitades en vez de ponerlas una al lado de la otra:
	cuanto mas juntos van los ocho, mejor tocan lo que escribiste. Con la hoja
	vacia vuelven a improvisar solos — no hay modo que elegir, lo dice el contenido.
  · **El rombo y el circulo no son decoracion**: el rombo marca los grados PILARES
	de la pentatonica —tonica y quinta— y el circulo los demas. Sin eso son
	cuadrados iguales y no hay donde apoyar la vista.
  · **Cada celda dice su NOTA**, en solfeo y con octava —SOL3, LA4—, y la hoja
	lleva la nota RAIZ de cada musico como cabecera de columna. Sin nombres la
	rejilla es bonita y muda: se pulsa a ciegas y no hay forma de volver a
	encontrar la nota que gusto.
  · **Dos mandos**: el COMPAS, que es el unico numero que se juzga a oido, y el
	TONO, que recorre los siete naturales. Cambiar de tono no estropea lo escrito
	—la hoja dice QUIEN toca y CUANDO, no en que altura—.
  · **Y ESCRIBIR NO ES JUGAR**: abrir la hoja desconecta al jugador (regla #26).

**Parche 3.16 — pulido de la estacion.** Las notas dejan de chasquear —tenian un
ataque instantaneo, que es una discontinuidad, y con ocho puestos atacando cinco
veces por segundo el corro sonaba a estatica—; ocho milisegundos de rampa lo
quitan entero. Y **las graves resuenan mas que las agudas**, como una cuerda
larga: sin eso los ocho registros se apagaban a la vez y el corro no tenia suelo.

Los ocho musicos **se distinguen ahora**, y por canales que no mienten: el TAMANO
sale de su registro —cuerpo grande, sonido grave— y el COLOR de su grado en la
escala, que es el mismo numero que decide si la rejilla lo pinta rombo o circulo.
Asi el corro y la hoja se pueden mirar a la vez sin traducir. El brillo queda
libre para el golpe. Y llevan instrumento delante: tres siluetas por grado, que es
lo que se ve de lejos cuando el color se pierde en la niebla.

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
