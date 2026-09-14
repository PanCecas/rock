@tool
class_name PlayerTuning
extends Resource
## Todos los números del jugador. REGLA DURA (CLAUDE.md #1): si se toca para que
## "se sienta bien", vive aquí y no en un .gd.
##
## Valores iniciales de docs/03_ARQUITECTURA_MECANICAS.md §2.1.
## Se edita con el juego corriendo: el controlador relee el Resource cada frame.

# --- Salto ------------------------------------------------------------------
@export_group("Salto")
## ALTURA VARIABLE, en metros. El impulso inicial siempre da para `altura_max`;
## soltar el boton durante la subida recorta la velocidad vertical hasta la que
## corresponde a `altura_min`. Cuanto mas mantengas, menos queda por recortar, asi
## que la relacion entre tiempo pulsado y altura es CONTINUA, no un interruptor.
@export_range(0.2, 6.0, 0.05) var altura_salto_min: float = 1.0
@export_range(0.5, 8.0, 0.05) var altura_salto_max: float = 2.6
## Gravedad asimétrica: subir flotante, caer contundente. Es medio game feel gratis.
@export_range(-60.0, -5.0, 0.5) var gravedad_subida: float = -22.0
@export_range(-90.0, -5.0, 0.5) var gravedad_caida: float = -38.0

## Perdón: puedes saltar durante este tiempo tras dejar el suelo.
@export_range(0.0, 0.4, 0.01) var coyote_time: float = 0.12
## Perdón: un salto pulsado antes de aterrizar se ejecuta al tocar suelo.
@export_range(0.0, 0.4, 0.01) var jump_buffer: float = 0.15
@export_range(-60.0, -1.0, 0.5) var velocidad_terminal: float = -45.0
@export var saltos_aereos: int = 1
## Tiempo minimo entre dos saltos. A CERO a proposito: `InputBuffer.invalidar()`
## ya garantiza una pulsacion = un salto, y cualquier valor por encima de un frame
## se come el doble toque rapido —el salto se sentia pegajoso y a veces se perdia
## del todo—. Queda expuesto solo por si hiciera falta amortiguar un mando ruidoso.
@export_range(0.0, 0.5, 0.01) var salto_intervalo_min: float = 0.0

# --- Locomoción -------------------------------------------------------------
@export_group("Locomoción")
## Los tres peldaños de la locomocion sin Shift. NO se eligen por la fuerza del
## stick: se encadenan por TIEMPO manteniendo la direccion, que es lo que da la
## sensacion de que el personaje coge carrerilla.
## Caminar estaba en 3.0 y se sentia arrastrado: es la velocidad con la que
## empiezas SIEMPRE, antes de que la carrerilla haga nada, asi que es la primera
## impresion del movimiento y no puede ser la mas floja.
@export_range(0.5, 12.0, 0.1) var velocidad_caminar: float = 4.2
@export_range(0.5, 16.0, 0.1) var velocidad_trotar: float = 6.4
@export_range(1.0, 20.0, 0.1) var velocidad_correr: float = 9.4
## Solo con Shift. Ver el grupo Surf.
@export_range(1.0, 30.0, 0.1) var velocidad_sprint: float = 11.0

@export_subgroup("Rampa de carrerilla")
## Segundos moviendote hasta pasar de caminar a trotar.
@export_range(0.05, 3.0, 0.05) var tiempo_a_trotar: float = 0.35
## Segundos hasta llegar a correr. La rampa es continua, no escalonada: los
## nombres son referencias, no estados.
@export_range(0.1, 5.0, 0.05) var tiempo_a_correr: float = 1.25
## Constante de tiempo del suavizado de velocidad (segundos). Bajo = instantaneo
## y seco; alto = pastoso. 0.16 es el punto donde se nota peso sin sentir retardo.
@export_range(0.01, 1.0, 0.01) var suavizado_velocidad: float = 0.16
## Como de rapido se pierde la carrerilla al soltar la direccion. Alto = se
## reinicia en cuanto paras; bajo = perdona los cambios de rumbo.
@export_range(0.5, 20.0, 0.1) var perdida_carrerilla: float = 3.5
@export_range(1.0, 200.0, 1.0) var aceleracion_suelo: float = 60.0
## Autoridad direccional EN EL AIRE. Estaba en 25 y permitia invertir por completo
## un rumbo de 9.4 m/s en menos de un segundo: el salto no comprometia a nada.
@export_range(1.0, 200.0, 1.0) var aceleracion_aire: float = 12.0
## Velocidad que se puede alcanzar en el aire PARTIENDO DE PARADO. Es el techo que
## le da peso al salto: si saltas quieto, en el aire te mueves poco; si saltas
## lanzado, conservas lo que traias. Antes este suelo era `velocidad_correr` y por
## eso un salto vertical llegaba a maxima velocidad de carrera sin pisar el suelo.
@export_range(0.0, 20.0, 0.1) var control_aereo_techo: float = 3.2
## AUTORIDAD PARA GIRAR EN EL AIRE, en m/s2, y separada de `aceleracion_aire` a
## proposito: son dos preguntas distintas.
##
##   aceleracion_aire -> cuanta velocidad puedes GANAR en el aire. Baja a
##     proposito: si no, un salto desde parado llega a velocidad de carrera y la
##     carrerilla no sirve de nada.
##   giro_aire        -> cuanto puedes REDIRIGIR lo que ya llevas. No crea
##     velocidad: solo la gira.
##
## Estaban unidas y por eso salir del surf por un desnivel dejaba al jugador
## volando en linea recta: 12 m/s2 contra 13.5 m/s de inercia son 1.6 s para
## girar 90 grados. Medido en el Gym.
@export_range(1.0, 200.0, 1.0) var giro_aire: float = 38.0
@export_range(1.0, 200.0, 1.0) var frenado_suelo: float = 45.0
@export_range(0.0, 200.0, 1.0) var frenado_aire: float = 4.0
## Frenado cuando vas MÁS RÁPIDO que tu velocidad objetivo y sigues empujando.
## Muy bajo a propósito: es lo que hace que la velocidad de un dash o de un slide
## sobreviva unos segundos en vez de evaporarse en dos frames.
@export_range(0.5, 60.0, 0.5) var frenado_momentum: float = 6.0
## EL PATINAJE. Frenado al SOLTAR la direccion llevando velocidad. Tiene parametro
## propio porque es el numero del "ice skating" y se ajusta solo: `frenado_suelo`
## lo multiplican ademas el aterrizaje y el picado.
##   6  -> como antes de la 2.05: seis metros de resbalon.
##   26 -> planta los pies en metro y medio. Conserva la sensacion de peso.
##   45 -> parada en seco, casi sin derrape.
@export_range(0.5, 120.0, 0.5) var frenado_soltar: float = 26.0
## Grados por segundo a los que el modelo gira hacia la dirección de movimiento.
@export_range(90.0, 2160.0, 10.0) var giro_grados_seg: float = 900.0
## CLAMP DURO de la velocidad horizontal. El momentum se conserva y se encadena,
## pero nunca se acumula sin techo: sin esto, encadenar dash y surf termina
## sacando al jugador del mapa.
## EL TOPE ES UN OBJETIVO, NO UN CORTE. Ver `velocidad_drag`.
@export_range(5.0, 60.0, 0.5) var velocidad_maxima: float = 22.0
## Con que rapidez se vuelve al tope cuando vas por encima, en 1/s.
##
## **Esto es lo que convierte el clamp en un SOFT CAP**, y es la diferencia entre
## que el momentum ganado se sienta ganado o no. Medido con el clamp duro: salir
## de un arco a 34 m/s te dejaba a 22.0 **en el primer frame**. Un frame. Todo lo
## que habias construido encadenando desaparecia sin que nada lo explicara en
## pantalla.
##
## Con drag, 34 decae hacia 22 con constante de tiempo 1/`velocidad_drag`: sigues
## siendo rapido un rato y lo vas perdiendo, que es lo que se puede leer y lo que
## premia haber encadenado bien.
@export_range(0.1, 20.0, 0.1) var velocidad_drag: float = 1.6
## TOPE DURO absoluto, en m/s. Este si corta, y no es de game feel: es la red que
## impide atravesar geometria entre dos frames de fisica. A 60 Hz, 55 m/s son 0.92
## m por tick — por encima de eso un muro de un metro deja de ser un muro.
@export_range(20.0, 200.0, 1.0) var velocidad_tope_duro: float = 55.0

