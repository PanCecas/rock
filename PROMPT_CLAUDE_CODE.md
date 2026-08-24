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

---

## PROMPT CORRECCIÓN 2.5 — salto estricto, momentum con techo y frenada de pies

```
Corrección de físicas, salto y combate en ROCK. Lee CLAUDE.md y
docs/03_ARQUITECTURA_MECANICAS.md antes de tocar nada. Todos los números nuevos
van expuestos en PlayerTuning.tres o en un AttackData .tres, nunca en un .gd.

1. EL SALTO NO RESPONDE BIEN
Tiene que ser estricto: 1 pulsación = 1 salto, 2 pulsaciones = doble salto, y se
acabó. Machacar el botón no puede acumular saltos ni producir comportamientos
erráticos. La causa es que cada estado consume la pulsación por su cuenta y una
pulsación puede sobrevivir en el buffer para disparar un segundo salto.
Solución: una PUERTA ÚNICA en el controlador por la que pasan todos los saltos.
Al consumir una pulsación, invalida cualquier otra que siguiera viva en la
ventana, y aplica un intervalo mínimo entre saltos.

2. MOMENTUM CON TECHO, Y EL ATAQUE DE DASH COMO CORTE
- El juego debe premiar CONSERVAR momentum, no machacar salto y dash para ganar
  velocidad. Pero el momentum encadenado sin límite acaba sacando al jugador del
  mapa: aplica un CLAMP DURO a la velocidad horizontal, en un solo sitio (justo
  antes de mover el cuerpo), para que sea imposible olvidarlo al añadir verbos.
- El ataque de dash pasa de estocada a CORTE: al cerrarse la ventana activa,
  un empujón extra (overshoot) que te lleva AL OTRO LADO del objetivo en vez de
  dejarte clavado delante. Y al terminar se sale EN COMBATE —con el soft-lock
  vivo y el siguiente golpe a un clic—, no parado.

3. EL SURF SOBREVIVE AL SALTO
Saltar en mitad de una línea rápida no debe costarte la línea. Al saltar desde
surf, márcalo como pendiente durante unos segundos; al aterrizar con Shift
todavía mantenido, vuelve a surfear con la velocidad que llevabas. Y al salir del
surf de verdad, se sale CORRIENDO, no andando.

4. LA FRENADA DE MARIO 64 ES UNA MANIOBRA DE PIES
El pivote del dash (pedir la dirección contraria para frenar y saltar) solo puede
existir tocando el suelo. En el aire no hay de dónde agarrarse, y clavarse a
media trayectoria rompe la inercia que el juego premia conservar. Valídalo con
is_on_floor().

Al terminar añade las comprobaciones a tools/TestFase2.tscn —spam de salto que no
acumula, clamp que no se supera, pivote inexistente en el aire, surf que
sobrevive al salto— y pasa la regresión de tools/TestFase1.tscn.
```

---

## PROMPT CORRECCIÓN 2.6 — salto responsivo, ataques de surf y aterrizaje en surf

