# Prompts para Claude Code — proyecto ROCK

Copia el bloque que necesites y pégalo en Claude Code dentro de `C:\Jueguitos Sexas\rock`.

---

## PROMPT MAESTRO (el de arranque — pega este primero)

```
Eres el ingeniero principal de ROCK, un juego 3D en Godot 4.7 (Forward+, Jolt Physics, D3D12).
La FASE 0 ya está hecha (ver el estado actual en CLAUDE.md). Lee CLAUDE.md y los cinco
documentos de docs/ antes de escribir una sola línea; son la fuente de verdad y no se
negocian sin decírmelo.

QUÉ ESTAMOS CONSTRUYENDO
Un clon de Shadow of the Colossus donde el jugador tiene la movilidad de un plataformero 3D
moderno estilo Tears of the Kingdom y un combate cuerpo a cuerpo estilizado y cancelable.
Verbos: correr, saltar, doble salto, dash (suelo y aire), planear con la capa, deslizarse,
wall-run, agarrarse de bordes, escalar, parry, esquiva, espada, lanza equipable y lanzable
que al clavarse se convierte en asidero y plataforma, lazo/gancho con zip-swing-pull, y arco.
El contenido real son los colosos: bosses gigantes que son niveles de plataformas EN MOVIMIENTO.

LA ESTÉTICA (esto define el proyecto tanto como el código)
Ruinas de piedra cubiertas de musgo bajo un cielo de crema pálida y plana. Perspectiva aérea
extrema: lo lejano se disuelve en niebla color #EFE8D8. Arcos casi negros (#12180F) que enmarcan
un centro luminoso. Sombras TINTADAS de lavanda (#B6AFC0) y verde profundo, nunca negras ni
oscurecidas. El único elemento saturado en pantalla es el jugador, con su capa azul cobalto
(#2E4E8F) y pelo oro pálido (#E8C86A). Reparto 60/30/10 exacto:
  60% verde antiguo + piedra desaturados (terreno, ruinas, arquitectura)
  30% crema + lavanda (cielo, bruma, profundidad)
  10% acentos (jugador, puntos débiles carmesí #C8322D, objetivos oro, VFX)
La paleta completa con todos los hex está en docs/01_DIRECCION_ARTE.md. Úsala tal cual.
El objetivo emocional es: misterio, onírico, místico, antiguo, silencioso.

CÓMO QUIERO QUE TRABAJES
- Sigue docs/04_ROADMAP.md en orden. Empieza por la FASE 0 y no la saltes.
- Respeta las reglas duras de CLAUDE.md. En particular: ningún número mágico fuera de un
  Resource, todo input pasa por InputBuffer, y SurfaceContext existe desde el primer día
  aunque de momento solo haya suelo estático (si eso se pospone hay que reescribir el
  controlador entero cuando lleguen los colosos).
- Construye primero las herramientas: Gym.tscn y DebugOverlay antes que ninguna mecánica.
  Me ahorran semanas y quiero poder tunear con el juego corriendo.
- Prueba todo con cápsulas grises. No pidas ni esperes assets de arte para validar el feel.
- Escribe GDScript tipado (: float, : Vector3, -> void). Nada de Variant por pereza.
- Comenta en español, solo donde el POR QUÉ no sea obvio. Nada de comentarios que repitan el
  código.
- Cuando termines un bloque, dime exactamente qué probar en el editor y qué debería sentir.

EMPIEZA POR LA FASE 1
Es la fase más importante del proyecto y su hito es el único filtro real: moverse tiene que
ser divertido sin combate, sin enemigos y sin arte. Usa el prompt de la FASE 1 de más abajo.

Antes de escribir código, enséñame el plan de archivos que vas a crear y espera mi visto bueno.
```

---

## PROMPT FASE 1 — el juguete de movimiento

