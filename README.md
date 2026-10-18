# Dead Shift — Contención

Dual stick shooter 3D con cámara isométrica, hecho en **Godot 4.7.2**. Sobrevive a ocho oleadas de zombis y derrota a los jefes de las oleadas cuatro y ocho. Todos los personajes, decorados, efectos y sonidos se generan por código; los recursos visuales son deliberadamente prototípicos.

## Jugar

Abre `project.godot` con Godot 4.7 y pulsa **F5**. También puedes ejecutar el proyecto desde consola:

```powershell
godot --path .
```

| Acción | Teclado y ratón | Mando |
| --- | --- | --- |
| Moverse | WASD | Stick izquierdo |
| Apuntar | Ratón | Stick derecho |
| Disparar | Mantener clic izquierdo | Stick derecho inclinado, RT o RB |
| Esquivar | Espacio | A o LB |
| Recargar | R | X |
| Cambiar arma | Q, rueda o 1–3 | Y |
| Lanzar granada | G o clic derecho | B |
| Pausa / continuar | Esc o P | Start |
| Navegar menús | Flechas y Enter, o ratón | Cruceta / stick y A |
| Pantalla completa | F11 | — |
| Silenciar sonido | M o botón del menú | Botón del menú |

El movimiento y la puntería son independientes. La esquiva concede invulnerabilidad breve y tiene tiempo de recuperación. Las armas recargan automáticamente al vaciarse; también puedes anticipar la recarga con R/X.

## Mecánicas

- Pistola, escopeta de perdigones y subfusil, cada uno con cargador, cadencia, dispersión y recarga propios.
- Granadas con trayectoria en arco, rebote, mecha de 1,2 segundos y daño de área sin daño al jugador. Se suman **2 al empezar cada oleada**, incluida la primera, hasta un máximo de **4**. Con ratón se lanzan hacia el cursor (alcance máximo de 10 m); con mando, en la dirección de apuntado. La cobertura bloquea la explosión.
- Zombis básicos, corredores, brutos, escupidores y jefes con ataques telegrafiados y proyectiles.
- Navegación alrededor de obstáculos, separación de la horda y colisiones con el escenario.
- Una elección de tres mejoras entre oleadas, recuperación parcial y suministros de vida y munición.
- Puntuación, récord y preferencia de sonido persistentes.
- Menú inicial, pausa, selección de mejoras, derrota, victoria y reinicio de partida.
- Pausa automática al perder el foco, sonido procedural, retroceso visual, partículas e indicadores de daño.

## Comprobación de integración

En una copia nueva, importa primero las escenas y clases con `godot --headless --path . --editor --quit`.

```powershell
godot --headless --path . -- --smoke-test
```

El modo de comprobación crea una partida real en el motor y verifica enemigos, proyectiles, daño, curación, mejoras, suministros y pausa. No requiere recursos externos ni complementos.

La suite completa comprueba física real, armas, mejoras, navegación, ataques y el ciclo de ocho oleadas, con victoria, derrota y reinicio:

```powershell
godot --headless --path . --fixed-fps 60 --script tests/integration.gd
```

Las pruebas preservan el archivo de récord y ajustes previo. La partida usa el renderizador Compatibility para reducir requisitos de GPU y no necesita descargas ni plugins.

## Organización del proyecto

La escena principal coordina nodos independientes para arena, navegación, cámara, audio, guardado e interfaz. `RunSession` contiene todos los nodos transitorios de una partida: actores, combate, suministros, efectos y oleadas. Los actores emiten señales y reciben sus dependencias; sus meshes y animaciones viven en hijos `Visuals`.

Consulta [la arquitectura y los puntos de extensión](docs/architecture.md) para ver el árbol de escenas, las responsabilidades y el ciclo de vida.

## Zombi low poly animado

El enemigo usa `assets/models/zombie_blocky.glb`, exportado desde
`assets/models/source/zombie_blocky_animated.blend`. Las variantes conservan sus
colores, tamaños y ataques. Los clips Idle y Walk se repiten; Attack se sincroniza
con la preparación de ataques especiales. Death desactiva las colisiones y conserva
el cuerpo durante la caída antes de retirarlo. Los enemigos muertos no cuentan para
las oleadas y solo conceden puntos una vez.

Para regenerar el GLB: ejecuta Blender en segundo plano con
`--background --python tools/export_blocky_zombie.py`.
Los materiales se personalizan en Blender y las paletas por tipo en
`scripts/actors/enemy_visuals.gd`.

La comprobación específica de animaciones se ejecuta con:
`godot --headless --path . --fixed-fps 60 --script tests/enemy_animation.gd`.

### Validación visual y de proporciones del zombi

`tools/export_blocky_zombie.py` exporta la pose base y las transformaciones locales
completas de los siete pivotes en cada clip. Evita la pérdida de traslaciones
constantes que deformaba el personaje al exportar las pistas NLA.

`godot --headless --path . --script tests/enemy_model_fidelity.gd` compara 444
posiciones de piezas importadas con muestras evaluadas en Blender, con tolerancia
de 1 cm para la optimización de animaciones del importador. El exportador regenera
`tests/fixtures/blocky_blender_reference.json` desde el archivo Blender.

`godot --path . --script tools/preview_zombie_godot.gd` genera capturas cercanas de
la pose base y los cuatro clips en `assets/models/qa_godot_*.png` para inspección.