# --- Dash: esquive UNIDIRECCIONAL -------------------------------------------
# El dash es un esquive, no un desplazamiento. Corto, seco y en una sola
# dirección. Lo que viene DESPUÉS (Surf) es lo que fluye y se puede pilotar.
# Antes duraba 0.16 s con giro de 420°/s y se sentía largo y raro justamente
# porque intentaba ser las dos cosas a la vez.
@export_group("Dash")
@export_range(1.0, 20.0, 0.1) var dash_distancia: float = 3.6
@export_range(0.05, 1.0, 0.01) var dash_duracion: float = 0.12
@export_range(0.0, 0.5, 0.01) var dash_iframes: float = 0.10
@export_range(0.0, 2.0, 0.01) var dash_recuperacion: float = 0.10
@export var dash_cargas_aire: int = 1
## TAP vs HOLD: si el botón sigue pulsado más de esto al acabar el dash, se
## encadena a sprint continuo en vez de volver a carrera normal.
@export_range(0.05, 1.0, 0.01) var dash_tap_max: float = 0.20
## Corrección de rumbo DURANTE el dash. Baja a propósito: es un esquive
## unidireccional. Quien pilota es el Surf que viene después.
@export_range(0.0, 1440.0, 10.0) var dash_giro_grados_seg: float = 120.0
## Fracción de la velocidad del dash que sobrevive al terminar sin mantener Shift.
@export_range(0.0, 1.0, 0.01) var dash_salida_mult: float = 0.45
## Grados dentro de los que el dash se autoalinea al enemigo cercano (Fase 2).
@export_range(0.0, 90.0, 1.0) var dash_correccion_grados: float = 20.0

@export_subgroup("Pivote (frenada estilo Mario 64)")
## Producto escalar por debajo del cual el input cuenta como "dirección opuesta".
## -1 exige exactamente lo contrario; -0.6 deja margen para diagonales traseras.
@export_range(-1.0, 0.0, 0.05) var dash_pivote_umbral: float = -0.6
## Fracción del dash que hay que haber recorrido antes de poder pivotar. Evita
## que una corrección brusca al arrancar se lea como frenada.
@export_range(0.0, 1.0, 0.05) var dash_pivote_min: float = 0.25
## Frames SEGUIDOS pidiendo la direccion contraria. Un giro brusco de camara
## invierte el significado de "adelante" durante un frame; exigir constancia evita
## frenadas que el jugador no pidio.
@export_range(1, 12, 1) var dash_pivote_frames: int = 2
## Salto vertical del pivote, en m/s. Alto: la frenada es un salto de verdad.
@export_range(0.0, 25.0, 0.1) var dash_pivote_salto: float = 11.5
## Empuje horizontal hacia la nueva dirección. Bajo a propósito: es un FRENAZO.
@export_range(0.0, 20.0, 0.1) var dash_pivote_impulso: float = 3.0

# --- Surf: el tramo fluido entre el esquive y la carrera ---------------------
# Manteniendo Shift, el dash desemboca aquí en vez de frenar. Es un estado
# deslizante y muy pilotable —"como el agua"— que se agota solo y entrega el
# testigo al sprint. Sin Shift no existe: solo hay caminar y trotar.
@export_group("Surf")
## Velocidad al salir del dash. Por encima del sprint: se nota que vienes lanzado.
@export_range(1.0, 40.0, 0.1) var surf_velocidad: float = 17.5
## Velocidad de crucero del surf una vez consumido el envión del dash. Es la
## velocidad de "correr" real del juego: el surf NO caduca, se sostiene mientras
## mantengas Shift, y la stamina es su único límite.
@export_range(1.0, 30.0, 0.1) var surf_crucero: float = 13.5
## Giro. ALTO: aquí es donde se pilota, y es lo que lo hace sentir fluido.
@export_range(30.0, 1080.0, 10.0) var surf_giro_grados_seg: float = 320.0
## Rozamiento. Bajo = el momentum se conserva y se siente que patinas.
@export_range(0.0, 40.0, 0.5) var surf_friccion: float = 5.0
@export_range(0.0, 100.0, 0.5) var surf_stamina: float = 10.0
## Alabeo del cuerpo al girar surfeando. Vende la inercia desde lejos.
@export_range(0.0, 45.0, 1.0) var surf_alabeo: float = 16.0
## Alabeo del wall-run, en grados. **Estaba escrito a mano dentro de
## `StateWallRun`** —un `22.0` suelto— y es exactamente lo que prohibe la regla
## dura #1: un numero que se toca para que se sienta bien viviendo en un `.gd`.
## Sus dos hermanos, el del surf y el del planeo, si estaban aqui.
@export_range(0.0, 60.0, 1.0) var wallrun_alabeo: float = 22.0
## Ventana durante la que saltar NO cancela el surf: al aterrizar se recupera.
## Saltar en mitad de una linea rapida no deberia costarte la linea.
@export_range(0.0, 6.0, 0.1) var surf_persistencia: float = 2.5

# --- Planeo -----------------------------------------------------------------
@export_group("Planeo")
@export_range(-20.0, 0.0, 0.1) var planeo_caida: float = -3.0
@export_range(1.0, 30.0, 0.1) var planeo_velocidad: float = 12.0
@export_range(1.0, 90.0, 1.0) var planeo_giro_grados_seg: float = 120.0
## Grados de alabeo visual al girar. La capa vende el planeo.
@export_range(0.0, 60.0, 1.0) var planeo_alabeo: float = 28.0
## Retardo antes de que la capa pueda abrirse. Con "mantener para planear" evita
## que un salto corto normal despliegue la capa nada mas despegar.
@export_range(0.0, 1.0, 0.01) var planeo_retardo_despliegue: float = 0.12

