extends RefCounted
class_name AreaPreviews


const PREVIEWS := {
	0: "res://assets/ui/save_previews/tutorial.png",
	1: "res://assets/ui/save_previews/valecourt.png",
	#2: "res://assets/ui/save_previews/cathedral.png",
	#3: "res://assets/ui/save_previews/coastal_road.png",
	#4: "res://assets/ui/save_previews/elven_reach.png",
	#5: "res://assets/ui/save_previews/thalassar.png",
	#6: "res://assets/ui/save_previews/aureth_bastion.png",
	#7: "res://assets/ui/save_previews/sahra_kel.png",
	#8: "res://assets/ui/save_previews/icefields.png",
	#9: "res://assets/ui/save_previews/tower.png",
}


const FALLBACK := "res://assets/ui/star_fragment.png"



static func get_preview_path(area_id: int) -> String:
	return PREVIEWS.get(area_id, FALLBACK)
