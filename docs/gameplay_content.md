# Contenido, estado y servicios

El contenido editable vive en escenas y Resources. Los actores y componentes
conservan el estado de una instancia; `RunSession` conecta sus dependencias.

## Proyectiles y daño

Las escenas `scenes/projectiles/player_bullet.tscn`, `enemy_bullet.tscn` y
`grenade.tscn` contienen meshes, materiales y colisiones. `Bullet` usa rayos
barridos para impactos continuos y permite penetración. La granada conserva
rebote, mecha, radio, caída del daño y bloqueo por cobertura.

Cada `Weapon` y `EnemyAttack` exporta `projectile_scene`. Cambiar esa propiedad
permite sustituir el proyectil sin cambiar el servicio de combate. La escena
de granada se elige en `CombatService.grenade_scene`.

`DamageContext` acompaña al disparo hasta el impacto: origen, portador,
equipo, identificador de ataque, posición y dirección del impacto. Las referencias
al origen y portador son débiles. `for_hit()` crea un contexto por impacto,
incluidos los impactos de un proyectil penetrante. `friendly_fire` habilita
explícitamente daño a aliados y al propio portador; está desactivado por defecto.

Los actores reciben `take_damage(amount, context)` y exponen
`get_damage_team()`. El argumento de contexto es opcional para daño ambiental
o herramientas, pero una muerte sin portador no otorga puntos ni una baja al
jugador. Las señales antiguas de disparo sirven como observación; la creación
real utiliza `projectile_spawn_requested`, que incluye contexto y escena.

## Vida y perks

`scenes/components/health_component.tscn` contiene `HealthComponent`, compartido por
jugador y enemigos. Es propietario de vida actual, máxima, curación y señales
de cambio y agotamiento. Invulnerabilidad, retroceso, animaciones y muerte
pertenecen al actor. `health` y `max_health` son fachadas públicas del componente.

Los Resources en `assets/perks/` reúnen identidad, título, descripción y
parámetros de cada mejora. `PerkCatalog` resuelve identificadores y aliases;
`Survivor.apply_perk()` aplica parámetros del actor y
`WeaponController.apply_perk()` los del equipamiento. Las definiciones se
comparten sin mutarlas: acumulación y reinicio afectan solo al estado local.

## Oleadas y recompensas

`assets/waves/default_campaign.tres` referencia ocho `WaveDefinition` con
cantidades, intervalos, límite simultáneo, composición, jefe e intermisión.
Las reglas de composición se evalúan en orden: la última coincidencia gana.
El serial de aparición se mantiene durante toda la campaña para preservar
el diseño original. `WaveDirector` ejecuta esos datos y expone
`get_current_wave()`, `get_wave_count()` y `get_intermission_duration()`.

`RunRewards`, en `scenes/gameplay/run_rewards.tscn`, posee puntuación, bajas,
bonificaciones, curación entre oleadas y reglas de suministros. Atribuye la
baja al portador del contexto mortal y evita recompensas duplicadas.
`PickupManager` crea suministros y anuncia la recogida; `RunRewards` decide
su efecto. Las reglas numéricas se editan en el componente Rewards.

## Coordenadas

Todos los servicios de creación (`EnemySpawner`, `CombatService`,
`PickupManager` e `ImpactEffects`) reciben posiciones y direcciones **globales**.
El servicio convierte a coordenadas locales o configura la escena después de
insertarla en su contenedor. `PrototypeMeshes` es una utilidad de construcción
de meshes hijos y recibe posiciones **locales**.

El plano de juego permanece en Y global = 0. Los mapas admiten traslación XZ
y rotación sobre Y. `CursorProjection.project()` comparte el
cálculo del cursor entre apuntado (altura de la boca) y granadas (suelo).

## Validación

El plugin habilitado `Content Validation` añade **Project > Tools > Validate
Gameplay Content** y comprueba contenido antes de ejecutar desde el editor.
Valida escenas abiertas, referencias de componentes, escenas de proyectil y
granada, registro de enemigos, ataques concretos y entradas para cada tipo y
oleada. Al abrir la escena principal o una arena también cruza el mapa con
la campaña y el registro de la sesión.

La ejecución comprueba el contenido antes de inicializar la partida. Un error
detiene la simulación y muestra un mensaje; las apariciones bloqueadas por
distancia o navegación fallan tras el tiempo configurable de la oleada
(`blocked_spawn_timeout`, 15 segundos por defecto). No se descartan enemigos
pendientes ni se sustituye silenciosamente un tipo no registrado.

Los perfiles de entrada siguen siendo independientes. Registro de jugadores,
selección de objetivos, cámara compartida y HUD cooperativo quedan para la
entrega de cooperativo.
