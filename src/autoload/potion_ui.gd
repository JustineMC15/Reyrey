extends CanvasLayer
# potion_ui.gd — autoload singleton "PotionUI"
#
# Left column: three sections, Survival / Combat / Utility, top to
# bottom. Locked slot -> placeholder. Unlocked slot -> every effect
# in that category, unlocked ones clickable, locked ones shown dim
# with their fragment cost so progression is visible.
#
# Right column: mixing station, one row per slot. Editing is gated
# on GameState.can_mix_potion() (checkpoint proximity); viewing the
# menu is always allowed.

const ICON_BUTTON_SCENE := preload("res://src/nav/inventory_icon_button.tscn")
const HEADER_FONT := preload("res://assets/fonts/Junicode.ttf")
const BODY_FONT := preload("res://assets/fonts/Seshat.otf")

const CATEGORY_LABELS := {
	"survival": "SURVIVAL",
	"combat": "COMBAT",
	"utility": "UTILITY",
}

const SELECTED_MODULATE := Color(1.3, 1.1, 0.6, 1.0)
const UNSELECTED_MODULATE := Color(1, 1, 1, 1)

var is_open := false

var root_panel: Control
var category_grids: Dictionary = {}     # category -> GridContainer
var slot_name_labels: Dictionary = {}   # category -> Label
var description_label: Label
var status_label: Label

var _effect_buttons: Dictionary = {}    # effect_id -> Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 305
	_build_ui()

	root_panel.hide()
	root_panel.modulate.a = 0.0

	GameState.potion_slot_unlocked.connect(func(_category): if is_open: _populate())
	GameState.potion_effect_unlocked.connect(func(_id): if is_open: _populate())
	GameState.potion_mix_changed.connect(func(): if is_open: _refresh_slots())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("potion_menu"):
		return

	if is_open:
		toggle()
		return

	if not GameState.can_trigger_gate() or InventoryUI.is_open or PauseMenu.is_open:
		return

	toggle()


func toggle() -> void:
	close() if is_open else open()


func open() -> void:
	is_open = true
	_populate()

	root_panel.show()
	get_tree().paused = true

	var tween := create_tween()
	tween.tween_property(root_panel, "modulate:a", 1.0, 0.15)


func close() -> void:
	is_open = false

	var tween := create_tween()
	tween.tween_property(root_panel, "modulate:a", 0.0, 0.15)
	tween.tween_callback(root_panel.hide)
	tween.tween_callback(func():
		get_tree().paused = false
	)


