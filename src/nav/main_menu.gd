extends Control

const PANEL_FADE_DURATION := 0.2
const HEADER_FONT := preload("res://assets/fonts/Junicode.ttf")
const BODY_FONT := preload("res://assets/fonts/Seshat.otf")
@export var click_sound: AudioStream

@onready var title_label: Label = $Title

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var start_button: Button = $MainButtons/Start
@onready var options_button: Button = $MainButtons/Options
@onready var exit_button: Button = $MainButtons/Exit
@onready var save_slots_back_button: Button = $SaveSlotsPanel/Layout/Back
@onready var save_slots_panel: Control = $SaveSlotsPanel
@onready var save_slot_cards: Array[SaveSlotCard] = [
	$SaveSlotsPanel/Layout/CardRow/SaveSlotCard1,
	$SaveSlotsPanel/Layout/CardRow/SaveSlotCard2,
	$SaveSlotsPanel/Layout/CardRow/SaveSlotCard3,
	$SaveSlotsPanel/Layout/CardRow/SaveSlotCard4,
]

@onready var settings_panel: Control = $SettingsPanel
@onready var master_slider: HSlider = $SettingsPanel/Layout/MasterRow/MasterSlider
@onready var music_slider: HSlider = $SettingsPanel/Layout/MusicRow/MusicSlider
@onready var sound_slider: HSlider = $SettingsPanel/Layout/SoundRow/SoundSlider
@onready var settings_back_button: Button = $SettingsPanel/Layout/Back

var click_player: AudioStreamPlayer


func _ready() -> void:
	settings_panel.hide()
	settings_panel.modulate.a = 0.0

	save_slots_panel.hide()
	save_slots_panel.modulate.a = 0.0

	click_player = AudioStreamPlayer.new()
	click_player.bus = "SFX"
	add_child(click_player)

	if click_sound:
		click_player.stream = click_sound

	_setup_slot_cards()

	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_quit_pressed)
	settings_back_button.pressed.connect(_on_settings_back_pressed)
	save_slots_back_button.pressed.connect(_on_save_slots_back_pressed)
	master_slider.value = SaveManager.get_bus_volume(SaveManager.BUS_MASTER)
	music_slider.value = SaveManager.get_bus_volume(SaveManager.BUS_MUSIC)
	sound_slider.value = SaveManager.get_bus_volume(SaveManager.BUS_SFX)

	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sound_slider.value_changed.connect(_on_sound_volume_changed)

	Music.play_music(
		preload("res://assets/sound/music/Night Vigil.mp3")
	)


func _setup_slot_cards() -> void:
	for i in save_slot_cards.size():
		var slot := i + 1
		var card := save_slot_cards[i]

		if SaveManager.has_save(slot):
			card.setup_from_save(slot, SaveManager.get_slot_summary(slot))
		else:
			card.setup_empty(slot)

		card.picked.connect(_on_slot_picked)
		card.delete_requested.connect(_on_slot_delete_requested)
func _on_save_slots_back_pressed() -> void:
	_play_click()

	await _fade_out_panel(save_slots_panel)

	title_label.show()

	await _fade_in_panel(main_buttons)


func _on_slot_delete_requested(slot: int) -> void:
	_play_click()

	var overlay := _build_delete_confirmation(slot)
	add_child(overlay)

	await _fade_in_panel(overlay)


func _build_delete_confirmation(slot: int) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.6, 0.6, 1.0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)

	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Delete Slot %d?" % slot
	title.add_theme_font_override("font", HEADER_FONT)
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var body := Label.new()
	body.text = "This cannot be undone."
	body.add_theme_font_override("font", BODY_FONT)
	body.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(body)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	vbox.add_child(button_row)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.add_theme_font_override("font", BODY_FONT)
	cancel_button.custom_minimum_size = Vector2(110, 0)
	button_row.add_child(cancel_button)

	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.add_theme_font_override("font", BODY_FONT)
	delete_button.add_theme_color_override("font_color", Color(0.95, 0.45, 0.4))
	delete_button.add_theme_color_override("font_hover_color", Color(1.0, 0.55, 0.5))
	delete_button.custom_minimum_size = Vector2(110, 0)
	button_row.add_child(delete_button)

	cancel_button.pressed.connect(func():
		_play_click()
		_close_delete_confirmation(overlay)
	)

	delete_button.pressed.connect(func():
		_play_click()
		SaveManager.delete_save(slot)
		_refresh_slot_card(slot)
		_close_delete_confirmation(overlay)
	)

	return overlay


func _close_delete_confirmation(overlay: Control) -> void:
	await _fade_out_panel(overlay)
	overlay.queue_free()

func _refresh_slot_card(slot: int) -> void:
	var card := save_slot_cards[slot - 1]

	if SaveManager.has_save(slot):
		card.setup_from_save(slot, SaveManager.get_slot_summary(slot))
	else:
		card.setup_empty(slot)
func _play_click() -> void:
	if click_player.stream:
		click_player.play()


func _fade_out_panel(panel: Control) -> void:
	if panel == null or not panel.visible:
		return

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, PANEL_FADE_DURATION)
	await tween.finished

	panel.hide()


func _fade_in_panel(panel: Control) -> void:
	if panel == null:
		return

	panel.modulate.a = 0.0
	panel.show()

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, PANEL_FADE_DURATION)
	await tween.finished


func _on_start_pressed() -> void:
	_play_click()

	await _fade_out_panel(settings_panel)
	await _fade_out_panel(main_buttons)

	title_label.hide()

	await _fade_in_panel(save_slots_panel)


func _on_slot_picked(slot: int) -> void:
	SaveManager.current_slot = slot

	await LoadingScreen.show_loading()

	if SaveManager.has_save(slot):
		await SaveManager.load_game(slot)
	else:
		GameState.reset_to_defaults()
		GameState.prepare_new_game()

		get_tree().change_scene_to_file(
			"res://src/game/game.tscn"
		)


func _on_settings_pressed() -> void:
	_play_click()

	await _fade_out_panel(save_slots_panel)
	await _fade_out_panel(main_buttons)

	await _fade_in_panel(settings_panel)


func _on_settings_back_pressed() -> void:
	_play_click()

	await _fade_out_panel(settings_panel)

	title_label.show()

	await _fade_in_panel(main_buttons)


func _on_master_volume_changed(value: float) -> void:
	SaveManager.set_bus_volume(SaveManager.BUS_MASTER, value)


func _on_music_volume_changed(value: float) -> void:
	SaveManager.set_bus_volume(SaveManager.BUS_MUSIC, value)


func _on_sound_volume_changed(value: float) -> void:
	SaveManager.set_bus_volume(SaveManager.BUS_SFX, value)


func _on_quit_pressed() -> void:
	_play_click()
	get_tree().quit()