# --- Agachado -----------------------------------------------------------------
@export_group("Agachado")
## Fraccion de la altura normal de la capsula al agacharse o surfear.
@export_range(0.3, 1.0, 0.05) var agachado_altura: float = 0.5
## Segundos que tarda la capsula en encogerse o estirarse. Instantaneo hace que
## el personaje "salte" verticalmente al agacharse; lento se siente pastoso.
@export_range(0.01, 1.0, 0.01) var agachado_transicion: float = 0.12
@export_range(0.5, 8.0, 0.1) var velocidad_agachado: float = 2.6
## Altura del salto estatico desde agachado. Muy por encima del salto normal: es
## el salto alto de Mario Odyssey, y su precio es tener que pararse a cargarlo.
@export_range(1.0, 12.0, 0.1) var altura_salto_agachado: float = 4.4
## LONG JUMP: agacharse surfeando y saltar. Multiplica la velocidad horizontal y
## deja poca vertical: es distancia, no altura.
@export_range(1.0, 4.0, 0.05) var longjump_mult: float = 1.55
@export_range(1.0, 20.0, 0.1) var longjump_vertical: float = 6.5

@export_subgroup("Side jump y friccion de agachado")
## SIDE JUMP de Mario 64: correr, pedir la direccion CONTRARIA y saltar dentro de
## la ventana da un salto lateral mas alto. `umbral` es el producto escalar por
## debajo del cual el giro cuenta como brusco.
@export_range(-1.0, 0.0, 0.05) var sidejump_umbral: float = -0.55
## Velocidad minima a la que hay que ir para que el giro brusco cuente.
@export_range(0.0, 15.0, 0.1) var sidejump_velocidad_min: float = 5.0
## Ventana desde el giro brusco en la que saltar produce el side jump.
@export_range(0.05, 1.0, 0.01) var sidejump_ventana: float = 0.28
@export_range(1.0, 3.0, 0.05) var sidejump_mult: float = 1.45
@export_range(0.0, 25.0, 0.1) var sidejump_lateral: float = 12.5
## LA PLANTADA. El side jump ocurre en dos tiempos —frenar, y despues saltar— y
## esto es lo que dura el primero. Corto: cinco centesimas se ven, diez ya se
## sienten como input perdido.
@export_range(0.0, 0.4, 0.01) var sidejump_frenazo: float = 0.09
## Deceleracion durante la plantada. Brutal a proposito: la inercia vieja tiene
## que estar muerta antes de que llegue el impulso nuevo.
@export_range(10.0, 300.0, 5.0) var sidejump_frenado: float = 120.0
## Deceleracion al agachado LLEVANDO velocidad. Agacharse frena, como en Mario 64.
@export_range(1.0, 100.0, 1.0) var crouch_friccion: float = 14.0
## Por debajo de esta velocidad el salto agachado cuenta como estatico.
@export_range(0.0, 6.0, 0.1) var crouch_quieto: float = 1.5

@export_subgroup("Slide kick (salto de conejo)")

# --- Deslizamiento ----------------------------------------------------------
@export_group("Deslizamiento")
## Velocidad mínima para poder entrar en slide. Debajo de esto no engancha.
@export_range(0.0, 20.0, 0.1) var slide_velocidad_min: float = 5.0
## Impulso que se suma al entrar. Deslizarse tiene que GANAR velocidad, no perderla.
@export_range(0.0, 15.0, 0.1) var slide_impulso: float = 3.5
@export_range(0.0, 30.0, 0.1) var slide_friccion: float = 7.0
## Aceleración extra cuesta abajo por unidad de pendiente. Premia leer el terreno.
@export_range(0.0, 60.0, 0.5) var slide_pendiente: float = 22.0
## Bajado de 2.5: el slide duraba tanto que dejaba de sentirse como un recurso y
## pasaba a ser una forma de moverse. Ahora cede pronto al agachado, que es quien
## te frena.
@export_range(0.1, 5.0, 0.05) var slide_duracion_max: float = 0.9
@export_range(0.0, 15.0, 0.1) var slide_salto_extra: float = 2.0

# --- Pared (wall-jump estilo Mario 3D) --------------------------------------
@export_group("Pared")
@export_range(0.0, 20.0, 0.1) var wallrun_velocidad: float = 8.5
@export_range(0.1, 5.0, 0.05) var wallrun_duracion: float = 1.6
## Gravedad durante el wall-run: casi nula al principio, crece al final.
@export_range(-30.0, 0.0, 0.5) var wallrun_gravedad: float = -4.0
@export_range(0.1, 10.0, 0.1) var wallrun_velocidad_min: float = 4.0
## Caida durante el wall-slide. Baja = da tiempo a reaccionar y encadenar.
@export_range(0.0, 20.0, 0.1) var wallslide_caida: float = 3.2
## Con cuanta fuerza se pega el cuerpo al muro mientras resbala, en m/s.
##
## Es un valor pequeño y va SOLO en la componente contra la pared. Antes se
## escribia con `motor.impulso()`, que reemplaza el vector horizontal entero: o
## sea que rozar un muro a 30 m/s te dejaba a 1.2 yendo hacia el, y toda la
## velocidad que llevabas A LO LARGO de la pared desaparecia. La intencion del
## numero era "no despegarse solo" y lo que hacia era borrarte.
@export_range(0.0, 8.0, 0.1) var wallslide_pegado: float = 1.2
## Rozamiento del muro sobre la velocidad que va A LO LARGO de el, por segundo.
##
## Esto si es una perdida legitima —estas restregandote contra piedra— pero es un
## rozamiento y no un borrado: conservas la linea y la vas perdiendo. Es el "bonk
## preservation" del genero.
@export_range(0.0, 20.0, 0.1) var wallslide_friccion: float = 2.2
## Velocidad minima CONTRA la pared para engancharse sin tener que empujar hacia
## ella. En Mario basta con chocar; exigir input hace que se sienta esquivo.
@export_range(0.0, 10.0, 0.1) var wallslide_entrada_min: float = 1.0

