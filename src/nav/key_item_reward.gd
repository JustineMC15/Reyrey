extends Control
class_name KeyItemReward

@export var display_duration: float = 3.0
@export var fade_duration: float = 0.4
@export var show_duration: float = 0.25

@onready var icon: TextureRect = $Icon
@onready var name_label: Label = $NameLabel

var hide_tween: Tween
var show_tween: Tween


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	name_label.text = ""


func show_key(key_icon: Texture2D, key_name: String) -> void:
	icon.texture = key_icon
	name_label.text = key_name

	if hide_tween:
		hide_tween.kill()
		hide_tween = null

	if show_tween:
		show_tween.kill()
		show_tween = null

	visible = true
	modulate.a = 0.0

	show_tween = create_tween()

	show_tween.tween_property(
		self,
		"modulate:a",
		1.0,
		show_duration
	)

	_restart_hide_timer()


func _restart_hide_timer() -> void:
	if hide_tween:
		hide_tween.kill()

	hide_tween = create_tween()

	hide_tween.tween_interval(display_duration)

	hide_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		fade_duration
	)

	hide_tween.tween_callback(_finish_hide)


func _finish_hide() -> void:
	visible = false
	hide_tween = null
