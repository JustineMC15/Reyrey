extends CanvasLayer

const FADE_TIME := 0.2
const MIN_VISIBLE_TIME := 0.35  # avoid a flicker if a load finishes instantly

@onready var background: ColorRect = $Background
@onready var rhombus: AnimatedSprite2D = $Rhombus

var _shown_at := 0.0
var _is_visible := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 500

	background.modulate.a = 0.0

	hide()


func show_loading() -> void:
	if _is_visible:
		return

	_is_visible = true
	_shown_at = Time.get_ticks_msec() / 1000.0

	show()

	if rhombus and rhombus.has_method("play"):
		rhombus.play()

	var tween := create_tween()
	tween.tween_property(background, "modulate:a", 1.0, FADE_TIME)
	await tween.finished


func hide_loading() -> void:
	if not _is_visible:
		return

	var elapsed := Time.get_ticks_msec() / 1000.0 - _shown_at
	var remaining := MIN_VISIBLE_TIME - elapsed

	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout

	var tween := create_tween()
	tween.tween_property(background, "modulate:a", 0.0, FADE_TIME)
	await tween.finished

	if rhombus and rhombus.has_method("stop"):
		rhombus.stop()

	hide()
	_is_visible = false
