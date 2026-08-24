extends CanvasLayer
# cutscene_player.gd — autoload singleton "Cutscene"
#
# Full-screen visual-novel scene: one image covering most of the
# screen, a black dialogue bar pinned to the bottom with speaker
# name + text. Space/Enter (ui_accept) advances a line, Esc
# (ui_cancel) skips the whole cutscene immediately.
#
# Usage:
#   await Cutscene.play(StoryContent.OPENING_LINES)
#
# Each line is a Dictionary: {"speaker": String, "text": String,
# "image": Texture2D}. "image" is optional — omit it and the
# previous line's image stays on screen, so a scene can run on a
# single placeholder background while you're still greyboxing.

signal cutscene_finished

const ADVANCE_ACTION := "ui_accept"
const SKIP_ACTION := "ui_cancel"
const BAR_HEIGHT := 220.0
const FADE_DURATION := 0.3

var _busy := false
var _skip_requested := false

var _root: Control
var _background_fallback: ColorRect
var _background: TextureRect
var _speaker_label: Label
var _text_label: Label


func _ready() -> void:
	layer = 501
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 0.0
	add_child(_root)

	# Solid black behind everything — shows through if a line's
	# "image" hasn't been authored yet, so nothing looks broken.
	_background_fallback = ColorRect.new()
	_background_fallback.color = Color.BLACK
	_background_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_background_fallback)

	_background = TextureRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_root.add_child(_background)

	var bar := Panel.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -BAR_HEIGHT

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.88)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	bar.add_theme_stylebox_override("panel", style)
	_root.add_child(bar)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	bar.add_child(vbox)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 22)
	_speaker_label.add_theme_color_override("font_color", Color(0.98, 0.62, 0.22, 1))
	vbox.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 26)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_text_label)

	var hint := Label.new()
	hint.text = "Space / Enter — continue      Esc — skip"
	hint.modulate.a = 0.5
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(hint)


func play(lines: Array) -> void:
	if _busy or lines.is_empty():
		return

	_busy = true
	_skip_requested = false

	var player := get_tree().get_first_node_in_group("player")

	if player and player.has_method("lock_input"):
		player.lock_input()

	visible = true

	var fade_in := create_tween()
	fade_in.tween_property(_root, "modulate:a", 1.0, FADE_DURATION)
	await fade_in.finished

	for line in lines:
		if _skip_requested:
			break

		if line.has("image"):
			_background.texture = line["image"]

		_speaker_label.text = line.get("speaker", "")
		_speaker_label.visible = _speaker_label.text != ""
		_text_label.text = line.get("text", "")

		await get_tree().create_timer(0.15).timeout

		while true:
			if Input.is_action_just_pressed(SKIP_ACTION):
				_skip_requested = true
				break

			if Input.is_action_just_pressed(ADVANCE_ACTION):
				break

			await get_tree().process_frame

	var fade_out := create_tween()
	fade_out.tween_property(_root, "modulate:a", 0.0, FADE_DURATION)
	await fade_out.finished

	visible = false

	if player and is_instance_valid(player) and player.has_method("unlock_input"):
		player.unlock_input()

	_busy = false
	cutscene_finished.emit()
