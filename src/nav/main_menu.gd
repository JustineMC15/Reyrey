extends Control

const PANEL_FADE_DURATION := 0.2

## Drop your button-press SFX here once you have it — every menu
## navigation button plays it before tweening to the next panel.
@export var click_sound: AudioStream

@onready var title_label: Label = $Title

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var start_button: Button = $MainButtons/Start
@onready var options_button: Button = $MainButtons/Options
@onready var exit_button: Button = $MainButtons/Exit

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