## Impulso VERTICAL del wall-jump, absoluto en m/s. Es el que manda: en Mario el
## salto de pared sube de verdad, no es un empujon lateral con propina.
@export_range(0.0, 25.0, 0.1) var walljump_vertical: float = 10.5
## Empuje perpendicular a la pared.
@export_range(0.0, 25.0, 0.1) var walljump_lateral: float = 9.0
## Cuanto momentum A LO LARGO de la pared sobrevive. Con 0 el salto se siente
## rigido: da igual como llegues, siempre rebotas igual.
## **EL ABANICO DEL WALL KICK: cuanto cambia la salida segun hacia donde MIRAS.**
##
## Es la mecanica que el documento de referencia llama «la joya», y la razon es
## que convierte un boton en una funcion continua: *el angulo con el que sales de
## una pared es el reflejo del angulo al que estabas mirando al tocarla*.
## Perpendicular da ALTURA y poca distancia; rasante da DISTANCIA y poca altura.
## Dos jugadores con las mismas teclas tienen techos de movilidad distintos, y eso
## no se compra con ningun otro numero de este archivo.
##
## **Es un ABANICO alrededor de los valores de siempre, no dos numeros nuevos**, y
## eso es a proposito: en 0.0 vuelven los angulos fijos de antes —10.5 y 9.0— asi
## que se puede apagar y comparar sin tocar nada mas. En el centro del abanico
## (incidencia 0.5) devuelve tambien los de siempre; solo abre los extremos.
##
## El documento pedia ademas REFLEJAR el momentum entrante. No se hizo, y no por
## olvido: se probo y el banco dijo que no cambiaba ni un numero —al pulsar saltar
## ya se ha pasado por un frame de `StateWallSlide`, que reescribe la velocidad, y
## no queda nada entrante que reflejar—. Esa friccion aqui ya estaba resuelta en
## `StateWallSlide` y medida: rozar a 30 m/s conserva el 92-98%.
##
## Medido antes de existir, con las tres miradas contra el mismo muro:
## `vy 10.5 / plano 9.0` **las tres**. El angulo no era una mecanica, era un dato
## que el juego ignoraba.
@export_range(0.0, 0.8, 0.05) var walljump_abanico: float = 0.30
@export_range(0.0, 1.5, 0.05) var walljump_conserva: float = 0.55
## Cuanto pesa la direccion que pide el jugador con la camara. Permite orientar
## el rebote sin poder volver contra la pared.
@export_range(0.0, 1.5, 0.05) var walljump_intencion: float = 0.5
## Ventana tras un wall-jump en la que el control aereo baja de autoridad. Sin
## esto, seguir apuntando a la pared cancela el propio salto y no despegas nunca.
@export_range(0.0, 0.6, 0.01) var walljump_bloqueo: float = 0.14
@export_range(0.0, 1.0, 0.05) var control_bloqueado_mult: float = 0.25
## ANGULO que decide entre wall-jump y wall-run, en grados, medido entre tu
## direccion de avance y la NORMAL de la pared.
##
## Llegar de frente (angulo pequeno) no deja correr: no hay componente a lo largo
## del muro que aprovechar, asi que rebotas. Llegar rozando (angulo grande) si:
## ahi el wall-run es la lectura natural. Antes lo decidia de que lado quedaba la
## pared, que es una propiedad del sensor y no de como llegas, y por eso los dos
## verbos se pisaban.
## LA frontera de los verbos de pared, en grados entre tu avance y la normal.
## Por debajo vas de frente —escalas o resbalas—; por encima vas rozando y corres.
## Un solo numero, sin hueco ni solape entre las dos mitades.
@export_range(10.0, 89.0, 1.0) var pared_umbral_frontal: float = 55.0
## Por debajo de esta velocidad plana, el angulo se mide con el INPUT y no con el
## movimiento: pegado a un muro y casi parado, la velocidad plana es ruido.
@export_range(0.1, 8.0, 0.1) var pared_avance_minimo: float = 1.5

## PERDON: sigues pudiendo saltar de la pared este tiempo despues de perder el
## contacto. Es lo que hace que encadenar dos muros no exija precision de frame.
@export_range(0.0, 0.6, 0.01) var pared_coyote: float = 0.15
## Tiempo tras un wall-jump en que la misma pared se ignora, para poder alternar.
@export_range(0.0, 1.0, 0.01) var pared_bloqueo: float = 0.18
## Cuanto se reorienta la camara detras del salto de pared. 0 = nada.
@export_range(0.0, 1.0, 0.05) var camara_realinea_walljump: float = 0.6

# --- Dive (clavado) ----------------------------------------------------------
@export_group("Dive")
## LIGERO: poco alcance y mucha caida. Es un CLAVADO, no una diagonal larga.
## Estaba en 21/-7 y con eso salia casi igual que el pesado: los dos eran la misma
## parabola tendida y el jugador no tenia forma de distinguirlos jugando. Ahora el
## ligero cae a plomo hacia delante y el pesado es el que viaja.
@export_range(0.0, 40.0, 0.5) var dive_impulso: float = 13.0

@export_subgroup("Clavado pesado")

# --- Agua ---------------------------------------------------------------------
@export_group("Agua")
## Multiplicador al mantener Shift dentro del agua. Nadar rapido tambien es un
## verbo: sin el, el agua se siente como un castigo de tiempo.
@export_range(1.0, 4.0, 0.05) var nado_sprint_mult: float = 1.8
@export_range(0.5, 20.0, 0.1) var nado_velocidad: float = 4.6
@export_range(0.5, 20.0, 0.1) var buceo_velocidad: float = 5.4
## Flotabilidad en superficie: cuanto empuja hacia arriba al hundirse.
@export_range(0.0, 60.0, 0.5) var agua_flotacion: float = 18.0
@export_range(0.0, 20.0, 0.1) var agua_rozamiento: float = 4.5
## Velocidad de ascenso manteniendo salto bajo el agua.
@export_range(0.5, 20.0, 0.1) var buceo_ascenso: float = 5.0
## Impulso hacia abajo al bucear desde la superficie.
@export_range(0.0, 20.0, 0.1) var buceo_impulso: float = 5.0
## Profundidad extra que gana una entrada en DIVE frente a una caida normal. Es
## la curva de clavado del esquema.
@export_range(0.0, 40.0, 0.5) var dive_penetracion: float = 16.0
## Gasto NADANDO ACTIVAMENTE. Bajado de 4.0: el agua drenaba incluso flotando
## quieto y a un ritmo que convertia cualquier travesia en una cuenta atras. El
## agua es una via, no un castigo.
@export_range(0.0, 60.0, 0.5) var agua_stamina: float = 1.2

@export_subgroup("Deriva y orientacion")
## DERIVA: oscilacion suave al soltar los controles buceando. Sin esto el cuerpo
## se queda congelado en mitad del agua y parece un error, no una pausa.
@export_range(0.0, 2.0, 0.01) var deriva_amplitud: float = 0.22
@export_range(0.0, 5.0, 0.05) var deriva_frecuencia: float = 0.9
@export_range(0.0, 20.0, 0.5) var deriva_balanceo: float = 7.0
## Velocidad a la que el cuerpo se alinea con una orientacion 3D COMPLETA, en
## grados/seg. La usan el nado —alinearse con el vector de velocidad— y la
## escalada —inclinarse con la pendiente—: son el mismo gesto, el cuerpo dejando
## de estar vertical, y compartir el ritmo es lo que hace que se lean igual.
@export_range(30.0, 1080.0, 10.0) var giro_3d_grados_seg: float = 420.0

## UPRIGHT ORIENTATION RECOVERY. Nadar y escalar inclinan el cuerpo en pitch y
## roll; la logica de tierra solo escribe el yaw, asi que al volver a tierra esos
## dos ejes se quedaban con la ultima inclinacion y el personaje salia torcido.
## Esto es la vuelta a la vertical: ni instantanea ni eterna.
@export_range(30.0, 1440.0, 10.0) var enderezar_grados_seg: float = 540.0
## Techo de la recuperacion. Pasado este tiempo se asienta a la vertical exacta.
@export_range(0.05, 2.0, 0.01) var enderezar_duracion: float = 0.35

@export_subgroup("Combate acuatico")

# --- Aterrizaje -------------------------------------------------------------
@export_group("Aterrizaje")
## LANDING SLIDE: aterrizar con velocidad manteniendo agachado NO frena, entra en
## deslizamiento conservando la inercia. Es la maniobra que premia planificar el
## aterrizaje en vez de sufrirlo, y por eso gana incluso al aterrizaje duro.
@export_range(0.0, 20.0, 0.1) var landing_slide_min: float = 4.5
## STATIONARY CROUCH LANDING: caer agachado y CASI PARADO no es un deslizamiento,
## es una recepcion. Por debajo de esta velocidad horizontal real —el input no
## decide esto, lo decide la velocidad— el aterrizaje se amortigua en cuclillas.
## Entre este valor y `landing_slide_min` queda a proposito una banda muerta que
## cae en el aterrizaje normal de siempre.
@export_range(0.0, 20.0, 0.1) var landing_crouch_max: float = 2.0
## Lo que dura la recepcion. Es corta: absorber, no castigar.
@export_range(0.0, 1.0, 0.01) var landing_crouch_duracion: float = 0.18
## Velocidad de impacto a partir de la que el aterrizaje es "duro" y cuesta control.
@export_range(0.0, 60.0, 0.5) var aterrizaje_duro: float = 20.0
@export_range(0.0, 1.0, 0.01) var aterrizaje_duro_duracion: float = 0.22

