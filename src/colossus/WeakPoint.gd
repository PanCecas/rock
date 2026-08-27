class_name WeakPoint
extends Hurtbox
## PUNTO DÉBIL. Lo que un coloso tiene y hay que alcanzar para hacerle daño de
## verdad — y, en la Fase 4, para rematarlo.
##
## **Declara QUÉ LO ABRE, no QUIÉN.** El punto débil dice `llave = &"perforante"`
## y cada ataque declara sus `etiquetas`; nadie escribe `if arma is Lanza` en
## ningún sitio. La diferencia no es de estilo:
##
##   · con etiquetas, añadir un arma nueva es escribirle `etiquetas` en su
##     `.tres` y ya perfora. El coloso no se toca.
##   · con `if arma is Lanza`, cada arma nueva obliga a abrir el coloso y añadir
##     una rama — y el coloso es lo último que uno quiere tocar, porque es donde
##     vive el contenido.
##
## Hoy la lanza es lo único que perfora, y eso la hace **la herramienta
## indispensable contra los colosos** que pide el diseño. Pero lo es por lo que
## declara, no porque el coloso la conozca.
##
## Extiende `Hurtbox` en vez de vivir al lado: así hereda toda la fontanería del
## combate —la Hitbox ya la encuentra, el equipo ya funciona, el `Golpe` ya llega
## hecho— y lo único que añade es la decisión de si ese golpe cuenta.

## Se emite cuando el punto débil recibe un golpe, critico o no. La Fase 4 lo
## escuchará para las fases del coloso; hoy sirve para el VFX y para el test.
signal punto_debil_golpeado(golpe: Golpe, critico: bool)
## Se emite cuando queda ABIERTO al remate. Separada de la anterior a propósito:
## un remate es un evento de guion, no un impacto más.
signal remate_disponible

## Etiqueta que hay que traer para hacerle daño de verdad.
@export var llave: StringName = &"perforante"
## Cuánto multiplica el daño un golpe que trae la llave.
@export_range(1.0, 20.0, 0.1) var multiplicador: float = 3.5
## Fracción del daño que pasa SIN la llave. Cero lo haría inmune, y un enemigo
## que no reacciona a un golpe se lee como un bug, no como una defensa.
@export_range(0.0, 1.0, 0.05) var sin_llave: float = 0.15
## ¿Golpearlo con la llave lo deja abierto al remate?
@export var abre_remate: bool = true
## Golpes con llave que aguanta antes de abrirse. Uno solo haría el remate un
## accidente; varios lo convierten en algo que se busca.
@export_range(1, 10, 1) var golpes_para_abrir: int = 3

var abierto: bool = false

var _acertados: int = 0


## Lo llama la Hitbox, igual que a cualquier hurtbox. Lo único que se añade aquí
## es decidir cuánto vale ESE golpe en ESTE sitio.
func recibir(golpe: Golpe) -> int:
	var critico := golpe.datos != null and golpe.datos.tiene(llave)
	golpe.critico = critico
	golpe.multiplicador = multiplicador if critico else sin_llave

	if critico:
		_acertados += 1
		if abre_remate and not abierto and _acertados >= golpes_para_abrir:
			abierto = true
			remate_disponible.emit()

	punto_debil_golpeado.emit(golpe, critico)
	return super(golpe)


## Vuelve a cerrarse. Lo usará la Fase 4 entre fases del coloso; hoy lo usa el
## test para no arrastrar estado de una comprobación a la siguiente.
func reiniciar() -> void:
	abierto = false
	_acertados = 0


func debug_line() -> String:
	return "%s  %d/%d%s" % [llave, _acertados, golpes_para_abrir,
		"  ABIERTO" if abierto else ""]
