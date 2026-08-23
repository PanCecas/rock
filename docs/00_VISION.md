# ROCK — Visión

## Pitch
Un mundo de ruinas verdes bajo un cielo de crema pálida. No hay enemigos comunes vagando:
hay **silencio, distancia y colosos**. La diferencia con Shadow of the Colossus es que aquí
**tú eres rápido**. Te mueves como en un plataformero 3D moderno (dash, planeo, deslizamiento,
wall-run, gancho) y peleas con una espada y una lanza con un combate estilizado y cancelable.
El coloso no es un puzzle lento: es **un nivel de plataformas que se defiende**.

## Los 3 pilares (todo se decide contra estos)

### P1 — El movimiento es el juego
Antes de que exista un solo enemigo, moverse por un campo vacío tiene que ser divertido.
Si la Fase 1 no es divertida sin combate, el proyecto no avanza. Esto no es negociable.

### P2 — El coloso es arquitectura viva
Cada coloso se diseña primero como **nivel de plataformas** (rutas, saltos, agarres,
riesgo de caída) y después se le añade la anatomía. Su ataque principal contra ti no es
"daño": es **tirarte al suelo**. Perder es perder altura.

### P3 — La saturación es sagrada
El entorno vive desaturado. El jugador, los puntos débiles y lo interactuable son lo único
saturado en pantalla. Esto reemplaza a la UI: la legibilidad la da el color, no un HUD.

## Bucle de juego
```
Explorar (planeo/gancho, silencio, escala)
   └─> Encontrar el coloso (silueta contra la bruma)
		└─> FASE A: acercarte y quebrar su guardia (combate en suelo, parry, lanza)
			 └─> FASE B: clavar la lanza / enganchar y SUBIR (plataformas sobre carne y piedra en movimiento)
				  └─> FASE C: aguantar las sacudidas, llegar al punto débil, golpear
					   └─> El coloso cambia de fase -> vuelve a A o B con nueva geometría
```

## Lo que NO es
- No es un souls-like (no hay stamina de ataque, no hay farmeo, no hay hogueras).
- No es mundo abierto grande. Es un mundo **medio, denso y vertical**.
- No tiene inventario ni crafteo. Tienes: espada, lanza, lazo, arco. Eso es todo.

## Referencia estética
Ilustración de ruinas con arcos de piedra, musgo, cielo crema plano, figura solitaria con capa
azul cobalto (o roja) como único punto saturado. Perspectiva aérea extrema: lo lejano se
disuelve en crema. Ver `01_DIRECCION_ARTE.md`.
