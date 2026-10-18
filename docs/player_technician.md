# Protagonista: técnica de mantenimiento

La protagonista usa `assets/models/player_technician.glb` a escala 0,9. La fuente
estática editable está en `assets/models/source/player_technician.blend` y la fuente
animada en `assets/models/source/player_technician_animated.blend`.

Los materiales nombrados permiten cambiar piel, pelo, mono, chaleco, botas y bandas.
El pelo/coleta, chaleco, auriculares, batería y extremidades son piezas separadas.
Las bandas de los puños se apoyan sobre el frente de las mangas, y guantes y
articulaciones usan pequeños solapes para evitar huecos al moverse.

## Animación e integración

Los clips de Blender son Idle, Walk, Aim, Dash, Reload y Death. LowerBody_Pivot y
UpperBody_Pivot permiten orientar el desplazamiento y el apuntado por separado.
Godot combina los canales de piernas de Walk con los de brazos de Reload cuando
se recarga en movimiento, e invierte el paso al retroceder.

Las tres armas se montan sobre WeaponSocket. Muzzle indica el origen real de las
balas y el fogonazo, incluido el cambio de longitud de cada arma. Death dura unos
0,67 segundos y sigue reproduciéndose cuando el menú de derrota pausa la partida;
el reinicio restaura el procesamiento y la pose normal.

El exportador escribe las transformaciones locales completas de todos los pivotes,
incluidas las posiciones constantes. La importación usa 24 fps y desactiva el
optimizador de AnimationPlayer para conservar fielmente las poses rápidas.

## Regeneración y revisión

Desde la raíz del proyecto, usando el ejecutable local de Blender:

```text
blender --background --python tools/generate_player_technician.py
blender --background --python tools/animate_player_technician.py
blender --background --python tools/export_player_technician.py
godot --headless --path . --editor --quit
```

El primer comando reconstruye la fuente estática desde el generador. Para conservar
ediciones manuales del archivo Blender, ejecutar solo los comandos posteriores.

```text
godot --headless --path . --script tests/player_model_fidelity.gd
godot --headless --path . --fixed-fps 60 --script tests/player_presentation.gd
godot --headless --path . --fixed-fps 60 --script tests/integration.gd
```

La prueba de fidelidad contrasta posiciones y límites de cada pieza contra 30 poses
evaluadas en Blender. La prueba de presentación comprueba clips, desplazamiento
independiente, retroceso, recarga, armas, origen de proyectiles, muerte pausada y
reinicio. La suite general ejercita las ocho oleadas y preserva los datos de usuario.

Para revisar las imágenes renderizadas en el motor:

```text
godot --path . --script tools/preview_player_godot.gd
godot --path . --script tools/preview_player_weapons.gd
godot --path . --script tools/preview_player_ingame.gd
```

Las dos primeras herramientas generan vistas cercanas de los seis clips y de las
tres armas en frontal oblicuo y lateral. La última captura la escena real en partida
y una vista ampliada para revisar personaje, disparos y escala respecto a enemigos.
Las capturas están en `assets/models/qa_player_*.png` y
`assets/models/player_technician_ingame*.png`.
