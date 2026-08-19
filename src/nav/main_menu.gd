extends Control

const SAVE_SLOT_COUNT := 4

@export var save_slot_card_scene: PackedScene

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var start_button: Button = $MainButtons/Start
@onready var options_button: Button = $MainButtons/Options
@onready var exit_button: Button = $MainButtons/Exit

@onready var save_slots: VBoxContainer = $VBox/SaveSlots
@onready var slot_container: HBoxContainer = $VBox/SaveSlots/SlotContainer

@onready var settings_panel: Control = $SettingsPanel
@onready var volume_slider: HSlider = $SettingsPanel/VolumeSlider


func _ready() -> void:
	settings_panel.hide()
	save_slots.hide()

	_build_slot_cards()

	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_quit_pressed)

	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	volume_slider.value_changed.connect(_on_volume_changed)


func _build_slot_cards() -> void:
	for child in slot_container.get_children():
		child.queue_free()

	for slot in range(1, SAVE_SLOT_COUNT + 1):
		var card: SaveSlotCard = save_slot_card_scene.instantiate()
		slot_container.add_child(card)

		if SaveManager.has_save(slot):
			card.setup_from_save(slot, SaveManager.get_slot_summary(slot))
		else:
			card.setup_empty(slot)

		card.picked.connect(_on_slot_picked)


func _on_start_pressed() -> void:
	# Reveal the save slot picker, hide the main buttons so it reads clean.
	settings_panel.hide()
	main_buttons.hide()
	save_slots.show()


func _on_slot_picked(slot: int) -> void:
	SaveManager.current_slot = slot

	if SaveManager.has_save(slot):
		await SaveManager.load_game(slot)
	else:
		GameState.reset_to_defaults()
		GameState.prepare_new_game()

		get_tree().change_scene_to_file(
			"res://src/game/game.tscn"
		)

func _on_settings_pressed() -> void:
	save_slots.hide()
	settings_panel.visible = not settings_panel.visible
	main_buttons.visible = not settings_panel.visible


func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(clampf(value, 0.0001, 1.0)))
	SaveManager.save_settings(value)


func _on_quit_pressed() -> void:
	get_tree().quit()
