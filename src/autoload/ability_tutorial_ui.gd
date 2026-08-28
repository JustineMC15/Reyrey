extends CanvasLayer
# ability_tutorial_ui.gd — autoload singleton "AbilityTutorialUI"
#
# When GameState grants a movement ability, this watches to see
# whether the player actually uses it. If NO_USE_GRACE_PERIOD
# seconds pass with the ability unused, a small tutorial_ui-style
# prompt fades in showing the ability's name and keybind, and stays
# up until the ability is used. Each ability only ever gets this
# treatment once per save file — tracked through GameState's
# existing tutorials_seen dictionary, keyed by ability_id, reusing
# the same "seen" bookkeeping as the movement/jump/attack tutorials.

const NO_USE_GRACE_PERIOD := 5.0
const FADE_IN_DURATION := 0.25
const FADE_OUT_DURATION := 0.25
const TUTORIAL_FONT := preload("res://assets/fonts/Seshat.otf")

const TRACKED_ABILITIES := [
	"double_jump",
	"dash",
	"dash_chain",
	"ground_slam",
	"glide",
	"wall_cling",
	"ledge_grab",
	"recall",
]

var _panel: Panel
var _label: Label

var _active_ability_id: String = ""
var _pending_queue: Array[String] = []
var _player: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200

	_build_ui()

	GameState.ability_claimed.connect(_on_ability_claimed)


func _build_ui() -> void:
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -200.0
	_panel.offset_right = 200.0
	_panel.offset_top = 176.0
	_panel.offset_bottom = 326.0

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


func _on_ability_claimed(ability_id: String) -> void:
	if not TRACKED_ABILITIES.has(ability_id):
		return

	if GameState.has_seen_tutorial(ability_id):
		return

	_player = get_tree().get_first_node_in_group("player")

	if _player == null:
		return

	if not _player.ability_used.is_connected(_on_player_ability_used):
		_player.ability_used.connect(_on_player_ability_used)

	var timer := get_tree().create_timer(NO_USE_GRACE_PERIOD)
	timer.timeout.connect(_on_grace_timeout.bind(ability_id))


func _on_grace_timeout(ability_id: String) -> void:
	if GameState.has_seen_tutorial(ability_id):
		return

	if _active_ability_id == "":
		_show_prompt(ability_id)
	elif not _pending_queue.has(ability_id):
		_pending_queue.append(ability_id)


func _show_prompt(ability_id: String) -> void:
	_active_ability_id = ability_id

	var data: Dictionary = GameState.ability_data.get(ability_id, {})
	var ability_name: String = data.get("name", ability_id.capitalize())
	var keybind_text := GameState.get_keybind_text(ability_id)

	_label.text = ability_name.to_upper()

	if keybind_text != "":
		_label.text += "\n" + keybind_text

	_panel.modulate.a = 0.0
	_panel.show()

	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, FADE_IN_DURATION)


func _on_player_ability_used(ability_id: String) -> void:
	if not TRACKED_ABILITIES.has(ability_id):
		return

	if GameState.has_seen_tutorial(ability_id):
		return

	GameState.mark_tutorial_seen(ability_id)
	_pending_queue.erase(ability_id)

	if ability_id == _active_ability_id:
		_dismiss_prompt()


func _dismiss_prompt() -> void:
	_active_ability_id = ""

	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, FADE_OUT_DURATION)
	tween.tween_callback(_panel.hide)
	tween.tween_callback(_show_next_pending)


func _show_next_pending() -> void:
	if _pending_queue.is_empty():
		return

	var next_id: String = _pending_queue.pop_front()

	if GameState.has_seen_tutorial(next_id):
		_show_next_pending()
		return

	_show_prompt(next_id)
