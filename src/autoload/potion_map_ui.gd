extends CanvasLayer
# potion_map_ui.gd — autoload singleton "PotionMapUI"
#
# Read-only progression map: a horizontally scrollable chain of
# every potion effect (box), connected by lines, ordered by
# ascending lifetime star fragment cost. A box's border and the line
# leading into it turn blue once enough fragments have been
# collected to unlock that effect.
#
# Deliberately a straight line for now — the categorized tree
# version is a later pass (see backlog). Opens only once the player
# has found at least one Wondrous Star Potion slot; otherwise there
# is nothing meaningful on the map yet.

const HEADER_FONT := preload("res://assets/fonts/Junicode.ttf")
const BODY_FONT := preload("res://assets/fonts/Seshat.otf")

const BOX_SIZE := Vector2(150, 170)
const LINE_WIDTH := 60.0
const LINE_HEIGHT := 6.0

const LOCKED_BORDER_COLOR := Color(0.4, 0.4, 0.4, 1.0)
const UNLOCKED_BORDER_COLOR := Color(0.35, 0.75, 1.0, 1.0)
const LOCKED_LINE_COLOR := Color(0.3, 0.3, 0.3, 1.0)
const UNLOCKED_LINE_COLOR := Color(0.35, 0.75, 1.0, 1.0)

var is_open := false

var root_panel: Control
var next_target_label: Label
var chain_row: HBoxContainer

var _box_styles: Dictionary = {}        # effect_id -> StyleBoxFlat (box border)
var _box_status_labels: Dictionary = {} # effect_id -> Label
var _line_rects: Dictionary = {}        # effect_id -> ColorRect (line leading INTO this effect)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 306
	_build_ui()

	root_panel.hide()
	root_panel.modulate.a = 0.0

	GameState.star_fragments_changed.connect(func(_amount): if is_open: _refresh())
	GameState.potion_effect_unlocked.connect(func(_id): if is_open: _refresh())
	GameState.potion_slot_unlocked.connect(func(_category): if is_open: _refresh())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("potion_map"):
		return

	if is_open:
		toggle()
		return

	if not GameState.has_any_potion_slot_unlocked():
		return

	if not GameState.can_trigger_gate() or GameState.is_other_modal_open("potion_map"):
		return

	toggle()


func toggle() -> void:
	close() if is_open else open()


func open() -> void:
	is_open = true
	GameState.register_modal_open("potion_map")
	_refresh()

	root_panel.show()
	get_tree().paused = true

	var tween := create_tween()
	tween.tween_property(root_panel, "modulate:a", 1.0, 0.15)


func close() -> void:
	is_open = false
	GameState.register_modal_closed("potion_map")

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
	frame.anchor_left = 0.08
	frame.anchor_top = 0.15
	frame.anchor_right = 0.92
	frame.anchor_bottom = 0.85
	root_panel.add_child(frame)

	var background := Panel.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(background)

	var title := Label.new()
	title.text = "POTION UNLOCK MAP"
	title.add_theme_font_override("font", HEADER_FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 10
	title.offset_bottom = 42
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(title)

	next_target_label = Label.new()
	next_target_label.add_theme_font_override("font", BODY_FONT)
	next_target_label.add_theme_font_size_override("font_size", 18)
	next_target_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	next_target_label.offset_top = 42
	next_target_label.offset_bottom = 68
	next_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(next_target_label)

	var scroll_container := ScrollContainer.new()
	scroll_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll_container.offset_top = 76
	scroll_container.offset_left = 24
	scroll_container.offset_right = -24
	scroll_container.offset_bottom = -24
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll_container)

	chain_row = HBoxContainer.new()
	chain_row.add_theme_constant_override("separation", 0)
	chain_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(chain_row)

	_build_chain()


func _build_chain() -> void:
	for child in chain_row.get_children():
		child.queue_free()

	_box_styles.clear()
	_box_status_labels.clear()
	_line_rects.clear()

	var effect_ids := GameState.get_potion_effects_by_progression()

	for i in effect_ids.size():
		var effect_id: String = effect_ids[i]

		if i > 0:
			chain_row.add_child(_build_line(effect_id))

		chain_row.add_child(_build_box(effect_id))


func _build_line(effect_id: String) -> Control:
	var wrap := CenterContainer.new()
	wrap.custom_minimum_size = Vector2(LINE_WIDTH, BOX_SIZE.y)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(LINE_WIDTH, LINE_HEIGHT)
	line.color = LOCKED_LINE_COLOR
	wrap.add_child(line)

	_line_rects[effect_id] = line

	return wrap


func _get_effect_icon(effect_id: String) -> Texture2D:
	return PotionUI.potion_effect_icons.get(effect_id, PotionUI.fallback_icon)


func _build_box(effect_id: String) -> PanelContainer:
	var data: Dictionary = GameState.potion_effect_data.get(effect_id, {})

	var panel := PanelContainer.new()
	panel.custom_minimum_size = BOX_SIZE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.05, 0.9)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = LOCKED_BORDER_COLOR
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var icon_rect := TextureRect.new()
	icon_rect.texture = _get_effect_icon(effect_id)
	icon_rect.custom_minimum_size = Vector2(0, 64)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(icon_rect)

	var name_label := Label.new()
	name_label.text = data.get("name", effect_id)
	name_label.add_theme_font_override("font", HEADER_FONT)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)

	var status_label := Label.new()
	status_label.add_theme_font_override("font", BODY_FONT)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(status_label)

	_box_styles[effect_id] = style
	_box_status_labels[effect_id] = status_label

	return panel


func _refresh() -> void:
	var effect_ids := GameState.get_potion_effects_by_progression()
	var next_locked_id := ""

	for effect_id in effect_ids:
		var data: Dictionary = GameState.potion_effect_data.get(effect_id, {})
		var cost: int = data.get("fragment_cost", 0)
		var unlocked: bool = GameState.is_potion_effect_unlocked(effect_id)

		var style: StyleBoxFlat = _box_styles[effect_id]
		style.border_color = UNLOCKED_BORDER_COLOR if unlocked else LOCKED_BORDER_COLOR

		var status_label: Label = _box_status_labels[effect_id]

		if unlocked:
			status_label.text = "UNLOCKED"
			status_label.modulate = UNLOCKED_BORDER_COLOR
		else:
			var remaining: int = max(0, cost - GameState.star_fragments)
			status_label.text = "%d / %d\n%d more needed" % [
				GameState.star_fragments, cost, remaining
			]
			status_label.modulate = Color(1, 1, 1, 0.7)

			if next_locked_id == "":
				next_locked_id = effect_id

		if _line_rects.has(effect_id):
			var line: ColorRect = _line_rects[effect_id]
			line.color = UNLOCKED_LINE_COLOR if unlocked else LOCKED_LINE_COLOR

	if next_locked_id == "":
		next_target_label.text = "All potion effects unlocked."
	else:
		var next_data: Dictionary = GameState.potion_effect_data.get(next_locked_id, {})
		var next_cost: int = next_data.get("fragment_cost", 0)
		var next_remaining: int = max(0, next_cost - GameState.star_fragments)

		next_target_label.text = "Next: %s — %d more fragments needed" % [
			next_data.get("name", next_locked_id), next_remaining
		]
