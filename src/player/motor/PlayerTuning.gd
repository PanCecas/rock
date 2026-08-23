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
## Altura en METROS, no en fuerza. La velocidad se deriva de la gravedad de subida.
@export_range(0.5, 6.0, 0.05) var altura_salto: float = 2.2
## Gravedad asimétrica: subir flotante, caer contundente. Es medio game feel gratis.
@export_range(-60.0, -5.0, 0.5) var gravedad_subida: float = -22.0
@export_range(-90.0, -5.0, 0.5) var gravedad_caida: float = -38.0
## Multiplicador a la velocidad Y al soltar el botón durante la subida.
@export_range(0.0, 1.0, 0.01) var jump_cut: float = 0.45
## Perdón: puedes saltar durante este tiempo tras dejar el suelo.
@export_range(0.0, 0.4, 0.01) var coyote_time: float = 0.12
## Perdón: un salto pulsado antes de aterrizar se ejecuta al tocar suelo.
@export_range(0.0, 0.4, 0.01) var jump_buffer: float = 0.15
@export_range(-60.0, -1.0, 0.5) var velocidad_terminal: float = -45.0
@export var saltos_aereos: int = 1

# --- Locomoción -------------------------------------------------------------
@export_group("Locomoción")
## Los tres peldaños de la locomocion sin Shift. NO se eligen por la fuerza del
## stick: se encadenan por TIEMPO manteniendo la direccion, que es lo que da la
## sensacion de que el personaje coge carrerilla.
@export_range(0.5, 12.0, 0.1) var velocidad_caminar: float = 3.0
@export_range(0.5, 16.0, 0.1) var velocidad_trotar: float = 5.4
@export_range(1.0, 20.0, 0.1) var velocidad_correr: float = 7.8
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
@export_range(1.0, 200.0, 1.0) var aceleracion_aire: float = 25.0
@export_range(1.0, 200.0, 1.0) var frenado_suelo: float = 45.0
@export_range(0.0, 200.0, 1.0) var frenado_aire: float = 4.0
## Frenado cuando vas MÁS RÁPIDO que tu velocidad objetivo y sigues empujando.
## Muy bajo a propósito: es lo que hace que la velocidad de un dash o de un slide
## sobreviva unos segundos en vez de evaporarse en dos frames.
@export_range(0.5, 60.0, 0.5) var frenado_momentum: float = 6.0
## Grados por segundo a los que el modelo gira hacia la dirección de movimiento.
@export_range(90.0, 2160.0, 10.0) var giro_grados_seg: float = 900.0
@export_range(0.0, 89.0, 1.0) var angulo_max_suelo: float = 50.0

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
@export_range(1.0, 40.0, 0.1) var surf_velocidad: float = 15.0
## Velocidad de crucero del surf una vez consumido el envión del dash. Es la
## velocidad de "correr" real del juego: el surf NO caduca, se sostiene mientras
## mantengas Shift, y la stamina es su único límite.
@export_range(1.0, 30.0, 0.1) var surf_crucero: float = 11.0
## Giro. ALTO: aquí es donde se pilota, y es lo que lo hace sentir fluido.
@export_range(30.0, 1080.0, 10.0) var surf_giro_grados_seg: float = 320.0
## Rozamiento. Bajo = el momentum se conserva y se siente que patinas.
@export_range(0.0, 40.0, 0.5) var surf_friccion: float = 5.0
@export_range(0.0, 100.0, 0.5) var surf_stamina: float = 10.0
## Alabeo del cuerpo al girar surfeando. Vende la inercia desde lejos.
@export_range(0.0, 45.0, 1.0) var surf_alabeo: float = 16.0

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

# --- Deslizamiento ----------------------------------------------------------
@export_group("Deslizamiento")
## Velocidad mínima para poder entrar en slide. Debajo de esto no engancha.
@export_range(0.0, 20.0, 0.1) var slide_velocidad_min: float = 5.0
## Impulso que se suma al entrar. Deslizarse tiene que GANAR velocidad, no perderla.
@export_range(0.0, 15.0, 0.1) var slide_impulso: float = 3.5
@export_range(0.0, 30.0, 0.1) var slide_friccion: float = 3.0
## Aceleración extra cuesta abajo por unidad de pendiente. Premia leer el terreno.
@export_range(0.0, 60.0, 0.5) var slide_pendiente: float = 22.0
@export_range(0.1, 5.0, 0.05) var slide_duracion_max: float = 2.5
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
## PERDON: sigues pudiendo saltar de la pared este tiempo despues de perder el
## contacto. Es lo que hace que encadenar dos muros no exija precision de frame.
@export_range(0.0, 0.6, 0.01) var pared_coyote: float = 0.15
## Tiempo tras un wall-jump en que la misma pared se ignora, para poder alternar.
@export_range(0.0, 1.0, 0.01) var pared_bloqueo: float = 0.18
## Cuanto se reorienta la camara detras del salto de pared. 0 = nada.
@export_range(0.0, 1.0, 0.05) var camara_realinea_walljump: float = 0.6

# --- Aterrizaje -------------------------------------------------------------
@export_group("Aterrizaje")
## Velocidad de impacto a partir de la que el aterrizaje es "duro" y cuesta control.
@export_range(0.0, 60.0, 0.5) var aterrizaje_duro: float = 20.0
@export_range(0.0, 1.0, 0.01) var aterrizaje_duro_duracion: float = 0.22

# --- Bordes y escalada ------------------------------------------------------
@export_group("Bordes y escalada")
## Perdón: si fallas el borde por menos de esto, se te concede el agarre.
@export_range(0.0, 1.5, 0.05) var ledge_assist: float = 0.4
@export_range(0.1, 3.0, 0.05) var ledge_alcance: float = 0.7
@export_range(0.1, 3.0, 0.05) var ledge_altura_max: float = 2.1
@export_range(0.1, 6.0, 0.1) var escalada_velocidad: float = 2.4
@export_range(0.1, 8.0, 0.1) var shimmy_velocidad: float = 1.6

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


## Velocidad inicial de salto derivada de la altura y la gravedad de subida.
## v = sqrt(2 * g * h)
func velocidad_salto() -> float:
	return sqrt(2.0 * absf(gravedad_subida) * altura_salto)


## Velocidad del dash derivada de distancia y duración.
func velocidad_dash() -> float:
	return dash_distancia / maxf(dash_duracion, 0.001)
