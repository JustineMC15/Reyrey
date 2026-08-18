extends CanvasLayer

@onready var root_panel: Control = $RootPanel
@onready var resume_button: Button = $RootPanel/VBox/Resume
@onready var save_exit_button: Button = $RootPanel/VBox/SaveAndExitToMenu
@onready var save_quit_button: Button = $RootPanel/VBox/SaveAndQuit

var is_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_panel.hide()

	resume_button.pressed.connect(close)
	save_exit_button.pressed.connect(_on_save_and_exit_to_menu)
	save_quit_button.pressed.connect(_on_save_and_quit)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if InventoryUI.is_open or not GameState.can_trigger_gate():
		return
	if get_tree().get_first_node_in_group("player") == null:
		return  # not in gameplay (e.g. still on the main menu)

	toggle()

func toggle() -> void:
	close() if is_open else open()

func open() -> void:
	is_open = true
	root_panel.show()
	get_tree().paused = true

func close() -> void:
	is_open = false
	root_panel.hide()
	get_tree().paused = false

func _autosave() -> void:
	if GameState.has_checkpoint():
		SaveManager.save_game(SaveManager.current_slot)

func _on_save_and_exit_to_menu() -> void:
	_autosave()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/nav/main_menu.tscn")

func _on_save_and_quit() -> void:
	_autosave()
	get_tree().quit()
