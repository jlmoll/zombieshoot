# Construir mapas desde el editor

Abre `scenes/world/arena.tscn` en Godot. Su geometría, decoración, luces y colisiones están guardadas en la escena y se ven sin ejecutar el juego.

## Pintar el suelo

Selecciona `Ground/FloorTiles` para pintar y borrar celdas con las herramientas de GridMap del editor. La biblioteca `assets/maps/arena_tiles.tres` contiene dos losetas (oscura y clara), compartidas por todas las celdas. El tamaño de celda es 3 × 1 × 3 y el suelo se pinta en la capa Y = 0. Las 144 celdas del mapa inicial conservan el patrón anterior sin crear nodos por loseta. Las losetas son visuales: el límite navegable sigue definido por `PlayableArea`.

## Distribución y piezas

- `Ground`: base del recinto y `FloorTiles`, un `GridMap` con las losetas pintadas.
- `Perimeter`: paredes físicas y luces del perímetro.
- `Cover`: instancias de barricadas y pilares.
- `Markings`: señalización y textos.
- `PlayerSpawn`: posición inicial del jugador.
- `PlayableArea/CollisionShape3D`: caja que delimita la navegación, independiente de las paredes físicas.
- `EnemySpawns`: marcadores de entrada de enemigos.
- `Navigation`: campo de direcciones compartido de la horda.

Arrastra `scenes/world/pieces/barricade.tscn`, `pillar.tscn` o `wall_segment.tscn` a la escena. Puedes duplicarlas, moverlas, rotarlas sobre Y y escalarlas. Editar la escena de una pieza actualiza todas sus instancias. Para nuevas piezas usa un `StaticBody3D` en la capa de colisión 2, con modelo y `CollisionShape3D` como hijos.

La navegación calcula las huellas de cajas, esferas, cápsulas y cilindros a partir de sus transformaciones globales. Las formas no compatibles emiten un aviso. Usa varias cajas para obstáculos complejos. Los elementos decorativos sin colisión no bloquean la navegación.

En la raíz del mapa puedes ajustar `navigation_cell_size` y `navigation_clearance`. El margen es compartido por toda la horda; diseña pasos suficientemente amplios para brutes y jefes. El mapa sigue siendo plano en Y = 0: rampas y plantas superpuestas requieren otro sistema de navegación.

## Límites y entradas

Para cambiar el tamaño, modifica la forma de `PlayableArea` y recoloca las paredes físicas y el suelo. La caja delimita el área navegable; no genera paredes. Al duplicar un mapa, haz únicos los recursos de forma que vayas a modificar.

Duplica un marcador de `EnemySpawns` o crea un `Marker3D` con `scripts/world/spawn_zone.gd`. Sus propiedades son:

| Propiedad | Uso |
| --- | --- |
| `width` | Anchura de la entrada sobre el eje X local; rota el marcador para orientar la entrada. Cero produce un punto fijo. |
| `weight` | Peso relativo al elegir entradas. |
| `first_wave` | Primera oleada en que puede usarse. |
| `enabled` | Activa o desactiva la entrada. |
| `enemy_kinds` | Tipos permitidos: walker, runner, spitter, brute, boss. |
| `minimum_distance` | Distancia mínima al jugador. |

Los puntos deben quedar dentro del área navegable y conectados con el jugador. El director reintenta si no encuentra una entrada válida; no descuenta enemigos pendientes. Deja siempre alguna entrada válida para cada tipo que pueda solicitar una oleada, incluidos los jefes. La entrada `BossEntrance` conserva la posición de los jefes del mapa original.

## Crear otro mapa

1. Duplica `arena.tscn` y edita su distribución.
2. Mantén el script `Arena` y el hijo `Navigation`. Asigna en el inspector las referencias `player_spawn`, `playable_area` y `spawn_container` si cambias sus nodos.
3. Abre `scenes/main.tscn` y asigna la nueva escena a `Map Scene` en la raíz.
4. Ejecuta una partida. El jugador aparece en `PlayerSpawn` y las oleadas usan las entradas del mapa.

Cada reinicio crea una instancia nueva del mapa. Si cambias obstáculos durante una partida mediante código, llama a `Arena.rebuild_navigation()` después de actualizar sus colisiones. No hace falta hornear una malla de navegación.

## Validación

`tests/integration.gd` comprueba la distribución original, ocho oleadas, colisiones, rutas, piezas movidas y rotadas, mapas transformados, límites editables, filtros de entradas y restauración del mapa al reiniciar.
