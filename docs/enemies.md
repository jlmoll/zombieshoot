# Enemigos como escenas y componentes reutilizables

## Orientación

El GLB original mira hacia +Z local: nariz, ojos y brazos están en ese lado. La escena antigua lo giraba 180 grados y el código orientaba su padre con la dirección negada. Había dos compensaciones distintas, y el movimiento por navegación seguía mirando al jugador aunque la ruta tomase un desvío.

La base actual no gira el modelo importado. La orientación se calcula con `atan2(facing.x, facing.z)`, usando la misma convención +Z que el personaje y las armas. Los enemigos de persecución miran en la dirección de su ruta. El spitter mantiene la mirada al objetivo cuando se retira y reproduce Walk en sentido inverso. Un ataque o una muerte restablecen la reproducción positiva.

No se ha modificado el GLB ni su fuente Blender. `tests/enemies/enemy_model_fidelity.gd` sigue comprobando las 444 posiciones de mallas contra la referencia exportada de Blender.

## Escenas

La escena base es `scenes/actors/enemy.tscn`. Las variantes son escenas heredadas de un nivel:

- `scenes/enemies/walker.tscn`
- `scenes/enemies/runner.tscn`
- `scenes/enemies/brute.tscn`
- `scenes/enemies/spitter.tscn`
- `scenes/enemies/boss.tscn`

```text
Enemy (Zombie, CharacterBody3D)
├── CollisionShape3D
├── Visuals (ZombieVisuals)
│   ├── Body
│   │   ├── ZombieModel (GLB propio, +Z frontal)
│   │   └── VariantDetails
│   │       └── Details (escena opcional)
│   └── Indicators
│       ├── HealthBar
│       │   ├── Background
│       │   └── Fill
│       └── AttackWarning
├── Movement (EnemyMovement)
├── Combat (EnemyCombat)
│   └── Ataques opcionales
└── AttackOrigin (Marker3D)
```

La raíz expone identidad, vida base, escalado por oleada, velocidad, daño de contacto, puntuación, radio, escala visual, reacción al daño y duración del cadáver. Radio, escala visual y altura de impacto actualizan la cápsula y el tamaño del modelo desde el editor. Las referencias a componentes se asignan en la escena.

`Visuals` expone colores de piel y ropa, visibilidad permanente de la barra, velocidad de giro, reproducción de muerte y punto de impacto de la animación. Sus indicadores ya existen como nodos; no se regeneran al crear cada enemigo. Los materiales se localizan por instancia para que un color no modifique otros enemigos.

El saco del spitter y las púas del boss son escenas propias en `scenes/enemies/models/`. Puedes moverlas, sustituirlas o eliminarlas desde la variante, sin cambiar scripts ni editar el modelo original.

## Composición e herencia

Igual que las armas, las variantes de datos usan herencia de escenas sin scripts repetidos. La raíz comparte movimiento físico, contacto, vida, daño y muerte. Los comportamientos variables se componen:

- `EnemyMovement`: persecución, consulta de navegación y separación de una población inyectada. Sus propiedades activan retirada y movimiento lateral para el spitter. No recorre el padre para buscar otros zombis.
- `EnemyCombat`: selección por prioridad, espera inicial, cooldown, fijación del objetivo y telegráficos.
- `EnemyAttack`: contrato base para un ataque. Sus propiedades controlan alcance, preparación, cooldown y aviso.
- `EnemyFanAttack`: abanico apuntado a la posición fijada del objetivo.
- `EnemyRadialAttack`: anillo de proyectiles, con densidad alternativa al bajar la vida.
- `EnemySlamAttack`: daño cercano y efectos; compone otro `EnemyRadialAttack` para su anillo.

Los ataques se guardan como escenas reutilizables en `scenes/enemies/attacks/`. El spitter instancia `spit.tscn`; el boss instancia `slam.tscn` y `burst.tscn`. El orden de los hijos de Combat define la prioridad cuando varios ataques tienen alcance válido. Los ataques anidados son payloads, no opciones de selección independientes.

Los ataques emiten señales de proyectiles, partículas y sacudida que pasan por Combat y el actor hacia los servicios de la partida. No dependen de la escena Game. El actor base y los visuales no contienen un `match kind` para decidir la variante.

## Añadir una variante

1. Crea una escena heredada de `scenes/actors/enemy.tscn`.
2. Asigna un `kind` y sus propiedades de estadísticas y tamaño.
3. Ajusta la paleta y los detalles en `Visuals`.
4. Añade ataques como hijos de `Combat` o deja ese nodo vacío para un enemigo de contacto.
5. Registra su escena en `EnemySpawner.enemy_scenes`, un diccionario exportado en el inspector.

El spawner instancia la escena registrada, aplica `configure_wave(wave)` e inyecta objetivo, navegación, población y servicios. La oleada modifica la vida inicial; no sustituye las propiedades de la variante. Para un modelo diferente, reemplaza `Visuals/Body/ZombieModel`, conservando la convención +Z y clips Idle, Walk, Attack y Death, o proporciona una presentación compatible.

Para ampliar un ataque cambia los valores de su nodo. Si necesita una mecánica nueva, hereda de `EnemyAttack` y sobrescribe `execute()`. No hace falta una nueva subclase de enemigo para combinar un movimiento con un ataque existente.

## Validación

```text
godot --headless --path . --fixed-fps 60 --script tests/enemies/enemies.gd
godot --headless --path . --fixed-fps 60 --script tests/enemies/enemy_animation.gd
godot --headless --path . --script tests/enemies/enemy_model_fidelity.gd
godot --headless --path . --fixed-fps 60 --script tests/integration.gd
```

Las pruebas de orientación usan las posiciones reales de nariz y cráneo, cuatro direcciones, desplazamiento físico y un desvío de navegación. También comprueban retirada, transición a ataque, aislamiento entre instancias, colisiones, las cinco variantes y las ocho oleadas.
