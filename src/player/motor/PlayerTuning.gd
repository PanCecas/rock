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
@export_range(0.5, 12.0, 0.1) var velocidad_caminar: float = 3.0
@export_range(0.5, 16.0, 0.1) var velocidad_trotar: float = 5.4
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
@export_range(5.0, 60.0, 0.5) var velocidad_maxima: float = 22.0

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
## Impulso hacia delante de la patada deslizante. Es el salto de conejo de Mario.
@export_range(0.0, 40.0, 0.5) var slide_kick_impulso: float = 26.0
@export_range(0.0, 20.0, 0.1) var slide_kick_vertical: float = 6.2
## Rozamiento de la patada YA EN EL SUELO. Era la friccion del agachado (14) y por
## eso la patada moria en dos metros: el impulso estaba bien, lo que fallaba es
## que se lo comia el frenado al aterrizar. Baja: la patada es un DESPLAZAMIENTO
## que ademas hace dano, y tiene que llegar lejos.
@export_range(0.5, 60.0, 0.5) var slide_kick_friccion: float = 3.2
## COOLDOWN. La patada llega mas lejos que nunca, y por eso encadenarla sin pausa
## superaba al surf: la movilidad mas rapida del juego tiene que seguir siendo el
## surf, o el shift deja de tener sentido. El pico de la patada es mayor; su
## velocidad SOSTENIDA, no. Esto es lo que separa las dos cosas.
@export_range(0.0, 3.0, 0.05) var slide_kick_cooldown: float = 0.9

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
@export_range(10.0, 89.0, 1.0) var pared_umbral_frontal: float = 55.0

## PERDON: sigues pudiendo saltar de la pared este tiempo despues de perder el
## contacto. Es lo que hace que encadenar dos muros no exija precision de frame.
@export_range(0.0, 0.6, 0.01) var pared_coyote: float = 0.15
## Tiempo tras un wall-jump en que la misma pared se ignora, para poder alternar.
@export_range(0.0, 1.0, 0.01) var pared_bloqueo: float = 0.18
## Cuanto se reorienta la camara detras del salto de pared. 0 = nada.
@export_range(0.0, 1.0, 0.05) var camara_realinea_walljump: float = 0.6

# --- Dive (clavado) ----------------------------------------------------------
@export_group("Dive")
## Velocidad horizontal minima para el DIVE. A CERO: atacar en el aire SIEMPRE
## es un clavado. Exigir carrera hacia que el ataque aereo mas visible del juego
## no apareciera casi nunca, que es justo lo contrario de lo que se buscaba.
@export_range(0.0, 20.0, 0.1) var dive_velocidad_min: float = 0.0
## Empuje hacia delante al entrar en dive. Es lo que dibuja la parabola.
## Velocidad horizontal del clavado. CONSTANTE durante todo el vuelo: es la
## fisica de Mario 64 —un cuerpo con velocidad horizontal fija en caida libre—,
## y es lo que hace que la trayectoria se pueda leer y planificar.
## ATAQUE AEREO: empuje inicial en la direccion del golpe. Sin el, el ataque en el
## aire era una animacion mientras el personaje caia casi en el mismo sitio; con
## el, es una herramienta de movilidad —ganar distancia atacando, como el salto
## largo de Mario— ademas de un golpe.
@export_range(0.0, 40.0, 0.5) var aereo_impulso: float = 12.0
## Cuanto del `avance` del AttackData se aplica en el aire. Era un 0.7 escrito a
## mano dentro del estado (numero magico, regla dura #1).
@export_range(0.0, 3.0, 0.05) var aereo_avance_mult: float = 1.0
@export_range(0.0, 40.0, 0.5) var dive_impulso: float = 21.0
## LA COMPONENTE QUE FALTABA. El clavado arrancaba con velocidad vertical 0 y
## dejaba que la gravedad hiciera el resto, asi que la trayectoria empezaba plana
## y solo se curvaba tarde: se leia como "desplazarse en el aire", no como
## clavarse. Salir YA hacia abajo es lo que dibuja la diagonal desde el frame uno.
@export_range(-30.0, 0.0, 0.5) var dive_vertical_inicial: float = -7.0

@export_subgroup("Clavado pesado")
## El pesado va mas lejos y mas plomo. Es el que se encadena de cabeza en cabeza.
@export_range(0.0, 40.0, 0.5) var dive_pesado_impulso: float = 25.0
@export_range(-30.0, 0.0, 0.5) var dive_pesado_vertical: float = -11.0
## REBOTE. Al clavarse sobre un enemigo se pisa su cabeza y se sale despedido
## hacia arriba, de vuelta al aire y con el clavado disponible otra vez. Es lo que
## convierte el ataque en una cadena en vez de en un punto final.
@export_range(0.0, 30.0, 0.5) var dive_rebote: float = 12.5
## Gravedad durante el dive. Mas fuerte que la normal: cae con intencion.
@export_range(-120.0, -10.0, 1.0) var dive_gravedad: float = -52.0
@export_range(0.0, 1440.0, 10.0) var dive_giro_grados_seg: float = 160.0

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
## Gasto puntual por ataque acuatico.
@export_range(0.0, 60.0, 0.5) var agua_stamina_ataque: float = 5.0

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
## Los ataques bajo el agua SON desplazamientos: no hay suelo del que empujar, asi
## que un golpe es un impulso con hitbox. Ver project.md.
@export_range(0.0, 40.0, 0.5) var agua_ataque_ligero_impulso: float = 12.0
@export_range(0.0, 40.0, 0.5) var agua_ataque_pesado_impulso: float = 9.0

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
@export_range(0.1, 8.0, 0.1) var shimmy_velocidad: float = 1.6

