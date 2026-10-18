# Construir mapas desde el editor

Abre `scenes/world/arena.tscn`. El mapa se compone con GridMaps y escenas de objetos completos; no se genera geometría al arrancar.

## Árbol de trabajo

| Nodo | Cómo editarlo |
| --- | --- |
| `Ground/FloorTiles` | Pinta y borra suelo con GridMap. |
| `Ground/Foundation` | Base decorativa reutilizable; mueve o escala la instancia si cambia el recinto. |
| `Structure` | Pinta paredes con colisión y luces integradas. |
| `Props` | Arrastra barricadas, pilares, paneles rayados y rótulos completos. |
| `Environment` | Instancia que contiene el entorno y las luces globales. Abre su escena para ajustar la iluminación. |
| `EnemySpawns` | Instancias de entradas configurables, con una barra de anchura visible solo en el editor. |
| `PlayerSpawn` | Marcador de posición inicial del jugador. |
| `PlayableArea/CollisionShape3D` | Caja que delimita la navegación y contiene las granadas en el aire. |
| `Navigation` | Sistema compartido de navegación; no necesita edición para recolocar objetos. |

## Pintar suelo y paredes

Selecciona el GridMap correspondiente y elige un elemento de su MeshLibrary. Ambos usan celdas de 3 × 1 × 3, en la capa Y = 0.

- Suelo: `assets/maps/arena_tiles.tres`, losetas clara y oscura.
- Estructura: `assets/maps/arena_structure.tres`, paredes norte, sur, oeste, este y esquina noroeste. Las piezas se alinean con los bordes de las celdas y pueden rotarse con las herramientas de GridMap. La esquina reúne dos paredes en una celda.

Las paredes incluyen su franja luminosa y sus formas de colisión. La navegación lee directamente esas formas, incluidas las orientaciones de celda. No hay que colocar luces ni rectángulos de navegación por separado.

Los catálogos fuente también son escenas editables: `scenes/world/catalogs/floor_tiles.tscn` y `structure_tiles.tscn`. Sus hijos son las piezas de la biblioteca. Para modificar la biblioteca, edita su catálogo y usa la exportación de escena a MeshLibrary del editor sobre el recurso correspondiente, conservando los identificadores de elementos utilizados por el mapa. Mantén cada pieza centrada en su origen de autoría; su desplazamiento forma parte del encaje en la rejilla.

El suelo sigue siendo visual: borrar una loseta no abre un agujero físico ni elimina esa zona de la navegación. El área transitable continúa delimitada por `PlayableArea` y los obstáculos. El juego está pensado para mapas planos en Y = 0.

## Colocar props completos

Arrastra estas escenas al contenedor `Props`:

- `scenes/world/pieces/barricade.tscn`
- `scenes/world/pieces/pillar.tscn`
- `scenes/world/props/hazard_panel.tscn`: una sola malla con todas las franjas; sin comportamiento de gameplay.
- `scenes/world/props/sector_sign.tscn`: anillo, número y subtítulo como un objeto. Cambia `Sector Number` y `Caption` en la raíz de la instancia; se actualizan en el editor.

Los props se mueven, duplican y rotan como unidades. Abre su escena para cambiar sus detalles internos. Los decorativos no tienen colisión. Para crear una cobertura nueva usa un `StaticBody3D` en la capa 2, con modelo y formas de colisión.

La navegación admite cajas, esferas, cápsulas y cilindros; para obstáculos complejos compón varias cajas. Configura resolución y margen en `navigation_cell_size` y `navigation_clearance` de la raíz. Deja pasos amplios para los enemigos grandes.

## Entradas

Arrastra `scenes/world/enemy_entrance.tscn` dentro de `EnemySpawns`. La barra de color muestra su anchura local X en el editor y desaparece durante el juego. Rota la instancia para orientar la entrada.

| Propiedad | Uso |
| --- | --- |
| `width` | Anchura de entrada; cero produce un punto fijo. |
| `weight` | Peso relativo al elegir entradas. |
| `first_wave` | Primera oleada en que se activa. |
| `enabled` | Activa o desactiva la entrada. |
| `enemy_kinds` | walker, runner, spitter, brute o boss. |
| `minimum_distance` | Distancia mínima al jugador. |

Las entradas son puntos de aparición, no puertas físicas. Los paneles rayados son props independientes. Deja al menos una entrada válida y conectada con el jugador para cada tipo solicitado por las oleadas, incluido boss. Si no hay punto válido, el director reintenta sin descontar enemigos.

## Otro mapa y reinicios

Duplica `arena.tscn`, modifica su distribución y asigna la escena nueva a `Map Scene` en la raíz de `scenes/main.tscn`. Si renombras nodos de configuración, actualiza las referencias exportadas de `Arena`. Cambiar el tamaño requiere ajustar la caja `PlayableArea`, la base y las celdas de suelo y estructura.

Cada reinicio recrea el mapa desde su escena. Si modificas colisiones o celdas de estructura durante una partida mediante código, llama después a `Arena.rebuild_navigation()`.

La suite `tests/integration.gd` comprueba las ocho oleadas, colisiones, props, GridMaps, rutas, entradas y restauración del mapa al reiniciar.
