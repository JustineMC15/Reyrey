extends CanvasLayer


@export var scripture_icons: Dictionary = {
	"double_jump": preload("res://assets/ui/scripture/scripture1.png"),
	"dash": preload("res://assets/ui/scripture/scripture2.png"),
	"ground_slam": preload("res://assets/ui/scripture/scripture3.png"),
	"glide": preload("res://assets/ui/scripture/scripture4.png"),
	"dash_chain": preload("res://assets/ui/scripture/scripture5.png"),
	"wall_cling": preload("res://assets/ui/scripture/scripture6.png"),
	"recall": preload("res://assets/ui/scripture/scripture7.png"),
	"ledge_grab": preload("res://assets/ui/scripture/scripture8.png"),
}  # ability_id -> Texture2D (grid sprite)
@export var ability_images: Dictionary = {}     # ability_id -> Texture2D (large illustration, NOT the sprite — spec requires a separate image here)
@export var shard_icon: Texture2D               # fallback Starlight Shard symbol
@export var shard_icons: Dictionary = {
	"shrine01": preload("res://assets/ui/shards/shard01.png"),
	"shrine02": preload("res://assets/ui/shards/shard02.png"),
	"shrine03": preload("res://assets/ui/shards/shard03.png"),
	"shrine04": preload("res://assets/ui/shards/shard04.png"),
	"shrine05": preload("res://assets/ui/shards/shard05.png")
} # Will use placeholder fallback shard for now while i work on 6-17
@export var sword_icon: Texture2D
@export var armor_icons: Dictionary = {
	0: preload("res://assets/ui/armor1.png"),
	1: preload("res://assets/ui/armor2.png"),
	2: preload("res://assets/ui/armor3.png"),
	3: preload("res://assets/ui/armor4.png"),
	4: preload("res://assets/ui/armor5.png"),
	5: preload("res://assets/ui/armor6.png")
}     # armor_tier (int) -> Texture2D
@export var star_fragment_icon: Texture2D
@export var icon_button_scene: PackedScene


const SWORD_DESCRIPTION := "Reyrey's blade, carried since before the road began.\n\nThe ancestral sword of House Valecourt, stolen by Reyrey and replaced with a normal-looking longsword.\n\n\"No one uses it anyways, why must it collect dust? I'm just borrowing it, until I get back home.\""
const SWORD_KEYBIND := "Mouse1 / F — Swing"
const SHARD_FLAVOR_HEADER := "Upon this shrine, the remnants of a star remain"

@onready var root_panel: Control = $RootPanel

@onready var scripture_grid: GridContainer = $RootPanel/MainFrame/Layout/MiddleColumn/ScripturesSection/ScriptureScroll/ScriptureGrid
@onready var shard_grid: GridContainer = $RootPanel/MainFrame/Layout/MiddleColumn/ShardsSection/ShardScroll/ShardGrid

@onready var sword_button: InventoryIconButton = $RootPanel/MainFrame/Layout/LeftColumn/SwordButton
@onready var armor_button: InventoryIconButton = $RootPanel/MainFrame/Layout/LeftColumn/ArmorButton
@onready var shard_currency_button: InventoryIconButton = $RootPanel/MainFrame/Layout/LeftColumn/ShardCurrencyButton

@onready var detail_name_top: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailNameTop
@onready var detail_icon: TextureRect = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailIcon
@onready var detail_name_bottom: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailNameBottom
@onready var detail_shard_header: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailScroll/DetailBody/DetailShardHeader
@onready var detail_description: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailScroll/DetailBody/DetailDescription
@onready var detail_keybind: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailScroll/DetailBody/DetailKeybind
@onready var detail_tin_header: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailScroll/DetailBody/DetailTinHeader
@onready var detail_tin_text: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailScroll/DetailBody/DetailTinText
@onready var detail_reynauld_header: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailScroll/DetailBody/DetailReynauldHeader
@onready var detail_reynauld_text: Label = $RootPanel/MainFrame/Layout/RightColumn/VBox/DetailVBox/DetailScroll/DetailBody/DetailReynauldText

var is_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	root_panel.hide()
	root_panel.modulate.a = 0.0

	sword_button.setup("sword", sword_icon)
	sword_button.hovered.connect(func(_id): _show_sword())

	armor_button.setup("armor", armor_icons.get(GameState.armor_tier))
	armor_button.hovered.connect(func(_id): _show_armor())

	shard_currency_button.setup("star_fragments", star_fragment_icon)
	shard_currency_button.hovered.connect(func(_id): _show_star_fragments())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("inventory"):
		return

	if is_open:
		toggle()
		return

	if not GameState.can_trigger_gate() or GameState.is_other_modal_open("inventory"):
		return

	toggle()


func toggle() -> void:
	close() if is_open else open()


func open() -> void:
	is_open = true
	GameState.register_modal_open("inventory")
	_populate()

	root_panel.show()
	get_tree().paused = true

	var tween := create_tween()
	tween.tween_property(root_panel, "modulate:a", 1.0, 0.15)

	sword_button.grab_focus()


func close() -> void:
	is_open = false
	GameState.register_modal_closed("inventory")

	get_viewport().gui_release_focus()

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

		var button := _spawn_icon(
			scripture_grid,
			ability_id,
			scripture_icons.get(ability_id)
		)
		button.hovered.connect(_show_scripture)

	var shard_ids := GameState.claimed_shrines.keys()

	shard_ids.sort_custom(func(a, b):
		return GameState.claimed_shrines[a].get("order", 0) < GameState.claimed_shrines[b].get("order", 0)
	)

	for shrine_id in shard_ids:
		var button := _spawn_icon(
			shard_grid,
			shrine_id,
			shard_icons.get(shrine_id, shard_icon)
		)
		button.hovered.connect(_show_shard)

	armor_button.icon_rect.texture = armor_icons.get(GameState.armor_tier)
	shard_currency_button.set_count(GameState.star_fragments)

	_wire_focus_neighbors()

	_show_sword()