```
Corrección de movimiento, físicas y combate en ROCK. Lee CLAUDE.md y
docs/03_ARQUITECTURA_MECANICAS.md antes de tocar nada. Los números nuevos van en
PlayerTuning.tres o en un AttackData .tres, nunca dentro de un .gd.

1. EL SALTO NO ES RESPONSIVO
Al pulsar salto dos veces rápido, el personaje se queda pegado o directamente no
salta. Tiene que ser inmediato: dos pulsaciones rápidas = dos saltos, sin retraso.
Revisa dos cosas concretas:
  · cualquier cooldown entre saltos se come el doble toque. Si necesitas
    garantizar "una pulsación = un salto", hazlo invalidando la pulsación
    consumida, no bloqueando por tiempo.
  · el doble salto casi siempre se pide ESTANDO YA en el estado de salto. Si tu
    máquina de estados rechaza las transiciones a sí misma, la pulsación y el
    salto aéreo se gastan y no pasa nada. Permite la reentrada explícita.

ALTURA VARIABLE: pulsación corta = salto corto, mantener = salto máximo. Que la
relación sea CONTINUA, no un interruptor: da siempre el impulso de altura máxima
y, al soltar durante la subida, RECORTA la velocidad vertical a la que
corresponde a la altura mínima. Cuanto más mantengas, menos queda por recortar.
Un multiplicador fijo tipo 0.45 deja solo dos alturas posibles.

2. LOS ATAQUES DE SURF NO EXISTEN
Atacar mientras se mantiene Shift saca del modo surf y lanza el ataque de suelo.
La causa es que el grupo de estados corre ANTES que la hoja y le roba la
pulsación. Deja que el estado de surf reclame los botones de ataque y añade dos
variantes que solo existen ahí:
  · Shift + ligero  -> estocada de esgrima: rápida, larga, en la dirección en la
    que SURFEAS (no hacia el enemigo más cercano: la línea que llevas ya es una
    decisión tomada), proyectándote hacia delante, y que al terminar VUELVA al
    surf para no romper la fluidez.
  · Shift + pesado  -> frenazo en seco, sin avance ninguno, con un empujón fuerte
    que manda a los enemigos hacia atrás.

3. DASH AÉREO + SHIFT = ATERRIZAR SURFEANDO
Si se hace un dash en el aire y se mantiene Shift durante la caída, al tocar el
suelo debe entrar en surf automáticamente. No lo resuelvas mirando el input en el
frame exacto del contacto: marca una intención pendiente al salir del dash aéreo
con Shift mantenido y consúmela al aterrizar. Un aterrizaje duro sí debe romper
el flujo; uno normal, no.

Al terminar añade las comprobaciones a tools/TestFase2.tscn —dos pulsaciones
rápidas dan dos saltos, soltar pronto recorta la altura, Shift+ligero lanza el
ataque de surf y no el de suelo, Shift+pesado deja al personaje plantado, y el
dash aéreo con Shift aterriza en surf— y pasa la regresión de TestFase1.tscn.
```

---

## PROMPT CORRECCIÓN 2.7 — agachado, techo, escalada BotW y patada baja

```
Corrección de movimiento y combate en ROCK, en tres partes. Lee CLAUDE.md y
docs/03_ARQUITECTURA_MECANICAS.md antes de tocar nada. Todo número nuevo va en
PlayerTuning.tres o en un AttackData .tres, nunca dentro de un .gd.

PARTE 1 — DOCUMENTACIÓN (solo texto, NO implementar)
En project.md, sección "Ideas Futuras (Por Implementar)", añade:
  1. Minijuego: pasar por dentro de unos aros en el aire sin tocar el suelo.
  2. Minijuego: completar un circuito de obstáculos haciendo parkour.
  3. Enemigo Mediano, cuya particularidad es que su TORSO ES ESCALABLE.
Del tercero, deja anotado por qué importa: es el puente pedagógico hacia los
colosos. El jugador aprende a agarrarse a algo que se mueve en un enemigo que
cabe en pantalla, antes de tener que hacerlo a sesenta metros del suelo.

PARTE 2 — CÓDIGO

1. AGACHARSE, SURF Y TECHO
- Estado Crouch nuevo (quieto y en movimiento). Al entrar en Crouch o en Surf la
  cápsula baja a la mitad, y de forma SUAVE: cambiarla de golpe hace que el
  personaje dé un salto vertical y se ve fatal. Interpola la altura.
- MECÁNICA ESTRICTA DE TECHO: un sensor hacia arriba decide si se PUEDE volver a
  la altura completa. Si hay techo, soltar el botón no basta: el jugador se queda
  agachado hasta salir. Usa un shapecast y no un rayo central; un rayo deja pasar
  al jugador por debajo del canto de una viga y luego lo empotra al estirarse.

2. SALTOS AGACHADOS (Mario Odyssey)
- Quieto y agachado + salto = salto MUCHO más alto. Su precio es tener que
  pararse a cargarlo, así que no compite con el flujo.
- Surfeando + agacharse + salto = LONG JUMP: multiplica el momentum horizontal y
  deja poca vertical. Es distancia, no altura.

  OJO, es el error que más va a costar encontrar: si los grupos de la FSM corren
  ANTES que las hojas, el grupo se queda la pulsación de salto y ejecuta el salto
  genérico; el salto alto y el long jump no llegan a existir nunca. Deja que la
  hoja pueda RECLAMAR la acción (un `maneja_salto()` o equivalente). Lo mismo
  aplica a los ataques.

3. ESCALADA ESTILO BREATH OF THE WILD
- El estado Climb ya existe pero solo funciona en superficies marcadas. Hazlo
  universal: cualquier pared vale. Lo que lo limita es la STAMINA, no el nivel.
  Escalar pasa a ser una decisión de recurso en vez de un carril concedido.
- Mantén una diferencia: la roca lisa cuesta más stamina que un asidero marcado.
  Así las superficies diseñadas siguen siendo especiales sin prohibir el resto.

4. PATADA BAJA (Low Kick)
- Atacar desde Crouch —o estando forzado a agacharse por un techo— ejecuta una
  patada baja en vez del ataque normal.
- Aplica DERRIBO, no aturdimiento: el enemigo se cae y queda una ventana larga
  para rematar. Es lo que le da una razón ofensiva a agacharse.

PARTE 3 — ZONA DE PRUEBAS
En el Gym, genera por código un TÚNEL de 1.2 m de hueco (el jugador mide 1.8),
con techo y paredes laterales para que no se pueda rodear, y una rampa de entrada
que invite a cruzarlo con velocidad. Solo debe poder atravesarse agachado o
surfeando, y una vez dentro NO se debe poder uno levantar. Es la prueba de que
agacharse es un estado y no un botón.

Al terminar añade las comprobaciones a tools/TestFase2.tscn —la cápsula encoge, el
salto agachado supera al normal, bajo el túnel no se puede uno levantar, la patada
baja derriba, y se escala una pared no marcada— y pasa la regresión de
tools/TestFase1.tscn.
```