# --- Clasificacion de superficies -------------------------------------------
# UN SOLO numero decide si una superficie se camina, se escala o no se toca. Antes
# habia dos —el limite de suelo y el del sensor de pared— y podian contradecirse:
# la misma rampa era "demasiado empinada para andar" y "demasiado tumbada para
# escalar" a la vez, y el jugador se quedaba resbalando sin poder hacer nada.
@export_group("Superficies")
## SLOPE LIMIT. Frontera entre CAMINAR y ESCALAR, y tambien el `floor_max_angle`
## del cuerpo: si el motor y la FSM usaran numeros distintos, uno de los dos
## mentiria. Estuvo en 75 y era demasiado: se caminaba por paredes casi
## perpendiculares y no se sentia como andar, se sentia como un error.
@export_range(0.0, 89.0, 1.0) var climb_angulo_min: float = 45.0
## Techo de la escalada. Por encima de 90 son desplomes: la pared se te viene
## encima. Mas de esto ya es un techo, y de un techo no se cuelga nadie.
@export_range(90.0, 180.0, 1.0) var climb_angulo_max: float = 110.0
## Requisito EXTRA del wall-run y el wall-slide. No es una segunda clasificacion
## de superficie —esa sigue siendo una sola—: es que correr en horizontal por la
## ladera de una colina de 50 grados no es un verbo, es un error. Escalar si vale
## ahi; correr, no.
@export_range(45.0, 110.0, 1.0) var wallrun_angulo_min: float = 70.0

# --- Bordes y escalada ------------------------------------------------------
@export_group("Bordes y escalada")
## Perdón: si fallas el borde por menos de esto, se te concede el agarre.
@export_range(0.0, 1.5, 0.05) var ledge_assist: float = 0.4
@export_range(0.1, 3.0, 0.05) var ledge_alcance: float = 0.7
@export_range(0.1, 3.0, 0.05) var ledge_altura_max: float = 2.1
## ESCALADA ESTILO BOTW: cualquier pared vale, no solo las marcadas como
## CLIMBABLE. Lo que la limita es la stamina, no el nivel: es lo que convierte
## escalar en una decision de recurso en vez de en un carril.
@export var escalada_universal: bool = true
## Multiplicador de gasto en superficies NO marcadas. La roca lisa cansa mas.
@export_range(1.0, 5.0, 0.1) var escalada_coste_liso: float = 1.6
## ADHERENCIA AUTOMATICA: caminar contra una pared perpendicular durante este
## tiempo engancha solo, sin pulsar nada. Escalar deja de ser un boton que hay
## que saber y pasa a ser lo que ocurre si insistes contra un muro.
@export_range(0.05, 2.0, 0.05) var escalada_auto_tiempo: float = 0.35
## Impulso al pulsar Shift escalando, en la direccion 2D del input. Es el salto
## de escalada de Breath of the Wild.
@export_range(0.0, 30.0, 0.5) var escalada_impulso: float = 9.0
@export_range(0.0, 100.0, 1.0) var escalada_impulso_stamina: float = 14.0
@export_range(0.1, 6.0, 0.1) var escalada_velocidad: float = 2.4
## Cuanto se empuja el cuerpo CONTRA la superficie cada segundo, a lo largo de su
## normal real. Es lo que hace que la escalada siga el relieve en vez de despegarse
## en cada saliente. Iba contra la normal aplanada, y sobre una rampa de 60 grados
## eso empujaba en horizontal: el personaje se separaba de la pendiente.
@export_range(0.0, 4.0, 0.05) var escalada_adherencia: float = 0.6
## COYOTE DE LA ESCALADA. Perder el contacto un frame no es soltarse: sobre relieve
## irregular el sensor parpadea, y sin esta ventana la escalada entraba en bucle
## Climb -> Fall -> Climb. Es el mismo perdon que el coyote del salto, aplicado a
## la pared.
@export_range(0.0, 1.0, 0.01) var escalada_coyote: float = 0.18
@export_range(0.1, 8.0, 0.1) var shimmy_velocidad: float = 1.6

# --- Picado (plunging attack) -----------------------------------------------
# El picado es el unico ataque del juego cuyo poder lo decide el JUGADOR con una
# decision previa: desde donde se tira. Escalar treinta metros para caer sobre un
# grupo tiene que valer mas que dar un saltito, o el traversal y el combate siguen
# siendo dos juegos distintos que comparten personaje.
@export_group("Picado")

@export_subgroup("Escalado por altura de caida")

# --- Combate ----------------------------------------------------------------
@export_group("Combate")
## Fraccion de la velocidad horizontal que sobrevive al plantarse a parriear.
##
## Era CERO —`velocity = Vector3.ZERO`— y eso incumple la regla del genero:
## convierte, escala o proyecta, nunca borres. Un parry es un compromiso y frenar
## es parte de el, pero llegar a 15 m/s y quedarte clavado en un frame se siente
## como chocar contra el aire. Medido antes: 15.0 -> 0.0.
@export_range(0.0, 1.0, 0.05) var parry_retencion: float = 0.25
@export_range(0.02, 0.6, 0.01) var parry_ventana: float = 0.16
@export_range(0.01, 0.3, 0.01) var parry_ventana_perfecta: float = 0.06
@export_range(0.0, 2.0, 0.01) var parry_recuperacion_fallo: float = 0.4
@export_range(0.0, 0.5, 0.005) var hitstop_parry: float = 0.16
## ESCALADO POR INERCIA. Un golpe que llega lanzado empuja mas que uno parado.
##
## Vivia con los numeros de la cuerda porque el primero que lo uso fue el golpe en
## viaje, que ya no existe. Pero no era suyo: `escalar_por_inercia()` la usa
## tambien `EnemyEstampado`, y un numero de combate compartido va en Combate.
##
## A `carga_inercia_ref` m/s el empuje sale tal y como esta en su `.tres`.
@export_range(1.0, 60.0, 0.5) var carga_inercia_ref: float = 18.0
## Suelo y techo del escalado. El techo es lo que lo mantiene MODERADO: llegar
## lanzado pega mas, pero no convierte cualquier golpe en un cañon.
@export_range(0.0, 1.0, 0.05) var carga_inercia_min: float = 0.45
@export_range(1.0, 4.0, 0.05) var carga_inercia_max: float = 1.55

