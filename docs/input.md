# Input Map y controles por jugador

## Estructura

`Player/PlayerInput` es el lector de entrada del personaje. El actor ya no contiene teclas, botones, ejes de mando ni búsquedas del primer mando conectado. Recibe órdenes semánticas y vectores de movimiento/apuntado.

Los bindings se editan en **Project Settings > Input Map**, dentro de `project.godot`:

- `p1_*`: perfil del primer jugador.
- `p2_*`: perfil del segundo jugador.
- `game_*`: acciones globales de partida y aplicación.

Cada perfil contiene `move_left/right/up/down`, `aim_left/right/up/down`, `fire`, `dash`, `reload`, `grenade`, `next_weapon`, `previous_weapon` y `weapon_1/2/3`. No comparte acciones de gameplay con el otro perfil.

## Asignación inicial

| Perfil | Teclado y ratón | Mando |
| --- | --- | --- |
| P1 | WASD, ratón y atajos actuales | ID 0 |
| P2 | Sin bindings de teclado por defecto | ID 1 |

Movimiento: stick izquierdo o cruceta. Apuntado: stick derecho. Disparo: gatillo derecho, botón superior derecho o apuntado con stick derecho. Esquiva: botón superior izquierdo o A. Recarga: X. Granada: B. Cambio de arma: Y.

En teclado se conservan espacio, R, G, Q, 1–3, rueda y botones del ratón. Los bindings de teclado actuales usan códigos lógicos para respetar las etiquetas mostradas; pueden cambiarse a teclas físicas desde Input Map.

Las acciones globales son `game_pause` (Escape, P y Start), `game_start` (Enter y Start), `game_fullscreen` (F11) y `game_mute` (M). Los atajos globales se gestionan en `Game._shortcut_input()`; Enter solo inicia desde título si la interfaz no consumió el evento.

## Preparar dos personajes

Cada personaje necesita un `PlayerInput` con un `player_slot` distinto. Configura la propiedad antes de añadir el personaje al árbol: 1 para el primero y 2 para el segundo.

El campo `gamepad_device` permite asignar el dispositivo al arrancar:

- `-2`: conservar los dispositivos definidos actualmente en Input Map, valor inicial.
- `-1`: desactivar el mando de ese perfil, manteniendo teclado/ratón.
- `0` o superior: asignar ese ID de mando a todos los bindings de mando de su perfil.

Para teclado/ratón más un solo mando:

```gdscript
first.get_node("PlayerInput").player_slot = 1
first.get_node("PlayerInput").gamepad_device = -1
second.get_node("PlayerInput").player_slot = 2
second.get_node("PlayerInput").gamepad_device = 0
```

Un futuro lobby puede llamar `controls.assign_gamepad(device_id)` en nodos ya inicializados. La reasignación solo cambia los bindings de mando del perfil correspondiente, limpia entradas retenidas y conserva sus bindings de teclado/ratón. Los bindings desactivados pueden restaurarse también al recrear el personaje.

No asignes el mismo perfil a dos personajes activos ni el mismo mando a dos perfiles, salvo que quieras que compartan entrada. Se conserva la asignación por ID: desconectar un mando no hace que otro personaje se apropie automáticamente del mando restante.

El ratón del sistema pertenece al perfil 1; `mouse_aim_enabled` permite desactivar su apuntado con ratón. El perfil 2 usa sus acciones de apuntado y conserva su última dirección al soltar el stick. `stick_aim_fires` permite desactivar el disparo automático del stick sin cambiar el arma.

La capa de entrada admite dos personajes y mandos independientes. La partida actual continúa instanciando un jugador: cámara, HUD, selección de objetivos de enemigos y reglas de cooperación siguen siendo sistemas de un jugador y se ampliarán cuando se implemente el modo cooperativo.

## Interfaz, pausa y eventos continuos

Las órdenes de gameplay se emiten desde `_unhandled_input()`, después de que la interfaz tenga oportunidad de consumirlas. El lector solo acepta acciones de su perfil.

Para movimiento, apuntado y disparo sostenido se leen las intensidades de Input Map, filtradas por los presses que llegaron al lector. Así un botón o tecla consumido por la interfaz no activa movimiento o disparo por el mero hecho de figurar en el estado global de `Input`. Las liberaciones se reflejan en ese estado global aunque la interfaz las consuma, evitando entradas pegadas. Los vectores usan zona muerta radial y longitud máxima 1.

`_input()` únicamente detecta movimiento del puntero para seleccionar el método de apuntado. No ejecuta acciones de gameplay. Los lectores heredan la pausa de la partida. Perder el foco limpia la entrada aceptada y desconectar un mando limpia las acciones asociadas a ese dispositivo.

## Validación

```text
godot --headless --path . --fixed-fps 60 --script tests/input/input_profiles.gd
godot --headless --path . --fixed-fps 60 --script tests/integration.gd
```

La prueba de perfiles instancia dos personajes y envía eventos reales de Godot con dos IDs de mando simulados. Comprueba entrada simultánea, aislamiento de movimiento/apuntado/disparo/cambio, reasignación de mando, remapeo de teclas, UI, zona muerta, desconexión y recreación del personaje.