```
Fase 0 cerrada. Vamos a la FASE 1 de docs/04_ROADMAP.md, que es la fase más importante del
proyecto: moverse tiene que ser divertido sin combate, sin enemigos y sin arte.

Construye en este orden, y para en cada punto para que yo lo pruebe:
1. SurfaceContext (con suelo estático de momento) y el LocomotionMotor encima.
2. La FSM jerárquica del jugador con Grounded/Airborne/Attached, cada estado como Node.
3. Salto con TODOS los perdones: gravedad asimétrica (-22 subiendo, -38 cayendo), coyote time
   0.12s, jump buffer 0.15s, jump cut al soltar (x0.45 a la velocidad Y).
4. Dash terrestre y aéreo con sistema de cargas y recarga al tocar suelo.
5. Planeo: caída -3 m/s, velocidad horizontal 12 m/s, banking al girar.
6. Deslizamiento con conservación de momentum en pendiente, wall-run y wall-slide.
7. Bordes: LedgeSensor por raycasts, agarre, colgado, shimmy, subida, y ledge assist
   (si el jugador falla el borde por menos de 0.4m se le concede igual).
8. Escalada libre sobre superficies marcadas con una capa de colisión propia.
9. StaminaComponent unificado que gobierna escalar, planear, correr y dashear. Los ataques
   NO gastan stamina.
10. CameraRig propio con modos Explore y Climb, amortiguación por resorte crítico y
    resolución de colisión por shapecast.

Todos los valores salen de PlayerTuning.tres y deben poder tocarse con el juego corriendo.
El DebugOverlay tiene que mostrar en todo momento: estado de la FSM, velocidad, contenido del
InputBuffer, contactos de suelo, stamina y ventanas activas.

Al final, monta en el Gym una carrera de obstáculos cronometrada que obligue a encadenar
salto + dash + planeo + deslizamiento + agarre de borde. El hito de la fase es que me apetezca
repetirla para bajar mi tiempo.
```

---

## PROMPT FASE 2 — combate flashy

```
FASE 2 de docs/04_ROADMAP.md: el combate. El objetivo del hito es que 30 segundos de combo
contra tres cápsulas grises se vean bien EN VÍDEO, sin arte y sin VFX.

Lo que hace que se sienta flashy no son las animaciones, son las ventanas de cancelación y el
hitstop. Priorízalos.

1. HitBox y HurtBox como Area3D con capas propias, y DamageResolver central.
2. AttackData como Resource con todos los campos de docs/03_ARQUITECTURA_MECANICAS.md §3.1.
   Ningún ataque se escribe en código: se crea un .tres.
3. HitstopManager: congela el AnimationTree del atacante y del receptor más 1-3 frames de
   micro-pausa global. NUNCA Engine.time_scale, porque eso se siente como lag.
   Escala: ligero 50ms, pesado 90ms, parry 160ms, punto débil de coloso 250ms.
4. Cadena ligera de 3 golpes con encadenado por buffer.
5. Las ventanas de cancelación, que son el núcleo: ataque a dash siempre desde el impacto,
   ataque a salto solo tras conectar, dash a ataque siempre. Y lo más importante: conectar un
   golpe EN EL AIRE restaura una carga de dash. Ese detalle es lo que convierte el combate en
   un juego de mantenerse en el aire.
6. Parry: ventana 0.16s con los primeros 0.06s como perfecto. Al acertar: hitstop 160ms,
   zoom punch de cámara, destello #F2F0E6, onda radial, y el enemigo entra en GuardBreak.
   El perfecto además ralentiza al enemigo 0.8s y abre un contraataque. Fallar cuesta 0.4s
   de recuperación vulnerable: tiene que doler.
7. Esquiva con i-frames y variante perfecta.
8. PoiseComponent, reacciones de daño direccionales, knockdown y guard break.
9. Ataque aéreo, launcher y plunge con impacto en área.
10. TargetingSystem con SOFT-lock (la cámara sugiere, no encadena) y CameraMode_Combat.
11. Los tres Guardianes de Ruina como cápsulas con IA mínima: Lancero agresivo, Escudo que
    existe para practicar el parry, y Vigía a distancia.

Cuando esté, grábame un vídeo de prueba y dime qué números tocar si algo no pega.
```

---

## PROMPT FASE 3 — lanza y lazo

```
FASE 3: la lanza y el lazo. Lee docs/03_ARQUITECTURA_MECANICAS.md §4 y §5.

LANZA — es el sistema más importante del juego después del movimiento, porque es la
herramienta de progresión vertical.
Máquina de estados propia: Holstered, Wielded, InFlight, Embedded, Grounded, Returning.
- Empuñada cambia el moveset entero: más alcance, más lenta, barrido en área.
- Apuntar en el aire baja el time_scale local a 0.35 con coste de stamina.
- Carga al mantener pulsado: más velocidad y penetración.
- CLAVADA es la clave: al impactar en superficie válida se reparenta al hueso o superficie,
  hereda su SurfaceContext, y registra a la vez un ClimbAnchor (te puedes enganchar con el
  lazo o agarrar a mano) y una PlatformSurface de 0.4m (te puedes PARAR ENCIMA).
  Si se clavó en un coloso, es un asidero permanente aunque el coloso se sacuda.
- spear_vault: si hay una lanza clavada cerca, el jugador se impulsa con ella como pértiga.
- Recuperación por curva Bezier hacia la mano, no en línea recta. Con catch_window: atraparla
  en el momento justo da un frame de invulnerabilidad y encadena directo a un thrust.
- Solo hay UNA lanza. La escasez es la mecánica: decidir dónde la clavas es táctico.

LAZO — tres modos elegidos por contexto de lo que apuntas: Zip a anclajes fijos, Swing a
superficies altas, Pull para RigidBody3D estilo Ultrahand.
Para el balanceo NO uses un joint de física en el jugador: restricción analítica, es decir, si
la distancia supera la longitud proyectas la posición al radio y eliminas la componente radial
de la velocidad. Estable y afinable. La cuerda visual sí puede ser verlet cosmético.

ARCO con apuntado en cámara lenta, incluido poder disparar mientras estás agarrado escalando.

Al final monta un puzzle-gym: una torre de 60 metros que solo se pueda subir combinando
lanza + lazo + planeo, sin una sola escalera. Ese es el hito.
```