# --- Stamina ----------------------------------------------------------------
# EL FEEDBACK. «El 40% del feel no esta en la fisica», dice el documento de
# movimiento, y aqui era cierto de la peor manera: el moveset medido al frame y
# **ni una sola particula en todo `src/`**. La pantalla decia lo mismo a 30 m/s
# que a 8.
#
# Va en su propio grupo a proposito: **nada de aqui decide nada del juego**. Si
# se pone todo a cero, el jugador se mueve exactamente igual.
@export_group("Feedback")
## Cuanto se aplasta al aterrizar, en fraccion de altura. 0.35 es un buen chafado
## sin que parezca que se rompe.
@export_range(0.0, 0.7, 0.01) var feedback_squash_max: float = 0.35
## Cuanto tarda en recuperarse, en segundos. El documento pide 0.12 y tiene razon
## en el orden de magnitud: por debajo de 0.08 no se ve y por encima de 0.2 parece
## que el personaje se ha quedado pegado al suelo.
@export_range(0.02, 0.6, 0.01) var feedback_squash_duracion: float = 0.12
## A partir de que velocidad de impacto se empieza a notar el aplastado, en m/s.
## Por debajo, aterrizar de un escalon daria el mismo golpe que caerse de una
## torre y el canal dejaria de significar nada.
@export_range(0.0, 30.0, 0.5) var feedback_squash_desde: float = 6.0
## Cuanto se estira al subir, en fraccion. Mas discreto que el aplastado porque es
## CONTINUO: lo que en un evento es carácter, sostenido es una deformidad.
@export_range(0.0, 0.5, 0.01) var feedback_estirado: float = 0.14
## Cada cuanto deja un fantasma la estela, en segundos.
@export_range(0.01, 0.4, 0.01) var feedback_estela_paso: float = 0.035
## Cuanto dura cada fantasma, en segundos.
@export_range(0.05, 1.5, 0.05) var feedback_estela_vida: float = 0.22
## Sacudida al aterrizar duro. **Pequeña a proposito**: el documento subraya que
## el screenshake solo va en eventos discretos y con 0.25, y que sacudir de forma
## continua no comunica velocidad — comunica que la camara esta rota.
@export_range(0.0, 1.5, 0.05) var feedback_shake_impacto: float = 0.25

@export_group("Stamina")
## Barra única: escalar, planear, correr, dashear y aguantar sacudidas.
## Los ataques NO gastan stamina: esto no es un souls.
@export_range(10.0, 500.0, 1.0) var stamina_max: float = 100.0
@export_range(0.0, 100.0, 0.5) var stamina_escalar: float = 6.0
@export_range(0.0, 100.0, 0.5) var stamina_planear: float = 4.0
@export_range(0.0, 100.0, 0.5) var stamina_sprint: float = 8.0
@export_range(0.0, 100.0, 0.5) var stamina_dash: float = 12.0
@export_range(0.0, 200.0, 1.0) var stamina_regen_suelo: float = 55.0
@export_range(0.0, 200.0, 1.0) var stamina_regen_colgado: float = 6.0
@export_range(0.0, 3.0, 0.05) var stamina_retardo_regen: float = 0.35

# --- Cámara -----------------------------------------------------------------
@export_group("Cámara")
@export_range(1.0, 20.0, 0.1) var camara_distancia: float = 6.5
@export_range(0.0, 4.0, 0.05) var camara_altura_objetivo: float = 1.35
## Palmo que la lente guarda por encima del agua nadando en superficie. Ver
## `CameraRig._sacar_del_agua()`.
@export_range(0.0, 3.0, 0.05) var camara_margen_agua: float = 0.55
@export_range(0.01, 1.0, 0.01) var camara_sensibilidad: float = 0.28
@export_range(-89.0, 0.0, 1.0) var camara_pitch_min: float = -65.0
@export_range(0.0, 89.0, 1.0) var camara_pitch_max: float = 55.0
@export_range(0.01, 1.0, 0.01) var camara_suavizado: float = 0.12
@export_range(20.0, 110.0, 1.0) var camara_fov: float = 62.0

@export_subgroup("FOV dinámico — la sensación de velocidad")
## Grados de FOV que se abren por cada m/s POR ENCIMA de la velocidad de correr.
## Es lo que hace que un disparo de resortera a 33 m/s se sienta como un disparo
## y no como caminar rápido.
@export_range(0.0, 3.0, 0.01) var camara_fov_por_ms: float = 0.42
## Tope de esos grados extra. Sin tope, el disparo mete un ojo de pez y se pierde
## la lectura del espacio justo cuando más falta hace.
@export_range(0.0, 40.0, 0.5) var camara_fov_extra_max: float = 15.0
## Lo rápido que ABRE (1/s). Alto: el golpe de velocidad tiene que llegar con el
## impulso, no medio segundo después.
@export_range(0.5, 30.0, 0.1) var camara_fov_abre: float = 9.0
## Lo rápido que CIERRA (1/s). **Más lento que abrir a propósito.** Un FOV que
## abre y cierra igual de rápido se lee como un parpadeo; abriendo de golpe y
## cerrando despacio, el disparo deja resaca y se siente potente.
@export_range(0.5, 30.0, 0.1) var camara_fov_cierra: float = 2.2

@export_subgroup("Look ahead — mirar a donde vas")
## Metros que la cámara se adelanta en la dirección del movimiento, a tope de
## velocidad. Moderado a propósito: adelantarse demasiado deja al personaje
## pegado al borde de la pantalla y se pierde de vista lo que tiene detrás.
@export_range(0.0, 12.0, 0.1) var camara_adelanto: float = 2.4
## Velocidad a la que el adelanto llega a su máximo, en m/s.
@export_range(1.0, 60.0, 0.5) var camara_adelanto_ref: float = 26.0
## Suavizado del adelanto (1/s). Bajo: el adelanto tiene que ARRASTRARSE detrás
## del movimiento, no pegarse a él, o gira con cada corrección del stick.
@export_range(0.2, 20.0, 0.1) var camara_adelanto_respuesta: float = 3.0
## Cuánto del adelanto es VERTICAL. Separado porque subir y bajar disparado —que
## es lo que hace la resortera— pide ver arriba, y eso no se consigue con el
## adelanto horizontal.
@export_range(0.0, 2.0, 0.05) var camara_adelanto_vertical: float = 0.55

@export_subgroup("Sacudida")
## Metros de desplazamiento de encuadre por unidad de intensidad.
##
## La sacudida va en `h_offset`/`v_offset` de la `Camera3D`, no en la rotación del
## brazo: rotar el brazo hace ORBITAR la cámara alrededor del jugador, que es
## mucho más mareante y además la mete en la geometría. Desplazar el encuadre
## sacude la imagen sin mover la cámara de sitio.
@export_range(0.0, 1.0, 0.005) var camara_shake_offset: float = 0.11
## Frecuencia del ruido de la sacudida. Alto = vibración; bajo = bandazo.
@export_range(0.5, 60.0, 0.5) var camara_shake_frecuencia: float = 22.0
## Grados de rotación que se mantienen además del desplazamiento. Un poco de giro
## vende el impacto; mucho marea.
@export_range(0.0, 3.0, 0.05) var camara_shake_giro: float = 0.35


## Velocidad inicial de salto: siempre la de altura maxima. v = sqrt(2 * g * h)
func velocidad_salto() -> float:
	return sqrt(2.0 * absf(gravedad_subida) * altura_salto_max)


## Como se lee una superficie a partir de su inclinacion. Es LA clasificacion:
## el sensor de suelo, el de pared, la escalada y el `floor_max_angle` del cuerpo
## salen todos de aqui, para que ninguno pueda contradecir a otro.
enum Superficie {
	CAMINABLE,   ## < climb_angulo_min. Suelo o pendiente, se anda.
	ESCALABLE,   ## climb_angulo_min .. climb_angulo_max. Pared o desplome.
	INVALIDA,    ## Por encima. Ni se anda ni se escala.
}