func _spawn_icon(
	grid: GridContainer,
	id: String,
	icon: Texture2D
) -> InventoryIconButton:
	var button: InventoryIconButton = icon_button_scene.instantiate()

	grid.add_child(button)
	button.setup(id, icon)

	return button


func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()


# Godot's automatic geometric focus-neighbor detection breaks down
# across very different container types (freeform LeftColumn vs.
# scrolled grids) — this wires the important cross-boundary links by
# hand so arrow-key navigation is deterministic. Navigation *within*
# a single grid still relies on Godot's automatic system, since that
# works fine on a uniform grid.
func _wire_focus_neighbors() -> void:
	sword_button.focus_neighbor_bottom = sword_button.get_path_to(armor_button)
	armor_button.focus_neighbor_top = armor_button.get_path_to(sword_button)
	armor_button.focus_neighbor_bottom = armor_button.get_path_to(shard_currency_button)
	shard_currency_button.focus_neighbor_top = shard_currency_button.get_path_to(armor_button)

	var scripture_buttons := scripture_grid.get_children()
	var shard_buttons := shard_grid.get_children()

	var first_middle_button: Control = null

	if not scripture_buttons.is_empty():
		first_middle_button = scripture_buttons[0]
	elif not shard_buttons.is_empty():
		first_middle_button = shard_buttons[0]

	if first_middle_button:
		sword_button.focus_neighbor_right = sword_button.get_path_to(first_middle_button)
		armor_button.focus_neighbor_right = armor_button.get_path_to(first_middle_button)
		shard_currency_button.focus_neighbor_right = shard_currency_button.get_path_to(first_middle_button)
		first_middle_button.focus_neighbor_left = first_middle_button.get_path_to(armor_button)

	if not scripture_buttons.is_empty() and not shard_buttons.is_empty():
		var last_scripture: Control = scripture_buttons[scripture_buttons.size() - 1]
		var first_shard: Control = shard_buttons[0]

		last_scripture.focus_neighbor_bottom = last_scripture.get_path_to(first_shard)
		first_shard.focus_neighbor_top = first_shard.get_path_to(last_scripture)
		first_shard.focus_neighbor_left = first_shard.get_path_to(shard_currency_button)


func _clear_detail() -> void:
	detail_name_top.hide()
	detail_icon.hide()
	detail_name_bottom.hide()
	detail_shard_header.hide()
	detail_description.hide()
	detail_keybind.hide()
	detail_tin_header.hide()
	detail_tin_text.hide()
	detail_reynauld_header.hide()
	detail_reynauld_text.hide()


func _show_sword() -> void:
	_clear_detail()

	detail_name_top.text = "Sword"
	detail_name_top.show()

	detail_name_bottom.text = "Tidesplitter"
	detail_name_bottom.show()

	detail_description.text = SWORD_DESCRIPTION
	detail_description.show()

	detail_keybind.text = SWORD_KEYBIND
	detail_keybind.show()


func _show_armor() -> void:
	_clear_detail()

	var data := GameState.get_armor_data()
	var armor_name: String = data.get("name", "Armor")

	detail_name_top.text = "Armor"
	detail_name_top.show()

	detail_name_bottom.text = armor_name
	detail_name_bottom.show()

	detail_description.text = data.get("description", "")
	detail_description.show()


func _show_star_fragments() -> void:
	_clear_detail()

	detail_name_top.text = "Currency"
	detail_name_top.show()

	detail_name_bottom.text = "Star Fragments"
	detail_name_bottom.show()

	detail_description.text = "%d collected. Spent at shrines and anvils along the road." % GameState.star_fragments
	detail_description.show()


func _show_scripture(ability_id: String) -> void:
	_clear_detail()

	var data: Dictionary = GameState.ability_data.get(ability_id, {})

	detail_name_top.text = data.get("name", ability_id.capitalize())
	detail_name_top.show()

	# Deliberately NOT the grid sprite — spec calls for a separate
	# illustration. Falls back to the sprite until you assign one in
	# the Inspector, so nothing renders blank in the meantime.
	detail_icon.texture = ability_images.get(ability_id, scripture_icons.get(ability_id))
	detail_icon.show()

	detail_description.text = data.get("description", "")
	detail_description.show()

	var keybind_text := GameState.get_keybind_text(ability_id)

	if keybind_text != "":
		detail_keybind.text = keybind_text
		detail_keybind.show()

	if data.has("tin_text"):
		detail_tin_header.show()
		detail_tin_text.text = data["tin_text"]
		detail_tin_text.show()

	if data.has("reynauld_text"):
		detail_reynauld_header.show()
		detail_reynauld_text.text = data["reynauld_text"]
		detail_reynauld_text.show()


func _show_shard(shrine_id: String) -> void:
	_clear_detail()

	var shard_data: Dictionary = GameState.claimed_shrines.get(shrine_id, {})

	detail_icon.texture = shard_icons.get(shrine_id, shard_icon)
	detail_icon.show()

	detail_shard_header.text = SHARD_FLAVOR_HEADER
	detail_shard_header.show()

	detail_description.text = shard_data.get("text", "")
	detail_description.show()