# --- Picado (plunging attack) -----------------------------------------------
# El picado es el unico ataque del juego cuyo poder lo decide el JUGADOR con una
# decision previa: desde donde se tira. Escalar treinta metros para caer sobre un
# grupo tiene que valer mas que dar un saltito, o el traversal y el combate siguen
# siendo dos juegos distintos que comparten personaje.
@export_group("Picado")
## Suspension antes de caer. No es adorno: es la telegrafia que da peso al impacto
## y el instante en que se elige donde caer.
@export_range(0.0, 1.0, 0.01) var plunge_suspension: float = 0.16
## Velocidad de caida del picado. Constante y muy por encima de la gravedad: cae
## como una piedra, no como un cuerpo.
@export_range(-120.0, -5.0, 1.0) var plunge_velocidad_caida: float = -34.0

@export_subgroup("Escalado por altura de caida")
## Por debajo de esta caida el picado vale lo que dice su AttackData y nada mas.
@export_range(0.0, 30.0, 0.5) var plunge_altura_min: float = 2.5
## Caida a partir de la cual ya no crece. Sin techo, una torre de 60 m convertiria
## el picado en un boton de borrar la pantalla.
@export_range(1.0, 100.0, 0.5) var plunge_altura_max: float = 20.0
## Multiplicadores en la caida maxima. A 1.0 el escalado queda desactivado.
@export_range(1.0, 6.0, 0.05) var plunge_dano_mult: float = 2.6
@export_range(1.0, 6.0, 0.05) var plunge_radio_mult: float = 2.1
@export_range(1.0, 6.0, 0.05) var plunge_stagger_mult: float = 2.2
@export_range(1.0, 6.0, 0.05) var plunge_empuje_mult: float = 2.4
## A partir de esta caida el aturdimiento pasa a DERRIBO. Es el salto cualitativo
## que hace que merezca la pena subir del todo en vez de un poco.
@export_range(0.0, 100.0, 0.5) var plunge_derribo_desde: float = 12.0

# --- Combate ----------------------------------------------------------------
@export_group("Combate")
@export_range(0.02, 0.6, 0.01) var parry_ventana: float = 0.16
@export_range(0.01, 0.3, 0.01) var parry_ventana_perfecta: float = 0.06
@export_range(0.0, 2.0, 0.01) var parry_recuperacion_fallo: float = 0.4
@export_range(0.0, 0.5, 0.005) var hitstop_ligero: float = 0.05
@export_range(0.0, 0.5, 0.005) var hitstop_pesado: float = 0.09
@export_range(0.0, 0.5, 0.005) var hitstop_parry: float = 0.16
@export_range(0.0, 1.0, 0.005) var hitstop_punto_debil: float = 0.25
@export_range(0.0, 0.6, 0.01) var esquiva_iframes: float = 0.30

# --- Stamina ----------------------------------------------------------------
@export_group("Stamina")
## Barra única: escalar, planear, correr, dashear y aguantar sacudidas.
## Los ataques NO gastan stamina: esto no es un souls.
@export_range(10.0, 500.0, 1.0) var stamina_max: float = 100.0
@export_range(0.0, 100.0, 0.5) var stamina_escalar: float = 6.0
@export_range(0.0, 100.0, 0.5) var stamina_aguantar_sacudida: float = 24.0
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
@export_range(0.01, 1.0, 0.01) var camara_sensibilidad: float = 0.28
@export_range(-89.0, 0.0, 1.0) var camara_pitch_min: float = -65.0
@export_range(0.0, 89.0, 1.0) var camara_pitch_max: float = 55.0
@export_range(0.01, 1.0, 0.01) var camara_suavizado: float = 0.12
@export_range(20.0, 110.0, 1.0) var camara_fov: float = 62.0


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


## `floor_max_angle` del cuerpo. Es el limite de escalada menos la holgura, no el
## limite pelado: si coincidieran, una cara de 75 grados exactos seria a la vez
## suelo para el motor y pared para la FSM, y el personaje se quedaba resbalando
## sobre la primera superficie que se supone que puede trepar.
func angulo_max_suelo() -> float:
	return climb_angulo_min - HOLGURA_ANGULO


func clasificar(grados: float) -> Superficie:
	if grados < climb_angulo_min - HOLGURA_ANGULO:
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
