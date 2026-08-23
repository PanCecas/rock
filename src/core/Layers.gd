class_name Layers
extends RefCounted
## Capas de colisión 3D, nombradas. Nadie escribe una máscara en decimal.
## Los nombres legibles están en project.godot > layer_names/3d_physics.

const WORLD := 1 << 0          ## Geometría estática del mundo
const PLAYER := 1 << 1         ## El jugador
const ENEMY := 1 << 2          ## Guardianes y colosos
const CLIMBABLE := 1 << 3      ## Superficies escalables a mano
const LEDGE := 1 << 4          ## Volúmenes de detección de borde
const HITBOX := 1 << 5         ## Cajas que hacen daño
const HURTBOX := 1 << 6        ## Cajas que reciben daño
const INTERACT := 1 << 7       ## Interactuables del mundo
const ANCHOR := 1 << 8         ## Anclajes válidos del lazo
const SPEAR_STICK := 1 << 9    ## Superficies donde la lanza se clava
const COLOSSUS_SURFACE := 1 << 10  ## Suelo caminable de un coloso (frame móvil)
const PROJECTILE := 1 << 11
const CAMERA_BLOCK := 1 << 12  ## Lo que empuja la cámara hacia dentro

## Todo lo que el jugador pisa: mundo estático + superficie de coloso.
const SUELO_JUGADOR := WORLD | COLOSSUS_SURFACE

## Lo que la cámara considera obstáculo.
const CAMARA := WORLD | CAMERA_BLOCK | COLOSSUS_SURFACE
