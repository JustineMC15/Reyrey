extends CanvasLayer
# potion_tutorial_ui.gd — autoload singleton "PotionTutorialUI"
#
# Two one-shot prompts, styled like the movement/jump/attack
# tutorials in tutorial_ui.tscn, dismissed the same way
# AbilityTutorialUI dismisses its prompts — by the player actually
# doing the thing, not by a timer.
#
# "potion_menu" — appears the first time a Wondrous Star Potion slot
# is unlocked (the world pickup), pointing at the mixing menu (P)
# and the potion map (O). Dismissed the first time either menu opens.
#
# "use_potion" — appears the first time the player has a charged
# mix, pointing at the drink keybind (G). Dismissed the first time a
# potion is actually drunk.
#
# Both tracked through GameState's existing tutorials_seen
# dictionary, so nothing new is needed in the save format.

const TUTORIAL_FONT := preload("res://assets/fonts/Seshat.otf")
const FADE_IN_DURATION := 0.25
const FADE_OUT_DURATION := 0.25

var _panel: Panel
var _label: Label
var _active_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 201

	_build_ui()

	GameState.potion_slot_unlocked.connect(_on_potion_slot_unlocked)
	GameState.modal_opened.connect(_on_modal_opened)
	GameState.potion_mix_changed.connect(_on_potion_mix_changed)
	GameState.potion_used.connect(_on_potion_used)


func _build_ui() -> void:
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -220.0
	_panel.offset_right = 220.0
	_panel.offset_top = 176.0
	_panel.offset_bottom = 396.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.6, 0.6, 0.0)
	_panel.add_theme_stylebox_override("panel", style)

	_panel.modulate.a = 0.0
	_panel.hide()
	add_child(_panel)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_font_override("font", TUTORIAL_FONT)
	_label.add_theme_font_size_override("font_size", 40)
	_label.add_theme_color_override("font_color", Color.BLACK)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 1)
	_label.add_theme_constant_override("line_spacing", 2)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_panel.add_child(_label)


func _on_potion_slot_unlocked(_category: String) -> void:
	if GameState.has_seen_tutorial("potion_menu"):
		return

	_show_prompt("MIX POTIONS\nP\n\nPOTION MAP\nO", "potion_menu")


func _on_modal_opened(panel_name: String) -> void:
	if panel_name != "potion" and panel_name != "potion_map":
		return

	if GameState.has_seen_tutorial("potion_menu"):
		return

	GameState.mark_tutorial_seen("potion_menu")

	if _active_id == "potion_menu":
		_dismiss_prompt()


func _on_potion_mix_changed() -> void:
	if not GameState.potion_charged:
		return

	if GameState.has_seen_tutorial("use_potion"):
		return

	_show_prompt("DRINK POTION\nG", "use_potion")


func _on_potion_used() -> void:
	if GameState.has_seen_tutorial("use_potion"):
		return

	GameState.mark_tutorial_seen("use_potion")

	if _active_id == "use_potion":
		_dismiss_prompt()


func _show_prompt(text: String, tutorial_id: String) -> void:
	_active_id = tutorial_id
	_label.text = text

	_panel.modulate.a = 0.0
	_panel.show()

	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, FADE_IN_DURATION)


func _dismiss_prompt() -> void:
	_active_id = ""

	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, FADE_OUT_DURATION)
	tween.tween_callback(_panel.hide)
