# Armas como escenas editables

## Decisión: composición y herencia de escenas corta

Una jerarquía de scripts `Weapon -> Firearm -> Automatic -> SMG` separaría armas que en este juego comparten todas sus reglas. Duplicar scripts por arma también duplicaría recarga, cadencia y correcciones de errores. En el extremo contrario, convertir cada número o cada temporizador en un nodo complicaría la edición.

La implementación combina:

- **Un contrato `Weapon`** para un arma completa, sin referencias al jugador, al HUD ni a la partida.
- **Composición** para cargador, patrón balístico y presentación 3D.
- **Herencia de escenas de un nivel**: pistola, escopeta y subfusil derivan de `weapon.tscn`. Cambian valores y modelo; usan el mismo script.
- **Herencia de scripts solo para comportamiento nuevo**. Por ejemplo, un emisor puede extender `ProjectileEmitter` y sobrescribir `get_directions()`. No hacen falta subclases para cambiar daño o número de perdigones.

## Escena de arma

```text
Pistol / Shotgun / SubmachineGun (Weapon)
├── Magazine (WeaponMagazine)
├── Emitter (ProjectileEmitter)
└── Presentation (WeaponPresentation)
    └── RecoilRoot
        ├── Muzzle (Marker3D)
        │   └── Flash
        └── ModelSlot
            └── Model (escena 3D propia)
```

Escenas iniciales:

- `scenes/weapons/pistol.tscn`
- `scenes/weapons/shotgun.tscn`
- `scenes/weapons/smg.tscn`

Abre cualquiera de ellas. En la raíz, el inspector agrupa las propiedades de identidad, balística, cargador, feedback y referencias a componentes. Daño, intervalo, velocidad, dispersión en radianes, perdigones, penetración, capacidad, recarga, sonidos, fogonazo, retroceso y sacudida se configuran en esa instancia. Los modelos se guardan aparte en `scenes/weapons/models/`.

La configuración base pertenece a la escena y no se modifica al aplicar perks. La munición, el progreso de recarga, los modificadores y el cooldown pertenecen a cada instancia. No hay diccionarios paralelos de armas ni copias de la munición en el jugador.

## Modelo y agarre

Para sustituir el aspecto, reemplaza el hijo `Model` de `Presentation/RecoilRoot/ModelSlot` por una escena propia, incluido un GLB. Ajusta posición, rotación y escala en el modelo o en `ModelSlot`. Las armas actuales apuntan hacia +Z local; el retroceso se mueve hacia -Z.

Coloca `Presentation/RecoilRoot/Muzzle` en la boca real del cañón. Es el origen usado para los proyectiles y el fogonazo; no se calcula a partir del tipo de arma. El arma corrige el origen cuando el modelo atraviesa visualmente una cobertura para evitar disparar a través de paredes.

La transformación local de la raíz del arma se conserva al montarla: puede usarse para ajustar el agarre de una variante. Usa `ModelSlot` para ajustes puramente visuales y deja `RecoilRoot` para el desplazamiento de retroceso compartido.

## Equipamiento y señales

`Player/WeaponController` contiene las tres escenas de arma en el editor. Al iniciar, registra esas instancias y las monta completas bajo el `WeaponSocket` animado del personaje, conservando referencias al inventario. Las instancias se liberan con el árbol del jugador.

El controller selecciona el arma, oculta las guardadas y mantiene la espera compartida de cambio/disparo. Cada arma controla su cargador y cadencia. Cambiar cancela la recarga saliente, conserva sus balas y no elimina la espera de cadencia anterior.

Flujo de disparo:

1. El jugador interpreta el input y comprueba si está vivo o esquivando.
2. `WeaponController.try_fire()` valida el bloqueo compartido y delega en el arma.
3. `Weapon.try_fire()` consume una bala y pide al emisor su patrón de proyectiles.
4. Las señales `projectile_requested`, `sound_requested` y `trauma_requested` se propagan al jugador y a los servicios de partida ya existentes.
5. El arma activa su propio fogonazo y retroceso; `fired` hace que la presentación del personaje adopte su pose de apuntado.

Los componentes no buscan hermanos mediante rutas de padres. `Weapon` recibe referencias exportadas a sus componentes y los coordina. La presentación del personaje conserva el cuerpo y las animaciones; ya no fabrica ni selecciona modelos de armas.

Para usar un arma aislada basta instanciar su escena, conectar las señales y llamar `try_fire(direccion, posicion_del_portador)`, `start_reload()` y `advance(delta)`. El controlador de tiempo debe dejar de avanzar cuando el portador no esté activo; el jugador actual lo hace desde su tick de física pausable.

## Añadir un arma

1. Crea una escena heredada de `scenes/weapons/weapon.tscn`.
2. Configura sus propiedades y un `weapon_id` distinto.
3. Añade su modelo en `ModelSlot` y sitúa `Muzzle`.
4. Instancia la escena como hijo de `Player/WeaponController`.

El ciclo con Q, rueda y mando recorre todas las armas encontradas. Las acciones numéricas actuales son `p1_weapon_1/2/3` y `p2_weapon_1/2/3`; sus bindings se editan en Input Map. Consulta [entrada por jugador](input.md).

Para cambiar únicamente la distribución de proyectiles, sustituye el script del componente `Emitter` por una subclase de `ProjectileEmitter`. Para cambiar toda la mecánica de disparo, extiende el contrato de `Weapon` en una escena específica. El emisor actual es balístico; hitscan o proyectiles con efectos propios requieren ampliar el contrato con `CombatService`.

## Validación

```text
godot --headless --path . --fixed-fps 60 --script tests/weapons/weapons.gd
godot --headless --path . --fixed-fps 60 --script tests/player/player_presentation.gd
godot --headless --path . --fixed-fps 60 --script tests/integration.gd
```

Las pruebas cubren armas sin jugador, transformaciones de la boca, configuración por instancia, aislamiento de munición y perks, recarga cancelada, bloqueo de cadencia al cambiar, reinicio, presentación del personaje y las ocho oleadas.