---

## PROMPT FASE 4 — el primer coloso (el vertical slice)

```
FASE 4, la que define si el juego existe: el coloso #1.
Lee docs/03_ARQUITECTURA_MECANICAS.md §1 y §6 enteros antes de empezar.

EMPIEZA POR LA HERRAMIENTA, NO POR EL COLOSO:
1. tools/ColossusTestRoom.tscn: una plataforma que se traslada, rota sobre varios ejes y se
   sacude con los mismos parámetros que tendrá un coloso real, con sliders para todo.
2. Valida SurfaceContext ahí hasta que sea perfecto: cero jitter, cero atravesar geometría,
   el input de cámara correctamente transformado al espacio del frame mientras la plataforma
   gira, y el jugador nunca reparentado en el árbol de escena (reconciliación por delta de
   transform). No pases de aquí hasta que esto sea sólido.

DESPUÉS el coloso:
3. ColossusController con Skeleton3D + AnimationTree movido por root motion.
4. GripSurface (Area3D por hueso, dónde se puede agarrar), ClimbCollider (StaticBody3D que
   siguen huesos, el suelo caminable), WeakPoint con estados oculto/expuesto y HP,
   AnchorPoint para el lazo.
5. ColossusBrain: DORMANT, AWARE, GROUND_PHASE, CLIMB_PHASE, WEAKPOINT_EXPOSED,
   PHASE_TRANSITION, DEATH.
6. ShakeDirector: no sacude al azar. Mide dónde está el jugador en el cuerpo, cuánta stamina
   le queda y cuánto lleva escalando, y elige el evento. Tiene que fallar a propósito a veces.
   El objetivo de diseño es que el jugador CASI se caiga, no que se caiga.
7. ClimbBrace: al sacudirse, el jugador solo puede aguantar mientras la stamina baja rápido.
   Al pasar, ventana de oro para avanzar.
8. CameraMode_Colossus con FramingDirector que mantiene coloso y jugador en cuadro y retrocede
   automáticamente para vender la escala.
9. El coloso #1 completo: 3 fases, 2 puntos débiles, muerte cinematográfica de 8-15 segundos.

REGLA DE DISEÑO QUE NO PUEDES SALTARTE: constrúyelo primero como una estatua QUIETA y juégalo
como nivel de plataformas puro. Solo cuando escalar la estatua quieta sea divertido, ponla a
caminar. Si no funciona quieta, no va a funcionar en movimiento.
```

---

## PROMPT FASE 5 — la estética

```
FASE 5: aplicar la dirección de arte. Lee docs/01_DIRECCION_ARTE.md entero.
Todo color sale de Palette.tres. Ningún hex escrito a mano.

1. banded_surface.gdshader: iluminación cuantizada en 3 bandas en la función light().
   SIN outline negro, la referencia no tiene contornos: el volumen lo da el valor.
   shadow_tint como uniform, con sombra = mix(albedo * ambient, shadow_tint, 0.35).
   Rim light muy sutil en crema para separar siluetas contra la bruma.
2. Post-proceso (CompositorEffect o quad fullscreen):
   a) desaturación por profundidad, que refuerza el 60/30/10 automáticamente y hace que el
      jugador saturado siempre destaque;
   b) overlay de pinceladas en screen-space al 4-8% de opacidad, ANIMADO A 12 FPS, no por
      frame, o el efecto "hierve" y marea;
   c) viñeta cálida muy leve.
3. Afina la niebla: fog_aerial_perspective hasta que el horizonte se disuelva y un coloso
   lejano se lea como silueta plana contra el crema.
4. Hierba en MultiMesh con shader de viento y color por gradiente de altura, de #3E5230 en la
   base a #B0C46B en la punta. El viento tiene que verse en oleadas desde lejos.
5. Bandadas de pájaros blancos (#F2F0E6) con boids simples que se espantan al pasar.
6. VFX en colores de acento. Blanco puro SOLO en el parry perfecto.
7. Un script de editor que valide la paleta: recorre los materiales y marca cualquier material
   de entorno con saturación HSV por encima de 0.35.
8. Kit modular de ruinas: arcos, muros, columnas, escaleras, suelos.

Al terminar, aplica el test de aceptación de docs/01_DIRECCION_ARTE.md §5 a tres capturas y
dime cuál de los cinco puntos falla.
```