---

## PROMPT CORRECCIÓN 2.8 — crouch reactivo, paredes por ángulo, dive y agua

```
Extensión del controlador 3D de ROCK. Lee CLAUDE.md y
docs/03_ARQUITECTURA_MECANICAS.md antes de tocar nada. Todo número nuevo va en
PlayerTuning.tres o en un AttackData .tres, nunca dentro de un .gd.

1. AGACHARSE REACTIVO Y SUS TRES SALTOS
El crouch actual se siente flojo y lento. Debe activarse casi al instante
(<0.1 s) y mantenerse solo mientras el botón esté pulsado. Permite caminar
agachado a velocidad reducida. Y dale vocabulario propio: el salto desde
agachado NO es uno, son tres, y los decide lo que estés haciendo.
  · quieto (sin input)   -> BACKFLIP: el DOBLE de fuerza vertical más un empujón
    hacia atrás. La parábola sale del empujón, no de la animación.
  · input lateral        -> SIDE HOP: brinco rápido y BAJO para evadir de lado,
    con i-frames. Poca altura a propósito: es una evasión, no movilidad.
  · avanzando            -> salto normal.

2. PAREDES: RESUELVE EL CONFLICTO ENTRE CLIMB, WALL RUN Y WALL JUMP
Hoy wall-run y wall-jump se pisan. La solución que quiero es de DISEÑO, en dos
niveles, y tiene que ser una regla que el jugador pueda tener en la cabeza:

  PRIORIDAD 1 — si mantienes el botón de agarre, ESCALAS. Punto. Así la
  ambigüedad solo queda entre los dos verbos que NO pediste explícitamente.
    · Escalada libre en 2D sobre la pared (estilo BotW/TotK).
    · Apuntar atrás o sin input + salto -> te SUELTAS con un salto normal hacia
      atrás. Nada de backflips aquí: el backflip es del agachado, y mezclarlos
      confunde.
    · Apuntar arriba o en diagonal superior + salto -> WALL LUNGE: un tirón a lo
      largo de la pared que gana altura y deja el agarre disponible, así que
      encadenar lunges es la forma rápida de subir.

  PRIORIDAD 2 — sin botón de agarre, decide el ÁNGULO con el que llegas, medido
  entre tu dirección de avance y la NORMAL de la pared:
    · de frente (ángulo pequeño) -> no hay componente a lo largo del muro que
      aprovechar, así que rebotas: wall-slide y wall-jump.
    · rozando (ángulo grande) -> ya vas casi paralelo: WALL RUN.
  NO lo decidas por de qué lado te queda la pared: eso es una propiedad del
  sensor, no de tu intención, y es justo por lo que hoy se pisan.

3. DIVE Y DIVE ATTACK
Atacar en el aire LLEVANDO CARRERA es un clavado, no un picado vertical. Sale
igual desde correr que desde surfear: lo que importa es el momentum, no el estado
de origen. Es un modo propio, no una variante de caer: gravedad más fuerte,
empuje hacia delante, giro reducido.
  · Pulsar ataque OTRA VEZ durante el dive lo arma: DIVE ATTACK, con la hitbox
    viva durante TODO el trayecto —no es un golpe con ventana, es un proyectil
    que eres tú— y capaz de LANZAR a los enemigos por el aire.
  · Si el clavado termina en agua, la entrada gana profundidad de verdad y dibuja
    una curva submarina. Una caída normal solo deja flotando.

4. AGUA — FASE 1 (movimiento y transiciones)
  · Volumen de agua como Area3D, no como cuerpo sólido: se atraviesa, y lo que
    cambia es el ESTADO, no la colisión.
  · Nado en superficie: movimiento 2D con el cuerpo flotando. La flotación debe
    ser un MUELLE hacia el nivel del agua, no un booleano: así entrar desde una
    caída se amortigua solo.
  · Tecla de agacharse -> bucear: movimiento 3D completo, usando la base COMPLETA
    de la cámara incluida la vertical. Proyectarla al plano convierte el buceo en
    nadar contra un techo invisible.
  · Mantener salto bajo el agua asciende; al romper la superficie se vuelve a
    nado de superficie automáticamente.
  · Dale grupo propio en la FSM. El agua no es "suelo con otra gravedad": es un
    tercer medio, y los verbos de tierra (coyote, doble salto, dash) no se cuelan.

  NO implementes la Fase 2 (combate acuático por dash e IA de enemigos
  acuáticos). Documéntala en project.md y para.

5. ZONA DE PRUEBAS
Añade al Gym un estanque con torre y trampolín altos, para poder probar el
clavado de verdad y no solo flotar. Ojo: si el suelo del Gym es una losa maciza,
no se puede excavar una piscina con una sola caja — construye el vaso hacia
arriba.

AVISO QUE TE VA A AHORRAR HORAS: en esta FSM los grupos corren ANTES que las
hojas y les roban el input. Cualquier estado con una versión PROPIA de una acción
compartida (el salto del agachado, los ataques del surf, la segunda pulsación del
dive) tiene que poder RECLAMARLA, y el guardia debe existir en TODOS los grupos,
no solo en el de suelo. El fallo siempre es silencioso: se ejecuta la acción
genérica y la específica no llega a existir nunca.

Al terminar añade las comprobaciones a tools/TestFase2.tscn y pasa la regresión de
tools/TestFase1.tscn.
```

