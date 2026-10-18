class_name AimCursor
extends Node
## Cursor presentation follows explicit state changes, not a frame poll.

var _reticle: ImageTexture
var _enabled: bool = false

func _ready() -> void:
	var bitmap: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	bitmap.fill(Color.TRANSPARENT)
	for y in range(32):
		for x in range(32):
			var horizontal: bool = absi(y - 16) <= 1 and absi(x - 16) >= 5 and absi(x - 16) <= 11
			var vertical: bool = absi(x - 16) <= 1 and absi(y - 16) >= 5 and absi(y - 16) <= 11
			if horizontal or vertical or Vector2(x - 16, y - 16).length() < 1.8:
				bitmap.set_pixel(x, y, Color("edfff7"))
	_reticle = ImageTexture.create_from_image(bitmap)

func set_gameplay(enabled: bool) -> void:
	if _enabled == enabled:
		return
	_enabled = enabled
	Input.set_custom_mouse_cursor(_reticle if enabled else null, Input.CURSOR_ARROW, Vector2(16, 16) if enabled else Vector2.ZERO)

func _exit_tree() -> void:
	if _enabled:
		Input.set_custom_mouse_cursor(null)