---

## PROMPTS SUELTOS ÚTILES

**Afinar el feel**
```
Coge el estado <X> del jugador y hazme un game feel pass: revísalo a 1/4 de velocidad,
lista cada transición que se sienta brusca, propón valores concretos de PlayerTuning para
arreglarla, y explícame en una línea qué cambia cada número.
```

**Auditoría de arquitectura**
```
Audita el código contra las reglas duras de CLAUDE.md. Lista cada violación con archivo y
línea, ordenadas por gravedad. No arregles nada todavía.
```

**Un coloso nuevo**
```
Diseña el coloso #<N>. Empieza por el MAPA DE AGARRES tratándolo como un nivel de plataformas
puro: rutas posibles, saltos requeridos, dónde se puede caer y qué verbo del jugador pone a
prueba cada tramo. Solo después dime su anatomía, sus fases y sus puntos débiles.
```

---

## PROMPT CORRECCIÓN 2.3 — la escalera de velocidad y el ataque de dash

```
Corrección de game feel sobre el controlador y el combate de ROCK. Lee CLAUDE.md y
docs/03_ARQUITECTURA_MECANICAS.md antes de tocar nada. Todos los números nuevos van
expuestos en PlayerTuning.tres o en un AttackData .tres: ninguno dentro de un .gd.

1. EL DASH SE SIENTE LARGO Y RARO — sepáralo en tres estados
El problema es que un solo estado intenta ser evasión y desplazamiento a la vez.
La escalera correcta es:

  sin Shift  ->  caminar (stick suave) · trotar (stick a fondo). Y nada más:
                 la velocidad alta se sostiene a mano, no se regala.
  con Shift  ->  DASH -> SURF -> correr sostenido

  · DASH es un ESQUIVE: corto (0.12 s), seco y UNIDIRECCIONAL. Baja el giro a
    ~120 grados/s. No es para desplazarse, es para salir de un sitio.
  · SURF es el tramo fluido: arranca por encima del sprint (~15 m/s), tiene giro
    ALTO (~320 grados/s) porque es donde se pilota, rozamiento bajo para que el
    momentum se note, alabeo del cuerpo al girar, y decae hacia la velocidad de
    sprint. La referencia es el agua: fluido, continuo, con inercia.
  · Al agotarse (~0.9 s) o al soltar Shift, entrega el testigo a correr. Como
    StateMove ya esprinta si Shift sigue pulsado, la transición no necesita un
    estado extra ni se nota como un frenazo.

Surf va en el grupo Grounded. Debe poder cancelarse a slide (agacharse), a salto y
a ataque, y consumir stamina mientras dura.

2. AÑADE UN ATAQUE DE DASH
Un AttackData nuevo lanzable desde Dash y desde Surf con el ataque ligero. Su
trabajo es CERRAR DISTANCIA: alcance largo (~3.2 m), avance grande (~9), arco
estrecho, recuperación corta. Y que ENCADENE al segundo golpe de la cadena ligera,
para que dash -> golpe -> cadena sea una vía de entrada al combo y no un callejón.
Exponlo como `ataque_dash` en el PlayerController.

3. NO TOQUES LAS FÍSICAS AVANZADAS
El backlog de Active Ragdoll y del grappler con cuerda física está documentado en
docs/03_ARQUITECTURA_MECANICAS.md §11 y está marcado como NO IMPLEMENTAR. Déjalo
como está: el active ragdoll choca con SurfaceContext y esa pelea hay que ganarla
sobre el papel antes de escribir código.

Al terminar, añade las comprobaciones al test funcional (tools/TestFase2.tscn):
que con Shift el dash entra en Surf por encima del sprint, que el Surf entrega a
Move al agotarse, que sin Shift NO entra en Surf, y que el ataque de dash conecta
cerrando distancia. Y pasa la regresión de tools/TestFase1.tscn.
```
