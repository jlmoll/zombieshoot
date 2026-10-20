# Iluminación de miniatura

El acabado utiliza colores lisos, plástico satinado y biseles pequeños en pilares
y barricadas. No añade grano, desenfoque ni aberración cromática. MSAA 4× limpia
los contornos y se mantiene el renderer Compatibility.

El botón **LUZ** del menú principal y de pausa alterna entre:

1. **Turno nocturno**: modo inicial, base fría y focos ámbar.
2. **Emergencia**: focos rojos y base fría más tenue.
3. **Contención**: luz fría más clara y acentos verdes.

La selección se guarda junto al sonido y al récord. Cualquier oleada cuyo
`WaveDefinition.boss_kind` no esté vacío activa Emergencia temporalmente.
Al despejarla, incluida la última oleada, vuelve la última selección del jugador.
Cambiar la preferencia durante un boss la guarda para después. Las transiciones
duran 1,2 segundos y funcionan también con la partida pausada.

## Autoría

- `scenes/world/map_environment.tscn`: luces globales y `ArenaLighting`.
- `scripts/presentation/arena_lighting.gd`: paletas, energías y transiciones.
- `scenes/world/props/miniature_lamp.tscn`: lámpara reutilizable con luz real y lente.
- `LightingFixtures` en `arena.tscn`: ocho lámparas editables, cuatro junto a pilares
  y cuatro sobre las entradas. Moverlas junto al objeto si se reorganiza el mapa.
- Los grupos `miniature_accent` y `miniature_lens` permiten que el controlador
  encuentre luces y materiales dentro de su propio mapa, sin afectar otros mapas.

Las mallas biseladas están guardadas en `assets/meshes`; las colisiones no cambian.
Se pueden regenerar con:

```powershell
godot --headless --path . --script tools/bake_miniature_meshes.gd
```

Las luces locales tienen alcance limitado y sombras. Conviene medir el coste
en los dispositivos de destino antes de aumentar su número.

## Verificación

Capturas del motor: [Turno nocturno](previews/lighting-night.png),
[Emergencia](previews/lighting-emergency.png) y
[Contención](previews/lighting-containment.png).

La integración comprueba el selector de ambos menús, persistencia, reinicio,
cambios durante bosses y activación/restauración en las ocho oleadas reales.
`tools/preview_lighting.gd` genera capturas reales de los tres modos y menús en
`.godot/qa/lighting/`; requiere ejecutar Godot con renderizado, sin `--headless`.