---

## PROMPT CORRECCIÓN 2.9 — clavado de Mario 64, fricción de agachado y adherencia

```
Ajustes al Character Controller de ROCK. Lee CLAUDE.md antes de tocar nada. Todo
número nuevo va en PlayerTuning.tres o en un AttackData .tres, nunca en un .gd.

1. SALTOS
- QUITA el backflip del salto agachado. La voltereta se rompe y no aporta nada que
  el impulso no diera ya. Déjalo como un salto vertical MUY fuerte y punto.
- SIDE JUMP de Mario 64: correr, pedir bruscamente la dirección CONTRARIA y
  saltar da un salto lateral más alto. Hoy no funciona.
  Detéctalo en el controlador y no en un estado: el giro brusco ocurre ANTES de
  que exista nada a lo que llamar "estado de girar". Es una lectura del input
  contra el momentum, y ese par solo lo tiene el controlador. Abre una ventana
  corta al detectarlo y que el salto la consuma.

2. ATAQUE DE CLAVADO EN EL AIRE
Atacar en el aire debe hacer un CLAVADO. Una sola pulsación, sin segundo paso y
sin exigir carrera previa: pedir las dos cosas hacía que el ataque aéreo más
visible del juego no apareciera casi nunca.
- Física de Mario 64: velocidad horizontal CONSTANTE en caída libre. Ni
  rozamiento ni aceleración, solo gravedad. Es lo que hace la trayectoria legible.
- Hitbox activa TODO el trayecto, no una ventana. Al impactar, knockback fuerte:
  manda al enemigo volando. Eso es todo lo que tiene que hacer.
- Reparte los botones por CONTEXTO y no por tecla: ligero con enemigo cerca es un
  golpe aéreo, ligero sin nadie a quien pegar es el clavado, y el pesado sigue
  siendo el picado vertical. El mismo botón hace lo único sensato en cada
  situación, que es mejor que obligar a recordar dos.

3. SLIDE Y CROUCH (Mario 64)
- El slide dura demasiado: acórtalo bastante y haz que CEDA al agachado en vez de
  levantarse. Los dos deben formar una sola maniobra continua.
- Agacharse LLEVANDO velocidad aplica fricción y te va parando progresivamente
  hasta quedar estático. El crouch es el freno del sistema de movimiento.
- SLIDE KICK: atacar con ataque ligero durante ese deslizamiento lanza la patada
  deslizante —el salto de conejo— con hitbox viva todo el trayecto. Que termine
  dejándote agachado, no de pie: encadenar patadas debe ser posible.

4. AGUA Y ESCALADA
- En el agua, Shift multiplica la velocidad de nado y de buceo. Hoy no hace nada.
- ADHERENCIA AUTOMÁTICA: caminar contra una superficie perpendicular durante
  ~0.35 s engancha solo, sin pulsar nada. Escalar deja de ser un botón que hay que
  saber y pasa a ser lo que ocurre si insistes contra un muro, que es como se
  descubre en Breath of the Wild. Y si te adheriste sin pulsar nada, tampoco
  deberías soltarte por dejar de pulsar: sal con salto o agachándote.
- Escalando, Shift da un impulso en la dirección 2D del input sobre la pared, con
  coste de stamina de golpe. Es el sprint de escalada de BotW.

RECORDATORIO DE ESTA FSM: los grupos corren ANTES que las hojas y les roban el
input. Cualquier estado con versión propia de una acción compartida tiene que
reclamarla, y el guardia debe existir en TODOS los grupos.

Al terminar añade las comprobaciones a tools/TestFase2.tscn y pasa la regresión de
tools/TestFase1.tscn. Consejo para esos tests: comprueba con LATCHES —si algo
ocurrió en algún momento del paso— en vez de mirar solo el frame final, o
acabarás midiendo timing en lugar de mecánicas.
```

