extends RefCounted
class_name AreaPreviews


const PREVIEWS := {
	"res://src/Rooms/room_01-tutorial.tscn": "res://assets/ui/save_previews/tutorial.png",
	"res://src/Rooms/room_02-valecourt-fields": "res://assets/ui/save_previews/valecourt.png",
}


const FALLBACK := "res://assets/ui/save_previews/unknown.png"

static func get_preview_path(checkpoint_scene_path: String) -> String:
	return PREVIEWS.get(checkpoint_scene_path, FALLBACK)
