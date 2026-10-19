# Arquitectura de Dead Shift

La escena principal compone los sistemas y coordina los estados de aplicación. La lógica de una partida vive en una escena independiente; los actores comunican sus intenciones mediante señales y no buscan la escena raíz.

## Árbol de nodos

```text
DeadShift (Game)
├── SaveData                  Récord y preferencias persistentes
├── Audio (GameAudio)         Banco de sonidos y voces reutilizables
├── CameraRig
│   └── Camera                Seguimiento isométrico y sacudidas
├── SessionSlot
│   └── RunSession            Una instancia nueva por partida
│       ├── Arena             Mapa recreado al reiniciar, con geometría, entradas y navegación
│       ├── Player
│       │   ├── CollisionShape3D
│       │   ├── PlayerInput   Acciones por perfil y dispositivo local
│       │   ├── WeaponController  Selección y bloqueo de cambio de armas
│       │   │   └── Weapon × 3   Escenas completas con cargador, emisor y modelo propio
│       │   └── Visuals       Cuerpo y animación; monta armas en WeaponSocket
│       ├── Enemies           EnemySpawner; propietario de los zombis
│       │   └── Zombie
│       │       ├── CollisionShape3D
│       │       ├── Movement / Combat  Componentes y ataques reutilizables
│       │       └── Visuals   Modelo, detalles, vida y avisos guardados como nodos
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

Los nodos y widgets permanentes se declaran en `.tscn`. La geometría de la arena se guarda en la escena: suelo y estructura en GridMaps; props, entorno y entradas en escenas reutilizables de `scenes/world/`. Los modelos de actores mantienen sus propios nodos de presentación.

## Responsabilidades y dependencias

| Componente | Responsabilidad | Entrada / salida principal |
| --- | --- | --- |
| `Game` | Estados `Mode`, pausa, reinicio y coordinación de la interfaz | Intenciones de menús y eventos de la partida |
| `RunSession` | Conectar los componentes de una partida; puntuación y recompensas | Señales de actores y de oleadas; `get_stats()` |
| `WaveDirector` | Orden y ritmo de las oleadas | Objetivo y contador inyectados; señales de aparición y fin |
| `EnemySpawner` | Crear escenas de enemigos e inyectar sus dependencias | Superviviente, navegación y servicios explícitos |
| `CombatService` | Crear proyectiles y resolver el daño de explosiones | Solicitudes de disparo y granada; población de enemigos |
| `Survivor` / `Zombie` | Movimiento, reglas y estado de cada actor | Señales de combate, audio, partículas y sacudida |
| `SurvivorVisuals` / `ZombieVisuals` | Cuerpo y animación | Datos del actor; nunca modifican sus reglas |
| `EnemyMovement` / `EnemyCombat` / `EnemyAttack` | Movimiento y ataques compuestos de cada variante | Objetivo, navegación y población inyectados; señales de efectos |
| `PlayerInput` | Lectura de controles por jugador, filtrada por UI | Perfiles p1/p2 de Input Map; comandos semánticos |
| `WeaponController` | Inventario, montaje, selección y bloqueo compartido | Órdenes del portador y señales de armas |
| `Weapon` | Contrato de arma, configuración y cadencia | Componentes exportados; señales de proyectiles y feedback |
| `WeaponMagazine` / `ProjectileEmitter` / `WeaponPresentation` | Munición y recarga, patrón balístico, modelo y boca propios | Composición de cada escena de arma |
| `PickupManager` / `SupplyPickup` | Crear, caducar, recoger y aplicar suministros | Objetivo inyectado y señal `collected` |
| `Arena` / `HordeNavigation` | Mapa editable y navegación compartida | Colisiones, área jugable y objetivo inyectado |
| `SpawnZone` | Entradas editables de enemigos | Anchura, peso, oleada, tipos permitidos y distancia mínima |
| `GameHUD` y sus vistas | Mostrar información e intenciones del jugador | Diccionarios de estadísticas y señales de menú |
| `SaveData` | Leer y escribir récord y sonido | `user://dead_shift.cfg` |

`RunSession.configure(map, audio, camera_rig)` es el único punto de inicialización de una partida: sitúa al jugador en su marcador, asigna el mapa y sus límites y conecta todos los servicios antes de `start()`. Por ejemplo, conecta `Survivor.bullet_requested` con `CombatService.spawn_player_bullet`; el superviviente puede instanciarse y probarse sin una partida global. Los impactos de balas y las detonaciones de granadas también se comunican mediante señales.

Los grupos `player`, `enemies`, `projectiles` y `grenades` sirven para inspección y pruebas; la lógica de producción usa referencias y contenedores explícitos. Un zombi separa su movimiento de sus hermanos en `Enemies`, evitando acoplar dos poblaciones distintas.

## Ciclo de vida y pausa

- `Game` controla `SceneTree.paused`. Audio, cámara e interfaz siguen activos durante los menús.
- `RunSession` es `PROCESS_MODE_PAUSABLE`: movimiento, oleadas, proyectiles, granadas, suministros y efectos se detienen juntos.
- El mapa y su navegación pertenecen a la partida y también se pausan.
- Reiniciar descarta el nodo `RunSession` completo. No se conservan listas de actores ni temporizadores del intento anterior.
- Audio, cámara, interfaz y guardado sobreviven al reinicio. El mapa se instancia de nuevo desde `Game.map_scene`; la navegación y la cámara reciben el nuevo superviviente.
- Si se pausa entre el último tick de combate y la notificación diferida de fin de oleada, el director vuelve a comprobarla al continuar.

## Dónde ampliar el juego

- **Oleadas y enemigos programados:** `scripts/gameplay/wave_director.gd`.
- **Enemigos:** base `scenes/actors/enemy.tscn`, variantes en `scenes/enemies/` y componentes en `scripts/enemies/`; consulta [enemigos editables](enemies.md).
- **Armas:** escenas en `scenes/weapons/` y componentes en `scripts/weapons/`; consulta [armas editables](weapons.md).
- **Controles:** bindings en `project.godot`, lector `scripts/input/player_input.gd`; consulta [entrada por jugador](input.md).
- **Movimiento del jugador:** `scripts/player.gd`; cuerpo y animación en `scripts/actors/player_visuals.gd`.
- **Granadas y balas:** `scripts/grenade.gd`, `scripts/projectile.gd` y resolución de daño en `CombatService`.
- **Mejoras y reglas compartidas:** `scripts/core/game_rules.gd`.
- **Mapas, estructura y props:** escena `scenes/world/arena.tscn` y `scripts/world/arena.gd`.
- **Interfaz:** `scenes/ui/hud.tscn` y los scripts de `scripts/ui/`.
- **Suministros:** `scenes/gameplay/supply_pickup.tscn` y su script.

Instanciar jugadores, enemigos e interfaz desde sus escenas, porque sus scripts esperan hijos declarados. La navegación lee las colisiones estáticas de la escena, sin una segunda descripción manual de obstáculos. El mapa admite traslación y rotación sobre Y dentro del plano de juego. Consulta [edición de mapas](map_authoring.md).

## Validación

Desde una copia nueva, importar primero las clases y escenas:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --fixed-fps 60 --script tests/integration.gd
godot --headless --path . -- --smoke-test
```

La suite verifica las mecánicas y ocho oleadas completas, además de propiedad de nodos, actores aislados, dependencias inyectadas, reinicios y persistencia. Restaura el guardado anterior al terminar. El runner de la prueba rápida está en `tests/smoke_test.gd`, separado del código de coordinación.