## Medio grado de margen para que la horquilla sea inclusiva DE VERDAD. La normal
## que devuelve un raycast contra una cara construida a 75.0 grados exactos vuelve
## como 74.997, y cortar en el numero redondo dejaria fuera justo el caso limite
## que el sistema promete aceptar. Vive aqui y no en cada sensor: si cada uno
## redondease a su manera, volveriamos a tener dos criterios.
const HOLGURA_ANGULO := 0.5


## `floor_max_angle` del cuerpo, y tiene que dar EXACTAMENTE el mismo veredicto
## que `clasificar()`: si el motor y la FSM discrepan aunque sea medio grado, la
## superficie de la frontera no es ni suelo ni pared y el personaje entra en bucle.
## Eso fue el bug de la rampa de 45.
func angulo_max_suelo() -> float:
	return climb_angulo_min + HOLGURA_ANGULO


func clasificar(grados: float) -> Superficie:
	# INCLUSIVO por arriba: el angulo limite se CAMINA. Un "limite de pendiente de
	# 45" que rechaza una rampa de 45 es una trampa, y ademas deja esa rampa sin
	# ninguna forma comoda de subirla.
	if grados <= climb_angulo_min + HOLGURA_ANGULO:
		return Superficie.CAMINABLE
	if grados <= climb_angulo_max + HOLGURA_ANGULO:
		return Superficie.ESCALABLE
	return Superficie.INVALIDA


## Salto estatico desde agachado. Vive aqui y no en el estado porque lo piden dos
## sitios —el agachado y la recepcion en cuclillas— y duplicar la formula seria la
## puerta de entrada a que uno de los dos se quede desincronizado.
func velocidad_salto_agachado() -> float:
	return sqrt(2.0 * absf(gravedad_subida) * altura_salto_agachado)


## Velocidad a la que se recorta el salto al soltar el boton pronto.
func velocidad_salto_corto() -> float:
	return sqrt(2.0 * absf(gravedad_subida) * altura_salto_min)


## Velocidad del dash derivada de distancia y duración.
func velocidad_dash() -> float:
	return dash_distancia / maxf(dash_duracion, 0.001)


# --- Lanza: apoyarse en ella --------------------------------------------------
@export_group("Lanza")
## PERTIGA. Saltar junto a una lanza clavada te impulsa con ella: es
## plataformeo disfrazado de arma (`docs/03 §4.1`).
## Radio dentro del cual la lanza sirve de apoyo.
@export_range(0.5, 8.0, 0.1) var vault_radio: float = 3.2
## Impulso vertical del apoyo, SUMADO al salto. Un salto normal sube 2.6 m; esto
## lo lleva a una altura que no se alcanza de ninguna otra forma sin escalar.
@export_range(0.0, 25.0, 0.5) var vault_impulso: float = 8.5
## Empujon horizontal en la direccion que pidas, para cruzar y no solo subir.
@export_range(0.0, 20.0, 0.5) var vault_avance: float = 5.0


# --- EL MOVESET: acciones cortas que terminan solas ----------------------------
#
# Referencia de feel: PSEUDOREGALIA. Un movimiento no es una simulacion que se
# sostiene, es un GESTO: empieza en el frame que lo pides, dura menos de segundo
# y pico, y se acaba solo. La velocidad la pone el jugador encadenando, no el
# motor integrando.
#
# Aqui no hay numeros de la fisica general —la gravedad, el clamp y la
# locomocion siguen arriba, donde estaban y como estaban—. Esto es solo lo que
# el moveset nuevo necesita.
@export_group("Moveset")

## LA CUERDA. Un arco, y se acabo.
##
## A que distancia se puede enganchar un ancla, en metros.
##
## **Es el numero que dibuja los niveles**, y por eso no se elige a gusto: se
## elige mirando la separacion real entre anclas vecinas. Con 12 m, de las cinco
## del Gym —separadas 13.7, 18.3, 9.7, 18.3 y 16.7 m— **solo UNA pareja se podia
## encadenar**, y por eso la cuerda se sentia corta con razon: no habia cadena que
## dar. Con 19 llegan las cinco.
##
## `MedirCadena` lo cuenta leyendo el mundo, no una tabla escrita a mano: el dia
## que se muevan las anclas, sigue diciendo la verdad.
@export_range(2.0, 60.0, 0.5) var cuerda_rango: float = 19.0
## Semiangulo del cono de camara dentro del que se busca ancla, en grados.
##
## Existe para que enganchar sea una DECISION y no un sorteo: en una sala con
## varias anclas, sin cono te engancharias a la que acabas de soltar —que esta
## justo detras y cerquisima— en vez de a la que estas mirando.
@export_range(10.0, 90.0, 1.0) var cuerda_cono_grados: float = 55.0
## Radio minimo del arco, en metros. Engancharse pegado al ancla daria un giro de
## radio cero: mucha velocidad angular, ningun desplazamiento, y una camara
## imposible de seguir.
@export_range(0.5, 8.0, 0.1) var cuerda_largo_min: float = 2.0
## LA Z SE MANTIENE: sueltas el boton y te sueltas de la cuerda.
##
## Es el gesto natural y el que hace que soltar en el punto correcto sea una
## decision de precision en vez de una segunda pulsacion que hay que acertar.
## Ademas convierte el arco en un rango continuo de intenciones, igual que el
## jump cut hace con el salto: un toque da un gancho corto, mantener da el arco
## entero.
##
## ARCO MINIMO, en segundos. Aunque sueltes en el mismo frame, el arco dura esto.
## Sin el, un toque rapido enganchaba y se soltaba sin llegar a mover nada y se
## leia como que la cuerda habia fallado.
@export_range(0.0, 1.0, 0.01) var cuerda_arco_min: float = 0.22
## TOPE DEL ARCO, en segundos. Pasado esto se suelta sola, mantengas o no.
##
## **Ya no es la mecanica, es el techo de seguridad.** Cuando el arco no se podia
## mantener, este numero ERA la mecanica: sin el, la cuerda dejaba de ser un
## movimiento y pasaba a ser un MODO —te cuelgas, bombeas, ganas altura pasada
## tras pasada y el nivel deja de importar—. Con la Z mantenida quien decide es el
## jugador, asi que el tope sube y se queda solo para que colgarse no sea eterno.
##
## Lo que impide bombear ya no es el reloj: es `cuerda_perdida`.
@export_range(0.2, 12.0, 0.1) var cuerda_arco_max: float = 3.0
## Fraccion de velocidad que pierde el arco por segundo.
##
## **Es lo que sustituye al reloj como freno del bombeo.** Un pendulo sin
## rozamiento es perpetuo, y con el stick metiendo tangencial cada frame no es
## perpetuo: es creciente. Medido en el 3.08 sin perdida, el arco daba vueltas a
## altura constante acelerando solo de 10 a 19 m/s.
@export_range(0.0, 1.0, 0.01) var cuerda_perdida: float = 0.10
## Aceleracion TANGENCIAL que imprime el stick, en m/s².
##
## Va por el arco, nunca contra la cuerda: empujar hacia el ancla no haria nada
## —la restriccion lo deshace— asi que solo cuenta lo que abre, cierra o inclina
## el giro. **Esto no es bombeo**: lo que hacia del bombeo una mecanica aparte era
## poder repetir pasadas, y con `cuerda_arco_max` no hay segunda pasada que dar.
@export_range(0.0, 120.0, 1.0) var cuerda_tangencial: float = 20.0
## Gravedad del arco, en m/s², y SIMETRICA a proposito.
##
## Regla dura #16: la del juego es asimetrica —-38 cayendo, -22 subiendo—, que es
## medio game feel gratis en un salto y rompe cualquier cosa que conserve energia.
## Medido en el 3.08 con la version anterior de esto: el arco terminaba 6 m por
## ENCIMA de donde empezo.
@export_range(5.0, 90.0, 0.5) var cuerda_gravedad: float = 30.0
## ¿EL ANCLA CUENTA COMO CONTACTO? Con esto puesto, soltarse de un arco devuelve
## la cuerda —igual que tocar suelo o pared— y se pueden encadenar anclas sin
## pisar nada. Es la diferencia entre un verbo encadenable y un billete de un
## solo viaje, y por eso esta aqui y no cableado: apagarlo devuelve el juego a
## como se sentia antes, que es la unica forma de juzgar el cambio.
##
## Lo que impide que sea bombear no es este interruptor: es que la MISMA ancla no
## vale dos veces seguidas (`PlayerController.ultima_ancla`). Encadenar exige un
## ancla nueva, o sea que el techo lo pone el nivel.
@export var cuerda_ancla_recarga: bool = true
## Multiplicador a la velocidad al soltar. Pequeño y siempre: soltar en el punto
## correcto ya es la recompensa —ahi es donde el arco va mas rapido— y esto solo
## lo subraya. Un multiplicador grande premiaria colgarse, no soltar bien.
@export_range(1.0, 2.0, 0.01) var cuerda_salida_mult: float = 1.15
## Techo de velocidad DURANTE el arco, en m/s.
##
## El clamp global (`velocidad_maxima`, 22) no le sirve de techo a un pendulo: le
## sirve de IMPUESTO. Un arco alcanza su pico justo abajo, que es donde es
## horizontal, asi que recortar ahi le quita energia en el unico punto donde el
## clamp muerde y el arco pierde altura por una razon que no es fisica.
@export_range(10.0, 60.0, 0.5) var cuerda_velocidad_max: float = 34.0
## Cuanto puede corregir la restriccion la POSICION del jugador en un frame, en
## metros. Escribir `global_position` salta por encima de las colisiones, asi que
## un tiron grande podria meter al jugador dentro de la geometria. Con tope, la
## mayor parte del trabajo la hace la velocidad, que si colisiona.
@export_range(0.05, 4.0, 0.05) var cuerda_correccion_max: float = 0.6
## Altura desde la que sale el cordon, sobre el origen del jugador, en metros.
## Es presentacion pura: la restriccion se calcula contra el origen, esto solo
## decide de donde parece que cuelga. A la altura del pecho, no de los pies.
@export_range(0.0, 3.0, 0.05) var cordon_altura_mano: float = 1.15

