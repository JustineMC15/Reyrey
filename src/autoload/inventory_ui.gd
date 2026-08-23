extends CanvasLayer

@export var scripture_icons: Dictionary = {}    # ability_id -> Texture2D
@export var shard_icon: Texture2D               # fallback symbol
@export var shard_icons: Dictionary = {}        # shrine_id -> Texture2D, overrides shard_icon
@export var sword_icon: Texture2D
@export var armor_icons: Dictionary = {}        # armor_tier (int) -> Texture2D
@export var icon_button_scene: PackedScene

@onready var root_panel: Control = $RootPanel

@onready var scripture_grid: GridContainer = $RootPanel/MainFrame/Layout/MiddleColumn/ScripturesSection/ScriptureScroll/ScriptureGrid
@onready var shard_grid: GridContainer = $RootPanel/MainFrame/Layout/MiddleColumn/ShardsSection/ShardScroll/ShardGrid

@onready var sword_button: InventoryIconButton = $RootPanel/MainFrame/Layout/LeftColumn/SwordButton
@onready var armor_button: InventoryIconButton = $RootPanel/MainFrame/Layout/LeftColumn/ArmorButton
@onready var shard_currency_button: InventoryIconButton = $RootPanel/MainFrame/Layout/LeftColumn/ShardCurrencyButton

@onready var detail_icon: TextureRect = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailIcon
@onready var detail_name: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailName
@onready var detail_keybind: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailKeybind
@onready var detail_tin_text: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailScroll/DetailBody/DetailTinText
@onready var detail_reynauld_text: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailScroll/DetailBody/DetailReynauldText
var is_open := false
var _selected_button: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	root_panel.hide()
	root_panel.modulate.a = 0.0

	sword_button.setup("sword", sword_icon)
	sword_button.picked.connect(func(_id):
		_select(sword_button)
		_show_sword()
	)

	armor_button.setup("armor", armor_icons.get(GameState.armor_tier))
	armor_button.picked.connect(func(_id):
		_select(armor_button)
		_show_armor()
	)

	shard_currency_button.setup("shard_currency", null)
	shard_currency_button.disabled = true  # TODO: enable once currency exists


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("inventory"):
		return

	if is_open:
		toggle()
		return

	if not GameState.can_trigger_gate() or PauseMenu.is_open:
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


func _populate() -> void:
	_clear_grid(scripture_grid)
	_clear_grid(shard_grid)

	for ability_id in GameState.abilities.keys():
		if not GameState.has_ability(ability_id):
			continue

		_spawn_icon(
			scripture_grid,
			ability_id,
			scripture_icons.get(ability_id),
			_show_scripture
		)

	var shard_ids := GameState.claimed_shrines.keys()

	shard_ids.sort_custom(func(a, b):
		return GameState.claimed_shrines[a].get("order", 0) < GameState.claimed_shrines[b].get("order", 0)
	)

	for shrine_id in shard_ids:
		_spawn_icon(
			shard_grid,
			shrine_id,
			shard_icons.get(shrine_id, shard_icon),
			_show_shard
		)

	armor_button.icon_rect.texture = armor_icons.get(GameState.armor_tier)

	_show_sword()


func _spawn_icon(
	grid: GridContainer,
	id: String,
	icon: Texture2D,
	on_picked: Callable
) -> void:
	var button: InventoryIconButton = icon_button_scene.instantiate()

	grid.add_child(button)

	button.setup(id, icon)

	button.picked.connect(func(picked_id):
		_select(button)
		on_picked.call(picked_id)
	)


func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()


func _select(button: Node) -> void:
	if _selected_button:
		_selected_button.set_selected(false)

	_selected_button = button

	if button:
		button.set_selected(true)


func _set_detail_text(tin_text: String, reynauld_text: String = "") -> void:
	detail_tin_text.text = tin_text
	detail_reynauld_text.text = reynauld_text

	detail_tin_text.visible = tin_text != ""
	detail_reynauld_text.visible = reynauld_text != ""


func _show_sword() -> void:
	_select(sword_button)

	detail_icon.texture = sword_icon
	detail_name.text = "Sword"
	detail_keybind.hide()

	_set_detail_text(
		"Reyrey's blade, carried since before the road began."
	)


func _show_armor() -> void:
	_select(armor_button)

	var data := GameState.get_armor_data()

	detail_icon.texture = armor_button.icon_rect.texture
	detail_name.text = data.get("name", "Armor")
	detail_keybind.hide()

	_set_detail_text(
		data.get("description", "")
	)


func _show_scripture(ability_id: String) -> void:
	var data: Dictionary = GameState.ability_data.get(ability_id, {})

	detail_icon.texture = scripture_icons.get(ability_id)
	detail_name.text = data.get("name", ability_id.capitalize())

	var keybind_text := GameState.get_keybind_text(ability_id)

	detail_keybind.text = keybind_text
	detail_keybind.visible = keybind_text != ""

	var tin_text := ""
	var reynauld_text := ""

	if data.has("tin_text"):
		tin_text = data["tin_text"]

	if data.has("reynauld_text"):
		reynauld_text = data["reynauld_text"]

	_set_detail_text(tin_text, reynauld_text)


func _show_shard(shrine_id: String) -> void:
	var shard_data: Dictionary = GameState.claimed_shrines.get(shrine_id, {})
	var order: int = shard_data.get("order", 0)

	detail_icon.texture = shard_icons.get(shrine_id, shard_icon)
	detail_name.text = "Starlight Shard %d" % (order + 1)
	detail_keybind.hide()

	_set_detail_text(
		shard_data.get("text", "")
	)
