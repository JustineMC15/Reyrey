@tool
extends Control
class_name TaperedLine

## Decorative separator: thin at both ends, thickest in the middle,
## instead of a plain full-width bar. Works as a vertical or
## horizontal divider depending on `orientation`.
##
## Everything is Inspector-editable and updates live in the 2D
## viewport (this script runs @tool): color, max thickness, and how
## sharply it pinches at the ends (taper_power — higher pinches
## thinner, closer to 1.0 spreads thickness more evenly along
## the line). Resize the node itself to change the line's length.

enum LineOrientation {
	VERTICAL,
	HORIZONTAL
}

@export var orientation: LineOrientation = LineOrientation.VERTICAL:
	set(value):
		orientation = value
		queue_redraw()

@export var line_color: Color = Color(1, 1, 1, 0.9):
	set(value):
		line_color = value
		queue_redraw()

@export_range(1.0, 20.0, 0.5) var max_thickness: float = 3.0:
	set(value):
		max_thickness = value
		queue_redraw()

@export_range(0.5, 4.0, 0.1) var taper_power: float = 1.5:
	set(value):
		taper_power = value
		queue_redraw()

@export_range(4, 64, 1) var segments: int = 24:
	set(value):
		segments = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var rect_size := size

	var length: float = (
		rect_size.y
		if orientation == LineOrientation.VERTICAL
		else rect_size.x
	)

	if length <= 0.0:
		return

	var near_edge: PackedVector2Array = []
	var far_edge: PackedVector2Array = []

	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var pos := t * length

		var taper := pow(sin(t * PI), taper_power)
		var half_thickness := (max_thickness * 0.5) * taper

		if orientation == LineOrientation.VERTICAL:
			near_edge.append(
				Vector2(
					rect_size.x * 0.5 - half_thickness,
					pos
				)
			)

			far_edge.append(
				Vector2(
					rect_size.x * 0.5 + half_thickness,
					pos
				)
			)
		else:
			near_edge.append(
				Vector2(
					pos,
					rect_size.y * 0.5 - half_thickness
				)
			)

			far_edge.append(
				Vector2(
					pos,
					rect_size.y * 0.5 + half_thickness
				)
			)

	far_edge.reverse()

	var polygon: PackedVector2Array = []
	polygon.append_array(near_edge)
	polygon.append_array(far_edge)

	draw_colored_polygon(polygon, line_color)
