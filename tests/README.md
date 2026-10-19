# Pruebas por sistema

Ejecutar todo desde PowerShell:

```powershell
./tools/test_all.ps1 -Godot 'C:/ruta/Godot_v4.7.2-stable_win64_console.exe'
```

El runner importa el proyecto y ejecuta dieciséis suites en procesos separados.
Falla ante errores de scripts, aserciones, fugas detectadas y códigos de salida
incorrectos, incluso si el motor devuelve cero. Los logs y un perfil de guardado
aislado viven en `.godot/qa/`. La integración preserva y restaura byte a byte
el guardado de ese perfil, que el runner prepara con un récord de ejemplo.

| Carpeta | Contrato |
| --- | --- |
| `actors` | Vida compartida, respuesta de actores y proyección de cursor |
| `combat` | Escenas, física, equipos, fuego amigo, contexto e impactos |
| `perks` | Definiciones, aplicación, acumulación y aislamiento |
| `rewards` | Atribución, puntos, curación, drops y coordenadas globales |
| `waves` / `validation` | Campaña completa, composición, errores y aparición bloqueada |
| `weapons` | Disparo, cargadores, recarga y equipamiento |
| `input` | Perfiles y dispositivos independientes |
| `enemies` | Variantes, ataques, animaciones y fidelidad Blender |
| `player` | Presentación, armas y fidelidad Blender |
| `fixtures` | Referencias exportadas desde los modelos Blender |

`integration.gd` mantiene la partida real completa con las ocho oleadas,
menús, pausa, reinicios, victoria, derrota y fallos de configuración.
`smoke_test.gd` sigue disponible mediante `-- --smoke-test`.

Los tests de contrato utilizan APIs públicas cuando existen, por ejemplo
`WaveDirector.advance()`. Los tests de fidelidad conservan inspección de
la jerarquía del modelo porque esa estructura es su objeto de verificación.
