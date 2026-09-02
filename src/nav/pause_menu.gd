extends CanvasLayer

const FADE_DURATION := 0.2

## Drop your button-press SFX here once you have it — every menu
## navigation button plays it before tweening to the next panel.
@export var click_sound: AudioStream

@onready var root_panel: Control = $RootPanel
@onready var resume_button: Button = $RootPanel/VBox/Resume
@onready var settings_button: Button = $RootPanel/VBox/Settings
@onready var save_exit_button: Button = $RootPanel/VBox/SaveAndExitToMenu
@onready var save_quit_button: Button = $RootPanel/VBox/SaveAndQuit

@onready var settings_panel: Control = $SettingsPanel
@onready var master_slider: HSlider = $SettingsPanel/VBox/MasterRow/MasterSlider
@onready var music_slider: HSlider = $SettingsPanel/VBox/MusicRow/MusicSlider
@onready var sound_slider: HSlider = $SettingsPanel/VBox/SoundRow/SoundSlider
@onready var settings_back_button: Button = $SettingsPanel/VBox/Back

var click_player: AudioStreamPlayer

var is_open := false
var fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	root_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	resume_button.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_button.process_mode = Node.PROCESS_MODE_ALWAYS
	save_exit_button.process_mode = Node.PROCESS_MODE_ALWAYS
	save_quit_button.process_mode = Node.PROCESS_MODE_ALWAYS

	master_slider.process_mode = Node.PROCESS_MODE_ALWAYS
	music_slider.process_mode = Node.PROCESS_MODE_ALWAYS
	sound_slider.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_back_button.process_mode = Node.PROCESS_MODE_ALWAYS

	root_panel.hide()
	root_panel.modulate.a = 0.0

	settings_panel.hide()
	settings_panel.modulate.a = 0.0

	click_player = AudioStreamPlayer.new()
	click_player.process_mode = Node.PROCESS_MODE_ALWAYS
	click_player.bus = "SFX"
	add_child(click_player)

	if click_sound:
		click_player.stream = click_sound

	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_back_button.pressed.connect(_on_settings_back_pressed)
	save_exit_button.pressed.connect(_on_save_and_exit_to_menu)
	save_quit_button.pressed.connect(_on_save_and_quit)

	master_slider.value = SaveManager.get_bus_volume(SaveManager.BUS_MASTER)
	music_slider.value = SaveManager.get_bus_volume(SaveManager.BUS_MUSIC)
	sound_slider.value = SaveManager.get_bus_volume(SaveManager.BUS_SFX)

	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sound_slider.value_changed.connect(_on_sound_volume_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if get_tree().get_first_node_in_group("player") == null:
		return

	if settings_panel.visible:
		_on_settings_back_pressed()
		return

	if is_open:
		toggle()
		return

	if not GameState.can_trigger_gate() or GameState.is_other_modal_open("pause"):
		return

	toggle()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	is_open = true
	GameState.register_modal_open("pause")

	root_panel.show()
	root_panel.modulate.a = 0.0

	if fade_tween:
		fade_tween.kill()

	get_tree().paused = true

	fade_tween = create_tween()
	fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_tween.tween_property(
		root_panel,
		"modulate:a",
		1.0,
		FADE_DURATION
	)


func close() -> void:
	is_open = false
	GameState.register_modal_closed("pause")

	if fade_tween:
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_tween.tween_property(
		root_panel,
		"modulate:a",
		0.0,
		FADE_DURATION
	)

	fade_tween.tween_callback(_finish_close)


func _finish_close() -> void:
	root_panel.hide()
	settings_panel.hide()
	settings_panel.modulate.a = 0.0
	get_tree().paused = false


func _play_click() -> void:
	if click_player.stream:
		click_player.play()


func _on_resume_pressed() -> void:
	_play_click()
	close()


func _on_settings_pressed() -> void:
	_play_click()
	_swap_panels(root_panel, settings_panel)


func _on_settings_back_pressed() -> void:
	_play_click()
	_swap_panels(settings_panel, root_panel)


func _swap_panels(panel_out: Control, panel_in: Control) -> void:
	var tween_out := create_tween()
	tween_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_out.tween_property(panel_out, "modulate:a", 0.0, FADE_DURATION)
	await tween_out.finished

	panel_out.hide()

	panel_in.modulate.a = 0.0
	panel_in.show()

	var tween_in := create_tween()
	tween_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_in.tween_property(panel_in, "modulate:a", 1.0, FADE_DURATION)
	await tween_in.finished


func _autosave() -> void:
	if GameState.has_checkpoint():
		SaveManager.save_game(SaveManager.current_slot)


func _on_save_and_exit_to_menu() -> void:
	_play_click()
	_autosave()

	if fade_tween:
		fade_tween.kill()

	is_open = false
	GameState.register_modal_closed("pause")
	root_panel.hide()
	settings_panel.hide()
	get_tree().paused = false

	get_tree().change_scene_to_file("res://src/nav/main_menu.tscn")


func _on_save_and_quit() -> void:
	_play_click()
	_autosave()
	get_tree().quit()


func _on_master_volume_changed(value: float) -> void:
	SaveManager.set_bus_volume(SaveManager.BUS_MASTER, value)


func _on_music_volume_changed(value: float) -> void:
	SaveManager.set_bus_volume(SaveManager.BUS_MUSIC, value)


func _on_sound_volume_changed(value: float) -> void:
	SaveManager.set_bus_volume(SaveManager.BUS_SFX, value)