---

## PROMPT CORRECCIÓN 2.01 — landing slide, agua viva y ledge snap

```
Paquete de correcciones al Character Controller de ROCK. Lee CLAUDE.md antes de
tocar nada. Todo número nuevo va en PlayerTuning.tres o en un AttackData .tres.

1. LANDING SLIDE (aterrizaje con crouch bufferizado)
Traer velocidad en el aire y aterrizar manteniendo agacharse NO debe frenar en
seco: transiciona a deslizamiento en la dirección de la inercia. Y que gane
incluso al aterrizaje duro — es la recompensa por haber planificado el
aterrizaje, y sin esa prioridad una caída buena se siente igual que una mala.
Ojo: el slide de aterrizaje CONSERVA el momentum, no le suma el impulso de un
slide normal, o cada caída se convierte en una catapulta.

2. LOS ATAQUES ACUÁTICOS SE QUEDAN ESTÁTICOS
Bajo el agua un golpe ES un desplazamiento: no hay suelo del que empujar, así que
atacar sin moverse no se lee como un golpe, se lee como que el botón no hace
nada. Ligero y pesado deben ser el mismo verbo con distinto peso: un impulso en
la dirección a la que apuntas, con hitbox viva durante el trayecto. Ligero rápido
y largo; pesado más corto y lento pero mucho más fuerte. Iguales en superficie y
buceando: no hay dos movesets, hay uno que respeta el medio.

3. UNDERWATER IDLE DRIFT
Al soltar los controles buceando el personaje no puede quedarse congelado: un
cuerpo quieto en mitad del agua se lee como un error del juego, no como una
pausa. Aplica una oscilación suave (seno) que afecte ligeramente a la posición y
a la rotación. Mueve la VELOCIDAD, no la posición directamente, para que siga
respetando colisiones. Dale fase aleatoria al entrar, o dos inmersiones seguidas
se calcan.

4. NADO DIRIGIDO POR EL VECTOR DE VELOCIDAD
El cuerpo debe alinearse con la dirección en la que NADA, con pitch y yaw reales:
si apuntas al fondo y avanzas, el personaje pica físicamente hacia el fondo.
No lo hagas rotando por ángulos de Euler: al apuntar recto arriba o abajo cruzas
el gimbal, que es justo la situación que se pide bajo el agua. Interpola bases
(`looking_at` + slerp) y ojo con qué eje mira tu modelo.

5. LA STAMINA ACUÁTICA DRENA SIEMPRE Y DEMASIADO
Justo lo contrario de lo que debe ser: flotar quieto o derivar NO puede costar
nada —debería incluso recuperar—, y solo nadar activamente o atacar consume, a un
ritmo mucho más lento. Mueve el gasto del grupo a cada estado: un grupo que drena
por existir hace que el medio entero se sienta un castigo.

6. LEDGE GRAB / SNAPPING
Durante la escalada, o en el aire cerca de un muro, detecta el borde superior:
un raycast frontal para la pared y otro descendente desde encima y algo por
delante de la cabeza para encontrar la esquina. Cuando la altura del personaje
llegue a la del borde, corta la física de escalada libre y haz SNAP: posiciona
las manos exactamente en la esquina y pasa al sub-estado de agarre, esperando el
input para izarse. Sin esto queda el momento tonto de estar trepando por encima
del borde sin poder subir.
Ancla el rayo descendente al PUNTO DE IMPACTO de la pared, no a una fracción fija
del alcance: si no, cae por delante del muro cuando el jugador está pegado a él.

Al terminar añade las comprobaciones a tools/TestFase2.tscn y pasa la regresión de
tools/TestFase1.tscn. Comprueba con latches (si algo ocurrió en algún momento del
paso), no solo en el frame final, o medirás timing en vez de mecánicas.
```

