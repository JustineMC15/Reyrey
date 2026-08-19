extends CanvasLayer

const FADE_DURATION := 0.2

@onready var root_panel: Control = $RootPanel
@onready var resume_button: Button = $RootPanel/VBox/Resume
@onready var save_exit_button: Button = $RootPanel/VBox/SaveAndExitToMenu
@onready var save_quit_button: Button = $RootPanel/VBox/SaveAndQuit

var is_open := false
var fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	resume_button.process_mode = Node.PROCESS_MODE_ALWAYS
	save_exit_button.process_mode = Node.PROCESS_MODE_ALWAYS
	save_quit_button.process_mode = Node.PROCESS_MODE_ALWAYS

	root_panel.hide()
	root_panel.modulate.a = 0.0

	resume_button.pressed.connect(close)
	save_exit_button.pressed.connect(_on_save_and_exit_to_menu)
	save_quit_button.pressed.connect(_on_save_and_quit)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if InventoryUI.is_open or not GameState.can_trigger_gate():
		return

	if get_tree().get_first_node_in_group("player") == null:
		return # Not in gameplay (e.g. still on the main menu)

	toggle()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	is_open = true
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
	get_tree().paused = false


func _autosave() -> void:
	if GameState.has_checkpoint():
		SaveManager.save_game(SaveManager.current_slot)


func _on_save_and_exit_to_menu() -> void:
	_autosave()
	close()
	get_tree().change_scene_to_file("res://src/nav/main_menu.tscn")


func _on_save_and_quit() -> void:
	_autosave()
	get_tree().quit()