func _build_ui() -> void:
	root_panel = Control.new()
	root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_panel.add_child(dim)

	var frame := Control.new()
	frame.anchor_left = 0.1
	frame.anchor_top = 0.1
	frame.anchor_right = 0.9
	frame.anchor_bottom = 0.9
	root_panel.add_child(frame)

	var background := Panel.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(background)

	var title := Label.new()
	title.text = "WONDROUS STAR POTION"
	title.add_theme_font_override("font", HEADER_FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 12
	title.offset_bottom = 52
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(title)

	var layout := HBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_top = 60
	layout.offset_left = 24
	layout.offset_right = -24
	layout.offset_bottom = -24
	layout.add_theme_constant_override("separation", 24)
	frame.add_child(layout)

	# LEFT COLUMN — effects, Survival / Combat / Utility top to bottom
	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.size_flags_stretch_ratio = 3.0
	left_column.add_theme_constant_override("separation", 16)
	layout.add_child(left_column)

	for category in GameState.POTION_CATEGORIES:
		left_column.add_child(_build_category_section(category))

	# RIGHT COLUMN — mixing station
	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.size_flags_stretch_ratio = 2.0
	right_column.add_theme_constant_override("separation", 12)
	layout.add_child(right_column)

	var station_title := Label.new()
	station_title.text = "MIXING STATION"
	station_title.add_theme_font_override("font", HEADER_FONT)
	station_title.add_theme_font_size_override("font_size", 22)
	right_column.add_child(station_title)

	for category in GameState.POTION_CATEGORIES:
		right_column.add_child(_build_slot_row(category))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	right_column.add_child(spacer)

	description_label = Label.new()
	description_label.add_theme_font_override("font", BODY_FONT)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	description_label.custom_minimum_size = Vector2(0, 90)
	description_label.text = "Hover an effect to read what it does."
	right_column.add_child(description_label)

	status_label = Label.new()
	status_label.add_theme_font_override("font", BODY_FONT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	right_column.add_child(status_label)
	var clear_button := Button.new()
	clear_button.text = "CLEAR MIX"
	clear_button.add_theme_font_override("font", BODY_FONT)
	clear_button.pressed.connect(_on_clear_pressed)
	right_column.add_child(clear_button)

func _build_category_section(category: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)

	var header := Label.new()
	header.text = CATEGORY_LABELS[category]
	header.add_theme_font_override("font", HEADER_FONT)
	header.add_theme_font_size_override("font_size", 20)
	section.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	section.add_child(grid)

	category_grids[category] = grid

	return section


func _build_slot_row(category: String) -> PanelContainer:
	var row := PanelContainer.new()

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var header := Label.new()
	header.text = CATEGORY_LABELS[category]
	header.custom_minimum_size = Vector2(90, 0)
	header.add_theme_font_override("font", HEADER_FONT)
	header.add_theme_font_size_override("font_size", 16)
	hbox.add_child(header)

	var slot_label := Label.new()
	slot_label.text = "— locked —"
	slot_label.add_theme_font_override("font", BODY_FONT)
	slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slot_label)

	slot_name_labels[category] = slot_label

	return row


func _populate() -> void:
	_effect_buttons.clear()

	for category in category_grids.keys():
		var grid: GridContainer = category_grids[category]

		for child in grid.get_children():
			child.queue_free()

		if not GameState.is_potion_slot_unlocked(category):
			var locked_label := Label.new()
			locked_label.text = "Slot not yet found"
			locked_label.add_theme_font_override("font", BODY_FONT)
			locked_label.modulate.a = 0.4
			grid.add_child(locked_label)
			continue

		for effect_id in GameState.get_effects_for_category(category):
			var data: Dictionary = GameState.potion_effect_data.get(effect_id, {})

			if GameState.is_potion_effect_unlocked(effect_id):
				var button: InventoryIconButton = ICON_BUTTON_SCENE.instantiate()
				grid.add_child(button)

				button.setup(effect_id, null)  # TODO: real vial icons per effect
				button.hovered.connect(_on_effect_hovered)
				button.pressed.connect(_on_effect_pressed.bind(effect_id, category))

				_effect_buttons[effect_id] = button
			else:
				var cost: int = data.get("fragment_cost", 0)

				var locked_effect_label := Label.new()
				locked_effect_label.text = "%s — %d fragments" % [
					data.get("name", effect_id), cost
				]
				locked_effect_label.add_theme_font_override("font", BODY_FONT)
				locked_effect_label.modulate.a = 0.4
				grid.add_child(locked_effect_label)

	_refresh_slots()


func _on_effect_hovered(effect_id: String) -> void:
	var data: Dictionary = GameState.potion_effect_data.get(effect_id, {})
	description_label.text = data.get("description", "")


func _on_effect_pressed(effect_id: String, category: String) -> void:
	if not GameState.can_mix_potion():
		status_label.text = "Move closer to a checkpoint to mix."
		return

	var current: String = GameState.selected_potion_effects.get(category, "")

	if current == effect_id:
		GameState.set_selected_potion_effect(category, "")
	else:
		GameState.set_selected_potion_effect(category, effect_id)


func _refresh_slots() -> void:
	for category in slot_name_labels.keys():
		var label: Label = slot_name_labels[category]
		var selected_id: String = GameState.selected_potion_effects.get(category, "")

		if not GameState.is_potion_slot_unlocked(category):
			label.text = "— locked —"
		elif selected_id == "":
			label.text = "— empty —"
		else:
			var data: Dictionary = GameState.potion_effect_data.get(selected_id, {})
			label.text = data.get("name", selected_id)

	for effect_id in _effect_buttons.keys():
		var button: Button = _effect_buttons[effect_id]
		var data: Dictionary = GameState.potion_effect_data.get(effect_id, {})
		var category: String = data.get("category", "")
		var is_selected: bool = GameState.selected_potion_effects.get(category, "") == effect_id

		button.modulate = SELECTED_MODULATE if is_selected else UNSELECTED_MODULATE

	if not GameState.can_mix_potion():
		status_label.text = "Move closer to a checkpoint to mix. Your current mix still works."
	elif GameState.potion_charged:
		status_label.text = "Potion charged — drink it any time."
	else:
		status_label.text = "Select an effect per slot to mix."

func _on_clear_pressed() -> void:
	if not GameState.can_mix_potion():
		status_label.text = "Move closer to a checkpoint to clear the mix."
		return

	GameState.clear_potion_mix()
	status_label.text = "Mix cleared."
