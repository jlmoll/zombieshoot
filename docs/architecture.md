# Arquitectura de Dead Shift

La escena principal compone los sistemas y coordina los estados de aplicación. La lógica de una partida vive en una escena independiente; los actores comunican sus intenciones mediante señales y no buscan la escena raíz.

## Árbol de nodos

```text
DeadShift (Game)
├── SaveData                  Récord y preferencias persistentes
├── Audio (GameAudio)         Banco de sonidos y voces reutilizables
├── Arena                     Geometría estática, luces y obstáculos
│   ├── Ground / Perimeter / Cover / Markings
│   └── Navigation            Campo de direcciones compartido por la horda
├── CameraRig
│   └── Camera                Seguimiento isométrico y sacudidas
├── SessionSlot
│   └── RunSession            Una instancia nueva por partida
│       ├── Player
│       │   ├── CollisionShape3D
│       │   └── Visuals       Modelo y animación del superviviente
│       ├── Enemies           EnemySpawner; propietario de los zombis
│       │   └── Zombie
│       │       ├── CollisionShape3D
│       │       └── Visuals   Modelo, animación, vida y avisos de ataque
│       ├── Combat
│       │   ├── Projectiles
│       │   └── Grenades
│       ├── Pickups           Suministros con vida útil propia
│       ├── Effects           Partículas con un límite de instancias
│       └── WaveDirector     Planificación, aparición y fin de oleadas
├── Interface (GameHUD)
│   ├── GameplayHUD          Vida, munición, granadas y estadísticas
│   ├── HudFeedback          Banners y flash de daño
│   └── MenuScreens          Título, pausa, mejoras y resultados
└── AimCursor                Presentación del cursor según el estado
```

Los nodos y widgets permanentes se declaran en `.tscn`. Las primitivas de los modelos y de la arena se generan por código dentro de sus nodos de presentación.

## Responsabilidades y dependencias

| Componente | Responsabilidad | Entrada / salida principal |
| --- | --- | --- |
| `Game` | Estados `Mode`, pausa, reinicio y coordinación de la interfaz | Intenciones de menús y eventos de la partida |
| `RunSession` | Conectar los componentes de una partida; puntuación y recompensas | Señales de actores y de oleadas; `get_stats()` |
| `WaveDirector` | Orden y ritmo de las oleadas | Objetivo y contador inyectados; señales de aparición y fin |
| `EnemySpawner` | Crear escenas de enemigos e inyectar sus dependencias | Superviviente, navegación y servicios explícitos |
| `CombatService` | Crear proyectiles y resolver el daño de explosiones | Solicitudes de disparo y granada; población de enemigos |
| `Survivor` / `Zombie` | Movimiento, reglas y estado de cada actor | Señales de combate, audio, partículas y sacudida |
| `SurvivorVisuals` / `ZombieVisuals` | Meshes y animación | Datos del actor; nunca modifican sus reglas |
| `PickupManager` / `SupplyPickup` | Crear, caducar, recoger y aplicar suministros | Objetivo inyectado y señal `collected` |
| `Arena` / `HordeNavigation` | Geometría y navegación compartida | Rectángulos de obstáculos y objetivo de navegación |
| `GameHUD` y sus vistas | Mostrar información e intenciones del jugador | Diccionarios de estadísticas y señales de menú |
| `SaveData` | Leer y escribir récord y sonido | `user://dead_shift.cfg` |

`RunSession.configure()` es el punto de conexión de los servicios de una partida. Por ejemplo, conecta `Survivor.bullet_requested` con `CombatService.spawn_player_bullet`; el superviviente puede instanciarse y probarse sin una partida global. Los impactos de balas y las detonaciones de granadas también se comunican mediante señales.

Los grupos `player`, `enemies`, `projectiles` y `grenades` sirven para inspección y pruebas; la lógica de producción usa referencias y contenedores explícitos. Un zombi separa su movimiento de sus hermanos en `Enemies`, evitando acoplar dos poblaciones distintas.

## Ciclo de vida y pausa

- `Game` controla `SceneTree.paused`. Audio, cámara e interfaz siguen activos durante los menús.
- `RunSession` es `PROCESS_MODE_PAUSABLE`: movimiento, oleadas, proyectiles, granadas, suministros y efectos se detienen juntos.
- La navegación también es pausable, aunque pertenece a la arena persistente.
- Reiniciar descarta el nodo `RunSession` completo. No se conservan listas de actores ni temporizadores del intento anterior.
- Arena, audio, cámara, interfaz y guardado sobreviven al reinicio. La navegación y la cámara reciben el nuevo superviviente.
- Si se pausa entre el último tick de combate y la notificación diferida de fin de oleada, el director vuelve a comprobarla al continuar.

## Dónde ampliar el juego

- **Oleadas y enemigos programados:** `scripts/gameplay/wave_director.gd`.
- **Comportamiento de enemigos:** `scripts/enemy.gd`; aspecto en `scripts/actors/enemy_visuals.gd`.
- **Armas y control del jugador:** `scripts/player.gd`; aspecto en `scripts/actors/player_visuals.gd`.
- **Granadas y balas:** `scripts/grenade.gd`, `scripts/projectile.gd` y resolución de daño en `CombatService`.
- **Mejoras y reglas compartidas:** `scripts/core/game_rules.gd`.
- **Cobertura y suelo:** escena `scenes/world/arena.tscn` y `scripts/world/arena.gd`.
- **Interfaz:** `scenes/ui/hud.tscn` y los scripts de `scripts/ui/`.
- **Suministros:** `scenes/gameplay/supply_pickup.tscn` y su script.

Instanciar jugadores, enemigos e interfaz desde sus escenas, porque sus scripts esperan hijos declarados. Mantener los cambios de geometría en `Arena` y su descripción de obstáculos juntos. Las coordenadas de la arena y sus contenedores de simulación comparten el origen de la escena principal.

## Validación

Desde una copia nueva, importar primero las clases y escenas:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --fixed-fps 60 --script tests/integration.gd
godot --headless --path . -- --smoke-test
```

La suite verifica las mecánicas y ocho oleadas completas, además de propiedad de nodos, actores aislados, dependencias inyectadas, reinicios y persistencia. Restaura el guardado anterior al terminar. El runner de la prueba rápida está en `tests/smoke_test.gd`, separado del código de coordinación.
