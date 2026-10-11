class_name ColorMarker
extends RefCounted
## Colourblind aid: one distinct symbol per colour id, drawn over each unit of liquid.
## Symbols differ in silhouette (not just fill) so they stay readable at small sizes.

const SHAPES: Array[String] = [
	"circle", "triangle", "square", "diamond", "star", "cross",
	"x", "hexagon", "triangle_down", "ring", "bars", "pentagon",
]
const DARK_INK := Color("#12163a")


static func shape_for(color_id: int) -> String:
	return SHAPES[color_id % SHAPES.size()]


## Draws the symbol for `color_id` centred at `center` (`r` ~ half the symbol size) onto `canvas`.
## `base` is the liquid colour underneath: dark ink on light liquids, white on dark ones.
static func draw(canvas: CanvasItem, color_id: int, center: Vector2, r: float, base: Color) -> void:
	var on_light := base.get_luminance() > 0.5
	var ink := DARK_INK if on_light else Color.WHITE
	var edge := Color(1, 1, 1, 0.55) if on_light else Color(0.04, 0.06, 0.22, 0.6)
	var shape := shape_for(color_id)
	match shape:
		"circle":
			canvas.draw_circle(center, r * 0.85 + 1.5, edge)
			canvas.draw_circle(center, r * 0.85, ink)
		"ring":
			canvas.draw_arc(center, r * 0.75, 0.0, TAU, 28, edge, r * 0.34 + 3.0, true)
			canvas.draw_arc(center, r * 0.75, 0.0, TAU, 28, ink, r * 0.34, true)
		"cross":
			_stroke(canvas, center + Vector2(-r, 0), center + Vector2(r, 0), ink, edge, r * 0.42)
			_stroke(canvas, center + Vector2(0, -r), center + Vector2(0, r), ink, edge, r * 0.42)
		"x":
			var d := r * 0.8
			_stroke(canvas, center + Vector2(-d, -d), center + Vector2(d, d), ink, edge, r * 0.42)
			_stroke(canvas, center + Vector2(-d, d), center + Vector2(d, -d), ink, edge, r * 0.42)
		"bars":
			_stroke(canvas, center + Vector2(-r, -r * 0.45), center + Vector2(r, -r * 0.45), ink, edge, r * 0.4)
			_stroke(canvas, center + Vector2(-r, r * 0.45), center + Vector2(r, r * 0.45), ink, edge, r * 0.4)
		_:
			var pts := _polygon(shape, center, r)
			canvas.draw_colored_polygon(pts, ink)
			var outline := pts.duplicate()
			outline.append(pts[0])
			canvas.draw_polyline(outline, edge, 1.6, true)


static func _stroke(canvas: CanvasItem, a: Vector2, b: Vector2, ink: Color, edge: Color, width: float) -> void:
	canvas.draw_line(a, b, edge, width + 3.0, true)
	canvas.draw_line(a, b, ink, width, true)


static func _polygon(shape: String, c: Vector2, r: float) -> PackedVector2Array:
	match shape:
		"triangle":
			return _ngon(c + Vector2(0, r * 0.12), 3, r * 1.1, -PI * 0.5)
		"triangle_down":
			return _ngon(c - Vector2(0, r * 0.12), 3, r * 1.1, PI * 0.5)
		"square":
			return _ngon(c, 4, r * 1.2, PI * 0.25)
		"diamond":
			return PackedVector2Array([c + Vector2(0, -r * 1.25), c + Vector2(r * 0.9, 0),
				c + Vector2(0, r * 1.25), c + Vector2(-r * 0.9, 0)])
		"hexagon":
			return _ngon(c, 6, r * 1.1, 0.0)
		"pentagon":
			return _ngon(c, 5, r * 1.1, -PI * 0.5)
		"star":
			var pts := PackedVector2Array()
			for k in 10:
				var rad := r * 1.2 if k % 2 == 0 else r * 0.52
				pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * k / 10.0) * rad)
			return pts
	return PackedVector2Array()


static func _ngon(c: Vector2, sides: int, radius: float, rotation: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in sides:
		pts.append(c + Vector2.from_angle(rotation + TAU * k / sides) * radius)
	return pts