## LA PATADA. El unico movimiento ofensivo, y ademas es traversal.
##
## Cuanto dura, en segundos. Corta a proposito: es un GESTO, y un gesto que se
## puede sostener deja de serlo. Con `patada_velocidad` decide ademas cuanto hueco
## cruza — 0.25 s a 18 m/s son 4.5 m, que es el ancho de vano que se puede dibujar
## en un nivel sabiendo que se salva con una patada y no con dos.
@export_range(0.05, 1.2, 0.01) var patada_duracion: float = 0.25
## Velocidad de la patada, en m/s. **ES UN SUELO, NO UN VALOR.**
##
## La distincion es la mecanica entera. Escrita como valor —que es como estaba— la
## patada BORRA la velocidad que traias: medido, entrar lanzado a 29.8 m/s y patear
## te dejaba a 18.0, o sea **11.8 m/s menos por usar tu propio moveset**. Eso rompe
## de frente la ley 5 del rediseño ("encadenar limpio acumula velocidad") y, peor,
## el principio rector: la velocidad la ponia el motor, no el jugador.
##
## Como suelo, la patada GARANTIZA 18 y no quita nada: llegas a 30, sales a 30, y
## el gesto cubre mas terreno porque venias mas rapido. Eso es lo que hace que
## encadenar valga algo.
@export_range(2.0, 40.0, 0.5) var patada_velocidad: float = 18.0
## CARGAS por tiempo de vuelo. Una es el minimo que hace que la patada cueste algo.
##
## Es el numero que mas cambia como se siente el aire, y por eso esta aqui suelto y
## no cableado: con una, el aire es un compromiso; con tres —que es por donde anda
## *Pseudoregalia* con las Sun Greaves al completo— el aire se convierte en un
## sitio donde se vive, y encadenar deja de exigir que cada patada acierte.
##
## **Esta en TRES desde que se midio.** Con una, tres de cada cuatro intentos de
## encadenar terminaban en el suelo por un calculo de medio metro, y eso no se lee
## como dificultad: se lee como que el juego no te deja. Ver `MedirPatada`, que
## cuenta cuantas caben en un tiempo de vuelo y cuanto terreno cubren.
@export_range(1, 5, 1) var patada_cargas: int = 3
## Vertical al terminar SIN acertar, en m/s. La patada suspende la gravedad
## mientras dura y esto es lo que devuelve al soltarte.
##
## Pequeño a proposito: un salto sube a 10.7 m/s, asi que esto no es un salto, es
## un respiro. Pero tampoco es cero —que es como estaba— porque salir de una patada
## con la vertical a cero es caer a plomo desde parado, y entonces el gesto no
## sirve para cruzar nada que no sea plano.
##
## **Se aplica como maximo con la vertical de entrada**, no como sustitucion:
## patear subiendo no te frena, patear cayendo te salva la caida. Una sola vez por
## tiempo de vuelo.
@export_range(0.0, 12.0, 0.1) var patada_salida_vertical: float = 2.0
## Vertical al ACERTAR, en m/s. El rebote.
##
## Es lo que convierte a un enemigo en plataforma, y sin el la frase del diseño
## —"golpear es seguir moviendote"— no se cumple: medido antes de existir, conectar
## te dejaba a vy 0.0 y cayendo. Alto a proposito, casi un salto: el premio por
## acertar tiene que devolverte al sitio desde donde se decide la siguiente cosa.
@export_range(0.0, 25.0, 0.5) var patada_rebote: float = 10.0
## Segundos de gravedad CERO tras acertar. Sin esto el rebote es un empujon y ya;
## con esto hay una pausa en la que se elige el siguiente objetivo.
@export_range(0.0, 1.0, 0.01) var patada_hangtime: float = 0.14
## Con cuanta autoridad se redirige, en grados por segundo.
##
## Alta a proposito: la ley del moveset dice que el jugador manda la direccion
## durante TODO el movimiento, y una patada que no se puede corregir es una
## animacion con la que se colisiona. Se gira la DIRECCION, no la velocidad: aqui
## un `slerp` es el primitivo correcto porque lo que rota es un unitario, no un
## vector que tendria que pasar por cero (regla dura #24).
@export_range(60.0, 1440.0, 10.0) var patada_giro_grados_seg: float = 540.0
