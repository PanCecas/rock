# legacy/ — el código de antes del rediseño del moveset

Aquí se guarda, **sin borrar nada**, el estado del jugador tal y como estaba en
`7e149d6` (parche 3.16), justo antes de reconstruir el moveset con
PSEUDOREGALIA como referencia de feel.

## Por qué hay un `.gdignore` vacío al lado

Sin él, Godot IMPORTA y PARSEA todo lo que haya aquí dentro. Y como esto es una
copia literal de `src/player/`, cada `class_name` quedaría declarado **dos
veces** —`PlayerState`, `StateMachine`, `LocomotionMotor`, `PlayerTuning`,
`SurfaceContext`…— y el proyecto entero dejaría de compilar con un error por
cada nombre repetido. `.gdignore` hace que el editor salte el directorio
completo: los archivos siguen en disco y en git, pero para Godot no existen.

**No lo borres.** Si algún día hay que recuperar algo de aquí, se copia el
archivo suelto a `src/`, no se quita el `.gdignore`.

## Qué hay

| Carpeta | Qué guarda |
|---|---|
| `player_3.16/` | Copia completa de `src/player/` en 7e149d6: controlador, motor, sensores y los 31 estados |
| `cuerda_3.16/` | Los cuatro verbos de cuerda y la segunda cuerda entera |

## Cómo volver a mirar esto

```
git show 7e149d6:src/player/states/StateSpearSwing.gd
```

funciona igual de bien y no ocupa sitio. Esta carpeta existe porque se pidió
tener los archivos a mano, no porque el historial no los tuviera.