---

## PROMPT CORRECCIÓN 2.02

```
Corrección #2.02 al controlador de movimiento. Antes de tocar código, localiza la
FSM, la locomoción, el crouch, el aterrizaje, el detector de superficies de
escalada y el sistema de nado dirigido por cámara. Integra, no dupliques.

1) STATIONARY CROUCH LANDING
No existe. Aterrizar agachado y prácticamente sin velocidad horizontal debe entrar
en una recepción en cuclillas propia, no obligar a levantarse, y CONSERVAR la
postura agachada al terminar. Con velocidad suficiente se mantiene el aterrizaje
de siempre. Decide con la velocidad horizontal REAL, no solo con el input, y evita
la cadena brusca aire -> landing -> crouch.

2) LÍMITE DE ÁNGULO DE ESCALADA (Climbable Surface Angle Limit)
Hoy solo se trepan muros casi verticales. Calcula el ángulo con la normal del
impacto —`Vector3.Angle(Vector3.up, hit.normal)`, o su equivalente contra el "up"
del marco de referencia si el mundo puede rotar— y acepta de 60° a 90°.
No basta con mover el número: la normal real tiene que usarse ADEMÁS para orientar
al personaje, calcular el offset contra la pared, mantenerlo pegado y alinear su
"arriba" con la inclinación. Una superficie de 60° no puede escalarse con la pose
de un muro de 90°.
Ojo con la geometría: apoyado contra una pendiente de 60°, el pecho del personaje
YA ESTÁ POR ENCIMA de la superficie —la pared se aleja 0.58 m por cada metro que
subes—, así que un único raycast a la altura del pecho no puede ver una rampa por
muchos grados que se le permitan. Hace falta una sonda más baja, con un techo de
ángulo propio para que un escalón vertical no cuente como pared.
Mantén funcionando inicio de escalada, movimiento vertical y lateral, salida,
detección de bordes, offset y animaciones.

3) UPRIGHT ORIENTATION RECOVERY
Al entrar o salir del agua el personaje queda torcido. Es el nado dirigido por
cámara: bajo el agua se escriben los ejes X (pitch) y Z (roll), y el controlador
terrestre solo actualiza Y (yaw), así que esos dos ejes se quedan con la última
inclinación.
En las transiciones Water -> InAir y Water -> Grounded, devuelve el cuerpo a la
vertical: X = 0, Z = 0, Y = yaw actual. Nada de asignación brusca: interpola con
Slerp/RotateTowards durante los primeros fotogramas.
Y en InAir -> Water, la alineación con la cámara también debe interpolarse: sin
snap de pitch ni de roll en el primer frame.

4) RESPETA LOS ESTADOS
No fuerces la rotación cada frame. Aplica la recuperación en las transiciones que
la necesitan y que no interfiera con escalada, nado, dash, movimiento aéreo,
agachado ni animaciones con rotación propia.

5) VALIDACIÓN
Crouch landing: saltar y aterrizar quieto manteniendo agachado; confirmar que
existe la recepción, que no se levanta, y que con movimiento horizontal sigue el
aterrizaje normal.
Escalada: 55° NO, y 60/70/80/90 SÍ. Confirmar que sigue pegado, que la orientación
sigue la normal y que ni flota ni se mete en la pared. Construye rampas de esos
ángulos con el PIE EN LA MISMA LÍNEA: si cada una empieza donde le toca, medirás
lo bien que te colocas en vez del ángulo.
Agua: entrar upright, entrar tras una caída, nadar arriba/abajo, girar con la
cámara sumergido, salir con pitch alto, salir con roll alto, salir en movimiento.
Terminar perfectamente vertical conservando el yaw.

Parámetros configurables como exports, nada hardcodeado, y reutiliza las
utilidades de rotación, estados y detección de superficies que ya existan.
Al terminar resume qué archivos y funciones tocaste y por qué.
```

