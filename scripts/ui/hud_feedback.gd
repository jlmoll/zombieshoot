class_name HudFeedback
extends "res://scripts/ui/ui_view.gd"
## Transient presentation effects independent from menu composition and stats.

@onready var banner: VBoxContainer = $Banner
@onready var banner_title: Label = $Banner/TitleLabel
@onready var banner_subtitle: Label = $Banner/SubtitleLabel
@onready var damage_flash: ColorRect = $DamageFlash

var _banner_timer: float = 0.0
var _flash_amount: float = 0.0


func _ready() -> void:
	_style_label(banner_title, 34, AMBER)
	_style_label(banner_subtitle, 15)


func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer = maxf(0.0, _banner_timer - delta)
		banner.modulate.a = minf(1.0, _banner_timer * 2.0)
		banner.visible = _banner_timer > 0.0
	_flash_amount = maxf(0.0, _flash_amount - delta * 1.7)
	damage_flash.color.a = _flash_amount


func set_banner(title: String, subtitle: String = "", duration: float = 2.5) -> void:
	banner_title.text = title
	banner_subtitle.text = subtitle
	_banner_timer = duration
	banner.modulate.a = 1.0
	banner.show()


func clear_banner() -> void:
	banner.hide()
	_banner_timer = 0.0


func set_damage_flash() -> void:
	_flash_amount = 0.28