---

## PROMPT CORRECCIÓN 2.03

```
Corrección #2.03. Antes de tocar código localiza: el crouch, dónde se cambia la
altura de la cápsula, dónde se comprueba el hueco sobre la cabeza, el detector de
suelo/pendiente, el de pared/escalada, dónde se calcula el ángulo de superficie y
dónde se decide Ground vs Climb. Modifica lo que existe; no dupliques sistemas.

1) CROUCH INTELIGENTE Y TEMPORAL
Mientras se mantenga el botón, agachado. Al soltarlo, levantarse si hay espacio;
si no lo hay, seguir agachado TEMPORALMENTE y recuperar la altura en cuanto la
obstrucción desaparezca, sin que el jugador tenga que volver a pulsar nada.
El crouch pedido por el jugador y el impuesto por el techo son cosas distintas:
   quiere agachado + puede levantarse -> postura final
El segundo no puede volverse permanente nunca.

2) LA ALTURA NO LA DECIDEN LAS PAREDES
Investiga por qué acercarse a una superficie inclinada cambia la altura de golpe
antes de arreglarlo. Sospecha de cualquier relación accidental entre detección de
suelo/pendiente/pared/escalada y la altura o el centro de la cápsula. Detectar una
rampa no es agacharse. La altura solo cambia si alguien pide postura, si no cabes
de pie, o en una transición que de verdad lo requiera.

3) UNA SOLA CLASIFICACIÓN DE SUPERFICIE
   < 75°      -> CAMINAR
   75° - 110° -> ESCALAR
   > 110°     -> ni una cosa ni la otra
Calcúlalo con la normal real del impacto y expón minClimbAngle / maxClimbAngle
como variables configurables. El MISMO ángulo tiene que alimentar el sensor de
suelo, el de pared, la escalada y el límite de suelo del motor: no puede haber un
detector que diga "walkable" mientras otro dice "climbable" sobre la misma cara.
Ojo al orden de prioridades que eso deja: lo que deja de ser caminable es
exactamente lo que empieza a ser escalable, así que la primera superficie que se
puede trepar es también la primera por la que te resbalas. Si el deslizamiento va
antes que el agarre, pedir escalar en el ángulo límite no hará nada.

4) ORIENTACIÓN DE ESCALADA POR LA NORMAL
75°, 90° y 105° tienen que sentirse distintos: orientación, offset y alineación
salen de hit.normal, no de asumir una pared vertical.

5) MOVILIDAD
Carrera un poco más rápida, sin tocar aceleración, frenado ni control.
Ataque aéreo y ataque deslizante con MUCHO más recorrido: la referencia es el
salto largo de Mario. Que se sientan herramientas de movilidad, no animaciones.
Mira también el rozamiento con el que terminan, no solo el impulso con el que
empiezan: un buen impulso comido por un buen freno no va a ninguna parte.

6) SIDE JUMP EN DOS TIEMPOS
Frenazo y salto no pueden ocurrir en el mismo frame. Primero se planta, y solo
después sale el impulso. La preparación tiene que ser corta y jugable.

7) NO IMPLEMENTAR: vehículo/mascota montable. Solo anotarlo como idea futura.

8) VALIDACIÓN
Crouch: mantener, soltar en abierto, soltar bajo un techo, salir del techo,
acercarse a una rampa (la altura no cambia), caminar por pendientes.
Ángulos: 60/70/74 caminan; 75/80/90/100/110 escalan; 111/120 no.
Movilidad: carrera, aéreo, deslizante, side jump.

9) INFORME FINAL, no un "hecho": cambios y en qué archivo, qué debería funcionar
ahora, valores finales, checklist de testing manual, y qué NO has podido
comprobar. No inventes resultados de pruebas que no hayas ejecutado.
```
